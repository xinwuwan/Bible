# backend/app/main.py
# FastAPI 入口：对齐前端 QaAnswer 契约。
#
# 端点：
#   GET  /health            健康检查（含 KB 统计、当前模式）
#   POST /qa/ask            {question, locale} -> QaAnswer
#   POST /qa/{answer_id}/feedback  {rating, comment?} -> {status}
#
# 合规闸门在 responder 内部已强制执行（enforce），这里再兜底一层：
#   返回前再次 check，若仍有违规（理论上不应发生）则强制转人工。
import os
import sys
import json
import time
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# 允许从 backend/ 直接以 `python -m app.main` 运行
sys.path.insert(0, str(Path(__file__).resolve().parent))

from .config import settings  # noqa: E402
from .kb import KnowledgeBase  # noqa: E402
from .responder import OfflineResponder, LlmResponder  # noqa: E402
from .compliance import check  # noqa: E402

app = FastAPI(title="Faith Compare QA Backend", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

kb = KnowledgeBase.load(settings.KB_PATH)
_use_llm = settings.MODE == "llm" and bool(settings.LLM_API_KEY)
responder = LlmResponder(kb, settings) if _use_llm else OfflineResponder(kb)


class AskReq(BaseModel):
    question: str
    locale: str = "zh"


class FeedbackReq(BaseModel):
    rating: int
    comment: str | None = None


def _store_feedback(answer_id: str, req: FeedbackReq):
    try:
        os.makedirs(settings.FEEDBACK_DIR, exist_ok=True)
        path = os.path.join(settings.FEEDBACK_DIR, "feedback.jsonl")
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(
                {"answer_id": answer_id, "rating": req.rating,
                 "comment": req.comment, "ts": time.time()},
                ensure_ascii=False,
            ) + "\n")
    except Exception:
        # 反馈落盘失败不影响主流程
        pass


@app.get("/health")
def health():
    return {
        "status": "ok",
        "mode": settings.MODE,
        "llm_enabled": _use_llm,
        "kb": {
            "verses": len(kb.verses),
            "doctrine": len(kb.doctrine),
            "faq": len(kb.faq),
        },
    }


@app.post("/qa/ask")
def qa_ask(req: AskReq):
    if not req.question or not req.question.strip():
        raise HTTPException(status_code=400, detail="question required")
    answer, _violations = responder.ask(req.question, req.locale)
    # 双保险：返回前再次校验，发现残留违规则强制转人工
    residual = check(answer)
    if residual:
        answer["needs_human"] = True
        answer["confidence"] = 0.0
        answer["answer_zh"] = "（返回前校验发现合规风险，已转交人工顾问）" + answer.get("answer_zh", "")
    return answer


@app.post("/qa/{answer_id}/feedback")
def qa_feedback(answer_id: str, req: FeedbackReq):
    if not (1 <= int(req.rating) <= 5):
        raise HTTPException(status_code=400, detail="rating must be 1..5")
    _store_feedback(answer_id, req)
    return {"status": "received"}
