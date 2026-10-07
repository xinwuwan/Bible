// health_repository.dart
// 模块 C 健康内容的数据源抽象 + 两种实现
//   - OfflineHealthRepository：读预置离线 SQLite（正式路径）
//   - MockHealthRepository  ：内存实现，供 widget 测试 / 无 DB 演示

import 'health_models.dart';
import 'offline_db_helper.dart';

abstract class HealthRepository {
  Future<List<HealthTopic>> loadTopics();

  Future<List<HealthSource>> loadSources(int topicId);

  Future<List<HealthGuidance>> loadGuidance(int topicId);

  Future<List<HealthMetric>> loadMetrics();

  Future<List<HealthLogEntry>> loadLogs(String userId);

  Future<void> saveLog(HealthLogEntry entry);
}

/// 读离线包（assets/app_offline.db 复制到可写目录后的那个 db）
class OfflineHealthRepository implements HealthRepository {
  const OfflineHealthRepository();

  @override
  Future<List<HealthTopic>> loadTopics() async => OfflineDbHelper.getHealthTopics()
      .map(HealthTopic.fromRow)
      .toList();

  @override
  Future<List<HealthSource>> loadSources(int topicId) async =>
      OfflineDbHelper.getHealthSources(topicId).map(HealthSource.fromRow).toList();

  @override
  Future<List<HealthGuidance>> loadGuidance(int topicId) async =>
      OfflineDbHelper.getHealthGuidance(topicId)
          .map(HealthGuidance.fromRow)
          .toList();

  @override
  Future<List<HealthMetric>> loadMetrics() async =>
      OfflineDbHelper.getHealthMetrics().map(HealthMetric.fromRow).toList();

  @override
  Future<List<HealthLogEntry>> loadLogs(String userId) async =>
      OfflineDbHelper.getHealthLogs(userId).map(HealthLogEntry.fromRow).toList();

  @override
  Future<void> saveLog(HealthLogEntry entry) async {
    OfflineDbHelper.insertHealthLog(entry.toRow());
  }
}

/// 内存实现：测试与演示用（不碰真实数据库）
class MockHealthRepository implements HealthRepository {
  final List<HealthTopic> topics;
  final List<HealthSource> sources;
  final List<HealthGuidance> guidance;
  final List<HealthMetric> metrics;
  final List<HealthLogEntry> logs = [];

  MockHealthRepository({
    List<HealthTopic>? topics,
    List<HealthSource>? sources,
    List<HealthGuidance>? guidance,
    List<HealthMetric>? metrics,
  })  : topics = topics ?? _defaultTopics(),
        sources = sources ?? _defaultSources(),
        guidance = guidance ?? _defaultGuidance(),
        metrics = metrics ?? _defaultMetrics();

  @override
  Future<List<HealthTopic>> loadTopics() async => List.unmodifiable(topics);

  @override
  Future<List<HealthSource>> loadSources(int topicId) async =>
      sources.where((s) => s.topicId == topicId).toList();

  @override
  Future<List<HealthGuidance>> loadGuidance(int topicId) async =>
      guidance.where((g) => g.topicId == topicId).toList();

  @override
  Future<List<HealthMetric>> loadMetrics() async => List.unmodifiable(metrics);

  @override
  Future<List<HealthLogEntry>> loadLogs(String userId) async =>
      logs.where((e) => e.userId == userId).toList();

  @override
  Future<void> saveLog(HealthLogEntry entry) async {
    logs.add(entry);
  }

  // --------------------------- 默认示例数据 -----------------------------

  static List<HealthTopic> _defaultTopics() => const [
        HealthTopic(topicId: 1, code: 'NUT', nameZh: '营养', sortOrder: 0,
            summary: '以圣经所记原始饮食为原则。'),
        HealthTopic(topicId: 2, code: 'EXE', nameZh: '运动', sortOrder: 1,
            summary: '有规律的身体活动。'),
        HealthTopic(topicId: 3, code: 'WAT', nameZh: '水', sortOrder: 2,
            summary: '充足的水分摄取。'),
        HealthTopic(topicId: 4, code: 'SUN', nameZh: '阳光', sortOrder: 3,
            summary: '适度的日光。'),
        HealthTopic(topicId: 5, code: 'TEM', nameZh: '节制', sortOrder: 4,
            summary: '有益之物适度，有害之物戒绝。'),
        HealthTopic(topicId: 6, code: 'AIR', nameZh: '空气', sortOrder: 5,
            summary: '清新空气与通风。'),
        HealthTopic(topicId: 7, code: 'RES', nameZh: '休息', sortOrder: 6,
            summary: '规律作息与安息。'),
        HealthTopic(topicId: 8, code: 'TRU', nameZh: '信靠', sortOrder: 7,
            summary: '心灵健康根植于信靠上帝。'),
      ];

  static List<HealthSource> _defaultSources() => const [
        HealthSource(id: 1, topicId: 1, sourceType: HealthSourceType.bible,
            sourceId: 'GEN 1:29'),
        HealthSource(id: 2, topicId: 2, sourceType: HealthSourceType.bible,
            sourceId: '1TI 4:8'),
        HealthSource(id: 3, topicId: 5, sourceType: HealthSourceType.bible,
            sourceId: '1CO 9:25'),
        HealthSource(id: 4, topicId: 8, sourceType: HealthSourceType.bible,
            sourceId: 'PHP 4:6-7'),
        HealthSource(id: 5, topicId: 8, sourceType: HealthSourceType.egw,
            sourceId: 'EGW-MH'),
      ];

  static List<HealthGuidance> _defaultGuidance() => const [
        // 已审条目：正常展示
        HealthGuidance(
            guidanceId: 1,
            topicId: 1,
            title: '以植物性食物为日常饮食基础',
            bodyZh: '示例正文（已过医学审核）。',
            evidenceLevel: 'B',
            medicalReviewed: true,
            disclaimer: HealthGuard.defaultDisclaimer),
        // 未审条目：默认被闸门拦截
        HealthGuidance(
            guidanceId: 2,
            topicId: 1,
            title: '示例：待审核条目',
            bodyZh: '示例正文（未过医学审核）。',
            evidenceLevel: 'C',
            medicalReviewed: false,
            disclaimer: HealthGuard.defaultDisclaimer),
        HealthGuidance(
            guidanceId: 3,
            topicId: 8,
            title: '以祷告交托，保守心怀',
            bodyZh: '示例正文（已过医学审核）。若持续情绪低落，请寻求专业协助。',
            evidenceLevel: 'C',
            medicalReviewed: true,
            disclaimer: HealthGuard.defaultDisclaimer),
      ];

  static List<HealthMetric> _defaultMetrics() => const [
        HealthMetric(metricId: 1, topicCode: 'NUT', nameZh: '蔬果份数',
            unit: '份/日', targetValue: '≥5'),
        HealthMetric(metricId: 2, topicCode: 'EXE', nameZh: '运动时长',
            unit: '分钟', targetValue: '≥30'),
        HealthMetric(metricId: 3, topicCode: 'WAT', nameZh: '饮水量',
            unit: '毫升', targetValue: '1500–2000'),
        HealthMetric(metricId: 7, topicCode: 'RES', nameZh: '睡眠时长',
            unit: '分钟', targetValue: '≥420'),
        HealthMetric(metricId: 8, topicCode: 'TRU', nameZh: '心情评分',
            unit: '1–5', targetValue: '≥3'),
      ];
}
