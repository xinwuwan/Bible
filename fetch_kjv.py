#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fetch_kjv.py - 下载全本 KJV 并生成 flutter_app/assets/web/app_data.json
=========================================================================
权威来源 : King James Version (1769 Blayney text, 美区 Public Domain)
源仓库   : aruljohn/Bible-kjv (GitHub) —— 每卷书一个 JSON 文件，
          格式: {"book": "Genesis",
                 "chapters":[{"chapter":"1",
                              "verses":[{"verse":"1","text":"..."}]}]}
          已核实该仓库根目录确为 66 个 <BookName>.json（无空格，如
          1Samuel.json / SongofSolomon.json），无单一 kjv.txt。
落库目标 : flutter_app/assets/web/app_data.json（模块 A 离线 JSON 资源）

设计要点:
  - 仅把权威英文原文 KJV 写入 kjv_text；中文栏 our_zh / cuv_ref_text 默认留空
    （本应用不伪造中文译文；和合本参照由 fetch_cuv.py 填入 cuv_ref_text）。
  - 列名严格对齐 UI（app_models.dart / web_data_core.dart）:
      verse: book_id, chapter, verse, ref, kjv_text, our_zh, cuv_ref_text
      book : book_id, book_code, name_en, name_zh, testament, chapter_count
  - ref 格式 "<book_code> <chapter>:<verse>"（如 "GEN 1:1"），search_page 依赖。
  - 纯标准库、无第三方依赖；CI / 用户本机均可直接 python3 fetch_kjv.py 运行。
  - 默认自动下载 66 卷 aruljohn JSON（需联网）；也可用 --input-dir 指定本地
    含 66 个 JSON 的目录（离线，例如把 aruljohn/Bible-kjv 仓库 clone 下来）。
  - 网络失败（CI 无外网等）时返回非 0，由调用方决定是否回退到已提交数据。

用法:
  python3 fetch_kjv.py                          # 自动下载默认 KJV 源(66 卷)
  python3 fetch_kjv.py --input-dir ./Bible-kjv  # 用本地目录(离线)
  python3 fetch_kjv.py --cuv cuv.json            # 额外把和合本填入 cuv_ref_text
"""

import argparse
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_FILE = os.path.join(ROOT, "flutter_app", "assets", "web", "app_data.json")
# 同一仓库的多条分发线路：raw 直连偶尔在 CI 上抖动，jsDelivr CDN 作镜像回退。
DEFAULT_KJV_BASES = [
    "https://raw.githubusercontent.com/aruljohn/Bible-kjv/master/",
    "https://cdn.jsdelivr.net/gh/aruljohn/Bible-kjv@master/",
]

# (code, name_en, name_zh, testament, chapter_count) - 公共领域事实清单
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


def build_books():
    books = []
    for i, (code, en, zh, test, chaps) in enumerate(BOOKS, start=1):
        books.append(
            {
                "book_id": i,
                "book_code": code,
                "name_en": en,
                "name_zh": zh,
                "testament": test,
                "chapter_count": chaps,
            }
        )
    return books


def book_filename(name_en):
    """aruljohn 仓库文件名：书名去空格 + .json（已核实，如 SongofSolomon.json）。"""
    return name_en.replace(" ", "") + ".json"


def parse_book_json(text, code, book_id):
    """解析单卷 aruljohn JSON 为 verse 行列表（列名对齐 UI 契约）。"""
    # 防御：源文件可能带 UTF-8 BOM（\ufeff），先剥离再解析
    obj = json.loads(text.lstrip("\ufeff"))
    out = []
    if not isinstance(obj, dict):
        return out
    for ch in obj.get("chapters", []):
        if not isinstance(ch, dict):
            continue
        try:
            ci = int(ch.get("chapter"))
        except (TypeError, ValueError):
            continue
        for v in ch.get("verses", []):
            if not isinstance(v, dict):
                continue
            try:
                vi = int(v.get("verse"))
            except (TypeError, ValueError):
                continue
            txt = (v.get("text") or "").strip()
            out.append(
                {
                    "book_id": book_id,
                    "chapter": ci,
                    "verse": vi,
                    "ref": f"{code} {ci}:{vi}",
                    "kjv_text": txt,
                    "our_zh": None,
                    "cuv_ref_text": None,
                }
            )
    return out


def load_passthrough():
    """保留现有 app_data.json 中的 health_* / doctrine，避免丢失模块 C 数据。"""
    if not os.path.exists(OUT_FILE):
        return {}
    try:
        with open(OUT_FILE, encoding="utf-8") as f:
            data = json.load(f)
        keys = ("doctrine", "health_topic", "health_topic_source",
                "health_metric", "health_guidance")
        return {k: data[k] for k in keys if k in data}
    except Exception:
        return {}


def fetch_url(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        # utf-8-sig: 自动剥离部分源文件自带的 UTF-8 BOM，否则 json.loads 会报错
        return r.read().decode("utf-8-sig")


def fetch_url_retry(url, retries=3):
    last = None
    for i in range(retries):
        try:
            return fetch_url(url)
        except Exception as e:  # noqa: BLE001 - 网络抖动重试
            last = e
            print(f"  [retry {i + 1}/{retries}] {url}: {e}")
    raise last


def collect_verses(bases, code_to_id, offline_dir=None):
    """返回 (verses, failed_list)。offline_dir 非空时走本地文件。

    每卷书依次尝试 bases 里的多条线路，任一线路成功即用之；
    全部线路都失败才记入 failed（由调用方按总量阈值决定是否报错）。
    """
    verses = []
    failed = []
    for code, en, zh, test, chaps in BOOKS:
        fn = book_filename(en)
        if offline_dir:
            fp = os.path.join(offline_dir, fn)
            if not os.path.exists(fp):
                failed.append((en, "missing local file"))
                continue
            with open(fp, encoding="utf-8") as f:
                text = f.read()
        else:
            text = None
            errs = []
            for base in bases:
                try:
                    text = fetch_url_retry(base + fn)
                    break
                except Exception as e:  # noqa: BLE001 - 换下一条线路
                    errs.append(f"{base}: {e}")
            if text is None:
                failed.append((en, "; ".join(errs)[:200]))
                continue
        verses.extend(parse_book_json(text, code, code_to_id[code]))
    return verses, failed


def main():
    ap = argparse.ArgumentParser(description="下载全本 KJV 并生成 app_data.json")
    ap.add_argument("--input-dir", help="本地含 66 个 aruljohn JSON 的目录(离线)")
    ap.add_argument("--cuv", help="和合本 JSON(MaatheusGois 格式)，合并进 cuv_ref_text")
    ap.add_argument(
        "--url-bases",
        default=",".join(DEFAULT_KJV_BASES),
        help="KJV 源 base URL 列表(逗号分隔，依次回退)",
    )
    args = ap.parse_args()

    books = build_books()
    code_to_id = {b["book_code"]: b["book_id"] for b in books}

    bases = [u.strip().rstrip("/") + "/" for u in args.url_bases.split(",") if u.strip()]
    verses, failed = collect_verses(bases, code_to_id, args.input_dir)
    if failed:
        print(f"[warn] {len(failed)} 卷未能获取: {failed[:6]}")

    # KJV 全本约 31000 节；少于 10000 视为源异常，交由调用方回退。
    if len(verses) < 10000:
        print(f"[error] 仅解析到 {len(verses)} 节(<10000)，源可能损坏", file=sys.stderr)
        return 2
    print(f"[info] parsed {len(verses)} KJV verses")

    out = {"book": books, "verse": verses}
    out.update(load_passthrough())

    os.makedirs(os.path.dirname(OUT_FILE), exist_ok=True)
    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)

    # 可选：本地一键合并和合本（CI 不用此参数，由 fetch_cuv.py 单独处理）
    if args.cuv:
        try:
            import fetch_cuv
        except ImportError:
            print("[warn] fetch_cuv 未找到，跳过和合本合并")
        else:
            with open(args.cuv, encoding="utf-8") as f:
                cuv_text = f.read()
            cuv, _, _ = fetch_cuv.parse_cuv(cuv_text)
            fetch_cuv.merge(OUT_FILE, cuv)

    size_kb = os.path.getsize(OUT_FILE) / 1024
    print(f"[done] wrote {OUT_FILE} ({size_kb:.1f} KB) - {len(verses)} verses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
