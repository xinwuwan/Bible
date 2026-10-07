# backend/app/responder.py
# 回答器：离线检索式（默认，无需任何 API key）+ 可选 LLM 增强（OpenAI 兼容接口）。
#
# 原则：答案绝不本地"编"。离线模式下——
#   · 命中经文引用 → 直接返回该 KJV 经文 + 中文产出
#   · 命中 FAQ 关键词 → 返回已审核的预置回答（含真实引用）
#   · 都没命中 → 返回 needs_human 引导语（不臆测）
# LLM 模式：把 grounding 上下文 + 严格输出 schema 交给模型，结果仍过合规闸门。
import json
import urllib.request
import urllib.error
import uuid

from . import compliance


def _new_id() -> str:
    return "qa_" + uuid.uuid4().hex[:12]


class OfflineResponder:
    def __init__(self, knowledge):
        self.kb = knowledge

    def _egw_citations(self, question: str):
        """返回与问题主题相关的经审核 EGW 引用（citations 形态）。"""
        out = []
        for e in self.kb.find_egw(question):
            out.append({
                "source_type": "EGW",
                "source_id": e.get("source_id", ""),
                "ref": e.get("ref", ""),
                "snippet": e.get("text", ""),
            })
        return out

    def ask(self, question: str, locale: str = "zh"):
        answer_id = _new_id()
        q = (question or "").strip()
        egw_cites = self._egw_citations(q)

        # 1) 直接经文引用（中英均可）
        v = self.kb.lookup_verse_ref(q)
        if v:
            body = (
                f"【{v.get('ref')}】KJV 英文底本（本应用中文为独立产出，非权威来源）\n\n"
                f"{v.get('zh') or '（中文译文待补充）'}"
            )
            citations = [
                {
                    "source_type": "BIBLE",
                    "source_id": "KJV-" + str(v.get("ref", "")).replace(" ", ""),
                    "ref": v.get("ref", ""),
                    "snippet": v.get("text", ""),
                }
            ]
            if egw_cites:
                citations += egw_cites
                body += "\n\n【怀爱伦(EWG)著作参考】" + "；".join(c["ref"] for c in egw_cites)
            ans = {
                "answer_id": answer_id,
                "answer_zh": body,
                "citations": citations,
                "confidence": 0.97,
                "needs_human": False,
            }
            return compliance.enforce(ans)

        # 2) FAQ 关键词匹配
        entry, score = self.kb.match_faq(q)
        if entry and score > 0:
            citations = [dict(c) for c in entry.get("citations", [])]
            body = entry.get("answer_zh", "")
            if egw_cites:
                # 去重（避免与 FAQ 内已挂载的 EGW 引用重复）
                have = {c.get("source_id") for c in citations}
                extra = [c for c in egw_cites if c["source_id"] not in have]
                if extra:
                    citations += extra
                    body += "\n\n【怀爱伦(EWG)著作参考】" + "；".join(c["ref"] for c in extra)
            conf = min(0.92, 0.70 + 0.05 * score)
            ans = {
                "answer_id": answer_id,
                "answer_zh": body,
                "citations": citations,
                "confidence": conf,
                "needs_human": False,
            }
            return compliance.enforce(ans)

        # 3) 无命中 → 转人工（不臆测，符合合规铁律）
        ans = {
            "answer_id": answer_id,
            "answer_zh": (
                "这个问题我暂时没有在已审核的知识库中检索到确切依据。"
                "为避免臆测，已转交人工顾问。你可以换一种问法，或等待顾问答复。"
            ),
            "citations": [],
            "confidence": 0.0,
            "needs_human": True,
        }
        return compliance.enforce(ans)


class LlmResponder:
    """可选 LLM 增强：仅当设置了 LLM_API_KEY 且 QA_MODE=llm 时启用。
    任何异常都优雅降级回离线回答器。"""

    SYSTEM_PROMPT = (
        "你是面向全球华人基督徒的信仰问答助手。权威依据仅限：KJV 英文圣经、"
        "怀爱伦(EGW)原版英文著作、基督复临安息日会(SDA)教义。"
        "中文回答是你独立的'产出'，不是权威来源；和合本(CUV)仅作参照，"
        "绝不能作为你的引用来源（source_id 不得以 CUV 开头）。\n"
        "必须严格只输出如下 JSON，不要任何额外文字：\n"
        "{\n"
        '  "answer_zh": "中文回答（基于下方 grounding 上下文，引用处注明出处）",\n'
        '  "citations": [{"source_type":"BIBLE|EGW|DOCTRINE",'
        '"source_id":"如 KJV-JHN3:16 或 SDA-B20","ref":"如 JHN 3:16","snippet":"引用原文片段"}],\n'
        '  "confidence": 0.0到1.0 的浮点数,\n'
        '  "needs_human": 布尔值（依据不足时务必为 true，把回答交人工复核）\n'
        "}\n"
        "规则：citations 至少 1 条且不得含 CUV；不确定时 needs_human 必须为 true；"
        "涉及医疗的内容不得给出诊断性建议。"
    )

    def __init__(self, knowledge, settings):
        self.kb = knowledge
        self.settings = settings
        self._offline = OfflineResponder(knowledge)
        self._context = knowledge.context_pack()

    def ask(self, question: str, locale: str = "zh"):
        try:
            raw = self._call_llm(question)
            data = json.loads(raw)
        except Exception:
            # 网络/解析失败 → 降级离线
            return self._offline.ask(question, locale)

        ans = {
            "answer_id": _new_id(),
            "answer_zh": str(data.get("answer_zh", "")),
            "citations": data.get("citations", []) or [],
            "confidence": float(data.get("confidence", 0.5)),
            "needs_human": bool(data.get("needs_human", False)),
        }
        # 即使 LLM 出错，也由合规闸门兜底
        return compliance.enforce(ans)

    def _call_llm(self, question: str, timeout: int = 25) -> str:
        url = self.settings.LLM_BASE_URL.rstrip("/") + "/chat/completions"
        payload = {
            "model": self.settings.LLM_MODEL,
            "messages": [
                {"role": "system", "content": self.SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": f"【grounding 上下文】\n{self._context}\n\n"
                    f"【用户问题】{question}\n\n请只输出规定 JSON。",
                },
            ],
            "temperature": 0.2,
            "response_format": {"type": "json_object"},
        }
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.settings.LLM_API_KEY}",
            },
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read().decode("utf-8"))
        return body["choices"][0]["message"]["content"]
