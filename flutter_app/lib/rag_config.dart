// RAG 兜底后端 + SDA 圣经注释代理（WorkBuddy 应用托管，国内可直接访问，免费）：
//   POST <base>/api/rag?sharecode=...      body {question, kind, context[]} -> {answer, flags, fallback}
//   GET  <base>/api/commentary?sharecode=...&book=GEN&chapter=1&verse=1
//                                     -> {ok, ref, text, source, url}
// sharecode 是托管平台的访问闸门（无码 403），必须作为查询串带上。
// 历史地址：阿里云 FC（bible-rag-proxy-kyesoqskvl.cn-hangzhou.fcapp.run，账号欠费已弃用）、
//          Cloudflare Workers（workers.dev，国内被屏蔽，仅备份）。
// 留空字符串 = 不启用 RAG 兜底（退回纯离线转人工），便于灰度与回滚。
const String kRagBaseUrl = 'https://bible-rag-proxy.app.workbuddy.host';
const String kRagSharecode = 'ZGXTEH5MO2';

/// RAG 问答端点（POST）。留空即禁用兜底。
String get kRagEndpoint => '$kRagBaseUrl/api/rag?sharecode=$kRagSharecode';

/// SDA 圣经注释端点（GET，服务端按节抽取代理）。留空即禁用注释按钮。
/// [ref] 形如 "GEN 1:1" / "1CO 13:4"。
String sdaCommentaryApiUrl(String ref) {
  final trimmed = ref.trim();
  if (trimmed.isEmpty) return '';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length < 2) return '';
  final book = Uri.encodeComponent(parts.first);
  final cv = parts[1].split(RegExp(r'[:：]'));
  if (cv.length < 2) return '';
  final chapter = Uri.encodeComponent(cv[0].trim());
  final verse = Uri.encodeComponent(cv[1].trim());
  return '$kRagBaseUrl/api/commentary?sharecode=$kRagSharecode'
      '&book=$book&chapter=$chapter&verse=$verse';
}
