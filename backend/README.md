# 模块 B 后端 —— 牧师问答服务

这是「真理对照」App **模块 B（牧师问答）** 的后端服务。它把用户的信仰问题，依据
**KJV 英文圣经 / 怀爱伦(EGW)原版著作 / SDA 教义** 生成带权威引用的中文回答。

---

## 重要：链接里的问答已经能用了（无需本后端）

前端默认使用**离线问答引擎**（已打进 App 安装包 / 网页）：基于内置的
`qa_faq.json` 信仰问答库 + KJV 经文，直接在本机/浏览器里检索回答，**不需要任何服务器、不需要 API key、零成本**。
未命中知识库的问题会诚实转人工，绝不臆测。

**本后端是「升级选项」**：当你想要**真·大模型(LLM)级别的自由回答**时才需要部署它。
不部署也完全不影响使用。

---

## 两种运行模式

| 模式 | 环境变量 | 是否需要 key | 说明 |
|------|----------|--------------|------|
| `offline`（默认） | `QA_MODE=offline` | 否 | 检索内置知识库，免费、离线、确定性强 |
| `llm` | `QA_MODE=llm` + `LLM_API_KEY` | 是 | 接 OpenAI 兼容接口，自由生成 + 知识库 grounding + 合规闸门 |

---

## 本地运行（开发 / 预览）

```bash
cd backend
pip install -r requirements.txt
python -m app.main          # 默认离线模式，监听 http://127.0.0.1:8000
```

验证：
```bash
curl http://127.0.0.1:8000/health
curl -X POST http://127.0.0.1:8000/qa/ask -H "Content-Type: application/json" \
     -d '{"question":"你们守安息日吗","locale":"zh"}'
```

跑测试：
```bash
python tests/test_contract.py   # 纯逻辑（无需 fastapi）
python tests/test_api.py        # API 契约（需先 pip install）
```

---

## 接入真 LLM（可选）

```bash
QA_MODE=llm \
LLM_BASE_URL=https://api.openai.com/v1 \
LLM_MODEL=gpt-4o-mini \
LLM_API_KEY=sk-xxxx \
python -m app.main
```
任何 OpenAI 兼容接口都可用（改 `LLM_BASE_URL` 即可，如本地 Ollama / 国产大模型网关）。
LLM 的输出仍会过**合规闸门**：剔除 CUV 引用、缺引用强制转人工、低置信提示转人工。

---

## 部署（免费平台，可选）

后端是独立服务，建议用**免费容器平台**托管（Railway / Render / Fly.io），再在构建前端时
用 dart-define 指过来：

```bash
flutter build web --release \
  --dart-define=API_BASE=https://你的后端地址 \
  --dart-define=USE_REMOTE_QA=true
```

- **Railway**：连 GitHub 仓库 → Root Directory 填 `backend` → 自动识别 `Procfile`。
- **Render**：新建 Web Service → Root Directory `backend` → 自动识别 `Dockerfile`。
- **Fly.io / 任意 Docker 主机**：仓库已含 `Dockerfile`，直接 build 即可。

> CI（`.github/workflows/deploy-web.yml`）只负责**前端**的 GitHub Pages 发布。
> 后端部署是独立步骤，按上面任一平台连仓库即可，互不影响。

---

## 合规铁律（代码已强制）

- 权威依据**仅限** KJV 英文圣经、EGW 原版英文著作、SDA 教义。
- 中文回答是本应用**独立产出**，不是权威来源；**和合本(CUV)绝不作引用来源**。
- 任何回答若失去权威引用，或不确定性高，一律**转人工顾问**，绝不以臆测充数。
- 涉及医疗的内容不得给出诊断性建议（前端模块 C 同理）。

---

## 如何扩充 / 校正内容

- **信仰问答**：编辑 `kb.json` 的 `faq` 数组（关键词 + 中文回答 + 真实引用），
  然后同步到前端的 `flutter_app/assets/web/qa_faq.json`（用项目根 `gen_*` 或手动拷贝）。
- **经文 / 教义**：`kb.json` 的 `verses` / `doctrine`。经文以 KJV 英文为底本。
- **EGW 内容**：当前种子库未含 EGW 原文引用（避免未经审核的误引）。若要加入，
  请把**已核对**的 EGW 著作文本放进 `verses`/`doctrine` 或新增 `egw` 类型条目，
  并在引用里写清书名+章节/页码，供用户溯源。

---

## 文件清单

| 文件 | 作用 |
|------|------|
| `app/main.py` | FastAPI 入口（/health、/qa/ask、/qa/{id}/feedback） |
| `app/kb.py` | 知识库加载 + 检索（含中英文经文引用解析） |
| `app/responder.py` | 离线回答器 + 可选 LLM 增强 |
| `app/compliance.py` | 服务端合规闸门（与前端双保险） |
| `app/config.py` | 环境变量配置 |
| `kb.json` | 种子知识库（KJV 经文 + SDA 教义 + 信仰问答） |
| `requirements.txt` / `Dockerfile` / `Procfile` | 运行与部署 |
| `tests/` | 契约测试 |
