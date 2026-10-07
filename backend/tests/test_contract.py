# backend/tests/test_contract.py
# 纯逻辑契约测试：不依赖 fastapi，直接验证合规闸门 + 知识库检索 + 离线回答器。
# 运行（在 backend/ 目录）：python tests/test_contract.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.kb import KnowledgeBase  # noqa: E402
from app import compliance  # noqa: E402
from app.responder import OfflineResponder  # noqa: E402

KB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "kb.json")
kb = KnowledgeBase.load(KB_PATH)

passed = 0
failed = 0


def check(name, cond):
    global passed, failed
    if cond:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        print(f"  FAIL  {name}")


print("== kb.json 加载与统计 ==")
check("verses >= 30", len(kb.verses) >= 30)
check("doctrine >= 19", len(kb.doctrine) >= 19)
check("faq >= 15", len(kb.faq) >= 15)

print("== 合规闸门：CUV 必须被剔除 ==")
ans = {
    "answer_id": "t1", "answer_zh": "x",
    "citations": [
        {"source_type": "BIBLE", "source_id": "KJV-JHN3:16", "ref": "JHN 3:16", "snippet": "a"},
        {"source_type": "BIBLE", "source_id": "CUV-JHN3:16", "ref": "JHN 3:16", "snippet": "b"},
    ],
    "confidence": 0.9, "needs_human": False,
}
cleaned, viol = compliance.enforce(ans)
check("CUV 引用被剔除", all(not c["source_id"].upper().startswith("CUV") for c in cleaned["citations"]))
check("剔除后剩余 1 条", len(cleaned["citations"]) == 1)

print("== 合规闸门：无引用非人工回答必须转人工 ==")
ans2 = {"answer_id": "t2", "answer_zh": "y", "citations": [], "confidence": 0.9, "needs_human": False}
cleaned2, viol2 = compliance.enforce(ans2)
check("needs_human 被强制置 True", cleaned2["needs_human"] is True)

print("== 合规闸门：低置信被标记 ==")
ans3 = {"answer_id": "t3", "answer_zh": "z", "citations": [{"source_type": "BIBLE", "source_id": "KJV-X", "ref": "X", "snippet": "s"}], "confidence": 0.5, "needs_human": False}
_, viol3 = compliance.enforce(ans3)
check("低置信(0.5)触发标记", any("置信过低" in v for v in viol3))

print("== 知识库 FAQ 关键词匹配 ==")
entry, score = kb.match_faq("请问你们守安息日吗")
check("安息日问题命中 FAQ", entry is not None and score > 0)
entry2, score2 = kb.match_faq("怎么才能得救")
check("得救问题命中 FAQ", entry2 is not None and score2 > 0)

print("== 知识库经文引用解析（中英） ==")
v_cn = kb.lookup_verse_ref("约翰福音3章16节")
check("中文引用解析 -> JHN 3:16", v_cn is not None and v_cn["ref"] == "JHN 3:16")
v_en = kb.lookup_verse_ref("JHN 3:16")
check("英文引用解析 -> JHN 3:16", v_en is not None and v_en["ref"] == "JHN 3:16")
v_miss = kb.lookup_verse_ref("不存在的书 99:99")
check("无效引用返回 None", v_miss is None)

print("== EGW 经审核原文接入 ==")
check("egw 原文 >= 5", len(kb.egw) >= 5)
check("find_egw(守安息日) 命中", len(kb.find_egw("你们守安息日吗")) >= 1)
check("find_egw(怎么得救) 命中 EGW", len(kb.find_egw("怎样可以得救")) >= 1)
check("find_egw(人死后去哪) 命中 EGW", len(kb.find_egw("人死后去哪里")) >= 1)
# 合规闸门不得误删 EGW 引用（只删 CUV）
egw_ans = {
    "answer_id": "egw1", "answer_zh": "x",
    "citations": [
        {"source_type": "EGW", "source_id": "EGW-DA-288", "ref": "DA 288", "snippet": "s"},
        {"source_type": "BIBLE", "source_id": "CUV-JHN3:16", "ref": "JHN 3:16", "snippet": "b"},
    ],
    "confidence": 0.9, "needs_human": False,
}
cleaned_egw, _ = compliance.enforce(egw_ans)
check("EGW 引用被保留（未被合规闸门误删）",
      any(c["source_id"].startswith("EGW") for c in cleaned_egw["citations"]))
check("EGW 答案中 CUV 已被剔除",
      all(not c["source_id"].upper().startswith("CUV") for c in cleaned_egw["citations"]))

print("== 离线回答器端到端（含 EGW）==")
resp_egw = OfflineResponder(kb).ask("你们守安息日吗")
check("安息日回答含 EGW 引用", any(c["source_type"] == "EGW" for c in resp_egw[0]["citations"]))
check("安息日回答无 CUV", all(not c["source_id"].upper().startswith("CUV") for c in resp_egw[0]["citations"]))

print("== 离线回答器端到端 ==")
resp = OfflineResponder(kb).ask("你们守安息日吗")
check("安息日回答有效引用", len(resp[0]["citations"]) >= 1)
check("安息日回答非人工", resp[0]["needs_human"] is False)
check("安息日回答无 CUV", all(not c["source_id"].upper().startswith("CUV") for c in resp[0]["citations"]))

resp_needs = OfflineResponder(kb).ask("今天天气怎么样zzz无关问题")
check("无命中 -> needs_human=True", resp_needs[0]["needs_human"] is True)
check("无命中 -> 无臆测回答正文为空引用", resp_needs[0]["answer_zh"].startswith("这个问题我暂时"))

print(f"\n结果：{passed} 通过 / {failed} 失败")
sys.exit(1 if failed else 0)
