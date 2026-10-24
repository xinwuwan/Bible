// health_qa_logic.dart
// 模块 C 离线健康问答：纯 Dart 逻辑（不依赖 Flutter，可在沙箱单测）。
//
// 设计：与模块 B 的 OfflineQaLogic 对齐——关键词长度加权匹配本地 NEWSTART 知识库，
// 无命中诚实转人工（绝不臆测、不替代医疗诊断）。
// 数据来源：assets/web/health_faq.json（gen_health_data.py 生成）。
//
// 合规：健康内容只锚定权威来源（BIBLE / EGW）；不提供诊断，涉及具体症状/用药必引导就医。
//
// v53：匹配核心逻辑抽到 health_qa_matcher.dart（纯 Dart、可单测），本文件只做
// 资产加载与结果包装；ask() 新增弱命中护栏（单命中短通用类别词不直接作答）。
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'health_qa_matcher.dart';

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

  /// 关键词长度加权匹配（越具体的关键词权重越大）。
  /// v53 起经 health_qa_matcher 实现，并加**弱命中护栏**：所有命中均为
  /// 短(<=2字)通用类别词（如「植物」）时不直接作答，转人工/RAG——
  /// 防「草本植物和木本植物可以一起同食吗」误中泛泛饮食条目（答非所问）。
  HealthQaAnswer ask(String question) {
    final m = matchHealthFaq(faq, question);
    if (m.hasEntry && m.score >= 2 && !m.weak) {
      final best = m.entry!;
      final citations = ((best['citations'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(HealthQaCitation.fromJson)
          .toList();
      return HealthQaAnswer(
        answerId: 'hqa_offline',
        answerZh: (best['answer_zh'] as String?) ?? '',
        citations: citations,
        confidence: (0.70 + 0.05 * m.score).clamp(0.0, 0.92),
        needsHuman: false,
      );
    }

    // 无命中或弱命中：诚实转人工，绝不臆测
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
    return retrieveHealthFaq(faq, question, topK: topK);
  }
}
