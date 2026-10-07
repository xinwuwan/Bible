# backend/tests/test_api.py
# API 契约测试（需要 fastapi + httpx）：用 TestClient 验证 /health、/qa/ask、/qa/{id}/feedback。
# 运行（在 backend/ 目录）：python tests/test_api.py
# 若未安装依赖，先：pip install -r requirements.txt
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from fastapi.testclient import TestClient  # noqa: E402
except ImportError:
    print("SKIP: fastapi/testclient 未安装（pip install -r requirements.txt 后重试）")
    sys.exit(0)

# 必须在导入 app.main 之前设定环境变量，避免加载到错误的 KB 路径
os.environ.setdefault("KB_PATH", os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "kb.json"))
os.environ.setdefault("QA_MODE", "offline")

from app.main import app  # noqa: E402

client = TestClient(app)
passed = failed = 0


def check(name, cond):
    global passed, failed
    if cond:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        print(f"  FAIL  {name}")


print("== /health ==")
r = client.get("/health")
check("health 200", r.status_code == 200)
check("health mode=offline", r.json().get("mode") == "offline")
check("health 含 kb 统计", "kb" in r.json())

print("== /qa/ask（命中 FAQ） ==")
r = client.post("/qa/ask", json={"question": "你们守安息日吗", "locale": "zh"})
check("ask 200", r.status_code == 200)
body = r.json()
check("返回 answer_id", bool(body.get("answer_id")))
check("返回 answer_zh 非空", bool(body.get("answer_zh")))
check("返回 citations", len(body.get("citations", [])) >= 1)
check("citations 无 CUV", all(not c["source_id"].upper().startswith("CUV") for c in body["citations"]))
check("非人工回答", body.get("needs_human") is False)

print("== /qa/ask（无命中 -> 转人工） ==")
r = client.post("/qa/ask", json={"question": "今天天气zzz无关", "locale": "zh"})
body = r.json()
check("无命中 needs_human=True", body.get("needs_human") is True)

print("== /qa/ask（空问题 400） ==")
r = client.post("/qa/ask", json={"question": "   ", "locale": "zh"})
check("空问题 400", r.status_code == 400)

print("== /qa/{id}/feedback ==")
r = client.post("/qa/qa_test/feedback", json={"rating": 5, "comment": "很好"})
check("feedback 200", r.status_code == 200)
check("feedback status=received", r.json().get("status") == "received")
r2 = client.post("/qa/qa_test/feedback", json={"rating": 9})
check("feedback 非法 rating 400", r2.status_code == 400)

print(f"\n结果：{passed} 通过 / {failed} 失败")
sys.exit(1 if failed else 0)
