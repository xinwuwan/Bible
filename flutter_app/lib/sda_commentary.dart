// sda_commentary.dart
// 复临安息日会圣经注释（SDA Bible Commentary）外链构造 + v53 内联展示服务。
//
// 数据源：bible-strong.app 第三方镜像（实测 HTTP 200、国内可达、不含 CF 挑战页）。
// 实测 URL 形态：https://bible-strong.app/commentary/en/sdabc/<osis>/<chapter>
//   - 书卷用 OSIS 码小写：gen / matt / john / 1cor …（已逐一验证 gen、matt、john、1cor 均 200）
//   - 章节为阿拉伯数字
//
// v53 起提供两种用法：
//   ① sdaCommentaryUrl —— 原始外链（「查看完整章节」兜底，新标签打开）
//   ② fetchSdaCommentary —— 经 RAG 代理服务端按节抽取，供经文卡片内联展示
//      （用户要求不外跳；镜像无 CORS 头 + X-Frame-Options，前端直抓/iframe 均被拦，
//        只能服务端代理。注释原文为英文，界面明确标注「英文原著」。）
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'rag_config.dart';

/// 应用内 bookCode（3 字母，含数字前缀如 1CO）→ bible-strong 的 OSIS 小写码。
const Map<String, String> _bookCodeToOsis = {
  // 律法书
  'GEN': 'gen', 'EXO': 'exod', 'LEV': 'lev', 'NUM': 'num', 'DEU': 'deut',
  // 历史书
  'JOS': 'josh', 'JDG': 'judg', 'RUT': 'ruth', '1SA': '1sam', '2SA': '2sam',
  '1KI': '1kgs', '2KI': '2kgs', '1CH': '1chr', '2CH': '2chr', 'EZR': 'ezra',
  'NEH': 'neh', 'EST': 'esth',
  // 诗歌·智慧书
  'JOB': 'job', 'PSA': 'ps', 'PRO': 'prov', 'ECC': 'eccl', 'SNG': 'song',
  // 先知书
  'ISA': 'isa', 'JER': 'jer', 'LAM': 'lam', 'EZK': 'ezek', 'DAN': 'dan',
  'HOS': 'hos', 'JOL': 'joel', 'AMO': 'amos', 'OBA': 'obad', 'JON': 'jonah',
  'MIC': 'mic', 'NAM': 'nah', 'HAB': 'hab', 'ZEP': 'zeph', 'HAG': 'hag',
  'ZEC': 'zech', 'MAL': 'mal',
  // 福音书·使徒行传
  'MAT': 'matt', 'MRK': 'mark', 'LUK': 'luke', 'JHN': 'john', 'ACT': 'acts',
  // 保罗书信
  'ROM': 'rom', '1CO': '1cor', '2CO': '2cor', 'GAL': 'gal', 'EPH': 'eph',
  'PHP': 'phil', 'COL': 'col', '1TH': '1thess', '2TH': '2thess', '1TI': '1tim',
  '2TI': '2tim', 'TIT': 'titus', 'PHM': 'phlm',
  // 普通书信·启示录
  'HEB': 'heb', 'JAS': 'jas', '1PE': '1pet', '2PE': '2pet', '1JN': '1john',
  '2JN': '2john', '3JN': '3john', 'JUD': 'jude', 'REV': 'rev',
};

/// 由经文 ref（如 "JHN 3:16" / "1CO 13:4"）构造 SDA 注释外链；
/// 解析失败（书卷不在表内 / 缺章节）返回 null，调用方据此不显示按钮。
String? sdaCommentaryUrl(String ref) {
  final trimmed = ref.trim();
  if (trimmed.isEmpty) return null;
  // ref 首段为书卷码（"JHN" 或 "1CO"），空格后为 "章:节"
  final bookCode = trimmed.split(RegExp(r'\s+')).first.toUpperCase();
  final osis = _bookCodeToOsis[bookCode];
  if (osis == null) return null;
  // 取章节：优先匹配 "章:节"，否则取首个数字（容错无节号情形）
  final m = RegExp(r'(\d+)\s*:\s*\d+').firstMatch(trimmed) ??
      RegExp(r'(\d+)').firstMatch(trimmed);
  if (m == null) return null;
  final chapter = m.group(1)!;
  return 'https://bible-strong.app/commentary/en/sdabc/$osis/$chapter';
}

// ---------------------------------------------------------------------------
// v53：SDA 注释内联展示（服务端代理按节抽取）
//
// 用户要求「点击后在当条经文下方显示本条注释，不外跳网页」。bible-strong 镜像
// 无 CORS 头且 X-Frame-Options: SAMEORIGIN，浏览器直抓/iframe 均被拦截，
// 故由 RAG 代理服务端抓取 + 按节抽取 + 清洗为纯文本，App 再渲染。
// 注释原文为英文（SDA Bible Commentary 官方英文版），界面明确标注。
// ---------------------------------------------------------------------------

/// 一条按节抽取的 SDA 注释。
class SdaCommentary {
  final String ref; // 如 "GEN 1:1"
  final String text; // 英文原文（可能含同节多条：正文注释 + EGW 评注）
  final String source; // 来源标注
  final String url; // 原始镜像页（「查看完整章节」用）

  const SdaCommentary({
    required this.ref,
    required this.text,
    required this.source,
    required this.url,
  });
}

/// 获取结果：成功带 commentary，失败带 error（调用方展示重试 + 外链兜底）。
class SdaCommentaryResult {
  final SdaCommentary? commentary;
  final String? error;
  const SdaCommentaryResult.ok(this.commentary) : error = null;
  const SdaCommentaryResult.fail(this.error) : commentary = null;
}

/// 从 RAG 代理获取 [ref] 对应经节的 SDA 注释（内联展示用）。
/// 网络异常 / 服务不可用 / 该节无注释 -> SdaCommentaryResult.fail。
Future<SdaCommentaryResult> fetchSdaCommentary(
  String ref, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 25),
}) async {
  final apiUrl = sdaCommentaryApiUrl(ref);
  if (apiUrl.isEmpty) {
    return const SdaCommentaryResult.fail('注释服务未配置');
  }
  final c = client ?? http.Client();
  try {
    final r = await c.get(Uri.parse(apiUrl)).timeout(timeout);
    if (r.statusCode != 200) {
      return SdaCommentaryResult.fail('注释服务返回 ${r.statusCode}');
    }
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (d['ok'] != true) {
      return SdaCommentaryResult.fail((d['error'] as String?) ?? '该节暂无注释');
    }
    final text = (d['text'] as String?) ?? '';
    if (text.trim().isEmpty) {
      return const SdaCommentaryResult.fail('该节暂无注释');
    }
    return SdaCommentaryResult.ok(SdaCommentary(
      ref: (d['ref'] as String?) ?? ref,
      text: text,
      source: (d['source'] as String?) ?? 'SDA Bible Commentary',
      url: (d['url'] as String?) ?? '',
    ));
  } catch (e) {
    return SdaCommentaryResult.fail('网络异常，请稍后重试');
  } finally {
    if (client == null) c.close();
  }
}
