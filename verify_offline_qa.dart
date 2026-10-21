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

  print('== FAQ 命中（亚伯拉罕迁徙）==');
  final a6 = logic.answer('是亚伯拉罕的父亲带他去的，还是亚伯拉罕带着其他家人去的？');
  check('亚伯拉罕回答非人工', a6.needsHuman == false);
  check('亚伯拉罕回答有引用', a6.citations.isNotEmpty);
  check('亚伯拉罕回答结论加粗', a6.answerZh.startsWith('**'));

  print('== 无命中 -> 转人工（不臆测）==');
  final a5 = logic.answer('今天天气怎么样zzz');
  check('无命中 needsHuman=true', a5.needsHuman == true);
  // 答案首句带 ** 加粗标记（结论先行），且诚实声明不妄言（牧者语气）
  check('无命中 answerZh 诚实引导',
      a5.answerZh.replaceAll('**', '').contains('不敢妄言'));

  print('== FAQ 命中（怀爱伦健康事工著作，修复答非所问）==');
  // 用户实测案例：问「怀爱伦的著作中哪些是关于健康事工的？」
  // 旧算法只累加命中分，「怀爱伦」即误中「教义 #18 预言的恩赐」条目。
  final a7 = logic.answer('怀爱伦的著作中哪些是关于健康事工的？');
  check('怀爱伦健康事工回答非人工', a7.needsHuman == false);
  check('怀爱伦健康事工回答有引用', a7.citations.isNotEmpty);
  check('怀爱伦健康事工答到服务真诠', a7.answerZh.contains('服务真诠'));
  check('怀爱伦健康事工答到医疗布道', a7.answerZh.contains('医疗布道'));
  check('怀爱伦健康事工答无 CUV', a7.citations.every((c) => !c.isCuv));

  print('== 覆盖率门控：跨主题问句不硬答 ==');
  // 「安息日和洗礼有什么区别」同时含两个主题，任何单条目覆盖率仅 0.5，
  // 必须转人工/RAG 而不是挑一个主题硬答。
  final a8 = logic.answer('安息日和洗礼有什么区别');
  check('跨主题问句转人工', a8.needsHuman == true);

  print('== FAQ 命中（怀爱伦儿童教育著作，v49 修复答非所问）==');
  // 用户实测案例：问「怀爱伦的著作中哪些是关于儿童教育的？」
  // 旧数据只有健康条目持「怀爱伦的著作」，本问句切出概念
  // {怀爱伦的著作, 儿童教育} -> 健康条目覆盖率仅 0.5，未过门控转人工。
  // v49 新增条目 A 同时持这两个关键词 -> 覆盖率 1.0 直接回答。
  final a9 = logic.answer('怀爱伦的著作中哪些是关于儿童教育的？');
  check('儿童教育原句非人工', a9.needsHuman == false);
  check('儿童教育原句有引用', a9.citations.isNotEmpty);
  check('儿童教育原句答到教育论', a9.answerZh.contains('教育论'));
  check('儿童教育原句答到儿童教育指南', a9.answerZh.contains('儿童教育指南'));
  check('儿童教育原句无 CUV', a9.citations.every((c) => !c.isCuv));

  // 变体：裸「怀爱伦」+ 概念（靠条目 A 的「怀爱伦」关键词拿到覆盖率 1.0）
  final a10 = logic.answer('怀爱伦关于儿童教育的著作');
  check('儿童教育变体(裸怀爱伦)非人工', a10.needsHuman == false);
  check('儿童教育变体答到教育论', a10.answerZh.contains('教育论'));

  print('== FAQ 命中（怀爱伦著作总览，v49 新条目）==');
  // 旧数据「怀著/著作」等通用词由健康条目持有 -> 通用问句被健康答案抢答。
  // v49 健康条目瘦身为健康专用，总览条目 C 接管通用问句（插在健康条目前赢并列）。
  final a11 = logic.answer('怀著有哪些');
  check('怀著有哪些非人工', a11.needsHuman == false);
  check('怀著有哪些答到历代愿望', a11.answerZh.contains('历代愿望'));
  check('怀著有哪些答到善恶之争', a11.answerZh.contains('善恶之争'));
  check('怀著有哪些无 CUV', a11.citations.every((c) => !c.isCuv));
  final a12 = logic.answer('从哪本开始读怀著');
  check('怀著入门问句非人工', a12.needsHuman == false);
  check('怀著入门答到喜乐的密码', a12.answerZh.contains('喜乐的密码'));

  print('== FAQ 命中（幼儿奉献礼，v49 新条目）==');
  // 严禁裸词「奉献」（会撞 #24 十一奉献）；奉献礼系词只进新条目。
  final a13 = logic.answer('幼儿奉献礼是什么意思');
  check('幼儿奉献礼非人工', a13.needsHuman == false);
  check('幼儿奉献礼答到哈拿', a13.answerZh.contains('哈拿'));
  check('幼儿奉献礼不答十一奉献', !a13.answerZh.contains('十一奉献'));
  // 回归：#24 十一奉献不被奉献礼条目抢答
  final a14 = logic.answer('十一奉献是什么意思');
  check('十一奉献回归非人工', a14.needsHuman == false);
  check('十一奉献回归答到十分之一', a14.answerZh.contains('十分之一'));

  print('== 修复：家庭祭坛问句不再命中夫妻吵架条目（v49）==');
  // 旧数据「家庭祭坛/家庭敬拜/亲子祷告」系词由 idx113 夫妻吵架条目持有，
  // 问家庭祭坛会得到吵架答案（答非所问）。v49 将这些词移交家庭敬拜条目。
  final a15 = logic.answer('家庭祭坛怎么搞');
  check('家庭祭坛问句非人工', a15.needsHuman == false);
  check('家庭祭坛答到家庭敬拜', a15.answerZh.contains('敬拜'));
  check('家庭祭坛不再答到吵架', !a15.answerZh.contains('吵架'));
  // 回归：夫妻祷告仍由吵架条目回答
  final a16 = logic.answer('夫妻一起祷告好吗');
  check('夫妻祷告回归命中吵架条目', a16.needsHuman == false && a16.answerZh.contains('冷战'));

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
