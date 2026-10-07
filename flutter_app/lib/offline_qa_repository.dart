// offline_qa_repository.dart
// 模块 B 离线问答的 Flutter 封装：实现 QaRepository 接口，从资产加载知识库。
//
// 与 backend/app/responder.py 的 OfflineResponder 对齐；无需任何后端、无需 API key。
// 真实 LLM 增强版本由 backend/ 提供（可选部署），通过 kUseRemoteQa + API_BASE 接入。
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'offline_db_helper.dart';
import 'offline_qa_logic.dart';
import 'qa_models.dart';
import 'qa_repository.dart';

class OfflineQaRepository implements QaRepository {
  final OfflineQaLogic _logic;
  static OfflineQaRepository? _instance;

  OfflineQaRepository._(this._logic);

  /// 单例：加载 qa_faq.json 资产 + 已加载的经文，构建检索索引。
  static Future<OfflineQaRepository> load() async {
    if (_instance != null) return _instance!;
    final faqStr = await rootBundle.loadString('assets/web/qa_faq.json');
    final faq = (jsonDecode(faqStr) as Map<String, dynamic>)['faq']
        as List<dynamic>;
    final logic = OfflineQaLogic.build(
      verses: OfflineDbHelper.getVerses(),
      books: OfflineDbHelper.getBooks(),
      faq: faq.cast<Map<String, dynamic>>(),
    );
    _instance = OfflineQaRepository._(logic);
    return _instance!;
  }

  /// 已加载的单例（main() 中 await load() 后可用；未加载则回退构造为空逻辑）。
  static OfflineQaRepository? get instance => _instance;

  @override
  Future<QaAnswer> ask(String question, {String locale = 'zh'}) async =>
      _logic.answer(question, locale: locale);

  @override
  Future<void> sendFeedback(String answerId, int rating, {String? comment}) async {
    // 离线模式：反馈暂存本地（后续可接入后端 / 审查队列）
  }
}
