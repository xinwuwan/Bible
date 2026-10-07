#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
export_notes_json.py — 把 comparison-note-pilot.html 里的 26 条对照注记
导出为 Flutter 可直接打包的 assets/notes.json（供模块 A 对照 UI 演示）。

处理的三件事（都是"不处理就会在 UI 上出问题"的坑）:
  1. ref 格式对齐
     pilot 用点分格式 "1CO.13.13"，离线库 verse.ref 是 "1CO 13:13"。
     若不转换，ComparisonPage 里 _normRef 比对不上，注记永远匹配不到经文。
  2. diff_type 规范化
     DDL 的 CHECK 只允许 archaic_kjv / mistranslation / text_tradition / consistent，
     pilot 实际用了 wording(16) / archaism(4) / structure(1)，这些值无法入库。
     本脚本做"建议映射"并保留 raw_diff_type + needs_review 标记，
     ⚠ 建议值由 conclusion 文本启发式推断，必须经神学顾问复核确认。
  3. status 一律保持原值(draft)
     【合规红线】绝不把 draft 改成 approved 来"让演示好看"。
     演示请在 Flutter 侧用 --dart-define=SHOW_DRAFT_NOTES=true 打开草稿可见。

用法:
  python export_notes_json.py                      # 默认输出 assets/notes.json
  python export_notes_json.py --out notes.json     # 指定输出
  python export_notes_json.py --keep-raw-types     # 不做建议映射，全标 unclassified
"""
import argparse
import html
import json
import os
import re
import sys
from typing import Any, Dict, List

PILOT_HTML_DEFAULT = "comparison-note-pilot.html"
OUT_DEFAULT = os.path.join("assets", "notes.json")

# DDL(001_init_schema.sql) comparison_note 的 CHECK 约束取值
CANONICAL = {"archaic_kjv", "mistranslation", "text_tradition", "consistent"}

# 同义别名 → canonical（语义明确、无争议）
ALIAS_EXACT = {
    "archaic_kjv": "archaic_kjv",
    "archaism": "archaic_kjv",
    "text_tradition": "text_tradition",
    "textual": "text_tradition",
    "mistranslation": "mistranslation",
    "consistent": "consistent",
}

# 启发式关键词（按优先级从高到低匹配 conclusion/observation）
HEURISTIC_RULES = [
    ("archaic_kjv", ["古词", "1611", "古义", "早期现代", "词义变化"]),
    ("text_tradition", ["底本", "抄本", "文本传统", "文本批判", "TR", "Byzantine", "批判本"]),
    ("mistranslation", ["偏离原意", "误译", "不准确", "曲解", "漏译", "加添"]),
    ("consistent", ["一致", "从之", "从和合本", "准确", "精确", "可接受", "相同", "无实质",
                    "无分歧", "难词", "难译"]),
]


def extract_json_array(text: str) -> List[Dict[str, Any]]:
    """从 HTML 中定位 <div class="code">[ ... ] 的 JSON 数组并解析。
    用括号配对扫描（跳过字符串字面量），避免依赖脆弱的行号。"""
    m = re.search(r'<div class="code">\s*(\[)', text)
    if not m:
        raise SystemExit("[错误] 未找到 <div class=\"code\">[ 标记，无法定位 JSON 数组")
    start = m.start(1)
    depth = 0
    i = start
    n = len(text)
    in_str = False
    quote = ""
    esc = False
    while i < n:
        ch = text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == quote:
                in_str = False
            i += 1
            continue
        if ch in ('"', "'"):
            in_str = True
            quote = ch
            i += 1
            continue
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                break
        i += 1
    if depth != 0:
        raise SystemExit("[错误] JSON 数组括号未闭合，提取失败")
    raw = text[start:i + 1]
    # HTML 里可能存在实体转义
    raw = html.unescape(raw)
    return json.loads(raw)


def to_offline_ref(verse_ref: str) -> str:
    """'1CO.13.13' → '1CO 13:13'（对齐离线库 verse.ref 格式）"""
    parts = verse_ref.strip().split(".")
    if len(parts) == 3:
        code, ch, v = parts
        return f"{code.upper()} {int(ch)}:{int(v)}" if ch.isdigit() and v.isdigit() \
            else f"{code.upper()} {ch}:{v}"
    return verse_ref.replace(".", " ", 1).upper()


def suggest_diff_type(item: Dict[str, Any], raw: str) -> tuple:
    """返回 (canonical 值 或 None, 建议来源说明)"""
    key = (raw or "").strip().lower()
    if key in ALIAS_EXACT:
        return ALIAS_EXACT[key], "exact-alias"
    blob = f"{item.get('conclusion', '')} {item.get('observation', '')} {item.get('implication', '')}"
    for canonical, kws in HEURISTIC_RULES:
        if any(k in blob for k in kws):
            return canonical, "heuristic"
    return None, "unresolved"


def main() -> int:
    ap = argparse.ArgumentParser(description="导出 pilot 注记为 Flutter assets/notes.json")
    ap.add_argument("--pilot", default=PILOT_HTML_DEFAULT, help="pilot HTML 路径")
    ap.add_argument("--out", default=OUT_DEFAULT, help="输出 JSON 路径")
    ap.add_argument(
        "--keep-raw-types",
        action="store_true",
        help="不做建议映射，非 canonical 一律标 unclassified（最保守）",
    )
    args = ap.parse_args()

    if not os.path.exists(args.pilot):
        print(f"[错误] 找不到 {args.pilot}", file=sys.stderr)
        return 2

    with open(args.pilot, "r", encoding="utf-8") as f:
        html_text = f.read()
    items = extract_json_array(html_text)
    print(f"[信息] 从 pilot 提取到 {len(items)} 条注记")

    out: List[Dict[str, Any]] = []
    review_needed: List[str] = []
    for it in items:
        raw_type = it.get("diff_type", "")
        verse_ref = it.get("verse_ref", "")
        ref = to_offline_ref(verse_ref)

        if args.keep_raw_types:
            new_type = raw_type if raw_type in CANONICAL else "unclassified"
            source = "raw"
        else:
            new_type, source = suggest_diff_type(it, raw_type)
            if new_type is None:
                new_type = "unclassified"
                source = "unresolved"

        needs_review = (raw_type not in CANONICAL) or (source in ("heuristic", "unresolved"))
        if needs_review:
            review_needed.append(f"{ref}  {raw_type} → {new_type}  ({source})")

        out.append({
            "ref": ref,
            "verse_ref": verse_ref,          # 保留原始，便于回溯
            "diff_type": new_type,           # canonical 或 unclassified
            "raw_diff_type": raw_type,       # 原始取值，供顾问复核
            "needs_review": needs_review,    # UI/审核台可据此标记
            "map_source": source,
            "kjv_text": it.get("kjv_text", ""),
            "our_zh": it.get("our_zh", ""),
            "cuv_text": it.get("cuv_text", ""),
            "observation": it.get("observation", ""),
            "basis": it.get("basis", ""),
            "implication": it.get("implication", ""),
            "conclusion": it.get("conclusion", ""),
            "status": it.get("status", "draft"),   # ⚠ 保持原值，绝不伪造 approved
            "author": it.get("author", ""),
        })

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    # 统计
    dist: Dict[str, int] = {}
    for o in out:
        dist[o["diff_type"]] = dist.get(o["diff_type"], 0) + 1
    approved = sum(1 for o in out if o["status"] == "approved")

    print(f"[完成] 已写出 {args.out}  共 {len(out)} 条")
    print(f"  diff_type 分布: {dist}")
    print(f"  status: approved={approved}  draft={len(out) - approved}")
    print(f"  需顾问复核: {len(review_needed)} 条")
    for line in review_needed:
        print(f"    - {line}")
    print()
    print("[合规提醒] status 全部保持原值(draft)，未做任何 approved 伪造。")
    print("           演示时请用: flutter run --dart-define=SHOW_DRAFT_NOTES=true")
    print("           发布前必须由神学顾问逐条审核并通过 review_queue 置为 approved。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
