# backend/app/config.py
# 后端运行配置（从环境变量读取，不依赖 pydantic，方便纯逻辑测试与部署）。
#
# 环境变量：
#   KB_PATH        知识库 JSON 路径（默认 backend/kb.json）
#   QA_MODE        offline（默认，无需 key）| llm（接 OpenAI 兼容接口）
#   LLM_API_KEY    可选；填了且 QA_MODE=llm 才启用真 LLM
#   LLM_BASE_URL   OpenAI 兼容接口 base（默认官方）
#   LLM_MODEL      模型名（默认 gpt-4o-mini）
#   CORS_ORIGINS   逗号分隔的允许源；"*" 表示全部（默认 *）
#   ALLOWED_ORIGIN 若设置则覆盖 CORS_ORIGINS，只允许单一前端域名（更严格）
#   FEEDBACK_DIR   反馈落盘目录（默认 backend/feedback）
import os

_BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # backend/


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


class Settings:
    KB_PATH = _env("KB_PATH", os.path.join(_BASE, "kb.json"))
    MODE = _env("QA_MODE", "offline").lower()
    LLM_API_KEY = _env("LLM_API_KEY", "")
    LLM_BASE_URL = _env("LLM_BASE_URL", "https://api.openai.com/v1")
    LLM_MODEL = _env("LLM_MODEL", "gpt-4o-mini")
    CORS_ORIGINS = _env("CORS_ORIGINS", "*")
    ALLOWED_ORIGIN = _env("ALLOWED_ORIGIN", "")
    FEEDBACK_DIR = _env("FEEDBACK_DIR", os.path.join(_BASE, "feedback"))

    @property
    def origins(self):
        if self.ALLOWED_ORIGIN:
            return [self.ALLOWED_ORIGIN]
        if self.CORS_ORIGINS.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


settings = Settings()
