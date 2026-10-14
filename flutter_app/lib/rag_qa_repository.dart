// rag_qa_repository.dart
// ===========================================================================
// RAG 兜底接入层：把已验证的离线匹配与 Cloudflare Worker 后端代理串起来。
// ---------------------------------------------------------------------------
// 策略（对齐铁律）：离线匹配命中 → 直接返回；无命中(needsHuman) → 用本地离线检索的
// top-K context 调 RAG 代理，只基于权威资料生成回答；命中越界引用/CUV/失败 → 强制转人工。
//
// 关键性质：
//   - 检索仍在端侧完成（零流量），Worker 只做"生成 + 审计"，key 不落前端。
//   - 离线层始终保留作无网降级：RAG 调用抛错即退回原有转人工引导。
// ===========================================================================

import 'health_qa_logic.dart';
import 'offline_qa_logic.dart';
import 'qa_models.dart';
import 'qa_repository.dart';
import 'rag_client.dart';
import 'rag_config.dart';

/// 把 faq 条目的 citations 统一抽取为 RagCitationPayload（兼容牧师 qa_faq 的
/// source_type/source_id 与健康 health_faq 的 sourceType/sourceId 两种字段命名）。
List<RagCitationPayload> toRagCitations(Map<String, dynamic> entry) {
  return ((entry['citations'] as List?) ?? [])
      .whereType<Map<String, dynamic>>()
      .map((c) => RagCitationPayload(
            sourceType: (c['source_type'] as String?) ??
                (c['sourceType'] as String?) ??
                'BIBLE',
            sourceId: (c['source_id'] as String?) ?? (c['sourceId'] as String?) ?? '',
            ref: (c['ref'] as String?) ?? '',
            snippet: (c['snippet'] as String?) ?? '',
          ))
      .toList();
}

/// 牧师问答 RAG 兜底仓储：实现 QaRepository，离线命中优先，无命中调 RAG。
class RagFallbackQaRepository implements QaRepository {
  final OfflineQaLogic offline;
  final RagClient ragClient;

  RagFallbackQaRepository({required this.offline, required this.ragClient});

  @override
  Future<QaAnswer> ask(String question, {String locale = 'zh'}) async {
    final offlineAns = offline.answer(question, locale: locale);
    if (!offlineAns.needsHuman) return offlineAns;

    // 离线无命中：用端侧检索的 top-K 作为 context 调 RAG
    final entries = offline.retrieve(question, topK: 3);
    final context = entries
        .map((e) => RagContextItem(
              kind: 'pastor',
              answerZh: (e['answer_zh'] as String?) ?? '',
              citations: toRagCitations(e),
            ))
        .toList();

    try {
      final result = await ragClient.ask(
          question: question, kind: 'pastor', context: context);
      return ragResultToAnswer(
        result: result,
        contextCitations: entries.expand(_qaCitations).toList(),
        answerId: 'qa_rag_${question.hashCode}',
      );
    } catch (_) {
      return offlineAns; // 网络/解析失败 → 退回原有转人工引导（离线降级）
    }
  }

  List<QaCitation> _qaCitations(Map<String, dynamic> e) =>
      ((e['citations'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(QaCitation.fromJson)
          .toList();

  @override
  Future<void> sendFeedback(String answerId, int rating, {String? comment}) async {
    // 离线 + RAG 模式：反馈暂存本地（后续可接入后端 / 审查队列）
  }
}

/// 健康问答 RAG 兜底：离线命中优先，无命中调 RAG（结果映射回 HealthQaAnswer）。
Future<HealthQaAnswer> healthRagAnswer(
    HealthQaLogic logic, String question) async {
  if (kRagEndpoint.isEmpty) {
    return logic.ask(question); // 未配置 RAG → 纯离线
  }
  final offline = logic.ask(question);
  if (!offline.needsHuman) return offline;

  final entries = logic.retrieve(question, topK: 3);
  final context = entries
      .map((e) => RagContextItem(
            kind: 'health',
            answerZh: (e['answer_zh'] as String?) ?? '',
            citations: toRagCitations(e),
          ))
      .toList();

  try {
    final client = RagClient(kRagEndpoint);
    final result =
        await client.ask(question: question, kind: 'health', context: context);
    client.close();
    if (result.needsHuman) return offline; // 合规兜底 → 转人工
    return HealthQaAnswer(
      answerId: 'hqa_rag_${question.hashCode}',
      answerZh: result.answer,
      citations: entries.expand(_healthCitations).toList(),
      confidence: 0.85,
      needsHuman: false,
    );
  } catch (_) {
    return offline; // 网络失败 → 离线降级
  }
}

List<HealthQaCitation> _healthCitations(Map<String, dynamic> e) =>
    ((e['citations'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(HealthQaCitation.fromJson)
        .toList();
