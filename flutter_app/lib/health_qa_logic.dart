// health_qa_logic.dart
// 模块 C 离线健康问答：纯 Dart 逻辑（不依赖 Flutter，可在沙箱单测）。
//
// 设计：与模块 B 的 OfflineQaLogic 对齐——关键词长度加权匹配本地 NEWSTART 知识库，
// 无命中诚实转人工（绝不臆测、不替代医疗诊断）。
// 数据来源：assets/web/health_faq.json（gen_health_data.py 生成）。
//
// 合规：健康内容只锚定权威来源（BIBLE / EGW）；不提供诊断，涉及具体症状/用药必引导就医。
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// 健康问答的权威来源类型（与模块 A/B 同一套来源体系）
enum HealthQaSourceType { bible, egw, doctrine, unknown }

extension HealthQaSourceTypeX on HealthQaSourceType {
  String get label {
    switch (this) {
      case HealthQaSourceType.bible:
        return '圣经 KJV';
      case HealthQaSourceType.egw:
        return '怀爱伦著作';
      case HealthQaSourceType.doctrine:
        return '教义';
      case HealthQaSourceType.unknown:
        return '来源';
    }
  }

  static HealthQaSourceType parse(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'BIBLE':
        return HealthQaSourceType.bible;
      case 'EGW':
        return HealthQaSourceType.egw;
      case 'DOCTRINE':
        return HealthQaSourceType.doctrine;
      default:
        return HealthQaSourceType.unknown;
    }
  }
}

class HealthQaCitation {
  final HealthQaSourceType sourceType;
  final String sourceId;
  final String ref;
  final String snippet;

  const HealthQaCitation({
    required this.sourceType,
    required this.sourceId,
    required this.ref,
    this.snippet = '',
  });

  factory HealthQaCitation.fromJson(Map<String, dynamic> j) => HealthQaCitation(
        sourceType: HealthQaSourceTypeX.parse(j['sourceType'] as String?),
        sourceId: (j['sourceId'] as String?) ?? '',
        ref: (j['ref'] as String?) ?? (j['sourceId'] as String? ?? ''),
        snippet: (j['snippet'] as String?) ?? '',
      );
}

class HealthQaAnswer {
  final String answerId;
  final String answerZh;
  final List<HealthQaCitation> citations;
  final double confidence;
  final bool needsHuman;

  const HealthQaAnswer({
    required this.answerId,
    required this.answerZh,
    required this.citations,
    required this.confidence,
    required this.needsHuman,
  });
}

class HealthQaLogic {
  final List<Map<String, dynamic>> faq;

  HealthQaLogic(this.faq);

  /// 从资产加载知识库
  static Future<HealthQaLogic> load() async {
    try {
      final s = await rootBundle.loadString('assets/web/health_faq.json');
      final d = jsonDecode(s) as Map<String, dynamic>;
      final list = (d['faq'] as List?) ?? [];
      return HealthQaLogic(
          list.whereType<Map<String, dynamic>>().toList());
    } catch (_) {
      return HealthQaLogic(const []);
    }
  }

  /// 关键词长度加权匹配（越具体的关键词权重越大）
  HealthQaAnswer ask(String question) {
    final q = question.trim();
    final ql = q.toLowerCase();

    Map<String, dynamic>? best;
    var bestScore = 0;
    for (final entry in faq) {
      var score = 0;
      for (final raw in (entry['keywords'] as List?) ?? []) {
        final kw = (raw as String).toLowerCase();
        if (kw.isNotEmpty && ql.contains(kw)) score += kw.length;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }
    if (best != null && bestScore >= 2) {
      final citations = ((best['citations'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(HealthQaCitation.fromJson)
          .toList();
      return HealthQaAnswer(
        answerId: 'hqa_offline',
        answerZh: (best['answer_zh'] as String?) ?? '',
        citations: citations,
        confidence: (0.70 + 0.05 * bestScore).clamp(0.0, 0.92),
        needsHuman: false,
      );
    }

    // 无命中：诚实转人工，绝不臆测
    return const HealthQaAnswer(
      answerId: 'hqa_needs_human',
      answerZh: '**弟兄姊妹，这个问题我暂时没有在已审核的健康知识里找到确切依据；'
          '健康关乎身体，我不敢随口给不确定的建议。** 你可以：\n'
          '① 换个角度再问，例如围绕营养、运动、睡眠、节制、压力或 NEWSTART 八大原则；\n'
          '② 看看页面顶部的「今日健康一贴」，每天都有一条小提醒；\n'
          '③ 若涉及具体症状、用药或长期不适，请务必咨询专业医生。愿你身心都得享安康。',
      citations: [],
      confidence: 0.0,
      needsHuman: true,
    );
  }

  /// 离线检索 top-K FAQ 条目（供 RAG 兜底作 context 用）。
  /// 返回条目本身（含 answer_zh / citations），调用方负责转成 RagContextItem。
  List<Map<String, dynamic>> retrieve(String question, {int topK = 3}) {
    final ql = question.trim().toLowerCase();
    final scored = <Map<String, dynamic>>[];
    for (final entry in faq) {
      var score = 0;
      for (final raw in (entry['keywords'] as List<dynamic>? ?? const [])) {
        final kw = (raw as String).toLowerCase();
        if (kw.isNotEmpty && ql.contains(kw)) score += kw.length;
      }
      if (score > 0) scored.add({'score': score, 'entry': entry});
    }
    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return scored
        .take(topK)
        .map((e) => e['entry'] as Map<String, dynamic>)
        .toList();
  }
}
