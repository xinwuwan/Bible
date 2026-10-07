#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fetch_cuv.py - 下载和合本(CUV)并合并进 app_data.json 的 cuv_ref_text
=========================================================================
权威定位 : KJV 英文原文为唯一权威底本。和合本(1919 官话和合本, 公共领域)
           仅作为「参照展示」（cuv_ref_text 栏），绝不充当本应用译文。
落库目标 : flutter_app/assets/web/app_data.json
           - 每节经文的 cuv_ref_text 栏（参照展示，灰化、标注仅参照）

数据来源 : MaatheusGois/bible 仓库的 versions/zh/cuv.json
           结构: [ { "id": "gn", "chapters": [ ["v1","v2",...], ... ] }, ... ]
           id 为 3 字母书卷代码(小写)，chapters[章-1][节-1] = 经文。

设计要点:
  - 书卷按 id 映射到本应用 book_id（与 fetch_kjv.py 的 66 卷顺序一致）；
    id 无法识别时回退到数组位置，并打印告警，不静默错配。
  - 仅填 cuv_ref_text，不改动 kjv_text / our_zh / health_* / doctrine。
  - ⚠️ our_zh（本应用译文）一律不由此脚本填充——译文须由应用独立产出，
    绝不采用和合本等现有中文译本作为译文内容（合规铁律）。
  - 依赖已存在的 app_data.json（先跑 fetch_kjv.py 生成）；若缺失则报错提示。
  - 纯标准库、无第三方依赖；CI 与用户本机均可直接 python3 fetch_cuv.py 运行。

用法:
  python3 fetch_cuv.py                 # 自动下载默认 CUV 源并合并
  python3 fetch_cuv.py --input cuv.json # 用本地 JSON（离线）
"""

import argparse
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_FILE = os.path.join(ROOT, "flutter_app", "assets", "web", "app_data.json")
# 同一文件的多条分发线路：raw 直连 + jsDelivr CDN 镜像，依次回退。
DEFAULT_CUV_URLS = [
    "https://raw.githubusercontent.com/MaatheusGois/bible/main/versions/zh/cuv.json",
    "https://cdn.jsdelivr.net/gh/MaatheusGois/bible@main/versions/zh/cuv.json",
]

# 66 卷标准顺序（与 fetch_kjv.py 的 BOOKS 完全一致），索引 i => book_id = i+1
CODES = [
    "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT",
    "1SA", "2SA", "1KI", "2KI", "1CH", "2CH", "EZR", "NEH",
    "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER",
    "LAM", "EZK", "DAN", "HOS", "JOL", "AMO", "OBA", "JON",
    "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL", "MAT",
    "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL",
    "EPH", "PHP", "COL", "1TH", "2TH", "1TI", "2TI", "TIT",
    "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN",
    "JUD", "REV",
]
# CUV 源(MaatheusGois)使用标准 3 字母书卷代码(如 gn/exo/psa/mat)，
# 与本项目内码(GEN/EXO/PSA/MAT)不同，需显式对齐到 66 卷标准顺序。
STD_IDS = [
    "gen", "exo", "lev", "num", "deu", "jos", "jdg", "rut",
    "1sa", "2sa", "1ki", "2ki", "1ch", "2ch", "ezr", "neh",
    "est", "job", "psa", "pro", "ecc", "sng", "isa", "jer",
    "lam", "ezk", "dan", "hos", "jol", "amo", "oba", "jon",
    "mic", "nam", "hab", "zep", "hag", "zec", "mal", "mat",
    "mrk", "luk", "jhn", "act", "rom", "1co", "2co", "gal",
    "eph", "php", "col", "1th", "2th", "1ti", "2ti", "tit",
    "phm", "heb", "jas", "1pe", "2pe", "1jn", "2jn", "3jn",
    "jud", "rev",
]
ID_TO_IDX = {}
for _i, _sid in enumerate(STD_IDS):
    ID_TO_IDX[_sid] = _i
# 同时接受本项目内码小写作为别名（如 gen 与 GEN 等价）
for _i, _code in enumerate(CODES):
    ID_TO_IDX.setdefault(_code.lower(), _i)


def fetch_url(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=120) as r:
        # utf-8-sig: 自动剥离部分源文件自带的 UTF-8 BOM，否则 json.loads 会报错
        return r.read().decode("utf-8-sig")


def fetch_urls_retry(urls, retries=4):
    """多线路 + 重试：依次尝试每条线路，每条重试 retries 次，全败才抛出。"""
    last = None
    for url in urls:
        for i in range(retries):
            try:
                return fetch_url(url)
            except Exception as e:  # noqa: BLE001 - 网络抖动换线路/重试
                last = e
                print(f"  [retry {i + 1}/{retries}] {url}: {e}")
    raise last


def parse_cuv(text):
    """解析 CUV JSON 为 {(book_id, chapter, verse): text} 字典。

    主映射按数组位置（CUV 源为 66 卷标准正典顺序，与本项目一致），
    不依赖猜测各书卷的 id 命名；id 仅作非致命的交叉校验。
    返回 (cuv_dict, book_count, id_warnings)。
    """
    # 防御：源文件可能带 UTF-8 BOM（\ufeff），先剥离再解析
    arr = json.loads(text.lstrip("\ufeff"))
    if not isinstance(arr, list):
        raise ValueError("CUV 源根节点不是数组")

    cuv = {}
    id_warnings = []
    for pos, entry in enumerate(arr):
        if not isinstance(entry, dict):
            continue
        book_id = pos + 1  # 位置主映射：第 pos 本 => book_id = pos+1
        cid = (entry.get("id") or "").strip().lower()
        id_idx = ID_TO_IDX.get(cid)
        if id_idx is not None and id_idx != pos:
            # id 可识别但与位置不符：记录告警，仍以位置为准
            id_warnings.append((cid, pos, id_idx))
        chapters = entry.get("chapters") or []
        for ci, ch in enumerate(chapters, start=1):
            if not isinstance(ch, list):
                continue
            for vi, vs in enumerate(ch, start=1):
                if vs is None:
                    continue
                cuv[(book_id, ci, vi)] = vs
    return cuv, len(arr), id_warnings


def merge(out_file, cuv):
    """把 cuv 合并进已有 app_data.json 的 cuv_ref_text 栏（和合本参照）。

    合规铁律：仅填充 cuv_ref_text（参照展示），绝不写入 our_zh（本应用译文栏）。
    译文须由 LLM 从 KJV 直译生成（translate_kjv.py），不得采用和合本等现有中文译本。
    """
    if not os.path.exists(out_file):
        print("[error] 未找到 app_data.json，请先运行 fetch_kjv.py 生成", file=sys.stderr)
        return None
    with open(out_file, encoding="utf-8") as f:
        data = json.load(f)
    verses = data.get("verse", [])
    cnt = 0
    for v in verses:
        key = (v.get("book_id"), v.get("chapter"), v.get("verse"))
        if key in cuv:
            # 和合本仅作为「参照展示」落库 cuv_ref_text；
            # 绝不写入 our_zh（本应用译文栏），译文须由应用独立产出。
            v["cuv_ref_text"] = cuv[key]
            cnt += 1
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    return cnt, len(verses), len(cuv)


def main():
    ap = argparse.ArgumentParser(description="下载和合本(CUV)并合并进 app_data.json")
    ap.add_argument("--input", help="本地 CUV JSON（离线模式，跳过下载）")
    ap.add_argument(
        "--urls",
        default=",".join(DEFAULT_CUV_URLS),
        help="CUV 源 URL 列表(逗号分隔，依次回退)",
    )
    args = ap.parse_args()

    if args.input:
        with open(args.input, encoding="utf-8-sig") as f:
            text = f.read()
    else:
        urls = [u.strip() for u in args.urls.split(",") if u.strip()]
        print(f"[info] downloading CUV from {len(urls)} mirrors")
        text = fetch_urls_retry(urls)

    cuv, book_count, id_warnings = parse_cuv(text)
    if not cuv:
        print("[error] 未解析到任何和合本经文，请检查源格式", file=sys.stderr)
        return 2
    print(f"[info] parsed {len(cuv)} CUV verses across {book_count} books")
    if id_warnings:
        print(f"[warn] {len(id_warnings)} 书卷 id 与位置不符(仍以位置为准): {id_warnings[:10]}")

    res = merge(OUT_FILE, cuv)
    if res is None:
        return 2
    cnt, total, cuv_total = res
    size_kb = os.path.getsize(OUT_FILE) / 1024
    print(f"[done] merged CUV for {cnt}/{total} verses (cuv source had {cuv_total}) -> {OUT_FILE} ({size_kb:.1f} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
