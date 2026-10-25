// RAG 兜底后端 + SDA 圣经注释代理（WorkBuddy 应用托管，国内可直接访问，免费）：
//   POST <base>/api/rag?sharecode=...      body {question, kind, context[]} -> {answer, flags, fallback}
//   GET  <base>/api/commentary?sharecode=...&book=GEN&chapter=1&verse=1[&lang=zh]
//                                     -> {ok, ref, text, source, url}
//   POST <base>/api/ocr?sharecode=...      body {image: <base64>, mime} -> {ok, text}
//                                     （v58：诊断材料图片文字转录，只转录不解读）
//   lang 省略或 en = 英文原著（bible-strong.app 镜像）；
//   lang=zh/cn = 简体中文（read.sdabible.org「SDA 圣经注释」官方中译 + 怀爱伦注释）。
// sharecode 是托管平台的访问闸门（无码 403），必须作为查询串带上。
// 历史地址：阿里云 FC（bible-rag-proxy-kyesoqskvl.cn-hangzhou.fcapp.run，账号欠费已弃用）、
//          Cloudflare Workers（workers.dev，国内被屏蔽，仅备份）。
// 留空字符串 = 不启用 RAG 兜底（退回纯离线转人工），便于灰度与回滚。
const String kRagBaseUrl = 'https://bible-rag-proxy.app.workbuddy.host';
const String kRagSharecode = 'ZGXTEH5MO2';

/// RAG 问答端点（POST）。留空即禁用兜底。
String get kRagEndpoint => '$kRagBaseUrl/api/rag?sharecode=$kRagSharecode';

/// 诊断材料图片 OCR 端点（POST）。留空即禁用（退回手动誊写）。
String get consultOcrApiUrl =>
    '$kRagBaseUrl/api/ocr?sharecode=$kRagSharecode';

/// SDA 圣经注释端点（GET，服务端按节抽取代理）。留空即禁用注释按钮。
/// [ref] 形如 "GEN 1:1" / "1CO 13:4"；[lang] 'en'（默认）英文原著 / 'zh' 简体中文。
String sdaCommentaryApiUrl(String ref, {String lang = 'en'}) {
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
      '&book=$book&chapter=$chapter&verse=$verse&lang=$lang';
}
