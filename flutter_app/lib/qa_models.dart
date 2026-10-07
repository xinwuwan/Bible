// qa_models.dart
// 模块 B 牧师问答的数据模型 + 客户端校验闸门
// 契约（mvp-breakdown.html）:
//   POST /qa/ask  → {answer_id, answer_zh, citations:[{source_type, source_id, ref, snippet}],
//                    confidence, needs_human}
//   needs_human=true 时 answer_zh 仅为引导语，需转人工顾问
//
// 客户端也要拦一道（Go/No-Go 否决项）:
//   - citations 为空            → 拒绝展示（无来源即臆测）
//   - cuv 前缀 id 出现在 citations → 直接拦截（和合本绝不作权威来源）
//   - confidence < 0.70         → 标记低置信，提示转人工

/// 引用来源类型
enum QaSourceType { bible, egw, doctrine, unknown }

extension QaSourceTypeX on QaSourceType {
  String get label {
    switch (this) {
      case QaSourceType.bible:
        return '圣经 KJV';
      case QaSourceType.egw:
        return '怀爱伦著作';
      case QaSourceType.doctrine:
        return '教义';
      case QaSourceType.unknown:
        return '未知来源';
    }
  }

  static QaSourceType parse(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'BIBLE':
        return QaSourceType.bible;
      case 'EGW':
        return QaSourceType.egw;
      case 'DOCTRINE':
        return QaSourceType.doctrine;
      default:
        return QaSourceType.unknown;
    }
  }
}

/// 单条引用（点击应跳回权威原文，形成「产出 → 来源」闭环）
class QaCitation {
  final QaSourceType sourceType;
  final String sourceId; // 如 KJV-JHN3:16 / EGW-SC-p45
  final String ref;
  final String snippet;

  const QaCitation({
    required this.sourceType,
    required this.sourceId,
    required this.ref,
    required this.snippet,
  });

  /// 合规红线：和合本 id 绝不允许作为权威引用出现
  bool get isCuv => sourceId.trim().toUpperCase().startsWith('CUV');

  factory QaCitation.fromJson(Map<String, dynamic> j) => QaCitation(
        sourceType: QaSourceTypeX.parse(j['source_type'] as String?),
        sourceId: (j['source_id'] ?? '') as String,
        ref: (j['ref'] ?? '') as String,
        snippet: (j['snippet'] ?? '') as String,
      );
}

/// 一次问答结果
class QaAnswer {
  final String answerId;
  final String answerZh;
  final List<QaCitation> citations;
  final double confidence;
  final bool needsHuman;

  const QaAnswer({
    required this.answerId,
    required this.answerZh,
    required this.citations,
    required this.confidence,
    required this.needsHuman,
  });

  factory QaAnswer.fromJson(Map<String, dynamic> j) => QaAnswer(
        answerId: (j['answer_id'] ?? '') as String,
        answerZh: (j['answer_zh'] ?? '') as String,
        citations: (j['citations'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(QaCitation.fromJson)
            .toList(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        needsHuman: (j['needs_human'] as bool?) ?? false,
      );
}

/// 对话轮次（用户提问 + 回答/状态）
class QaTurn {
  final String question;
  final QaAnswer? answer;
  final bool loading;
  final String? error;
  final List<String> guardViolations; // 闸门拦截原因（非空则不得展示答案）

  const QaTurn({
    required this.question,
    this.answer,
    this.loading = false,
    this.error,
    this.guardViolations = const [],
  });

  bool get blocked => guardViolations.isNotEmpty;
}

/// 客户端校验闸门（与后端闸门互为双保险）
class CitationGuard {
  static const double minConfidence = 0.70;

  /// 返回违规原因列表；空列表表示通过。
  static List<String> check(QaAnswer a) {
    final v = <String>[];
    if (!a.needsHuman) {
      if (a.citations.isEmpty) {
        v.add('引用缺失：无权威来源支撑，已拦截（不展示回答）');
      }
      final cuv = a.citations.where((c) => c.isCuv).toList();
      if (cuv.isNotEmpty) {
        v.add('来源非法：出现和合本 id（${cuv.map((c) => c.sourceId).join('、')}），已拦截');
      }
      if (a.confidence < minConfidence) {
        v.add('置信过低（${a.confidence.toStringAsFixed(2)} < '
            '${minConfidence.toStringAsFixed(2)}）：建议转人工顾问');
      }
    } else {
      // needs_human=true 时后端只给引导语，允许 citations 为空
      final cuv = a.citations.where((c) => c.isCuv).toList();
      if (cuv.isNotEmpty) {
        v.add('来源非法：出现和合本 id，已拦截');
      }
    }
    return v;
  }
}
