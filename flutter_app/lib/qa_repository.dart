// qa_repository.dart
// 模块 B 问答数据源：远端实现（对齐 POST /qa/ask 契约）+ Mock 实现（演示 / widget 测试）
//
// 注意：答案必须由后端 RAG + 校验闸门产出，客户端绝不本地"编"答案。
// Mock 实现仅用于无后端时的界面演示与自动化测试，其内容是硬编码样例。

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'qa_models.dart';

abstract class QaRepository {
  /// 提交问题，返回经闸门校验的回答
  Future<QaAnswer> ask(String question, {String locale = 'zh'});

  /// 用户纠错 / 评分 → 写 qa_feedback，必要时进 review_queue
  Future<void> sendFeedback(String answerId, int rating, {String? comment});
}

/// 远端实现
class RemoteQaRepository implements QaRepository {
  final String baseUrl;
  final http.Client client;
  final Duration timeout;

  RemoteQaRepository({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : client = client ?? http.Client();

  @override
  Future<QaAnswer> ask(String question, {String locale = 'zh'}) async {
    final uri = Uri.parse('$baseUrl/qa/ask');
    final resp = await client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'question': question, 'locale': locale}),
        )
        .timeout(timeout);
    if (resp.statusCode != 200) {
      throw Exception('问答失败: HTTP ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return QaAnswer.fromJson(data);
  }

  @override
  Future<void> sendFeedback(String answerId, int rating, {String? comment}) async {
    final uri = Uri.parse('$baseUrl/qa/$answerId/feedback');
    final resp = await client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'rating': rating, if (comment != null) 'comment': comment}),
        )
        .timeout(timeout);
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('反馈提交失败: HTTP ${resp.statusCode}');
    }
  }
}

/// Mock 实现：用于无后端时的界面演示与 widget 测试。
/// 通过脚本化应答（Map<关键词, QaAnswer>）控制返回，便于覆盖各类闸门分支。
class MockQaRepository implements QaRepository {
  /// 按问题关键字返回预设回答；未命中则返回 scripted 或默认回答
  final Map<String, QaAnswer> scripted;
  final QaAnswer fallback;
  final Duration latency;
  final List<Map<String, dynamic>> feedbackLog = [];

  MockQaRepository({
    Map<String, QaAnswer>? scripted,
    QaAnswer? fallback,
    this.latency = const Duration(milliseconds: 10),
  })  : scripted = scripted ?? const {},
        fallback = fallback ?? _defaultAnswer;

  static final QaAnswer _defaultAnswer = QaAnswer(
    answerId: 'qa_mock_1',
    answerZh: '这是本地 Mock 回答（无后端时用于界面演示）。'
        '正式答案必须由后端 RAG 依据 KJV / 怀爱伦著作 / 教义原文生成，并附权威引用。',
    citations: const [
      QaCitation(
        sourceType: QaSourceType.bible,
        sourceId: 'KJV-JHN3:16',
        ref: 'JHN 3:16',
        snippet: 'For God so loved the world, that he gave his only begotten Son...',
      ),
    ],
    confidence: 0.75,
    needsHuman: false,
  );

  @override
  Future<QaAnswer> ask(String question, {String locale = 'zh'}) async {
    await Future<void>.delayed(latency);
    for (final entry in scripted.entries) {
      if (question.contains(entry.key)) return entry.value;
    }
    return fallback;
  }

  @override
  Future<void> sendFeedback(String answerId, int rating, {String? comment}) async {
    feedbackLog.add({'answer_id': answerId, 'rating': rating, 'comment': comment});
  }
}
