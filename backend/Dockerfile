# backend/Dockerfile
# 轻量后端镜像：基于官方 python:3.11-slim，安装依赖后启动 uvicorn。
FROM python:3.11-slim

WORKDIR /app

# 先拷贝依赖清单以利用分层缓存
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 拷贝应用代码与知识库
COPY app/ ./app/
COPY kb.json .

# 默认离线模式（无需任何 API key）；如需真 LLM 在运行时传入环境变量。
ENV QA_MODE=offline \
    KB_PATH=/app/kb.json \
    CORS_ORIGINS=*

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
