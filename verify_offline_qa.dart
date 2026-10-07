// verify_offline_qa.dart
// 模块 B 离线问答（Dart 侧）纯逻辑验证：不依赖 Flutter 引擎，可在沙箱用 dart 直接跑。
// 运行：dart run verify_offline_qa.dart
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

  final verses = (data['verse'] as List).cast<Map<String, dynamic>>();
  final books = (data['book'] as List).cast<Map<String, dynamic>>();
  final faq = (faqJson['faq'] as List).cast<Map<String, dynamic>>();

  final logic = OfflineQaLogic.build(verses: verses, books: books, faq: faq);

  print('== 数据规模 ==');
  check('verses 已加载', verses.isNotEmpty);
  check('faq 已加载 (>=15)', faq.length >= 15);

  print('== FAQ 命中（安息日）==');
  final a1 = logic.answer('你们守安息日吗');
  check('安息日回答非人工', a1.needsHuman == false);
  check('安息日回答有引用', a1.citations.isNotEmpty);
  check('安息日回答无 CUV', a1.citations.every((c) => !c.isCuv));

  print('== FAQ 命中（得救）==');
  final a2 = logic.answer('怎么才能得救呢');
  check('得救回答非人工且有引用', a2.needsHuman == false && a2.citations.isNotEmpty);

  print('== 经文引用直查（中文）==');
  final a3 = logic.answer('约翰福音3章16节是什么意思');
  check('中文引用 -> JHN 3:16', a3.citations.any((c) => c.ref == 'JHN 3:16'));
  check('中文引用非人工', a3.needsHuman == false);

  print('== 经文引用直查（英文）==');
  final a4 = logic.answer('JHN 3:16');
  check('英文引用 -> JHN 3:16', a4.citations.any((c) => c.ref == 'JHN 3:16'));

  print('== 无命中 -> 转人工（不臆测）==');
  final a5 = logic.answer('今天天气怎么样zzz');
  check('无命中 needsHuman=true', a5.needsHuman == true);
  check('无命中 answerZh 诚实引导', a5.answerZh.startsWith('这个问题我暂时'));

  print('== 合规闸门：CUV 强制剔除 ==');
  // 直接构造含 CUV 的回答，验证 _enforce（通过 answer 不可达，这里用模型校验 isCuv）
  final cuvCit = QaCitation.fromJson({
    'source_type': 'BIBLE',
    'source_id': 'CUV-JHN3:16',
    'ref': 'JHN 3:16',
    'snippet': 'x'
  });
  check('CUV 判定 isCuv=true', cuvCit.isCuv);

  print('\n结果：$passed 通过 / $failed 失败');
  exit(failed == 0 ? 0 : 1);
}
