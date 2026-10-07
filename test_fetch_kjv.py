# test_fetch_kjv.py
# 纯逻辑验证 fetch_kjv 的 JSON 解析 / 文件名映射 / 列名契约（不触发网络）。
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fetch_kjv as fk

# 1) 文件名映射（与 aruljohn 仓库真实文件名对齐，这是修 404 的关键）
assert fk.book_filename("Genesis") == "Genesis.json"
assert fk.book_filename("1 Samuel") == "1Samuel.json"
assert fk.book_filename("Song of Solomon") == "SongofSolomon.json"
assert fk.book_filename("Matthew") == "Matthew.json"

# 2) 单卷 aruljohn JSON 解析
SAMPLE = json.dumps({
    "book": "Genesis",
    "chapters": [
        {"chapter": "1", "verses": [
            {"verse": "1", "text": "In the beginning God created the heaven and the earth."},
            {"verse": "2", "text": "And the earth was without form, and void."},
        ]},
        {"chapter": "2", "verses": [
            {"verse": "1", "text": "Thus the heavens and the earth were finished."},
        ]},
    ],
})
vs = fk.parse_book_json(SAMPLE, "GEN", 1)
assert len(vs) == 3, vs
expected_keys = {"book_id", "chapter", "verse", "ref", "kjv_text", "our_zh", "cuv_ref_text"}
for v in vs:
    assert set(v.keys()) == expected_keys, v.keys()
    assert v["our_zh"] is None and v["cuv_ref_text"] is None
    assert v["kjv_text"].endswith(".")
assert vs[0]["ref"] == "GEN 1:1", vs[0]["ref"]
assert vs[1]["ref"] == "GEN 1:2"
assert vs[2]["ref"] == "GEN 2:1"
assert vs[0]["book_id"] == 1

# 3) 书卷元数据完整（66 卷，首末正确）
books = fk.build_books()
assert len(books) == 66, len(books)
assert books[0]["book_code"] == "GEN" and books[-1]["book_code"] == "REV"

# 4) 离线目录抓取：用临时目录构造两卷 JSON，验证 collect_verses 合并正确
with tempfile.TemporaryDirectory() as d:
    # Genesis.json
    with open(os.path.join(d, "Genesis.json"), "w", encoding="utf-8") as f:
        f.write(SAMPLE)
    # Matthew.json
    matt = json.dumps({"book": "Matthew", "chapters": [
        {"chapter": "1", "verses": [{"verse": "1", "text": "The book of the generation of Jesus Christ."}]},
    ]})
    with open(os.path.join(d, "Matthew.json"), "w", encoding="utf-8") as f:
        f.write(matt)
    code_to_id = {b["book_code"]: b["book_id"] for b in books}
    verses, failed = fk.collect_verses("https://example.invalid/", code_to_id, offline_dir=d)
    # 离线目录只放 2 卷，其余 64 卷缺文件是预期的
    assert len(failed) == 64, len(failed)
    assert len(verses) == 4, len(verses)  # GEN(3 节) + MAT(1 节)
    refs = {v["ref"] for v in verses}
    assert "GEN 1:1" in refs and "MAT 1:1" in refs, refs
    # 书卷顺序：GEN(1) 后 Matthew(40)，MAT 的 book_id 应为 40
    mat = [v for v in verses if v["ref"] == "MAT 1:1"][0]
    assert mat["book_id"] == 40, mat["book_id"]

print("OK fetch_kjv: filename-map + aruljohn JSON parse + 66-book meta + offline dir all verified")
