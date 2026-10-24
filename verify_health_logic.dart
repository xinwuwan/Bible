// verify_health_logic.dart
// 纯 Dart 校验脚本：直接 import 真实的 health_models.dart（不含任何 Flutter 依赖），
// 在普通 Dart VM 上实跑核心合规逻辑与数据转换，验证模块 C 的关键正确性。
// 运行：<dart> verify_health_logic.dart   （无需 Flutter 引擎，故不依赖 dart:ui）
//
// v53：① import 从陈旧的根目录副本切到 flutter_app/lib/ 真实代码
//        （根目录副本停留在 10-06，缺 HealthDailyTip，CI 等于在测旧代码）；
//      ② 新增健康问答匹配护栏测试段（health_qa_matcher.dart，纯 Dart）。
import 'dart:convert';
import 'dart:io';

import 'flutter_app/lib/health_models.dart';
import 'flutter_app/lib/health_qa_matcher.dart';

int _pass = 0;
int _fail = 0;

void check(String name, bool ok, [String detail = '']) {
  if (ok) {
    _pass++;
    print('  PASS  $name');
  } else {
    _fail++;
    print('  FAIL  $name  ${detail.isNotEmpty ? '-> $detail' : ''}');
  }
}

HealthGuidance g({
  required bool reviewed,
  String disclaimer = HealthGuard.defaultDisclaimer,
  String? evidenceLevel = 'B',
}) =>
    HealthGuidance(
      guidanceId: 1,
      topicId: 1,
      title: 't',
      bodyZh: 'b',
      evidenceLevel: evidenceLevel,
      medicalReviewed: reviewed,
      disclaimer: disclaimer,
    );

void main() {
  print('=== 模块 C 健康模型 · 纯 Dart 实跑校验 ===');

  // 1) NewstartCode.tryParse 大小写/非法
  check('tryParse NUT', NewstartCodeX.tryParse('NUT') == NewstartCode.nut);
  check('tryParse nut (lower)', NewstartCodeX.tryParse('nut') == NewstartCode.nut);
  check('tryParse TRU', NewstartCodeX.tryParse('TRU') == NewstartCode.tru);
  check('tryParse 空 -> null', NewstartCodeX.tryParse('') == null);
  check('tryParse 非法 -> null', NewstartCodeX.tryParse('XYZ') == null);

  // 2) defaultNameZh 映射
  check('NUT 中文名', NewstartCode.nut.defaultNameZh == '营养');
  check('TRU 中文名', NewstartCode.tru.defaultNameZh == '信靠');
  check('8 支柱全映射',
      NewstartCode.values.every((c) => c.defaultNameZh.isNotEmpty));

  // 3) 合规闸门：已审可展示
  final reviewed = g(reviewed: true);
  check('已审 + 非预览 -> 可展示', HealthGuard.visible(reviewed));
  check('已审 + 非预览 -> 无违规', HealthGuard.checkGuidance(reviewed).isEmpty);

  // 4) 合规闸门：未审在非预览模式被拦截
  final unreviewed = g(reviewed: false);
  check('未审 + 非预览 -> 拦截', !HealthGuard.visible(unreviewed));
  check('未审 + 非预览 -> 含拦截原因',
      HealthGuard.checkGuidance(unreviewed).join().contains('医学审核'));

  // 5) 合规闸门：预览模式放行未审（仅内部预览）
  check('未审 + 预览模式 -> 放行', HealthGuard.visible(unreviewed, previewMode: true));
  check('已审 + 预览模式 -> 仍放行', HealthGuard.visible(reviewed, previewMode: true));

  // 6) 免责声明缺失：无论是否过审都必须拦截
  final noDisc = g(reviewed: true, disclaimer: '   ');
  check('已审但无声明 -> 拦截', !HealthGuard.visible(noDisc));
  check('无声明原因存在', HealthGuard.checkGuidance(noDisc).join().contains('免责'));
  final noDiscPreview = g(reviewed: false, disclaimer: '');
  check('未审且无声明 + 预览 -> 仍拦截(声明优先)',
      !HealthGuard.visible(noDiscPreview, previewMode: true));

  // 7) fromRow：SQLite 0/1 -> bool，缺省声明兜底
  final rowReviewed = {
    'guidance_id': 7,
    'topic_id': 3,
    'title': 't7',
    'body_zh': 'b7',
    'evidence_level': 'A',
    'medical_reviewed': 1,
    'disclaimer': '自定义声明',
  };
  final gr = HealthGuidance.fromRow(rowReviewed);
  check('fromRow 1 -> reviewed=true', gr.medicalReviewed == true);
  check('fromRow 自定义声明保留', gr.disclaimer == '自定义声明');

  final rowUnrev = {
    'guidance_id': 8,
    'topic_id': 3,
    'title': 't8',
    'body_zh': 'b8',
    'evidence_level': 'C',
    'medical_reviewed': 0,
  };
  final gu = HealthGuidance.fromRow(rowUnrev);
  check('fromRow 0 -> reviewed=false', gu.medicalReviewed == false);
  check('fromRow 无声明 -> 默认声明兜底',
      gu.disclaimer == HealthGuard.defaultDisclaimer);

  // 8) HealthLogEntry isSameDay / toRow / fromRow
  final now = DateTime(2026, 10, 6, 9, 30);
  final sameDayLater = DateTime(2026, 10, 6, 23, 59);
  final nextDay = DateTime(2026, 10, 7, 0, 1);
  final log = HealthLogEntry(
      userId: 'u1',
      topicCode: 'NUT',
      metricId: 2,
      value: '6',
      loggedAt: now);
  check('isSameDay 同日', log.isSameDay(sameDayLater));
  check('isSameDay 次日 -> false', !log.isSameDay(nextDay));

  final row = log.toRow();
  check('toRow topic_code', row['topic_code'] == 'NUT');
  check('toRow value', row['value'] == '6');
  check('toRow logged_at ISO', row['logged_at'] == now.toIso8601String());

  final log2 = HealthLogEntry.fromRow(row);
  check('fromRow 还原 value', log2.value == '6');
  check('fromRow 还原 topicCode', log2.topicCode == 'NUT');
  check('fromRow 还原 同日', log2.isSameDay(now));

  // 9) HealthTopic.fromRow + newstart/displayName
  final tRow = {
    'topic_id': 1,
    'code': 'WAT',
    'name_zh': '水',
    'summary': '充足饮水',
    'sort_order': 3,
  };
  final topic = HealthTopic.fromRow(tRow);
  check('Topic newstart 解析', topic.newstart == NewstartCode.wat);
  check('Topic displayName 取 NEWSTART 名', topic.displayName == '水');
  check('Topic sortOrder', topic.sortOrder == 3);

  // 10) HealthSource.fromRow
  final sRow = {
    'id': 5,
    'topic_id': 1,
    'source_type': 'BIBLE',
    'source_id': 'GEN 1:29',
  };
  final src = HealthSource.fromRow(sRow);
  check('Source type BIBLE', src.sourceType == HealthSourceType.bible);
  check('Source id 保留', src.sourceId == 'GEN 1:29');

  // =====================================================================
  // 11) v53 健康问答匹配护栏（health_qa_matcher.dart，纯 Dart 实跑真实数据）
  // =====================================================================
  print('');
  print('=== v53 健康问答匹配护栏 ===');
  final hfaq = parseHealthFaq(
      File('flutter_app/assets/web/health_faq.json').readAsStringSync());
  check('health_faq 已加载 (>=54)', hfaq.length >= 54);

  // 用户实报案例：草本木本同食 -> 应命中「食物相克/搭配」条目，且非弱命中
  final m1 = matchHealthFaq(hfaq, '草本植物和木本植物可以一起同食吗？');
  final m1Ans = (m1.entry?['answer_zh'] as String?) ?? '';
  check('草本木本同食 -> 命中食物搭配条目',
      m1.hasEntry && !m1.weak && m1Ans.contains('食物相克'),
      'score=${m1.score} hits=${m1.hits}');
  check('草本木本同食 -> 多关键词命中（非单弱命中）', m1.hits.length >= 2,
      'hits=${m1.hits}');

  // 同义问法：两种食物能不能一起吃
  final m2 = matchHealthFaq(hfaq, '米饭和面条能一起吃吗');
  check('一起吃问法 -> 命中食物搭配条目',
      m2.hasEntry && !m2.weak && ((m2.entry?['answer_zh'] as String?) ?? '').contains('食物相克'),
      'score=${m2.score} hits=${m2.hits}');

  // 护栏核心：单命中短通用类别词 -> 弱命中，不得直接作答
  final m3 = matchHealthFaq(hfaq, '植物');
  check('单命中「植物」-> 弱命中（不直接答）', m3.weak, 'hits=${m3.hits}');
  final m4 = matchHealthFaq(hfaq, '饮食');
  check('单命中「饮食」-> 弱命中（不直接答）', m4.weak, 'hits=${m4.hits}');

  // 具体症状/主题问句不受护栏影响
  final m5 = matchHealthFaq(hfaq, '睡不着怎么办');
  check('睡不着 -> 强命中睡眠条目', m5.hasEntry && !m5.weak,
      'score=${m5.score} hits=${m5.hits}');
  final m6 = matchHealthFaq(hfaq, '头疼怎么缓解');
  check('头疼 -> 强命中头痛条目', m6.hasEntry && !m6.weak,
      'score=${m6.score} hits=${m6.hits}');
  final m7 = matchHealthFaq(hfaq, '天天跑步好吗');
  check('跑步 -> 非弱命中（含非通用词）', m7.hasEntry && !m7.weak,
      'score=${m7.score} hits=${m7.hits}');

  // 无命中 -> 空
  final m8 = matchHealthFaq(hfaq, 'zzz完全不相关的问题qqq');
  check('无命中 -> hasEntry=false', !m8.hasEntry);

  // retrieve 不过护栏：给 RAG 的上下文应包含弱命中条目
  final r1 = retrieveHealthFaq(hfaq, '植物', topK: 3);
  check('retrieve「植物」仍返回上下文（护栏只拦直接答）', r1.isNotEmpty);

  print('');
  print('结果: $_pass 通过 / $_fail 失败');
  if (_fail > 0) {
    print('JSON: ${jsonEncode({'pass': _pass, 'fail': _fail, 'ok': false})}');
    // 非零退出，便于 CI / 后续自动化识别
    throw Exception('$_fail 项校验未通过');
  }
  print('JSON: ${jsonEncode({'pass': _pass, 'fail': _fail, 'ok': true})}');
  print('全部通过 ✅');
}
