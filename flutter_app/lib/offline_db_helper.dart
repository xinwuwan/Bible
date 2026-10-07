// offline_db_helper.dart
// 模块 A / C 离线数据访问层（web / 桌面 / 手机通用）。
//
// 数据来源：assets/web/app_data.json（由 gen_web_data.py 从 app_offline.db 导出），
// 通过 rootBundle 加载。网页端无文件系统，因此不再复制 .db 文件，改用 JSON 资源，
// 三端加载方式完全一致。
//
// 打卡记录（health_log_entry）改用 shared_preferences 持久化：web 端走 IndexedDB /
// localStorage，桌面 / 手机走原生偏好存储，均无需可写文件系统。
//
// 依赖 (pubspec.yaml):
//   flutter:
//     assets:
//       - assets/web/app_data.json
//   dependencies:
//     shared_preferences: ^2.2.2

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'web_data_core.dart';

class OfflineDbHelper {
  static const String _asset = 'assets/web/app_data.json';
  static const String _kLogs = 'health_logs_v1';

  static final AppDataStore _store = AppDataStore();
  static List<Map<String, dynamic>>? _logsCache;

  /// 离线内容是否已就绪（加载成功后为真；网页端现在也为真）。
  static bool get isAvailable => _store.isAvailable;

  /// 加载 JSON 资源（web / 桌面 / 手机通用）。应在 runApp 前 await。
  /// 可选 [str] 用于测试：直接喂入 JSON 字符串并强制重新解析，跳过 rootBundle。
  static Future<void> load([String? str]) async {
    if (str != null) {
      _store.parse(str);
      return;
    }
    if (_store.isAvailable) return;
    final s = await rootBundle.loadString(_asset);
    _store.parse(s);
  }

  /// 兼容旧调用点（main 曾用 ensureReady 复制 .db）；现在无需可写目录，直接加载 JSON。
  static Future<void> ensureReady(String _) async => load();

  // ---------------------------------------------------------------------------
  // 模块 A：圣经对照
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> getBooks() => _store.getBooks();

  static List<Map<String, dynamic>> getChapter(int bookId, int chapter) =>
      _store.getChapter(bookId, chapter);

  static List<Map<String, dynamic>> getDoctrines() => _store.getDoctrines();

  static List<Map<String, dynamic>> getVerses() => _store.getVerses();

  /// 全文检索：覆盖 KJV 英文 + 本应用中文，按相关度排序。
  static List<Map<String, dynamic>> search(String query, {int limit = 50}) =>
      _store.search(query, limit: limit);

  /// 把查询串转为逐字分词形式（CJK 逐字、英文保留），供 UI 复用。
  static String ftsQuery(String q) => AppDataStore.ftsQuery(q);

  // ---------------------------------------------------------------------------
  // 模块 C：NEWSTART 健康内容（只读部分来自 JSON；打卡记录来自 shared_preferences）
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> getHealthTopics() =>
      _store.getHealthTopics();

  static List<Map<String, dynamic>> getHealthSources(int topicId) =>
      _store.getHealthSources(topicId);

  static List<Map<String, dynamic>> getHealthGuidance(int topicId) =>
      _store.getHealthGuidance(topicId);

  static List<Map<String, dynamic>> getHealthMetrics() =>
      _store.getHealthMetrics();

  /// 读入本地打卡记录缓存（应用启动时调用一次）。
  static Future<void> loadLogsCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLogs);
    if (raw == null || raw.isEmpty) {
      _logsCache = const [];
      return;
    }
    final decoded = jsonDecode(raw);
    _logsCache = decoded is List ? decoded.cast<Map<String, dynamic>>() : const [];
  }

  /// 某用户的打卡记录（从内存缓存读取，同步返回）。
  static List<Map<String, dynamic>> getHealthLogs(String userId) =>
      (_logsCache ?? const [])
          .where((r) => r['user_id'] == userId)
          .toList();

  /// 写入一条打卡记录，返回自增 log_id，并持久化到 shared_preferences。
  static Future<int> insertHealthLog(Map<String, dynamic> row) async {
    final cache = List<Map<String, dynamic>>.from(_logsCache ?? const []);
    final maxId = cache.isEmpty
        ? 0
        : cache
            .map((e) => (e['log_id'] as num? ?? 0).toInt())
            .reduce((a, b) => a > b ? a : b);
    final newRow = <String, dynamic>{'log_id': maxId + 1, ...row};
    cache.add(newRow);
    _logsCache = cache;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLogs, jsonEncode(cache));
    return maxId + 1;
  }

  static void close() {
    _logsCache = null;
  }
}
