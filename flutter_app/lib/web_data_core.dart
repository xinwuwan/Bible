// web_data_core.dart
// 模块 A / C 的离线数据逻辑层（纯 Dart，不依赖 Flutter）。
//
// 设计目的：
//   - 与平台无关：同一套解析 / 查询逻辑在 web / 桌面 / 手机都适用；
//   - 可独立验证：本文件只依赖 dart:convert，可在沙箱用 `dart` 直接跑单元测试，
//     无需 flutter 引擎（flutter build / test 在本环境会挂死）。
//
// 数据来源：assets/web/app_data.json（由 gen_web_data.py 从 app_offline.db 导出）。
// 顶层键即 SQLite 表名，值 = 该表全部行（键名 = 列名），与 OfflineDbHelper 的 SQL 列一一对应。

import 'dart:convert';

class AppDataStore {
  Map<String, dynamic>? _data;

  /// 是否已加载（加载成功后为真；网页端不再恒为 false）
  bool get isAvailable => _data != null;

  /// 解析 JSON 字符串（同步，纯逻辑，便于测试）
  void parse(String jsonString) {
    _data = jsonDecode(jsonString) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _table(String name) {
    final t = _data == null ? null : _data![name];
    if (t is List) return t.cast<Map<String, dynamic>>();
    return const [];
  }

  List<Map<String, dynamic>> getBooks() => _table('book');

  List<Map<String, dynamic>> getChapter(int bookId, int chapter) =>
      _table('verse')
          .where((r) =>
              r['book_id'] == bookId &&
              r['chapter'] == chapter)
          .toList();

  List<Map<String, dynamic>> getDoctrines() => _table('doctrine');

  List<Map<String, dynamic>> getVerses() => _table('verse');

  List<Map<String, dynamic>> getHealthTopics() => _table('health_topic');

  List<Map<String, dynamic>> getHealthSources(int topicId) =>
      _table('health_topic_source')
          .where((r) => r['topic_id'] == topicId)
          .toList();

  List<Map<String, dynamic>> getHealthGuidance(int topicId) =>
      _table('health_guidance')
          .where((r) => r['topic_id'] == topicId)
          .toList();

  List<Map<String, dynamic>> getHealthMetrics() => _table('health_metric');

  /// 把查询串转为逐字分词形式：CJK 字符逐字空格分词（与打包脚本对称），
  /// 非 CJK（英文/数字）保持原样。这样中文单字/短语与英文都能正确检索。
  static String ftsQuery(String q) {
    final buf = StringBuffer();
    for (final rune in q.runes) {
      final s = String.fromCharCode(rune);
      if ((0x3400 <= rune && rune <= 0x9FFF) ||
          (0x3000 <= rune && rune <= 0x303F) ||
          (0xFF00 <= rune && rune <= 0xFFEF)) {
        buf.write(' $s ');
      } else {
        buf.write(s);
      }
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 全文检索（Dart 侧实现，覆盖 KJV 英文 + 本应用中文）。
  /// 返回 [ref, kjv_text, our_zh]，按命中相关度（得分）排序。
  List<Map<String, dynamic>> search(String query, {int limit = 50}) {
    final q = (query).trim();
    if (q.isEmpty) return const [];
    final tokens = ftsQuery(q)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return const [];

    final verses = _table('verse');
    final scored = <Map<String, dynamic>>[];
    for (final v in verses) {
      final kjv = (v['kjv_text'] as String? ?? '').toLowerCase();
      final zh = (v['our_zh'] as String? ?? '').toLowerCase();
      var score = 0;
      for (final t in tokens) {
        final tl = t.toLowerCase();
        if (kjv.contains(tl)) score += 2;
        if (zh.contains(tl)) score += 1;
      }
      if (score > 0) scored.add({...v, '_score': score});
    }
    scored.sort(
        (a, b) => (b['_score'] as int).compareTo(a['_score'] as int));
    return scored.take(limit).map((v) => <String, dynamic>{
          'ref': v['ref'],
          'kjv_text': v['kjv_text'],
          'our_zh': v['our_zh'],
        }).toList();
  }
}
