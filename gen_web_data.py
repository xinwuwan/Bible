# gen_web_data.py
# 把离线 SQLite 预置库（app_offline.db）导出为 web / 桌面 / 手机通用的 JSON 资源。
#
# 关键：列名必须与 UI 消费者严格一致（见 app_models.dart / web_data_core.dart）：
#   verse  : book_id, chapter, verse, ref, kjv_text, our_zh, cuv_ref_text
#   book   : book_id, book_code, name_en, name_zh, testament, chapter_count
#   doctrine: belief_id, code, title_en, title_zh, en_text, zh_text
#   health_*: 原样透传（模块 C 数据）
# ref 格式："<book_code> <chapter>:<verse>" 例如 "GEN 1:1"
#   （search_page._resolve 依赖此格式解析跳转动定位）
#
# 输出: flutter_app/assets/web/app_data.json
# 将来灌入全本 KJV/CUV/EGW 时，推荐直接用 fetch_kjv.py（自动下载全本）；
# 本脚本用于把本地 SQLite 样本库转为正确列名的 JSON 资源。

import json
import os
import sqlite3

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC_DB = os.path.join(ROOT, "app_offline.db")
OUT_DIR = os.path.join(ROOT, "flutter_app", "assets", "web")
OUT_FILE = os.path.join(OUT_DIR, "app_data.json")

# 仅透传、不改列名的表
PASSTHRU = [
    "doctrine",
    "health_topic",
    "health_topic_source",
    "health_metric",
    "health_guidance",
]


def main():
    if not os.path.exists(SRC_DB):
        raise SystemExit(f"找不到源库: {SRC_DB}")
    os.makedirs(OUT_DIR, exist_ok=True)

    con = sqlite3.connect(SRC_DB)
    con.row_factory = sqlite3.Row
    cur = con.cursor()

    # book_id -> book_code（用于生成 ref）
    cur.execute("SELECT book_id, book_code FROM book ORDER BY book_id")
    code_by_id = {r["book_id"]: r["book_code"] for r in cur.fetchall()}

    # ---- verse：重映射到 UI 期望列名 + 生成规范 ref ----
    cur.execute(
        "SELECT book_id, chapter, verse, ref, kjv_text, our_zh, cuv_ref_text "
        "FROM verse ORDER BY book_id, chapter, verse"
    )
    verses = []
    for r in cur.fetchall():
        bid = r["book_id"]
        ch = r["chapter"]
        vs = r["verse"]
        ref = (r["ref"] or "").strip() or f"{code_by_id.get(bid, '?')} {ch}:{vs}"
        verses.append(
            {
                "book_id": bid,
                "chapter": ch,
                "verse": vs,
                "ref": ref,
                "kjv_text": r["kjv_text"] or "",
                # 空值写为 null，让卡片显示「（译文待补充）」「（无参照文本）」而非空白
                "our_zh": r["our_zh"] if r["our_zh"] else None,
                "cuv_ref_text": r["cuv_ref_text"] if r["cuv_ref_text"] else None,
            }
        )
    con.close()

    out = {"verse": verses}

    # ---- book：保留全部列 ----
    con = sqlite3.connect(SRC_DB)
    con.row_factory = sqlite3.Row
    cur = con.cursor()
    cur.execute(
        "SELECT book_id, book_code, name_en, name_zh, testament, chapter_count "
        "FROM book ORDER BY book_id"
    )
    out["book"] = [dict(r) for r in cur.fetchall()]

    # ---- 健康 / 教义：原样透传 ----
    for t in PASSTHRU:
        try:
            cur.execute(f"SELECT * FROM '{t}'")
            cols = [d[0] for d in cur.description]
            out[t] = [dict(zip(cols, row)) for row in cur.fetchall()]
        except sqlite3.Error:
            out[t] = []
    con.close()

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)

    size_kb = os.path.getsize(OUT_FILE) / 1024
    print(f"已写出: {OUT_FILE}  ({size_kb:.1f} KB)")
    print("  verse      ", len(out["verse"]), "行")
    print("  book       ", len(out["book"]), "行")
    for t in PASSTHRU:
        print(f"  {t:12} ", len(out[t]), "行")


if __name__ == "__main__":
    main()
