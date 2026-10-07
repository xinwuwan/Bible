#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ingest_egw.py — 怀爱伦(EGW)生前 PD 单篇采集 / 切片 / 向量化（P0 法务重汇编）
==============================================================================
权威来源 : Ellen G. White 生前发表(卒于 1915)且美区 Public Domain 的英文原版。
落库目标 : egw_work / egw_paragraph / content_chunk(向量)
依赖     : psycopg[binary], sentence-transformers, pgvector, embed_util.py

合规红线（务必遵守）:
  1. 仅采集 EGW 生前发表、美区 PD 的英文原版文本；
  2. 禁止采集任何语言译本、现代带版权版本、身后 White Estate 汇编整本(Tier 2)；
  3. work.pd_confirmed 默认 False，须经法务裁定后由顾问置 True 方可发布；
  4. 英联邦等其它法域版权规则不同，全球分发须另行评估。

输入 JSON 期望结构:
{
  "work_id": "SC", "title_en": "Steps to Christ", "year": 1892,
  "paragraphs": [
    {"chapter": 1, "paragraph": 1, "text": "..."},
    {"chapter": 1, "paragraph": 2, "text": "..."}
  ]
}
也可用 --text 模式读纯文本（每段以空行分隔，章节用 "# Chapter N" 标记）。

source_id 约定: "EGW-" + work_id + "-p" + 全局段号   例: "EGW-SC-p45"
ref      约定: "{work_id} ch{chapter} p{paragraph}"（无章节时仅 p{paragraph}）
"""

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from typing import List, Optional, Tuple

from embed_util import EMBED_DIM, chunk_text, embed_texts, pgvector_literal

DB_URL = os.getenv("DATABASE_URL", "postgresql://app:app@localhost:5432/faith_app")

# 建议采集的 EGW 生前 PD 著作(美区；卒于1915→美国版权已过期)。
# 此为初判清单，pd_confirmed 须经法务裁定；身后汇编(Tier 2, 如 Counsels on Diet and Foods 1938)
# 整本不在此列，改由顾问按主题从这些生前 PD 单篇重新汇编。
SUGGESTED_WORKS: List[Tuple[str, str, int]] = [
    ("SC",   "Steps to Christ", 1892),
    ("GC",   "The Great Controversy", 1888),
    ("PP",   "Patriarchs and Prophets", 1890),
    ("DA",   "The Desire of Ages", 1898),
    ("COL",  "Christ's Object Lessons", 1900),
    ("ED",   "Education", 1903),
    ("MHB",  "Thoughts From the Mount of Blessing", 1896),
    ("MH",   "The Ministry of Healing", 1905),
    ("AA",   "The Acts of the Apostles", 1911),
    ("EW",   "Early Writings", 1882),
    ("SL",   "The Sanctified Life", 1889),
    ("SOP1", "The Spirit of Prophecy, Vol 1", 1870),
    ("SOP2", "The Spirit of Prophecy, Vol 2", 1877),
    ("SOP3", "The Spirit of Prophecy, Vol 3", 1878),
    ("SOP4", "The Spirit of Prophecy, Vol 4", 1884),
]


@dataclass
class Paragraph:
    work_id: str
    chapter: Optional[int]
    paragraph: int
    global_no: int
    text: str

    @property
    def source_id(self) -> str:
        return f"EGW-{self.work_id}-p{self.global_no}"

    @property
    def ref(self) -> str:
        ch = f"ch{self.chapter} " if self.chapter else ""
        return f"{self.work_id} {ch}p{self.paragraph}"


def load_egw_json(path: str) -> Tuple[dict, List[Paragraph]]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    paras: List[Paragraph] = []
    for gi, p in enumerate(data.get("paragraphs", []), start=1):
        paras.append(Paragraph(
            work_id=str(data["work_id"]).upper(),
            chapter=p.get("chapter"),
            paragraph=int(p.get("paragraph", gi)),
            global_no=gi,
            text=str(p["text"]).strip(),
        ))
    if not paras:
        raise ValueError("paragraphs 为空")
    meta = {"work_id": str(data["work_id"]).upper(),
            "title_en": data.get("title_en", ""), "year": data.get("year")}
    return meta, paras


def load_egw_text(path: str, work_id: str, title: str, year: int) -> List[Paragraph]:
    with open(path, "r", encoding="utf-8") as f:
        raw = f.read()
    paras: List[Paragraph] = []
    cur_chapter: Optional[int] = None
    gi = 0
    for blk in re.split(r"\n\s*\n", raw):
        blk = blk.strip()
        if not blk:
            continue
        m = re.match(r"^#+\s*Chapter\s+(\d+)", blk, re.IGNORECASE)
        if m:
            cur_chapter = int(m.group(1))
            blk = re.sub(r"^#+\s*Chapter\s+\d+.*(\n|$)", "", blk, flags=re.IGNORECASE).strip()
            if not blk:
                continue
        gi += 1
        paras.append(Paragraph(
            work_id=str(work_id).upper(), chapter=cur_chapter,
            paragraph=gi, global_no=gi, text=blk,
        ))
    if not paras:
        raise ValueError("纯文本未解析出段落")
    return paras


def seed_work(conn, work_id: str, title_en: str, year, tier: int = 1) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """INSERT INTO egw_work (work_id, title_en, year, tier, pd_confirmed)
               VALUES (%s,%s,%s,%s,false)
               ON CONFLICT (work_id) DO NOTHING""",
            (work_id, title_en, year, tier),
        )
    conn.commit()


def insert_paragraphs(conn, paras: List[Paragraph],
                      embeddings: Optional[List[List[float]]]) -> None:
    work_id = paras[0].work_id if paras else None
    with conn.cursor() as cur:
        # 幂等：重跑前清除该 work 已有的 EGW chunks（段落本身用 ON CONFLICT 去重）
        if work_id:
            cur.execute(
                "DELETE FROM content_chunk WHERE source_type='EGW' AND source_id LIKE %s",
                (f"EGW-{work_id}-p%",),
            )
        for idx, p in enumerate(paras):
            cur.execute(
                """INSERT INTO egw_paragraph (work_id, chapter_no, paragraph_no, en_text)
                   VALUES (%s,%s,%s,%s)
                   ON CONFLICT (work_id, chapter_no, paragraph_no) DO NOTHING""",
                (p.work_id, p.chapter, p.paragraph, p.text),
            )
            vec = embeddings[idx] if embeddings else None
            chunks = chunk_text(p.text)
            for ci, chunk in enumerate(chunks):
                sid = p.source_id if len(chunks) == 1 else f"{p.source_id}#{ci}"
                emb_lit = pgvector_literal(vec) if vec is not None else None
                cur.execute(
                    """INSERT INTO content_chunk (source_type, source_id, ref, chunk_text, embedding)
                       VALUES ('EGW', %s, %s, %s, %s::vector)""",
                    (sid, p.ref, chunk, emb_lit),
                )
    conn.commit()


def main() -> int:
    ap = argparse.ArgumentParser(description="EGW 生前 PD 单篇采集 / 向量化骨架")
    ap.add_argument("--input", help="EGW JSON 路径")
    ap.add_argument("--text", help="EGW 纯文本路径(空行分段, '# Chapter N' 标章节)")
    ap.add_argument("--work-id", help="纯文本模式的 work_id")
    ap.add_argument("--title", help="纯文本模式的标题")
    ap.add_argument("--year", type=int, help="纯文本模式的出版年")
    ap.add_argument("--list-works", action="store_true", help="打印建议采集的生前 PD 著作清单")
    ap.add_argument("--skip-embed", action="store_true", help="仅入库不生成向量")
    ap.add_argument("--db-url", default=DB_URL, help="PostgreSQL 连接串")
    args = ap.parse_args()

    if args.list_works:
        print("建议采集的 EGW 生前 PD 著作(美区, 须法务裁定 pd_confirmed):")
        for wid, title, yr in SUGGESTED_WORKS:
            print(f"  {wid:5} {yr}  {title}")
        return 0

    if not args.input and not args.text:
        ap.error("需提供 --input(JSON) 或 --text(纯文本)")

    try:
        import psycopg
    except ImportError:
        print("[错误] 未安装 psycopg，请先 pip install 'psycopg[binary]'", file=sys.stderr)
        return 2

    # 解析输入
    if args.input:
        meta, paras = load_egw_json(args.input)
        work_id, title_en, year = meta["work_id"], meta["title_en"], meta.get("year")
    else:
        if not (args.work_id and args.title and args.year):
            ap.error("纯文本模式需同时提供 --work-id/--title/--year")
        paras = load_egw_text(args.text, args.work_id, args.title, args.year)
        work_id, title_en, year = args.work_id.upper(), args.title, args.year

    # 合规提醒：不在建议清单中的 work 需额外谨慎
    if work_id not in {w[0] for w in SUGGESTED_WORKS}:
        print(f"[警告] work_id={work_id} 不在内置生前 PD 建议清单，请确认其 PD 状态与法务裁定。",
              file=sys.stderr)

    print(f"[信息] 解析到 {len(paras)} 段 (work={work_id})")

    embeddings = None
    if not args.skip_embed:
        embeddings = embed_texts([p.text for p in paras])
        if embeddings and len(embeddings[0]) != EMBED_DIM:
            print(f"[错误] 模型维度 {len(embeddings[0])} != 期望 {EMBED_DIM}，"
                  f"请调整 001_init_schema.sql 的 VECTOR({EMBED_DIM})", file=sys.stderr)
            return 3

    conn = psycopg.connect(args.db_url)
    try:
        seed_work(conn, work_id, title_en, year, tier=1)
        insert_paragraphs(conn, paras, embeddings)
    finally:
        conn.close()

    print(f"[完成] work={work_id} 已写入 egw_paragraph({len(paras)}) + content_chunk")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
