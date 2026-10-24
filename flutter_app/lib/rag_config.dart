// RAG 兜底后端（WorkBuddy 应用托管，国内可直接访问，免费）：
//   POST https://bible-rag-proxy.app.workbuddy.host/api/rag?sharecode=ZGXTEH5MO2
//   body {question, kind, context[]} -> {answer, flags, fallback}
// sharecode 是托管平台的访问闸门（无码 403），必须作为查询串带上。
// 历史地址：阿里云 FC（bible-rag-proxy-kyesoqskvl.cn-hangzhou.fcapp.run，账号欠费已弃用）、
//          Cloudflare Workers（workers.dev，国内被屏蔽，仅备份）。
// 留空字符串 = 不启用 RAG 兜底（退回纯离线转人工），便于灰度与回滚。
const String kRagEndpoint = 'https://bible-rag-proxy.app.workbuddy.host/api/rag?sharecode=ZGXTEH5MO2';
