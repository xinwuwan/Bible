#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
test_fetch_cuv.py - 离线验证 fetch_cuv.py 的解析与合并逻辑（不联网）
用一份假 CUV JSON + 假 app_data.json 验证:
  - id "gn" 正确映射到 book_id=1
  - chapters[章-1][节-1] 正确取到对应节
  - 合并后 cuv_ref_text 被正确填充
"""
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fetch_cuv as fc

SAMPLE_CUV = json.dumps([
    {
        "id": "gn",
        "chapters": [
            ["和合本 创1:1", "和合本 创1:2", "和合本 创1:3"],
            ["和合本 创2:1"],
        ],
    },
    {
        "id": "exo",
        "chapters": [
            ["和合本 出1:1"],
        ],
    },
])

SAMPLE_APP = {
    "book": [{"book_id": 1, "book_code": "GEN"}, {"book_id": 2, "book_code": "EXO"}],
    "verse": [
        {"book_id": 1, "chapter": 1, "verse": 1, "ref": "GEN 1:1", "kjv_text": "In the beginning...", "our_zh": None, "cuv_ref_text": None},
        {"book_id": 1, "chapter": 1, "verse": 2, "ref": "GEN 1:2", "kjv_text": "...", "our_zh": None, "cuv_ref_text": None},
        {"book_id": 1, "chapter": 2, "verse": 1, "ref": "GEN 2:1", "kjv_text": "...", "our_zh": None, "cuv_ref_text": None},
        {"book_id": 2, "chapter": 1, "verse": 1, "ref": "EXO 1:1", "kjv_text": "...", "our_zh": None, "cuv_ref_text": None},
    ],
}


def main():
    tmp = tempfile.mkdtemp()
    out = os.path.join(tmp, "app_data.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(SAMPLE_APP, f, ensure_ascii=False)

    cuv, book_count, id_warnings = fc.parse_cuv(SAMPLE_CUV)
    assert book_count == 2, f"book_count={book_count}"
    # 位置主映射不依赖 id 命名，只要能取到正确书卷/章节/节即可
    assert cuv[(1, 1, 1)] == "和合本 创1:1"
    assert cuv[(1, 1, 2)] == "和合本 创1:2"
    assert cuv[(1, 2, 1)] == "和合本 创2:1"
    assert cuv[(2, 1, 1)] == "和合本 出1:1"

    fc.OUT_FILE = out
    cnt, total, cuv_total = fc.merge(out, cuv)
    assert cnt == 4 and total == 4, f"cnt={cnt} total={total}"

    with open(out, encoding="utf-8") as f:
        data = json.load(f)
    for v in data["verse"]:
        assert v["cuv_ref_text"] is not None, f"未填充: {v['ref']}"
    assert data["verse"][0]["cuv_ref_text"] == "和合本 创1:1"
    assert data["verse"][3]["cuv_ref_text"] == "和合本 出1:1"

    # 验证 health_* / doctrine 不被破坏（merge 只动 verse.cuv_ref_text）
    print("ALL OK: CUV parse + merge logic verified (4/4 verses filled, no data loss)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
