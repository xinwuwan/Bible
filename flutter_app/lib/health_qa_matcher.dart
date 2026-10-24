// health_qa_matcher.dart
// 模块 C 离线健康问答的**纯匹配逻辑**（不依赖 Flutter，可在沙箱用 dart 直接单测）。
//
// v53 从 health_qa_logic.dart 抽出：原文件 import 了 flutter/services（rootBundle），
// 导致纯 Dart 测试无法覆盖真实匹配逻辑（根目录的旧副本还曾让 CI 测到陈旧代码）。
// 本文件零依赖，verify_health_logic.dart 直接 import 测试。
//
// v53 弱命中护栏：
//   根因（2026-10-24 用户实报）：「草本植物和木本植物可以一起同食吗？」整句只命中
//   一个两字通用类别词「植物」（score=2，刚好压中旧门槛 >=2），触发泛泛的饮食
//   条目（答非所问）。护栏规则：**所有命中均为短(<=2字)通用类别词时不直接作答**，
//   转人工/RAG 兜底——具体症状词（头疼/睡不着）、长关键词（一起吃/素食）不受影响。
import 'dart:convert';

/// 弱命中通用类别词：单独命中这些宽泛类别词，不足以授权直接作答。
/// 收录标准：宽泛食物/健康类别，常作为更具体主题词的子串出现（植物⊂草本植物）。
/// 不收具体症状或食物主题词（压力/坚果/头疼等——那些是问句的真正主题）。
const Set<String> healthQaGenericWords = {
  '植物', '食物', '饮食', '健康', '营养', '运动', '锻炼', '活动',
  '谷物', '纤维', '皮肤', '心脏',
};

/// 健康 FAQ 匹配结果（含命中明细，供护栏判断）。
class HealthQaMatch {
  final Map<String, dynamic>? entry;
  final int score;
  final List<String> hits;

  const HealthQaMatch(this.entry, this.score, this.hits);

  bool get hasEntry => entry != null;

  /// 弱命中：无命中，或所有命中均为短(<=2字)通用类别词。
  /// 弱命中不得直接作答（宁缺毋滥，转人工/RAG）。
  bool get weak {
    if (hits.isEmpty) return true;
    for (final h in hits) {
      if (h.length > 2) return false;
      if (!healthQaGenericWords.contains(h)) return false;
    }
    return true;
  }
}

/// 关键词长度加权匹配（与模块 B 对齐：越具体的关键词权重越大）。
HealthQaMatch matchHealthFaq(
    List<Map<String, dynamic>> faq, String question) {
  final q = question.trim();
  final ql = q.toLowerCase();

  Map<String, dynamic>? best;
  var bestScore = 0;
  List<String> bestHits = const [];
  for (final entry in faq) {
    var score = 0;
    final hits = <String>[];
    for (final raw in (entry['keywords'] as List?) ?? []) {
      final kw = (raw as String).toLowerCase();
      if (kw.isNotEmpty && ql.contains(kw)) {
        score += kw.length;
        hits.add(kw);
      }
    }
    if (score > bestScore) {
      bestScore = score;
      best = entry;
      bestHits = hits;
    }
  }
  return HealthQaMatch(best, bestScore, bestHits);
}

/// 离线检索 top-K FAQ 条目（供 RAG 兜底作 context 用）。
/// 注意：检索不过护栏——给 LLM 的上下文越多越有利于综合，
/// 护栏只拦「直接作答」这一条路径。
List<Map<String, dynamic>> retrieveHealthFaq(
    List<Map<String, dynamic>> faq, String question,
    {int topK = 3}) {
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

/// 从 JSON 字符串解析 faq 列表（测试与加载共用）。
List<Map<String, dynamic>> parseHealthFaq(String jsonStr) {
  final d = jsonDecode(jsonStr) as Map<String, dynamic>;
  final list = (d['faq'] as List?) ?? [];
  return list.whereType<Map<String, dynamic>>().toList();
}
