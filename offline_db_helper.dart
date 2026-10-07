// offline_db_helper.dart
// Flutter 离线 SQLite 预置包读取示例 (M2 客户端骨架)
// 配套 build_offline_db.py 的产物 app_offline.db。
//
// 依赖 (pubspec.yaml):
//   dependencies:
//     sqlite3: ^2.4.0
//   flutter:
//     assets:
//       - assets/app_offline.db
//
// 重要: assets 是只读的，首次启动必须把 db 从 asset 复制到应用可写目录(AppSupport)
//       后再用 sqlite3.open() 打开，否则 iOS/Android 无法写入（FTS 索引已固化在文件内，
//       读取与检索均无需写权限，但标准做法仍复制到可写目录以策万全）。

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

class OfflineDbHelper {
  static Database? _db;
  static const String assetPath = 'assets/app_offline.db';

  /// 首次启动：把预置 db 从 asset 复制到可写目录（仅一次）。
  static Future<void> ensureReady(String writableDir) async {
    final dbFile = File(p.join(writableDir, 'app_offline.db'));
    if (!await dbFile.exists()) {
      final bytes = await rootBundle.load(assetPath);
      await dbFile.writeAsBytes(bytes.buffer.asUint8List());
    }
    _db = sqlite3.open(dbFile.path);
  }

  /// 仅供测试：直接打开指定路径的 db，跳过 asset 复制流程。
  /// widget test 里用临时生成的 db 注入，避免依赖 rootBundle 加载真实资产。
  static void openPathForTest(String dbFilePath) {
    _db?.dispose();
    _db = sqlite3.open(dbFilePath);
  }

  /// 取某章全部节（KJV + 本应用中文 + 和合本参照）。
  static List<Map<String, dynamic>> getChapter(int bookId, int chapter) {
    final result = _db!.select(
      '''SELECT verse, ref, kjv_text, our_zh, cuv_ref_text
         FROM verse WHERE book_id = ? AND chapter = ? ORDER BY verse''',
      [bookId, chapter],
    );
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// 按书卷取目录（用于阅读器侧边栏）。
  static List<Map<String, dynamic>> getBooks() {
    final result = _db!.select(
      'SELECT book_id, book_code, name_zh, testament, chapter_count FROM book ORDER BY book_id');
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// 把查询串转为 FTS5 可用形式：CJK 字符逐字空格分词（与打包脚本 _fts_zh 对称），
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

  /// 全文检索：FTS5 覆盖 KJV 英文 + 本应用中文，JOIN 回原文。
  /// 返回 [ref, kjv_text, our_zh]，按相关度 rank 排序。
  static List<Map<String, dynamic>> search(String query, {int limit = 50}) {
    final result = _db!.select(
      '''SELECT v.ref AS ref, v.kjv_text AS kjv_text, v.our_zh AS our_zh
         FROM verse v JOIN verse_fts f ON f.rowid = v.verse_id
         WHERE verse_fts MATCH ? ORDER BY rank LIMIT ?''',
      [ftsQuery(query), limit],
    );
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// 取教义条款（标题 + 中英文本）。
  static List<Map<String, dynamic>> getDoctrines() {
    final result = _db!.select(
      'SELECT belief_id, code, title_zh, en_text, zh_text FROM doctrine ORDER BY belief_id');
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ---------------------------------------------------------------------------
  // 模块 C：NEWSTART 健康内容
  // 说明：health_* 表是 build_offline_db.py 的可选产物。旧版离线包可能没有这些表，
  //       因此统一先做存在性检查，缺表时返回空列表而不是抛异常（保证老包仍可用）。
  // ---------------------------------------------------------------------------

  static bool _hasTable(String name) {
    final r = _db!.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?", [name]);
    return r.isNotEmpty;
  }

  /// 八大支柱（按 NEWSTART 顺序）
  static List<Map<String, dynamic>> getHealthTopics() {
    if (!_hasTable('health_topic')) return const [];
    final result = _db!.select(
        'SELECT topic_id, code, name_zh, summary, sort_order FROM health_topic '
        'ORDER BY sort_order, topic_id');
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// 某支柱绑定的权威来源（BIBLE / EGW / DOCTRINE）
  static List<Map<String, dynamic>> getHealthSources(int topicId) {
    if (!_hasTable('health_topic_source')) return const [];
    final result = _db!.select(
        'SELECT id, topic_id, source_type, source_id FROM health_topic_source '
        'WHERE topic_id = ? ORDER BY id',
        [topicId]);
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// 某支柱的指导条目（打包闸门已过滤未审核条目；此处仍返回原始字段由 UI 二次校验）
  static List<Map<String, dynamic>> getHealthGuidance(int topicId) {
    if (!_hasTable('health_guidance')) return const [];
    final result = _db!.select(
        '''SELECT guidance_id, topic_id, title, body_zh, evidence_level,
                  medical_reviewed, disclaimer
           FROM health_guidance WHERE topic_id = ? ORDER BY guidance_id''',
        [topicId]);
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// 全部打卡指标定义
  static List<Map<String, dynamic>> getHealthMetrics() {
    if (!_hasTable('health_metric')) return const [];
    final result = _db!.select(
        'SELECT metric_id, topic_code, name_zh, unit, target_value FROM health_metric '
        'ORDER BY metric_id');
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// 某用户的打卡记录（最近 500 条）。
  /// 时间比较放在 Dart 侧做（isSameDay），避免 SQLite 里字符串比较 ISO8601
  /// 因时区后缀不同（Z vs +08:00）而失准。
  static List<Map<String, dynamic>> getHealthLogs(String userId) {
    if (!_hasTable('health_log_entry')) return const [];
    final result = _db!.select(
        '''SELECT log_id, user_id, topic_code, metric_id, value, logged_at
           FROM health_log_entry
           WHERE user_id = ? ORDER BY logged_at DESC LIMIT 500''',
        [userId]);
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// 写入一条打卡记录，返回自增 log_id
  static int insertHealthLog(Map<String, dynamic> row) {
    if (!_hasTable('health_log_entry')) return 0;
    _db!.execute(
        '''INSERT INTO health_log_entry (user_id, topic_code, metric_id, value, logged_at)
           VALUES (?,?,?,?,?)''',
        [row['user_id'], row['topic_code'], row['metric_id'], row['value'],
         row['logged_at']]);
    final r = _db!.select('SELECT last_insert_rowid() AS id');
    return (r.first['id'] as num).toInt();
  }

  static void close() {
    _db?.dispose();
    _db = null;
  }
}
