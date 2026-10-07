// verify_health_logic.dart
// 纯 Dart 校验脚本：直接 import 真实的 health_models.dart（不含任何 Flutter 依赖），
// 在普通 Dart VM 上实跑核心合规逻辑与数据转换，验证模块 C 的关键正确性。
// 运行：<dart> verify_health_logic.dart   （无需 Flutter 引擎，故不依赖 dart:ui）
import 'dart:convert';
import 'health_models.dart';

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
