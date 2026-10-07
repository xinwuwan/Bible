#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ingest_kjv.py — KJV 逐节入库 + 切片 + 向量化（M1 数据层采集骨架）
=====================================================================
权威来源 : King James Version (1769 Blayney text, 美区 Public Domain)
落库目标 : bible_book(种子) / bible_verse_kjv / content_chunk(向量)
依赖     : psycopg[binary], sentence-transformers, pgvector

重要约定:
  - 仅索引权威原文(英文)到 content_chunk；中文译文走 bible_verse_zh，本脚本不生成译文。
  - embedding 维度必须与 001_init_schema.sql 中 content_chunk.embedding(VECTOR(512)) 一致。
  - 本脚本为"骨架"，需自行准备 KJV 文本(JSON) 与可运行 embedding 环境。

输入 JSON 期望两种结构之一:
  结构A: [{"book":"JHN","chapter":3,"verse":16,"text":"For God so loved..."}, ...]
  结构B: {"books":[{"code":"JHN","name":"John",
                    "chapters":[{"chapter":3,"verses":[{"verse":16,"text":"..."}]}]}]}

source_id 约定: "KJV-" + ref.replace(" ", "")  例如 "KJV-JHN3:16"
"""

import argparse
import json
import os
import sys
from dataclasses import dataclass
from typing import List, Optional

# --------------------------- 配置 ---------------------------
DB_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://app:app@localhost:5432/faith_app",
)
EMBED_MODEL = os.getenv("EMBEDDING_MODEL", "BAAI/bge-small-zh-v1.5")
EMBED_DIM = 512  # 须与 content_chunk.embedding 维度一致

# ----------------- KJV 66 卷元数据(事实清单, 公共领域) -----------------
# (code, name_en, name_zh, testament, chapter_count)
BOOKS = [
    ("GEN", "Genesis", "创世记", "OT", 50), ("EXO", "Exodus", "出埃及记", "OT", 40),
    ("LEV", "Leviticus", "利未记", "OT", 27), ("NUM", "Numbers", "民数记", "OT", 36),
    ("DEU", "Deuteronomy", "申命记", "OT", 34), ("JOS", "Joshua", "约书亚记", "OT", 24),
    ("JDG", "Judges", "士师记", "OT", 21), ("RUT", "Ruth", "路得记", "OT", 4),
    ("1SA", "1 Samuel", "撒母耳记上", "OT", 31), ("2SA", "2 Samuel", "撒母耳记下", "OT", 24),
    ("1KI", "1 Kings", "列王纪上", "OT", 22), ("2KI", "2 Kings", "列王纪下", "OT", 25),
    ("1CH", "1 Chronicles", "历代志上", "OT", 29), ("2CH", "2 Chronicles", "历代志下", "OT", 36),
    ("EZR", "Ezra", "以斯拉记", "OT", 10), ("NEH", "Nehemiah", "尼希米记", "OT", 13),
    ("EST", "Esther", "以斯帖记", "OT", 10), ("JOB", "Job", "约伯记", "OT", 42),
    ("PSA", "Psalms", "诗篇", "OT", 150), ("PRO", "Proverbs", "箴言", "OT", 31),
    ("ECC", "Ecclesiastes", "传道书", "OT", 12), ("SNG", "Song of Solomon", "雅歌", "OT", 8),
    ("ISA", "Isaiah", "以赛亚书", "OT", 66), ("JER", "Jeremiah", "耶利米书", "OT", 52),
    ("LAM", "Lamentations", "耶利米哀歌", "OT", 5), ("EZK", "Ezekiel", "以西结书", "OT", 48),
    ("DAN", "Daniel", "但以理书", "OT", 12), ("HOS", "Hosea", "何西阿书", "OT", 14),
    ("JOL", "Joel", "约珥书", "OT", 3), ("AMO", "Amos", "阿摩司书", "OT", 9),
    ("OBA", "Obadiah", "俄巴底亚书", "OT", 1), ("JON", "Jonah", "约拿书", "OT", 4),
    ("MIC", "Micah", "弥迦书", "OT", 7), ("NAM", "Nahum", "那鸿书", "OT", 3),
    ("HAB", "Habakkuk", "哈巴谷书", "OT", 3), ("ZEP", "Zephaniah", "西番雅书", "OT", 3),
    ("HAG", "Haggai", "哈该书", "OT", 2), ("ZEC", "Zechariah", "撒迦利亚书", "OT", 14),
    ("MAL", "Malachi", "玛拉基书", "OT", 4),
    ("MAT", "Matthew", "马太福音", "NT", 28), ("MRK", "Mark", "马可福音", "NT", 16),
    ("LUK", "Luke", "路加福音", "NT", 24), ("JHN", "John", "约翰福音", "NT", 21),
    ("ACT", "Acts", "使徒行传", "NT", 28), ("ROM", "Romans", "罗马书", "NT", 16),
    ("1CO", "1 Corinthians", "哥林多前书", "NT", 16), ("2CO", "2 Corinthians", "哥林多后书", "NT", 13),
    ("GAL", "Galatians", "加拉太书", "NT", 6), ("EPH", "Ephesians", "以弗所书", "NT", 6),
    ("PHP", "Philippians", "腓立比书", "NT", 4), ("COL", "Colossians", "歌罗西书", "NT", 4),
    ("1TH", "1 Thessalonians", "帖撒罗尼迦前书", "NT", 5), ("2TH", "2 Thessalonians", "帖撒罗尼迦后书", "NT", 3),
    ("1TI", "1 Timothy", "提摩太前书", "NT", 6), ("2TI", "2 Timothy", "提摩太后书", "NT", 4),
    ("TIT", "Titus", "提多书", "NT", 3), ("PHM", "Philemon", "腓利门书", "NT", 1),
    ("HEB", "Hebrews", "希伯来书", "NT", 13), ("JAS", "James", "雅各书", "NT", 5),
    ("1PE", "1 Peter", "彼得前书", "NT", 5), ("2PE", "2 Peter", "彼得后书", "NT", 3),
    ("1JN", "1 John", "约翰一书", "NT", 5), ("2JN", "2 John", "约翰二书", "NT", 1),
    ("3JN", "3 John", "约翰三书", "NT", 1), ("JUD", "Jude", "犹大书", "NT", 1),
    ("REV", "Revelation", "启示录", "NT", 22),
]


@dataclass
class Verse:
    book_code: str
    chapter: int
    verse: int
    text: str

    @property
    def ref(self) -> str:
        return f"{self.book_code} {self.chapter}:{self.verse}"

    @property
    def source_id(self) -> str:
        return f"KJV-{self.book_code}{self.chapter}:{self.verse}"


def load_kjv_json(path: str) -> List[Verse]:
    """读取并归一化 KJV JSON 为 Verse 列表（兼容结构 A / B）。"""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    rows: List[Verse] = []
    if isinstance(data, list):                      # 结构 A
        for item in data:
            rows.append(Verse(
                book_code=str(item["book"]).upper(),
                chapter=int(item["chapter"]),
                verse=int(item["verse"]),
                text=str(item["text"]).strip(),
            ))
    elif isinstance(data, dict) and "books" in data:  # 结构 B
        for b in data["books"]:
            code = str(b["code"]).upper()
            for ch in b.get("chapters", []):
                for v in ch.get("verses", []):
                    rows.append(Verse(
                        book_code=code,
                        chapter=int(ch["chapter"]),
                        verse=int(v["verse"]),
                        text=str(v["text"]).strip(),
                    ))
    else:
        raise ValueError("无法识别的 KJV JSON 结构")

    if not rows:
        raise ValueError("KJV 数据为空")
    return rows


def chunk_for_rag(v: Verse) -> List[str]:
    """单节切片：KJV 单节通常较短，整节作为一个 chunk；
    超长节（如诗篇长章）按句子边界再切，保证检索粒度合理。"""
    text = v.text
    if len(text) <= 600:
        return [text]
    # 简易按 '. ' / '; ' 切分，保留分隔符
    parts, buf = [], ""
    for ch in text:
        buf += ch
        if ch in ".!?;" and len(buf) > 200:
            parts.append(buf.strip())
            buf = ""
    if buf.strip():
        parts.append(buf.strip())
    return parts or [text]


def seed_books(conn) -> None:
    """幂等写入 bible_book 元数据。"""
    with conn.cursor() as cur:
        for i, (code, en, zh, test, chaps) in enumerate(BOOKS, start=1):
            cur.execute(
                """INSERT INTO bible_book (book_id, book_code, name_en, name_zh, testament, chapter_count)
                   VALUES (%s,%s,%s,%s,%s,%s)
                   ON CONFLICT (book_id) DO NOTHING""",
                (i, code, en, zh, test, chaps),
            )
    conn.commit()


def embed_texts(texts: List[str]) -> Optional[List[List[float]]]:
    """加载 sentence-transformers 模型并产出归一化向量。"""
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer(EMBED_MODEL)
    vecs = model.encode(texts, normalize_embeddings=True, show_progress_bar=True)
    return [list(map(float, v)) for v in vecs]


def insert_verses(conn, rows: List[Verse], embeddings: Optional[List[List[float]]] = None) -> None:
    """写入 bible_verse_kjv 与 content_chunk。
    embeddings 与 rows 一一对应；为空时仅入库、向量留 NULL。"""
    with conn.cursor() as cur:
        for idx, v in enumerate(rows):
            cur.execute(
                """INSERT INTO bible_verse_kjv (book_id, chapter, verse, ref, kjv_text)
                   SELECT book_id, %s, %s, %s, %s FROM bible_book WHERE book_code = %s
                   ON CONFLICT (book_id, chapter, verse) DO NOTHING
                   RETURNING verse_id""",
                (v.chapter, v.verse, v.ref, v.text, v.book_code),
            )
            res = cur.fetchone()
            if res is None:
                # 已存在：取现有 verse_id，跳过重复
                cur.execute(
                    "SELECT verse_id FROM bible_verse_kjv bk JOIN bible_book bb "
                    "ON bk.book_id=bb.book_id WHERE bb.book_code=%s AND bk.chapter=%s AND bk.verse=%s",
                    (v.book_code, v.chapter, v.verse),
                )
                res = cur.fetchone()
            if res is None:
                continue
            verse_id = res[0]

            # 切片 + 向量入库
            for ci, chunk in enumerate(chunk_for_rag(v)):
                emb_param = None
                if embeddings is not None:
                    # 整节一个 chunk 时取对应向量；多 chunk 复用同节向量
                    vec = embeddings[idx]
                    emb_param = "[" + ",".join(str(x) for x in vec) + "]"
                cur.execute(
                    """INSERT INTO content_chunk (source_type, source_id, ref, chunk_text, embedding)
                       VALUES ('BIBLE', %s, %s, %s, %s::vector)""",
                    (v.source_id if ci == 0 else f"{v.source_id}#{ci}", v.ref, chunk, emb_param),
                )
    conn.commit()


def main() -> int:
    ap = argparse.ArgumentParser(description="KJV 入库 + 向量化骨架")
    ap.add_argument("--input", required=True, help="KJV JSON 路径")
    ap.add_argument("--skip-embed", action="store_true", help="仅入库，不生成向量")
    ap.add_argument("--db-url", default=DB_URL, help="PostgreSQL 连接串")
    args = ap.parse_args()

    try:
        import psycopg
    except ImportError:
        print("[错误] 未安装 psycopg，请先 pip install 'psycopg[binary]'", file=sys.stderr)
        return 2

    rows = load_kjv_json(args.input)
    print(f"[信息] 解析到 {len(rows)} 节")

    embeddings = None
    if not args.skip_embed:
        embeddings = embed_texts([v.text for v in rows])
        if embeddings and len(embeddings[0]) != EMBED_DIM:
            print(f"[错误] 模型输出维度 {len(embeddings[0])} != 期望 {EMBED_DIM}，"
                  f"请调整 001_init_schema.sql 的 VECTOR({EMBED_DIM})", file=sys.stderr)
            return 3

    conn = psycopg.connect(args.db_url)
    try:
        seed_books(conn)
        insert_verses(conn, rows, embeddings)
    finally:
        conn.close()

    print(f"[完成] 已写入 {len(rows)} 节至 bible_verse_kjv / content_chunk")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
