// 国内云函数版（阿里云函数计算 FC，Web 函数，公网直连无需备案）：
//   POST https://bible-rag-proxy-kyesoqskvl.cn-hangzhou.fcapp.run/api/rag
//   body {question, kind, context[]} -> {answer, flags, fallback}
// 留空字符串 = 不启用 RAG 兜底（退回纯离线转人工），便于灰度与回滚。
const String kRagEndpoint = 'https://bible-rag-proxy-kyesoqskvl.cn-hangzhou.fcapp.run/api/rag';
