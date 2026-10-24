# _patch_v53_golden.py
# v53：黄金测试集调整 + idx8 关键词补充
#   1) idx8（安息日条目）补 周六/礼拜六/周六聚会 关键词——该条目本就该拥有这些词
#      （「你们为什么周六聚会」的 residue「周六」进词典后，FMM 可切出，
#        retrieve 能同时取到 idx8+idx43 供 RAG 综合，答案质量更高）
#   2) 三个真残留用例翻转为 rag 期望（诚实：离线层不硬答，RAG 兜底综合）：
#      - 孕妇能受洗吗：残留「孕妇」，洗礼条目文本未涵盖 -> rag (retrieveIdx 10)
#      - 基督什么时候再来：残留「基督」，再来条目文本未涵盖 -> rag (retrieveIdx 11)
#      - 你们为什么周六聚会：跨条目（周六=idx8 / 聚会=idx43）-> rag (retrieveIdx 8)
#   3) 新增 v53 回归用例：家庭主题（直接答）+ 未覆盖主题否决（转人工）
import json
from pathlib import Path

ROOT = Path("C:/Users/xinwu/WorkBuddy/2026-10-05-14-30-06")
FAQ = ROOT / "flutter_app/assets/web/qa_faq.json"
GOLDEN = ROOT / "test_data/qa_golden.json"

# ---- 1) idx8 补关键词 ----
doc = json.loads(FAQ.read_text(encoding="utf-8"))
faq = doc["faq"]
idx8 = faq[8]
kws = list(idx8.get("keywords", []))
for w in ["周六", "礼拜六", "周六聚会", "星期六"]:
    if w not in kws:
        kws.append(w)
idx8["keywords"] = kws
print("idx8 keywords now:", kws)
FAQ.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

# ---- 2) 黄金集翻转 ----
g = json.loads(GOLDEN.read_text(encoding="utf-8"))
flips = {
    "孕妇能受洗吗": {"expect": "rag", "retrieveIdx": 10,
                    "note": "v53：残留实义主题「孕妇」未被洗礼条目文本覆盖，否决硬答；RAG兜底应能取到idx10"},
    "基督什么时候再来": {"expect": "rag", "retrieveIdx": 11,
                        "note": "v53：残留「基督」未被再来条目文本覆盖，否决硬答；RAG兜底应能取到idx11"},
    "你们为什么周六聚会": {"expect": "rag", "retrieveIdx": 8,
                          "note": "v53：跨条目问句（周六=idx8/聚会=idx43），RAG兜底应能同时取到两条综合"},
}
n_flip = 0
for c in g["cases"]:
    if c["q"] in flips:
        # 清掉旧的 answer 型字段
        for k in ["contains", "notContains", "ref"]:
            c.pop(k, None)
        c.update(flips[c["q"]])
        n_flip += 1
print("flipped cases:", n_flip)

# ---- 3) 新增 v53 用例 ----
new_cases = [
    {"q": "怀爱伦的著作中，有哪些是关于家庭的？", "expect": "answer",
     "contains": ["复临信徒的家庭", "教会证言"], "notContains": ["入门路线"],
     "note": "v53 核心回归：原答非所问（误中idx239入门路线）；新家庭条目应直接答"},
    {"q": "怀爱伦有哪些关于家庭的书", "expect": "answer",
     "contains": ["复临信徒的家庭"], "note": "v53：家庭问句另一说法"},
    {"q": "怀爱伦论家庭", "expect": "answer",
     "contains": ["家庭"], "note": "v53：家庭问句最短说法"},
    {"q": "怀爱伦的著作中，有哪些是关于外星人的？", "expect": "human",
     "note": "v53 否决护栏：未收录主题词（外星人）必须转人工，不得硬答"},
    {"q": "怀爱伦的著作中，有哪些是关于考古学的？", "expect": "human",
     "note": "v53 否决护栏：未收录主题词（考古学）必须转人工"},
]
have = {c["q"] for c in g["cases"]}
added = 0
for c in new_cases:
    if c["q"] not in have:
        g["cases"].append(c)
        added += 1
print("added cases:", added, "| total now:", len(g["cases"]))
GOLDEN.write_text(json.dumps(g, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
