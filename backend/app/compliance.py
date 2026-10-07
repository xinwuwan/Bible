# backend/app/compliance.py
# 服务端合规闸门 —— 与前端 CitationGuard 互为双保险。
#
# 红线（绝不妥协）：
#   1. 任何 source_id 以 "CUV" 开头 → 直接剔除（和合本绝不作权威来源）
#   2. 非 needs_human 的回答必须至少 1 条权威引用，否则强制转人工
#   3. 置信度 < 0.70 标记低置信（前端会提示转人工）
#
# 设计原则：服务端是最后一道墙，宁可"转人工"也绝不把无依据/违规内容交给用户。
import re

CUV_PREFIX = "CUV"
MIN_CONFIDENCE = 0.70


def _is_cuv(citation: dict) -> bool:
    return str(citation.get("source_id", "")).strip().upper().startswith(CUV_PREFIX)


def _strip_cuv(citations):
    return [c for c in (citations or []) if not _is_cuv(c)]


def check(answer: dict) -> list:
    """返回违规原因列表；空列表表示通过。"""
    violations = []
    citations = answer.get("citations") or []
    if not answer.get("needs_human"):
        if not citations:
            violations.append("引用缺失：无权威来源支撑，已拦截（不展示回答）")
        if any(_is_cuv(c) for c in citations):
            violations.append("来源非法：出现和合本 id，已拦截")
        if float(answer.get("confidence", 0.0)) < MIN_CONFIDENCE:
            violations.append(
                f"置信过低（{float(answer.get('confidence', 0.0)):.2f} < "
                f"{MIN_CONFIDENCE:.2f}）：建议转人工顾问"
            )
    else:
        # needs_human=true 时允许 citations 为空（只给引导语）
        if any(_is_cuv(c) for c in citations):
            violations.append("来源非法：出现和合本 id，已拦截")
    return violations


def enforce(answer: dict):
    """强制清洗并返回 (answer, violations)。任何 CUV 引用被剔除；
    若清洗后非人工回答丢失全部引用，则强制转人工。"""
    answer["citations"] = _strip_cuv(answer.get("citations"))
    violations = check(answer)
    if (not answer.get("needs_human")) and not answer.get("citations"):
        answer["needs_human"] = True
        answer["confidence"] = 0.0
        answer["answer_zh"] = (
            "（答案缺少权威引用，已转交人工顾问复核）" + (answer.get("answer_zh") or "")
        )
        violations = check(answer)
    return answer, violations
