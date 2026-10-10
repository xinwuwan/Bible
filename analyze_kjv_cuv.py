#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
analyze_kjv_cuv.py - 用 LLM 比对 KJV 英文与和合本(CUV)中文，标出「含义/底本/措辞」差异。
=========================================================================
目的：为模块 A「对照阅读」自动生成 kjv_cuv_diffs.json，减少人工逐节核对的精力消耗。

合规铁律：
  - KJV 为权威底本；本脚本只「描述」KJV 与和合本的可见差异，绝不把和合本当权威、
    也绝不复制和合本作为本应用译文。
  - 生成的 note 一律中性，只说明「两译所据底本/措辞不同」，不判定谁对谁错。

产物：flutter_app/assets/web/kjv_cuv_diffs.json
  结构：{ "version":1, "generated_by":"<model>", "items": { "GEN 1:1": {...}, ... } }
  items 与仓库已有的 curated-seed 会被合并（脚本以 ref 为键，已有的保留、新的追加）。

特性：
  - 按「章」批量比对（每章一次 API 调用），大幅减少调用次数（约 1189 章）。
  - 断点续跑：已存在于 items 的 ref 跳过；每章比对完立即落盘。
  - 限流退避：遇 429/5xx 指数退避重试。

运行（需 OpenAI 兼容接口的密钥，与 translate_kjv.py 同套环境变量）：
  set LLM_API_KEY=sk-...
  set LLM_BASE_URL=https://open.bigmodel.cn/api/paas/v4   # 智谱 GLM 等
  set LLM_MODEL=glm-4-flash
  python analyze_kjv_cuv.py                  # 全本，断点续跑
  python analyze_kjv_cuv.py --books 1,2,3    # 只比前 3 卷（调试）
  python analyze_kjv_cuv.py --max-chapters 50  # 本轮最多 50 章（配合 CI 接力）
  python analyze_kjv_cuv.py --dry-run         # 仅统计待比章数
"""

import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(ROOT, "flutter_app", "assets", "web", "app_data.json")
DIFFS_FILE = os.path.join(ROOT, "flutter_app", "assets", "web", "kjv_cuv_diffs.json")

SYSTEM_PROMPT = (
    "你是严谨的圣经文本比对助手。给定一章圣经的 KJV 英文与和合本(CUV, 1919)中文，"
    "请逐节判断两者在「含义 / 所据底本 / 关键措辞」上是否存在需要读者留意的差异。\n"
    "只标记真正的差异，不要对实质一致的内容标记。差异类型 type 取值：\n"
    "  - text_tradition：所依原文底本/文本传统不同（如 KJV 依 Textus Receptus 含某句、"
    "和合本依批判本省略，或反之）。\n"
    "  - archaic_kjv：KJV 用词为古英语，现代读者易误解，但两者含义其实一致"
    "（如 prevent=先到、charity=爱）。\n"
    "  - wording：译法措辞导致中文读者可能误读 KJV 含义的其他情况。\n"
    "severity 取值 high / medium / low。\n"
    "note：一句中文中性说明，说明两译所据底本/措辞不同，绝不断言谁对谁错，"
    "也绝不把和合本当作权威来源。\n"
    "kjv_focus / cuv_focus：若存在需加粗提示的具体片段，给出该节 KJV / 和合本中对应的"
    "原文片段（用于前端加粗定位）；无则给空字符串。\n"
    "只输出 JSON，不要任何解释。格式："
    '{"items":[{"ref":"BOOK CH:VERSE","type":"...","severity":"...",'
    '"note":"...","kjv_focus":"...","cuv_focus":"..."}]}；'
    "若本章无差异，items 为空数组 []。"
)

VALID_TYPES = {"text_tradition", "archaic_kjv", "wording"}


def _env(name, default=""):
    return os.environ.get(name, default)


class Settings:
    API_KEY = _env("LLM_API_KEY", "")
    BASE_URL = _env("LLM_BASE_URL", "https://api.openai.com/v1").rstrip("/")
    MODEL = _env("LLM_MODEL", "gpt-4o-mini")


def load_data():
    with open(DATA_FILE, encoding="utf-8") as f:
        return json.load(f)


def group_by_chapter(data):
    verses = data.get("verse", [])
    chapters = {}
    order = []
    for v in verses:
        key = (v.get("book_id"), v.get("chapter"))
        if key not in chapters:
            chapters[key] = []
            order.append(key)
        chapters[key].append(v)
    return [(k[0], k[1], chapters[k]) for k in order]


def load_diffs():
    if os.path.exists(DIFFS_FILE):
        with open(DIFFS_FILE, encoding="utf-8") as f:
            d = json.load(f)
        return d.get("items", {}), d
    return {}, {"version": 1, "items": {}}


def save_diffs(meta, items, model):
    meta["items"] = items
    meta["generated_by"] = model
    tmp = DIFFS_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    os.replace(tmp, DIFFS_FILE)


def call_llm(chapter_verses, settings, timeout=120):
    lines = "\n".join(
        f'{v.get("ref")}\tKJV: {v.get("kjv_text") or ""}\tCUV: {v.get("cuv_ref_text") or ""}'
        for v in chapter_verses
    )
    payload = {
        "model": settings.MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"请比对以下一章的 KJV 与和合本（每行格式：REF\\tKJV\\tCUV）：\n{lines}",
            },
        ],
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }
    url = settings.BASE_URL + "/chat/completions"
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {settings.API_KEY}",
        },
    )
    last_err = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                body = json.loads(resp.read().decode("utf-8"))
            content = body["choices"][0]["message"]["content"]
            return json.loads(content)
        except urllib.error.HTTPError as e:
            last_err = e
            if e.code == 429 or e.code >= 500:
                wait = min(2 ** attempt * 5, 60)
                time.sleep(wait)
                continue
            raise
    raise RuntimeError(f"LLM 调用失败: {last_err}")


def main():
    ap = argparse.ArgumentParser(description="用 LLM 比对 KJV 与和合本差异")
    ap.add_argument("--books", help="只比指定书卷 id（逗号分隔，如 1,2,3）")
    ap.add_argument("--max-chapters", type=int, default=0,
                    help="本轮最多比章数（0=不限制）；用于拆成多轮接力避免超时")
    ap.add_argument("--dry-run", action="store_true", help="仅统计待比章数")
    args = ap.parse_args()

    settings = Settings()
    if args.dry_run and not settings.API_KEY:
        # dry-run 不需要 key，但仍展示待比章数
        pass

    data = load_data()
    chapters = group_by_chapter(data)
    items, meta = load_diffs()

    want_books = None
    if args.books:
        want_books = {int(x) for x in args.books.split(",") if x.strip()}

    pending = []
    for book_id, chapter, vs in chapters:
        if want_books and book_id not in want_books:
            continue
        # 整章都已比对过则跳过
        if all((v.get("ref") in items) for v in vs):
            continue
        pending.append((book_id, chapter, vs))

    if args.max_chapters and args.max_chapters > 0:
        pending = pending[: args.max_chapters]

    if args.dry_run:
        print(f"[dry-run] 待比章数 = {len(pending)} / 总章数 {len(chapters)}")
        return 0

    if not settings.API_KEY:
        print("[error] 未设置 LLM_API_KEY，无法比对。请先配置环境变量（或 CI secret）。",
              file=sys.stderr)
        return 2

    print(f"[info] 开始比对，待比章数 = {len(pending)}")
    done = 0
    fails = []
    for book_id, chapter, vs in pending:
        try:
            result = call_llm(vs, settings)
            new_items = result.get("items", []) or []
            added = 0
            for it in new_items:
                ref = (it.get("ref") or "").strip()
                if not ref or ref in items:
                    continue
                t = it.get("type", "wording")
                if t not in VALID_TYPES:
                    t = "wording"
                items[ref] = {
                    "type": t,
                    "severity": it.get("severity", "low"),
                    "note": it.get("note", ""),
                    "kjv_focus": it.get("kjv_focus") or None,
                    "cuv_focus": it.get("cuv_focus") or None,
                }
                added += 1
            done += 1
            if done % 10 == 0 or added > 0:
                save_diffs(meta, items, settings.MODEL)
                print(f"[progress] 已完成 {done}/{len(pending)} 章，累计标记 {len(items)} 节差异（本章程新增 {added}）")
        except Exception as e:  # noqa: BLE001
            print(f"[warn] 第 {book_id} 卷 {chapter} 章失败: {e}", file=sys.stderr)
            fails.append({"book_id": book_id, "chapter": chapter, "error": str(e)})
    save_diffs(meta, items, settings.MODEL)
    print(f"[done] 比对完成：成功 {done} 章，失败 {len(fails)} 章，累计 {len(items)} 节差异")
    if fails:
        print(f"[warn] 失败章节见 _analyze_fail.json，可重跑本脚本断点续跑。")
        with open(os.path.join(ROOT, "_analyze_fail.json"), "w", encoding="utf-8") as f:
            json.dump(fails, f, ensure_ascii=False, indent=2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
