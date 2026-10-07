#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_injected_data.py - CI 注入后的数据完整性硬闸门
========================================================
在 fetch_kjv.py / fetch_cuv.py 之后、flutter build web 之前运行。
任何一项不满足都返回非 0，让构建亮红灯，杜绝"静默发布坏数据站点"。

检查项（全部满足才放行）:
  1. book 数组恰好 66 卷
  2. verse >= 30000 节（全本 KJV 约 31100 节）
  3. GEN 1:1 的 kjv_text 非空（KJV 注入成功）
  4. GEN 1:1 的 cuv_ref_text 非空（和合本参照列已注入）
  5. 和合本参照列覆盖率 >= 99%（全本可参照）
  6. 抽查 REV 22:21 / MAL 4:6 的 kjv_text 非空（末卷抽查）
  7. our_zh 若存在，不得与和合本(cuv_ref_text)逐字相同（合规：译文须由应用独立产出，不得复制现有中文译本）
  8. health_topic / doctrine 等模块 C、教义数据仍在（未被注入覆盖丢失）

用法:
  python3 verify_injected_data.py                     # 检查默认文件
  python3 verify_injected_data.py <path/app_data.json> # 检查指定文件（本地测试用）
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
DEFAULT_FILE = os.path.join(
    ROOT, "flutter_app", "assets", "web", "app_data.json"
)

errors = []


def check(name, ok, detail=""):
    tag = "PASS" if ok else "FAIL"
    print(f"[{tag}] {name}" + (f" - {detail}" if detail else ""))
    if not ok:
        errors.append(name)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_FILE
    if not os.path.exists(path):
        print(f"[FAIL] 文件不存在: {path}")
        return 2
    size_mb = os.path.getsize(path) / 1024 / 1024
    print(f"[info] verifying {path} ({size_mb:.1f} MB)")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    books = data.get("book", [])
    verses = data.get("verse", [])
    check("book 恰好 66 卷", len(books) == 66, f"got {len(books)}")
    check("verse >= 30000", len(verses) >= 30000, f"got {len(verses)}")

    idx = {(v.get("book_id"), v.get("chapter"), v.get("verse")): v for v in verses}
    gen11 = idx.get((1, 1, 1), {})
    check(
        "GEN 1:1 kjv_text 非空",
        bool((gen11.get("kjv_text") or "").strip()),
        repr((gen11.get("kjv_text") or "")[:40]),
    )
    check(
        "GEN 1:1 cuv_ref_text 非空（和合本参照已注入）",
        bool((gen11.get("cuv_ref_text") or "").strip()),
        repr((gen11.get("cuv_ref_text") or "")[:20]),
    )

    # 和合本参照列覆盖率（全本应能参照）
    cuv_filled = sum(1 for v in verses if (v.get("cuv_ref_text") or "").strip())
    check(
        "和合本参照列覆盖率 >= 99%",
        len(verses) > 0 and cuv_filled / len(verses) >= 0.99,
        f"{cuv_filled}/{len(verses)} = {cuv_filled / max(len(verses), 1):.1%}",
    )

    # 合规：our_zh 可由 LLM 从 KJV 直译填充，但绝不能与和合本逐字相同
    # （不得复制现有中文译本）。
    zh_filled = sum(1 for v in verses if (v.get("our_zh") or "").strip())
    copy_violations = sum(
        1
        for v in verses
        if (v.get("our_zh") or "").strip()
        and (v.get("our_zh") or "").strip() == (v.get("cuv_ref_text") or "").strip()
    )
    check(
        "our_zh 未复制和合本（逐字相同计数=0，合规）",
        copy_violations == 0,
        f"our_zh 已填充 {zh_filled} 节；与和合本雷同 {copy_violations} 节",
    )

    rev = idx.get((66, 22, 21), {})
    check(
        "REV 22:21 kjv_text 非空（末卷抽查）",
        bool((rev.get("kjv_text") or "").strip()),
        repr((rev.get("kjv_text") or "")[:40]),
    )
    mal = idx.get((39, 4, 6), {})
    check(
        "MAL 4:6 kjv_text 非空（旧约末卷抽查）",
        bool((mal.get("kjv_text") or "").strip()),
        repr((mal.get("kjv_text") or "")[:40]),
    )

    for key in ("doctrine", "health_topic"):
        check(
            f"{key} 数据保留（模块 C / 教义未被覆盖丢失）",
            len(data.get(key, [])) > 0,
            f"got {len(data.get(key, []))}",
        )

    if errors:
        print(f"\n[FAIL] {len(errors)} 项不达标: {errors}")
        print(">>> 禁止发布：请检查 fetch 步骤日志或重新运行构建 <<<")
        return 1
    print("\n[OK] 注入数据完整性全部通过，可以发布")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
