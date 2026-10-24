// verify_offline_qa.dart
// 模块 B 离线问答（Dart 侧）验证：不依赖 Flutter 引擎，可在沙箱用 dart 直接跑。
// 运行：dart run verify_offline_qa.dart
//
// v51 起改为**数据驱动**：用例全部来自 test_data/qa_golden.json（与 Python
// _run_golden.py 共用同一份数据），本文件只保留结构性断言（CUV 剔除、数据规模）。
// expect 类型：
//   answer -> 离线直接答：非人工、有引用、无 CUV、contains 全含、notContains 全不含
//   verse  -> 经文引用直查：citations 含指定 ref
//   rag    -> 离线转人工，但 retrieve top-3 须含 retrieveIdx（RAG 兜底可救）
//   human  -> 必须转人工（不硬答），且诚实文案含「不敢妄言」
import 'dart:convert';
import 'dart:io';

import 'flutter_app/lib/offline_qa_logic.dart';
import 'flutter_app/lib/qa_models.dart';

int passed = 0;
int failed = 0;

void check(String name, bool cond) {
  if (cond) {
    passed++;
    print('  PASS  $name');
  } else {
    failed++;
    print('  FAIL  $name');
  }
}

void main() {
  final base = 'flutter_app/assets/web/';
  final data = jsonDecode(File('${base}app_data.json').readAsStringSync())
      as Map<String, dynamic>;
  final faqJson =
      jsonDecode(File('${base}qa_faq.json').readAsStringSync())
          as Map<String, dynamic>;
  final golden = jsonDecode(File('test_data/qa_golden.json').readAsStringSync())
      as Map<String, dynamic>;

  final verses = (data['verse'] as List).cast<Map<String, dynamic>>();
  final books = (data['book'] as List).cast<Map<String, dynamic>>();
  final faq = (faqJson['faq'] as List).cast<Map<String, dynamic>>();
  final cases = (golden['cases'] as List).cast<Map<String, dynamic>>();

  final logic = OfflineQaLogic.build(verses: verses, books: books, faq: faq);

  print('== 结构性断言 ==');
  check('verses 已加载', verses.isNotEmpty);
  check('faq 已加载 (>=261)', faq.length >= 261);
  check('黄金用例已加载 (>=60)', cases.length >= 60);
  // CUV 判定（合规闸门：任何 CUV id 强制剔除）
  final cuvCit = QaCitation.fromJson({
    'source_type': 'BIBLE',
    'source_id': 'CUV-JHN3:16',
    'ref': 'JHN 3:16',
    'snippet': 'x'
  });
  check('CUV 判定 isCuv=true', cuvCit.isCuv);

  print('== 黄金测试集（${cases.length} 用例，数据驱动）==');
  for (final c in cases) {
    final q = c['q'] as String;
    final expect = c['expect'] as String;
    final a = logic.answer(q);
    final noCuv = a.citations.every((x) => !x.isCuv);

    if (expect == 'answer') {
      final contains = (c['contains'] as List?)?.cast<String>() ?? const [];
      final notContains = (c['notContains'] as List?)?.cast<String>() ?? const [];
      check('[$q] 非人工', a.needsHuman == false);
      check('[$q] 有引用', a.citations.isNotEmpty);
      check('[$q] 无 CUV', noCuv);
      check('[$q] 结论加粗', a.answerZh.startsWith('**'));
      for (final m in contains) {
        check('[$q] 含 $m', a.answerZh.contains(m));
      }
      for (final m in notContains) {
        check('[$q] 不含 $m', !a.answerZh.contains(m));
      }
    } else if (expect == 'verse') {
      final ref = c['ref'] as String;
      check('[$q] 经文直查 $ref', a.citations.any((x) => x.ref == ref));
      check('[$q] 非人工', a.needsHuman == false);
    } else if (expect == 'rag') {
      final wantIdx = c['retrieveIdx'] as int;
      final top = logic.retrieve(q, topK: 3);
      final hit = top.any((e) => identical(e, faq[wantIdx]));
      check('[$q] 离线转人工(不硬答)', a.needsHuman == true);
      check('[$q] retrieve 含 idx$wantIdx（RAG 可救）', hit);
    } else if (expect == 'human') {
      check('[$q] 转人工', a.needsHuman == true);
      check('[$q] 诚实不妄言',
          a.answerZh.replaceAll('**', '').contains('不敢妄言'));
    }
  }

  print('\n结果：$passed 通过 / $failed 失败');
  exit(failed == 0 ? 0 : 1);
}
