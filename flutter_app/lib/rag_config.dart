// rag_config.dart
// RAG 后端代理端点配置（Worker 部署后填入你的 workers.dev 域名）。
// 留空字符串 = 不启用 RAG 兜底（退回纯离线转人工），便于灰度与回滚。
const String kRagEndpoint = 'https://bible-rag-proxy.xinwuwan.workers.dev/api/rag';
