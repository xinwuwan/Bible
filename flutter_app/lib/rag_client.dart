// rag_client.dart
// ===========================================================================
// RAG 后端代理的 Flutter 客户端（对准 rag-worker/worker.js 的 POST /api/rag）
// ---------------------------------------------------------------------------
// 职责：App 在离线关键词匹配 needsHuman 时，把**本地已离线检索出的 top-K context**
//       发给 Worker（key 不落前端），换回大模型基于权威资料生成的回答。
//
// 合规铁律（与 Worker 一致）：
//   - 越界引用 / CUV / fallback 命中 → 强制 needsHuman（诚实兜底，转人工顾问）
//   - 正常回答的 citations 用"发出去的 context 权威引用"，保证来源闭环
// ===========================================================================

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'qa_models.dart';

/// 发给 Worker 的单条检索上下文（对齐 qa_faq.json / health_faq.json 结构）
class RagContextItem {
  final String kind; // 'pastor' | 'health'
  final String answerZh;
  final List<RagCitationPayload> citations;

  const RagContextItem({
    required this.kind,
    required this.answerZh,
    required this.citations,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'answer_zh': answerZh,
        'citations': citations.map((c) => c.toJson()).toList(),
      };
}

class RagCitationPayload {
  final String sourceType; // BIBLE / EGW / DOCTRINE
  final String sourceId;
  final String ref;
  final String snippet;

  const RagCitationPayload({
    required this.sourceType,
    required this.sourceId,
    required this.ref,
    required this.snippet,
  });

  Map<String, dynamic> toJson() => {
        'source_type': sourceType,
        'source_id': sourceId,
        'ref': ref,
        'snippet': snippet,
      };

  QaCitation toQaCitation() => QaCitation(
        sourceType: QaSourceTypeX.parse(sourceType),
        sourceId: sourceId,
        ref: ref,
        snippet: snippet,
      );
}

/// Worker 的返回体
class RagResult {
  final String answer;
  final List<String> flags;
  final bool fallback;

  const RagResult({
    required this.answer,
    required this.flags,
    required this.fallback,
  });

  factory RagResult.fromJson(Map<String, dynamic> j) => RagResult(
        answer: (j['answer'] as String?) ?? '',
        flags: (j['flags'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        fallback: (j['fallback'] as bool?) ?? false,
      );

  /// 是否触发合规兜底（越界引用 / CUV / Worker 主动 fallback）
  bool get needsHuman =>
      fallback || flags.any((f) => f.contains('越界引用') || f.contains('CUV'));
}

/// RAG 代理客户端
class RagClient {
  final String endpoint; // 例如 https://bible-rag-proxy.your-subdomain.workers.dev/api/rag
  final http.Client _client;

  RagClient(this.endpoint, {http.Client? client})
      : _client = client ?? http.Client();

  Future<RagResult> ask({
    required String question,
    required String kind, // 'pastor' | 'health'
    required List<RagContextItem> context,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final resp = await _client
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'question': question,
            'kind': kind,
            'context': context.map((c) => c.toJson()).toList(),
          }),
        )
        .timeout(timeout);
    if (resp.statusCode != 200) {
      throw Exception('RAG 请求失败: HTTP ${resp.statusCode}');
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    return RagResult.fromJson(j);
  }

  void close() => _client.close();
}

/// 把 RAG 结果映射成 App 的 QaAnswer。
/// [contextCitations] 即本次发出去的 context 权威引用（保证来源闭环）。
/// 命中合规兜底时强制 needsHuman，绝不把无依据/越界内容当定论。
QaAnswer ragResultToAnswer({
  required RagResult result,
  required List<QaCitation> contextCitations,
  required String answerId,
  double confidence = 0.85,
}) {
  if (result.needsHuman) {
    return QaAnswer(
      answerId: answerId,
      answerZh: result.answer.isNotEmpty
          ? result.answer
          : '**这个问题经 RAG 检索后仍未找到权威依据，已转人工顾问复核。** '
              '你可以直接输入经文引用（如「路加福音3:23」），我立刻陪你查考并附权威出处。',
      citations: const [],
      confidence: 0.0,
      needsHuman: true,
    );
  }
  return QaAnswer(
    answerId: answerId,
    answerZh: result.answer,
    citations: contextCitations,
    confidence: confidence,
    needsHuman: false,
  );
}
