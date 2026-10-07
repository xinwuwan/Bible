// health_models.dart
// 模块 C 健康（NEWSTART）的数据模型 + 客户端合规闸门
// 对应落库表（001_init_schema.sql）：
//   health_topic / health_topic_source / health_guidance / health_metric / health_log_entry
//
// 合规红线（Go/No-Go 否决项之一：未审健康条目漏出）：
//   - medical_reviewed = false 的指导条目不得展示（除非显式开启内部预览开关）
//   - 每条指导必须携带医疗免责声明（缺失则用默认声明兜底）
//   - 健康内容只锚定权威来源（BIBLE / EGW / DOCTRINE），与模块 A/B 共用同一权威库

/// NEWSTART 八支柱代码
enum NewstartCode { nut, exe, wat, sun, tem, air, res, tru }

extension NewstartCodeX on NewstartCode {
  String get code => name.toUpperCase();

  String get defaultNameZh {
    switch (this) {
      case NewstartCode.nut:
        return '营养';
      case NewstartCode.exe:
        return '运动';
      case NewstartCode.wat:
        return '水';
      case NewstartCode.sun:
        return '阳光';
      case NewstartCode.tem:
        return '节制';
      case NewstartCode.air:
        return '空气';
      case NewstartCode.res:
        return '休息';
      case NewstartCode.tru:
        return '信靠';
    }
  }

  static NewstartCode? tryParse(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'NUT':
        return NewstartCode.nut;
      case 'EXE':
        return NewstartCode.exe;
      case 'WAT':
        return NewstartCode.wat;
      case 'SUN':
        return NewstartCode.sun;
      case 'TEM':
        return NewstartCode.tem;
      case 'AIR':
        return NewstartCode.air;
      case 'RES':
        return NewstartCode.res;
      case 'TRU':
        return NewstartCode.tru;
      default:
        return null;
    }
  }
}

/// 健康内容的权威来源类型（与模块 A/B 同一套来源体系）
enum HealthSourceType { bible, egw, doctrine, unknown }

extension HealthSourceTypeX on HealthSourceType {
  String get label {
    switch (this) {
      case HealthSourceType.bible:
        return '圣经 KJV';
      case HealthSourceType.egw:
        return '怀爱伦著作';
      case HealthSourceType.doctrine:
        return '教义';
      case HealthSourceType.unknown:
        return '未知来源';
    }
  }

  static HealthSourceType parse(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'BIBLE':
        return HealthSourceType.bible;
      case 'EGW':
        return HealthSourceType.egw;
      case 'DOCTRINE':
        return HealthSourceType.doctrine;
      default:
        return HealthSourceType.unknown;
    }
  }
}

class HealthTopic {
  final int topicId;
  final String code;
  final String nameZh;
  final String? summary;
  final int sortOrder;

  const HealthTopic({
    required this.topicId,
    required this.code,
    required this.nameZh,
    this.summary,
    this.sortOrder = 0,
  });

  NewstartCode? get newstart => NewstartCodeX.tryParse(code);

  String get displayName => newstart?.defaultNameZh ?? nameZh;

  factory HealthTopic.fromRow(Map<String, dynamic> r) => HealthTopic(
        topicId: (r['topic_id'] as num?)?.toInt() ?? 0,
        code: (r['code'] ?? '') as String,
        nameZh: (r['name_zh'] ?? '') as String,
        summary: r['summary'] as String?,
        sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class HealthSource {
  final int id;
  final int topicId;
  final HealthSourceType sourceType;
  final String sourceId;

  const HealthSource({
    required this.id,
    required this.topicId,
    required this.sourceType,
    required this.sourceId,
  });

  factory HealthSource.fromRow(Map<String, dynamic> r) => HealthSource(
        id: (r['id'] as num?)?.toInt() ?? 0,
        topicId: (r['topic_id'] as num?)?.toInt() ?? 0,
        sourceType: HealthSourceTypeX.parse(r['source_type'] as String?),
        sourceId: (r['source_id'] ?? '') as String,
      );
}

class HealthGuidance {
  final int guidanceId;
  final int topicId;
  final String title;
  final String bodyZh;
  final String? evidenceLevel; // A / B / C
  final bool medicalReviewed;
  final String disclaimer;

  const HealthGuidance({
    required this.guidanceId,
    required this.topicId,
    required this.title,
    required this.bodyZh,
    this.evidenceLevel,
    required this.medicalReviewed,
    required this.disclaimer,
  });

  factory HealthGuidance.fromRow(Map<String, dynamic> r) => HealthGuidance(
        guidanceId: (r['guidance_id'] as num?)?.toInt() ?? 0,
        topicId: (r['topic_id'] as num?)?.toInt() ?? 0,
        title: (r['title'] ?? '') as String,
        bodyZh: (r['body_zh'] ?? '') as String,
        evidenceLevel: r['evidence_level'] as String?,
        // SQLite 无 bool：0/1 兼容
        medicalReviewed: ((r['medical_reviewed'] as num?)?.toInt() ?? 0) != 0,
        disclaimer: (r['disclaimer'] as String?) ?? HealthGuard.defaultDisclaimer,
      );
}

class HealthMetric {
  final int metricId;
  final String topicCode;
  final String nameZh;
  final String? unit;
  final String? targetValue;

  const HealthMetric({
    required this.metricId,
    required this.topicCode,
    required this.nameZh,
    this.unit,
    this.targetValue,
  });

  String get unitLabel => (unit == null || unit!.isEmpty) ? '' : ' $unit';

  factory HealthMetric.fromRow(Map<String, dynamic> r) => HealthMetric(
        metricId: (r['metric_id'] as num?)?.toInt() ?? 0,
        topicCode: (r['topic_code'] ?? '') as String,
        nameZh: (r['name_zh'] ?? '') as String,
        unit: r['unit'] as String?,
        targetValue: r['target_value'] as String?,
      );
}

class HealthLogEntry {
  final int? logId;
  final String userId;
  final String topicCode;
  final int? metricId;
  final String value;
  final DateTime loggedAt;

  const HealthLogEntry({
    this.logId,
    required this.userId,
    required this.topicCode,
    this.metricId,
    required this.value,
    required this.loggedAt,
  });

  /// 同一天（按本地日期计）
  bool isSameDay(DateTime other) =>
      loggedAt.year == other.year &&
      loggedAt.month == other.month &&
      loggedAt.day == other.day;

  Map<String, dynamic> toRow() => {
        if (logId != null) 'log_id': logId,
        'user_id': userId,
        'topic_code': topicCode,
        'metric_id': metricId,
        'value': value,
        'logged_at': loggedAt.toIso8601String(),
      };

  factory HealthLogEntry.fromRow(Map<String, dynamic> r) => HealthLogEntry(
        logId: (r['log_id'] as num?)?.toInt(),
        userId: (r['user_id'] ?? '') as String,
        topicCode: (r['topic_code'] ?? '') as String,
        metricId: (r['metric_id'] as num?)?.toInt(),
        value: (r['value'] ?? '') as String,
        loggedAt: DateTime.tryParse((r['logged_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// 客户端合规闸门（打包脚本与后端闸门之外的第三道防线）
class HealthGuard {
  static const String defaultDisclaimer =
      '本内容不替代专业医疗诊断，如有健康问题请咨询医生。';

  /// 返回违规原因；空列表表示可展示。
  /// [previewMode] 仅在 dart-define SHOW_UNREVIEWED_HEALTH=true 时开启，
  /// 用于内部预览，正式构建必须为 false。
  static List<String> checkGuidance(HealthGuidance g,
      {bool previewMode = false}) {
    final v = <String>[];
    if (!g.medicalReviewed && !previewMode) {
      v.add('本条内容尚未通过医学审核，依合规闸门不予展示');
    }
    if (g.disclaimer.trim().isEmpty) {
      v.add('缺少医疗免责声明');
    }
    return v;
  }

  /// 是否允许展示
  static bool visible(HealthGuidance g, {bool previewMode = false}) =>
      checkGuidance(g, previewMode: previewMode).isEmpty;
}
