# -*- coding: utf-8 -*-
"""v55：黄金测试集补「怀爱伦对于家庭的著作」类问法（用户 2026-10-25 实报）。

新增 4 例（71 -> 75）：
- 用户原句「怀爱伦对于家庭的著作有哪些」（补词+第四决胜键双重修复）
- 裸词平局场景「怀爱伦 家庭 著作」（空格强制切断复合词，纯第四决胜键路径）
- 变体问法两例
幂等：q 已存在则跳过。
"""
import io
import json
from pathlib import Path

ROOT = Path("C:/Users/xinwu/WorkBuddy/2026-10-05-14-30-06")
GOLDEN = ROOT / "test_data/qa_golden.json"

doc = json.load(io.open(GOLDEN, encoding="utf-8"))
cases = doc["cases"]
existing = {c["q"] for c in cases}

NEW = [
    {
        "q": "怀爱伦对于家庭的著作有哪些",
        "expect": "answer",
        "contains": ["复临信徒的家庭", "教会证言"],
        "notContains": ["入门路线"],
        "note": "v55 用户实报原句：曾三项平局败给队首入门路线条目（cov=0.667 score=5 平局）；「对于家庭」复合词 + 第四决胜键双重修复",
    },
    {
        "q": "怀爱伦 家庭 著作",
        "expect": "answer",
        "contains": ["复临信徒的家庭"],
        "notContains": ["入门路线"],
        "note": "v55：空格强制切断复合词 -> {怀爱伦,家庭,著作} 裸词三元组，纯第四决胜键路径（上位词命中 0 < 1）",
    },
    {
        "q": "怀爱伦有关家庭的著作有哪些",
        "expect": "answer",
        "contains": ["复临信徒的家庭"],
        "note": "v55：「有关家庭」变体",
    },
    {
        "q": "怀爱伦家庭方面的著作",
        "expect": "answer",
        "contains": ["复临信徒的家庭"],
        "note": "v55：「家庭方面」变体",
    },
]

add = [c for c in NEW if c["q"] not in existing]
if not add:
    print("ALL PRESENT, nothing to do")
    raise SystemExit(0)

cases.extend(add)
with io.open(GOLDEN, "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=2)
    f.write("\n")
print("golden cases: %d -> %d" % (len(existing), len(cases)))
print("added:", [c["q"] for c in add])
