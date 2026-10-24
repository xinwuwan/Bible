# _run_golden.py
# v51：黄金测试集 Python runner——与 Dart verify_offline_qa.dart 共用 test_data/qa_golden.json。
# 用 backend/app/kb.py 真实 FMM 逻辑跑全部用例，输出通过/失败统计与逐条明细。
# 用法：python _run_golden.py [--verbose]
import json
import sys

sys.path.insert(0, "backend/app")
from kb import KnowledgeBase, should_answer_direct

GOLDEN = "test_data/qa_golden.json"
FAQ = "flutter_app/assets/web/qa_faq.json"

doc = json.load(open(FAQ, encoding="utf-8"))
faq = doc["faq"]
data = json.load(open("flutter_app/assets/web/app_data.json", encoding="utf-8"))
# app_data.json 的 verse 用 book_id，需经 book 表转成 kb.py 契约要求的 book_code
books = {b["book_id"]: b["book_code"] for b in data.get("book", [])}
verses = []
for v in data.get("verse", []):
    v2 = dict(v)
    v2["book_code"] = books.get(v.get("book_id"), "")
    verses.append(v2)
kb = KnowledgeBase({"verses": verses, "doctrine": data.get("doctrine", []), "faq": faq})
golden = json.load(open(GOLDEN, encoding="utf-8"))


def retrieve_topk(question, top_k=3):
    """与 Dart OfflineQaLogic.retrieve 等价的 top-K（按 cov,score,n 排序）。"""
    q = kb._concepts(question)
    if not q:
        return []
    scored = []
    for i, entry in enumerate(faq):
        matched = kb._entry_concepts(entry) & q
        if not matched:
            continue
        score = sum(len(m) for m in matched)
        scored.append((len(matched) / len(q), score, len(matched), i))
    scored.sort(key=lambda x: (x[0], x[1], x[2]), reverse=True)
    return [i for _, _, _, i in scored[:top_k]]


def no_cuv(entry):
    return all(not c["source_id"].startswith("CUV") for c in entry.get("citations", []))


passed = failed = 0
fails = []
verbose = "--verbose" in sys.argv

for case in golden["cases"]:
    q = case["q"]
    expect = case["expect"]
    ok = True
    detail = ""
    entry, score, cov = kb.match_faq_full(q)

    if expect == "verse":
        v = kb.lookup_verse_ref(q)
        ok = v is not None and v.get("ref") == case["ref"]
        detail = "ref=%s" % (v.get("ref") if v else None)
    elif expect == "answer":
        direct = entry is not None and should_answer_direct(cov, score)
        ok = direct
        if ok:
            ans = entry["answer_zh"]
            for m in case.get("contains", []):
                if m not in ans:
                    ok = False
                    detail = "缺标记 %r" % m
            for m in case.get("notContains", []):
                if m in ans:
                    ok = False
                    detail = "误含 %r" % m
            if not no_cuv(entry):
                ok = False
                detail = "CUV 混入"
        else:
            detail = "未直接答 cov=%.2f sc=%d" % (cov, score)
    elif expect == "rag":
        # 离线层应转人工（不硬答），但 retrieve top-3 须含指定条目（RAG 兜底可救）
        direct = entry is not None and should_answer_direct(cov, score)
        topk = retrieve_topk(q)
        want = case.get("retrieveIdx")
        ok = (not direct) and (want in topk)
        detail = "direct=%s topk=%s" % (direct, topk)
    elif expect == "human":
        direct = entry is not None and should_answer_direct(cov, score)
        ok = not direct
        detail = "cov=%.2f sc=%d" % (cov, score)
    else:
        ok = False
        detail = "未知 expect: %s" % expect

    if ok:
        passed += 1
        if verbose:
            print("PASS [%s] %s" % (expect, q))
    else:
        failed += 1
        fails.append((q, expect, detail))
        print("FAIL [%s] %s -> %s" % (expect, q, detail))

print("\n黄金测试集：%d 通过 / %d 失败（共 %d 用例）" % (passed, failed, len(golden["cases"])))
sys.exit(1 if failed else 0)
