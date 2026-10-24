# _regress_qa_v50.py
# v50 路由回归：用 backend/app/kb.py 真实 FMM 匹配，验证 18 条新增怀著专题条目可达，
# 且不会把既有专属问句答非所问。
import json, sys
sys.path.insert(0, "backend/app")
from kb import KnowledgeBase

doc = json.load(open("flutter_app/assets/web/qa_faq.json", encoding="utf-8"))
faq = doc["faq"]
n_before = 243
new_idx = list(range(n_before, len(faq)))
kb = KnowledgeBase({"faq": faq})

def ans_of(entry):
    return entry.get("answer_zh", "")

print("== 新增条目可达性（用各自最特异的关键词试探）==")
problems = []
for i in new_idx:
    e = faq[i]
    kws = e["keywords"]
    # 选最长的关键词（最特异）依次试探，看能否命中本条目
    win = None
    for kw in sorted(kws, key=len, reverse=True):
        best, score, cov = kb.match_faq_full(kw)
        if best is e:
            win = kw
            break
    if win is None:
        # 退而求其次：试所有关键词，看是否至少有一条能命中本条目
        for kw in kws:
            best, score, cov = kb.match_faq_full(kw)
            if best is e:
                win = kw
                break
    if win is None:
        # 找最长关键词实际命中了谁
        probe = max(kws, key=len)
        best, score, cov = kb.match_faq_full(probe)
        winner_idx = faq.index(best) if best in faq else -1
        problems.append((i, kws, probe, winner_idx))
        print(f"  [SHADOW] idx{i} 全部关键词被 idx{winner_idx} 抢答 | probe={probe!r}")
    else:
        print(f"  [OK]     idx{i} 经 {win!r} 可达 | 关键词数={len(kws)}")

print("\n== 既有专属问句回归（不能被新条目抢答）==")
regress = [
    ("你们守安息日吗", "安息日"),
    ("怎么才能得救呢", "得救"),
    ("怀爱伦的著作中哪些是关于健康事工的？", "医疗布道"),  # a7
    ("怀爱伦的著作中哪些是关于儿童教育的？", "教育论"),      # a9
    ("怀著有哪些", "历代愿望"),                              # a11
    ("从哪本开始读怀著", "喜乐的密码"),                      # a12
    ("幼儿奉献礼是什么意思", "哈拿"),                        # a13
    ("十一奉献是什么意思", "十分之一"),                      # a14
    ("家庭祭坛怎么搞", "敬拜"),                              # a15
    ("夫妻一起祷告好吗", "冷战"),                            # a16
    ("怀爱伦", "预言恩赐"),                                    # 裸词应落 idx23
]
fail = 0
for q, expect in regress:
    best, score, cov = kb.match_faq_full(q)
    got = ans_of(best)
    idx = faq.index(best) if best in faq else -1
    ok = expect in got
    if not ok:
        fail += 1
        print(f"  [FAIL] {q!r} -> idx{idx} 缺 {expect!r} | cov={cov:.2f}")
    else:
        print(f"  [OK]   {q!r} -> idx{idx} (含 {expect!r})")

print("\n== v50 新条目代表性路由 ==\n")
probe_q = [
    "怀爱伦怎么看饮食", "怀爱伦论节制", "newstart 八大原则",
    "怀爱伦论教育", "怀爱伦论安息日", "怀爱伦论死亡",
    "怀爱伦论医疗布道", "怀爱伦论祷告", "如何读怀著", "怀著权威",
    "怀爱伦论十一奉献", "怀爱伦论家庭教育", "喜乐乃是良药",
    "怀爱伦论医治", "怀爱伦论复临", "圣经是孩子的第一本书",
    "怀爱伦论运动", "怀爱伦论阳光",
]
for q in probe_q:
    best, score, cov = kb.match_faq_full(q)
    idx = faq.index(best) if best in faq else -1
    print(f"  {q!r:24} -> idx{idx:3} cov={cov:.2f} score={score} | {ans_of(best)[:24]}")

print(f"\nSHADOW 问题数: {len(problems)} | 回归失败数: {fail}")
sys.exit(1 if problems or fail else 0)
