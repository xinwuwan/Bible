#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_offline_db.py — 生成 Flutter 离线 SQLite 预置包（M2 客户端骨架）
================================================================================
把权威内容(KJV 英文 + 本应用独立中文 + 教义)导出为一个自包含 SQLite 文件
app_offline.db，随 Flutter 应用作为 asset 预置，实现首屏零网络圣经阅读 +
全文检索(FTS5)。

数据来源(二选一):
  --db-url     从 Postgres(已 ingest 的内容)导出            [需 psycopg]
  --from-json  从中间 JSON 导出(解耦 / CI / 无 DB 环境)

输出: app_offline.db
  - book / verse / doctrine 表（verse 含 kjv_text, our_zh, cuv_ref_text）
  - verse_fts：FTS5 虚拟表，覆盖 kjv_text(英文) 与 our_zh(中文) 联合全文检索
    （rowid 绑定 verse.verse_id，查询时 JOIN 回原文）

合规: 离线包中的中文(our_zh)一律来自本应用自产译文，cuv_ref_text 仅作参照展示，
      二者都不作为权威来源参与任何推理。

Flutter 侧用法见 offline_db_helper.dart；pubspec.yaml 需声明 assets: [assets/app_offline.db]
"""
import argparse
import json
import os
import sqlite3
import sys
from typing import List, Tuple

OUT_DEFAULT = "app_offline.db"


def _fts_zh(text):
    """中文逐字空格分词，使 FTS5 unicode61 能把每个汉字作为独立 token 索引。
    unicode61 默认会丢弃连续 CJK 字符，必须显式拆字；非 CJK 字符保持原样。"""
    if not text:
        return ""
    out = []
    for ch in text:
        o = ord(ch)
        if (0x3400 <= o <= 0x9FFF) or (0x3000 <= o <= 0x303F) or (0xFF00 <= o <= 0xFFEF):
            out.append(ch)
            out.append(" ")
        else:
            out.append(ch)
    return "".join(out).strip()

SCHEMA = """
CREATE TABLE IF NOT EXISTS book (
  book_id      INTEGER PRIMARY KEY,
  book_code    TEXT NOT NULL,
  name_en      TEXT NOT NULL,
  name_zh      TEXT NOT NULL,
  testament    TEXT NOT NULL,
  chapter_count INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS verse (
  verse_id     INTEGER PRIMARY KEY,
  book_id      INTEGER NOT NULL,
  chapter      INTEGER NOT NULL,
  verse        INTEGER NOT NULL,
  ref          TEXT NOT NULL,
  kjv_text     TEXT NOT NULL,
  our_zh       TEXT,
  cuv_ref_text TEXT,
  UNIQUE(book_id, chapter, verse)
);
CREATE INDEX IF NOT EXISTS idx_verse_book ON verse(book_id, chapter);
CREATE TABLE IF NOT EXISTS doctrine (
  belief_id INTEGER PRIMARY KEY,
  code      TEXT NOT NULL,
  title_en  TEXT NOT NULL,
  title_zh  TEXT,
  en_text   TEXT NOT NULL,
  zh_text   TEXT
);
-- 模块 C：NEWSTART 健康八支柱（可选；无 health 数据时表为空，不影响主线）
CREATE TABLE IF NOT EXISTS health_topic (
  topic_id   INTEGER PRIMARY KEY,
  code       TEXT NOT NULL UNIQUE,
  name_zh    TEXT NOT NULL,
  summary    TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS health_topic_source (
  id          INTEGER PRIMARY KEY,
  topic_id    INTEGER NOT NULL,
  source_type TEXT NOT NULL,
  source_id   TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS health_guidance (
  guidance_id      INTEGER PRIMARY KEY,
  topic_id         INTEGER NOT NULL,
  title            TEXT NOT NULL,
  body_zh          TEXT NOT NULL,
  evidence_level   TEXT,
  medical_reviewed INTEGER NOT NULL DEFAULT 0,
  disclaimer       TEXT
);
CREATE TABLE IF NOT EXISTS health_metric (
  metric_id    INTEGER PRIMARY KEY,
  topic_code   TEXT NOT NULL,
  name_zh      TEXT NOT NULL,
  unit         TEXT,
  target_value TEXT
);
CREATE TABLE IF NOT EXISTS health_log_entry (
  log_id     INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    TEXT NOT NULL,
  topic_code TEXT NOT NULL,
  metric_id  INTEGER,
  value      TEXT,
  logged_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_health_log_user ON health_log_entry(user_id, logged_at);
"""

FTS_SQL = """
CREATE VIRTUAL TABLE IF NOT EXISTS verse_fts USING fts5(
  ref UNINDEXED,
  kjv_text,
  our_zh,
  tokenize='unicode61'
);
"""


DEFAULT_DISCLAIMER = "本内容不替代专业医疗诊断，如有健康问题请咨询医生。"

# 合规闸门：True 时把未过医学审核的健康条目也打进离线包（仅供内部预览，禁止发布）
ALLOW_UNREVIEWED = False


def export_from_postgres(db_url: str) -> Tuple[list, list, list, dict]:
    import psycopg
    conn = psycopg.connect(db_url)
    books = conn.execute(
        "SELECT book_id, book_code, name_en, name_zh, testament, chapter_count "
        "FROM bible_book ORDER BY book_id").fetchall()
    verses = conn.execute(
        """SELECT v.verse_id, v.book_id, v.chapter, v.verse, v.ref, v.kjv_text,
                  z.our_zh, c.cuv_text
           FROM bible_verse_kjv v
           LEFT JOIN bible_verse_zh z ON z.verse_id = v.verse_id
           LEFT JOIN bible_verse_cuv_ref c ON c.verse_id = v.verse_id
           ORDER BY v.verse_id""").fetchall()
    doctrines = conn.execute(
        """SELECT d.belief_id, d.code, d.title_en, d.title_zh, d.en_text, z.zh_text
           FROM doctrine_belief d
           LEFT JOIN doctrine_belief_zh z ON z.belief_id = d.belief_id
           ORDER BY d.belief_id""").fetchall()
    # 模块 C 健康内容：默认只导出已过医学审核的条目（合规闸门，默认安全）
    h_topics = conn.execute(
        "SELECT topic_id, code, name_zh, summary FROM health_topic ORDER BY topic_id").fetchall()
    h_sources = conn.execute(
        "SELECT id, topic_id, source_type, source_id FROM health_topic_source "
        "ORDER BY topic_id, id").fetchall()
    h_metrics = conn.execute(
        "SELECT metric_id, topic_code, name_zh, unit, target_value FROM health_metric "
        "ORDER BY metric_id").fetchall()
    h_sql = ("SELECT guidance_id, topic_id, title, body_zh, evidence_level, "
             "medical_reviewed, disclaimer FROM health_guidance ")
    if not ALLOW_UNREVIEWED:
        h_sql += "WHERE medical_reviewed = TRUE "   # 闸门：未审核一律不进发布包
    h_sql += "ORDER BY guidance_id"
    h_guidance = conn.execute(h_sql).fetchall()
    conn.close()
    health = {
        "topics": [tuple(r) for r in h_topics],
        "sources": [tuple(r) for r in h_sources],
        "guidance": [tuple(r) for r in h_guidance],
        "metrics": [tuple(r) for r in h_metrics],
    }
    return list(books), list(verses), list(doctrines), health


def load_from_json(path: str) -> Tuple[list, list, list, dict]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    books = [(b["book_id"], b["book_code"], b["name_en"], b["name_zh"],
              b["testament"], b["chapter_count"]) for b in data.get("books", [])]
    verses = []
    for v in data.get("verses", []):
        verses.append((v["verse_id"], v["book_id"], v["chapter"], v["verse"],
                       v["ref"], v["kjv_text"], v.get("our_zh"), v.get("cuv_ref_text")))
    doctrines = [(d["belief_id"], d["code"], d["title_en"], d.get("title_zh"),
                  d["en_text"], d.get("zh_text")) for d in data.get("doctrines", [])]
    h = data.get("health") or {}
    topics = [(t["topic_id"], t["code"], t["name_zh"], t.get("summary"))
              for t in h.get("topics", [])]
    sources = [(s.get("id", i + 1), s["topic_id"], s["source_type"], s["source_id"])
               for i, s in enumerate(h.get("sources", []))]
    metrics = [(m["metric_id"], m["topic_code"], m["name_zh"],
                m.get("unit"), m.get("target_value")) for m in h.get("metrics", [])]
    guidance = []
    for g in h.get("guidance", []):
        if not ALLOW_UNREVIEWED and not g.get("medical_reviewed", False):
            continue      # 闸门：未过医学审核不进发布包
        guidance.append((g["guidance_id"], g["topic_id"], g["title"], g["body_zh"],
                         g.get("evidence_level"),
                         1 if g.get("medical_reviewed", False) else 0,
                         g.get("disclaimer") or DEFAULT_DISCLAIMER))
    health = {"topics": topics, "sources": sources,
              "guidance": guidance, "metrics": metrics}
    return books, verses, doctrines, health


def build_sqlite(out_path: str, books: list, verses: list, doctrines: list,
                 health: dict = None) -> str:
    health = health or {"topics": [], "sources": [], "guidance": [], "metrics": []}
    if os.path.exists(out_path):
        os.remove(out_path)
    conn = sqlite3.connect(out_path)
    conn.executescript(SCHEMA)
    try:
        conn.execute(FTS_SQL)
    except sqlite3.OperationalError as e:
        conn.close()
        raise SystemExit(
            f"[错误] 当前 SQLite 不支持 FTS5（需 SQLite 3.9+ 且编译启用 FTS5）: {e}")
    conn.executemany(
        "INSERT INTO book (book_id, book_code, name_en, name_zh, testament, chapter_count) "
        "VALUES (?,?,?,?,?,?)", books)
    conn.executemany(
        "INSERT INTO verse (verse_id, book_id, chapter, verse, ref, kjv_text, our_zh, cuv_ref_text) "
        "VALUES (?,?,?,?,?,?,?,?)", verses)
    conn.executemany(
        "INSERT INTO doctrine (belief_id, code, title_en, title_zh, en_text, zh_text) "
        "VALUES (?,?,?,?,?,?)", doctrines)
    # FTS5 同步写入：rowid 绑定 verse_id；our_zh 经逐字空格分词以索引中文
    conn.executemany(
        "INSERT INTO verse_fts (rowid, ref, kjv_text, our_zh) VALUES (?,?,?,?)",
        [(v[0], v[4], v[5], _fts_zh(v[6])) for v in verses])
    # 模块 C 健康内容（可选；sort_order 用列表顺序 = NEWSTART 顺序）
    conn.executemany(
        "INSERT INTO health_topic (topic_id, code, name_zh, summary, sort_order) "
        "VALUES (?,?,?,?,?)",
        [(t[0], t[1], t[2], t[3], i) for i, t in enumerate(health["topics"])])
    conn.executemany(
        "INSERT INTO health_topic_source (id, topic_id, source_type, source_id) "
        "VALUES (?,?,?,?)", health["sources"])
    conn.executemany(
        "INSERT INTO health_guidance (guidance_id, topic_id, title, body_zh, "
        "evidence_level, medical_reviewed, disclaimer) VALUES (?,?,?,?,?,?,?)",
        health["guidance"])
    conn.executemany(
        "INSERT INTO health_metric (metric_id, topic_code, name_zh, unit, target_value) "
        "VALUES (?,?,?,?,?)", health["metrics"])
    conn.commit()
    n_book = conn.execute("SELECT COUNT(*) FROM book").fetchone()[0]
    n_verse = conn.execute("SELECT COUNT(*) FROM verse").fetchone()[0]
    n_doc = conn.execute("SELECT COUNT(*) FROM doctrine").fetchone()[0]
    n_fts = conn.execute("SELECT COUNT(*) FROM verse_fts").fetchone()[0]
    n_ht = conn.execute("SELECT COUNT(*) FROM health_topic").fetchone()[0]
    n_hg = conn.execute("SELECT COUNT(*) FROM health_guidance").fetchone()[0]
    n_hm = conn.execute("SELECT COUNT(*) FROM health_metric").fetchone()[0]
    conn.close()
    print(f"[完成] 离线包已生成: {out_path}")
    print(f"  book={n_book}  verse={n_verse}  doctrine={n_doc}  verse_fts={n_fts}")
    print(f"  health_topic={n_ht}  health_guidance={n_hg}  health_metric={n_hm}"
          + ("  (含未审核条目)" if ALLOW_UNREVIEWED else "  (仅已过医学审核)"))
    return out_path


def main() -> int:
    ap = argparse.ArgumentParser(description="生成 Flutter 离线 SQLite 预置包 (M2)")
    ap.add_argument("--db-url", default=os.getenv("DATABASE_URL"),
                    help="Postgres 连接串(已 ingest 的权威内容)")
    ap.add_argument("--from-json", help="从中间 JSON 导出(解耦 / 测试 / 无 DB 环境)")
    ap.add_argument("--out", default=OUT_DEFAULT,
                    help=f"输出 db 路径(默认 {OUT_DEFAULT})")
    ap.add_argument("--allow-unreviewed-health", action="store_true",
                    help="把未过医学审核的健康条目也打进包（仅供内部预览，禁止发布）")
    args = ap.parse_args()

    global ALLOW_UNREVIEWED
    ALLOW_UNREVIEWED = bool(args.allow_unreviewed_health)

    if args.from_json:
        books, verses, doctrines, health = load_from_json(args.from_json)
    elif args.db_url:
        try:
            books, verses, doctrines, health = export_from_postgres(args.db_url)
        except ImportError:
            print("[错误] 从 Postgres 导出需 psycopg，请先 pip install 'psycopg[binary]'",
                  file=sys.stderr)
            return 2
    else:
        ap.error("需提供 --db-url 或 --from-json")

    build_sqlite(args.out, books, verses, doctrines, health)
    print("[提示] 把生成的 db 放到 Flutter 的 assets/ 目录，并在 pubspec.yaml 声明:")
    print("       flutter:\n         assets:\n           - assets/app_offline.db")
    print("[提示] Flutter 侧读取 / 查询参考 offline_db_helper.dart")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
