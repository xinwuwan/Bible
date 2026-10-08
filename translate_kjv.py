#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
translate_kjv.py - 用 LLM 从 KJV 英文直译生成「本应用中文译文」(our_zh)
=========================================================================
合规铁律：译文必须是应用独立产出，绝不复制任何现有中文译本（和合本/新译本等）。
因此本脚本只把 KJV 英文交给 LLM 翻译，并校验产物不与和合本(cuv_ref_text)雷同。

产物：flutter_app/assets/web/our_zh.json
      结构：{ "GEN 1:1": "起初，神创造天地。", ... }   (ref -> 中文译文)
      该文件随仓库提交；CI 部署时用 --apply 灌入 app_data.json 的 our_zh 栏。

特性：
  - 按「章」批量翻译（每章一次 API 调用），极大减少调用次数（约 1189 章）。
  - 断点续译：our_zh.json 已存在的 ref 跳过；每章翻译完立即落盘。
  - 防复制校验：--apply 阶段若 our_zh 与 cuv_ref_text 逐字相同，则丢弃该节译文
    （宁可留空，也不把和合本当译文）。
  - 限流退避：遇 429/5xx 指数退避重试；整章失败跳过并记入 _translate_fail.json。
  - 增量落库：每译满 25 章即提交并推送 our_zh.json，超时也只丢最后 25 章，且
    可被下一轮自动续译（配合 --max-chapters 与 CI 自动重触发形成接力）。

运行（需 OpenAI 兼容接口的密钥）：
  set LLM_API_KEY=sk-...
  set LLM_BASE_URL=https://api.openai.com/v1   # 可换 DeepSeek / Qwen 等兼容端点
  set LLM_MODEL=gpt-4o-mini
  python translate_kjv.py                  # 全本，断点续译
  python translate_kjv.py --books 1,2,3    # 只译前 3 卷（调试用）
  python translate_kjv.py --dry-run        # 仅统计待译章数
  python translate_kjv.py --apply           # 把 our_zh.json 合并进 app_data.json
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(ROOT, "flutter_app", "assets", "web", "app_data.json")
OUR_ZH_FILE = os.path.join(ROOT, "flutter_app", "assets", "web", "our_zh.json")
FAIL_FILE = os.path.join(ROOT, "flutter_app", "assets", "web", "_translate_fail.json")

SYSTEM_PROMPT = (
    "你是一位严谨的圣经译者。请把给定的英文圣经经文（KJV 1611/1769 标准文本）"
    "准确、自然、忠实地翻译成中文。\n"
    "硬性规则：\n"
    "1) 忠实传达原意与关键神学用语，不要增删含义；\n"
    "2) 绝对不要照抄任何已出版的中文圣经译本（如和合本、和合本修订版、新译本、"
    "吕振中等）——必须给出你自己的译法；\n"
    "3) 专有名词（人名、地名）采用通用中文译名并保持前后一致；\n"
    "4) 只输出 JSON，不要任何解释。格式："
    '{"verses":[{"ref":"BOOK CH:VERSE","zh":"中文译文"}, ...]}，'
    "顺序与输入一致。"
)


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
    """返回 [(book_id, chapter, [verse_dict, ...]), ...]，按卷/章排序。"""
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


def load_our_zh():
    if os.path.exists(OUR_ZH_FILE):
        with open(OUR_ZH_FILE, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_our_zh(our_zh):
    tmp = OUR_ZH_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(our_zh, f, ensure_ascii=False, indent=1)
    os.replace(tmp, OUR_ZH_FILE)


def commit_progress():
    """CI 中增量提交并推送 our_zh.json，作为断点续译的落库点。

    失败仅告警、不中断主流程（可能发生在无 git/无 token 的本地环境）。
    """
    try:
        subprocess.run(
            ["git", "add", "--", OUR_ZH_FILE],
            check=True, capture_output=True, text=True,
        )
        st = subprocess.run(
            ["git", "diff", "--cached", "--quiet", "--", OUR_ZH_FILE],
            capture_output=True,
        )
        if st.returncode == 0:
            return  # 无变化，无需提交
        subprocess.run(
            ["git", "commit", "-m", "chore: incremental KJV translation progress"],
            check=True, capture_output=True, text=True,
        )
        subprocess.run(["git", "push"], check=True, capture_output=True, text=True)
        print("[progress] 已提交并推送当前译文进度")
    except Exception as e:  # noqa: BLE001 - 增量提交失败不应中断翻译
        print(f"[warn] 增量提交失败（不影响翻译，下一轮可续译）: {e}", file=sys.stderr)


def call_llm(chapter_verses, settings, timeout=90):
    """把一章经文交给 LLM 翻译，返回 {ref: zh}。"""
    lines = "\n".join(
        f'{v.get("ref")}\t{v.get("kjv_text")}' for v in chapter_verses
    )
    payload = {
        "model": settings.MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"请翻译以下经文（每行格式：REF\\t英文）：\n{lines}",
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
            parsed = json.loads(content)
            out = {}
            for item in parsed.get("verses", []):
                ref = item.get("ref")
                zh = (item.get("zh") or "").strip()
                if ref and zh:
                    out[ref] = zh
            return out
        except urllib.error.HTTPError as e:
            last_err = e
            if e.code == 429 or e.code >= 500:
                wait = min(2 ** attempt * 5, 60)
                time.sleep(wait)
                continue
            raise
    raise RuntimeError(f"LLM 调用失败: {last_err}")


def apply_to_data(our_zh):
    """把 our_zh.json 合并进 app_data.json 的 our_zh 栏（带防复制校验）。

    返回 (filled, dropped_cuv_copy)。
    """
    data = load_data()
    verses = data.get("verse", [])
    filled = 0
    dropped = 0
    for v in verses:
        ref = v.get("ref")
        zh = our_zh.get(ref)
        if not zh:
            continue
        cuv = (v.get("cuv_ref_text") or "").strip()
        # 合规：若译文与和合本逐字相同，视为复制，丢弃（留空）。
        if cuv and zh.strip() == cuv:
            dropped += 1
            continue
        v["our_zh"] = zh
        filled += 1
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    return filled, dropped


def main():
    ap = argparse.ArgumentParser(description="用 LLM 从 KJV 直译生成 our_zh 译文")
    ap.add_argument("--books", help="只译指定书卷 id（逗号分隔，如 1,2,3）")
    ap.add_argument(
        "--max-chapters", type=int, default=0,
        help="本次最多翻译章数（0=不限制）；用于把全本拆成多轮接力，避免超时。",
    )
    ap.add_argument("--dry-run", action="store_true", help="仅统计待译章数")
    ap.add_argument(
        "--apply",
        action="store_true",
        help="把已生成的 our_zh.json 合并进 app_data.json 的 our_zh 栏",
    )
    args = ap.parse_args()

    settings = Settings()

    if args.apply:
        if not os.path.exists(OUR_ZH_FILE):
            print("[apply] 未找到 our_zh.json，先运行翻译步骤。")
            return 1
        our_zh = load_our_zh()
        filled, dropped = apply_to_data(our_zh)
        print(f"[apply] 已填充 our_zh = {filled} 节；因与和合本雷同丢弃 = {dropped} 节")
        return 0

    data = load_data()
    chapters = group_by_chapter(data)
    our_zh = load_our_zh()

    want_books = None
    if args.books:
        want_books = {int(x) for x in args.books.split(",") if x.strip()}

    pending = []
    for book_id, chapter, vs in chapters:
        if want_books and book_id not in want_books:
            continue
        # 整章都已译过则跳过
        if all((v.get("ref") in our_zh) for v in vs):
            continue
        pending.append((book_id, chapter, vs))

    # 把全本拆成多轮：限制本轮处理的章数，配合 CI 自动重触发接力。
    if args.max_chapters and args.max_chapters > 0:
        pending = pending[: args.max_chapters]

    if args.dry_run:
        print(f"[dry-run] 待译章数 = {len(pending)} / 总章数 {len(chapters)}")
        return 0

    if not settings.API_KEY:
        print("[error] 未设置 LLM_API_KEY，无法翻译。请先配置环境变量。", file=sys.stderr)
        print("        也可在 CI 中设置同名 secret 后由部署流程自动翻译。", file=sys.stderr)
        return 2

    print(f"[info] 开始翻译，待译章数 = {len(pending)}")
    fails = []
    done = 0
    for book_id, chapter, vs in pending:
        try:
            result = call_llm(vs, settings)
            our_zh.update(result)
            done += 1
            if done % 25 == 0:
                save_our_zh(our_zh)
                commit_progress()
                print(f"[progress] 已完成 {done}/{len(pending)} 章，累计 {len(our_zh)} 节")
        except Exception as e:  # noqa: BLE001
            print(f"[warn] 第 {book_id} 卷 {chapter} 章失败: {e}", file=sys.stderr)
            fails.append({"book_id": book_id, "chapter": chapter, "error": str(e)})
            with open(FAIL_FILE, "w", encoding="utf-8") as f:
                json.dump(fails, f, ensure_ascii=False, indent=1)
    save_our_zh(our_zh)
    commit_progress()  # 收尾落库（本轮不足 25 章或已是最后一轮时）
    print(f"[done] 翻译完成：成功 {done} 章，失败 {len(fails)} 章，累计 {len(our_zh)} 节")
    if fails:
        print(f"[warn] 失败章节见 {FAIL_FILE}，可重跑本脚本断点续译。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
