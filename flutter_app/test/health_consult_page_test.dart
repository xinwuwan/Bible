// health_consult_page_test.dart
// v57：医药布道页测试——材料自动识别填写提示、疾病知识库内联检索、
// 综合参考报告零外链（用户明确要求：所有信息当前页查看、无外部网址跳转）。
// v58：上传诊断证明图片 → OCR 转录 → 自动填写表单的链路测试
// （用户实报：上传图片后四个字段全空、未自动识别）。
import 'dart:convert';
import 'dart:typed_data';

import 'package:faith_compare_app/consult_models.dart';
import 'package:faith_compare_app/consult_ocr.dart';
import 'package:faith_compare_app/health_consult_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpPage(WidgetTester tester) async {
  // 预加载静态数据（ConsultData 静态缓存，加载后页面直接渲染）
  await tester.runAsync(() => ConsultData.load());
  await tester.pumpWidget(const MaterialApp(home: HealthConsultPage()));
  await tester.pumpAndSettle();
}

/// 滚动到可见（ListView 懒加载，屏外内容需滚动后才构建）
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 400,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('医药布道页：场景横幅 + 合规横幅 + 四个板块标题', (tester) async {
    await _pumpPage(tester);

    expect(find.text('专业咨询 · 医药布道'), findsOneWidget);
    // 适用场景横幅（v56 加入）
    expect(find.textContaining('已持有病历'), findsOneWidget);
    // 合规横幅
    expect(find.textContaining('不诊断、不替代医生'), findsOneWidget);
    // 板块①（首屏可见）
    expect(find.textContaining('① 上传材料 / 填写关键信息'), findsOneWidget);
    // ②/④ 在屏外，分别滚动后再断言
    await _scrollTo(tester, find.textContaining('② 材料级别核验'));
    expect(find.textContaining('② 材料级别核验'), findsOneWidget);
    await _scrollTo(tester, find.textContaining('④ 疾病知识库'));
    expect(find.textContaining('④ 疾病知识库'), findsOneWidget);
    // 未提交前不显示综合报告
    expect(find.textContaining('③ 综合参考报告'), findsNothing);
  });

  testWidgets('疾病知识库：默认展示全部病种计数', (tester) async {
    await _pumpPage(tester);
    await _scrollTo(tester, find.textContaining('④ 疾病知识库'));
    expect(find.textContaining('共收录'), findsOneWidget);
    // 规模达到 v57 预期（>= 80 种）
    final text = tester.widget<Text>(find.textContaining('共收录')).data ?? '';
    expect(text.contains('共收录'), true);
    final n = int.tryParse(RegExp(r'\d+').firstMatch(text)?.group(0) ?? '0') ?? 0;
    expect(n, greaterThanOrEqualTo(80), reason: '知识库规模: $text');
  });

  testWidgets('疾病知识库：检索孤立性纤维性肿瘤并内联展开完整解读', (tester) async {
    await _pumpPage(tester);
    await _scrollTo(tester, find.textContaining('④ 疾病知识库'));

    // 输入检索词
    final search = find.byWidgetPredicate((w) =>
        w is TextField &&
        (w.decoration?.hintText ?? '').contains('检索疾病'));
    expect(search, findsOneWidget);
    await tester.enterText(search, '孤立性纤维性肿瘤');
    await tester.pumpAndSettle();

    // 命中卡片（病名同时出现在检索输入框与结果卡片，放宽为 findsWidgets）
    expect(find.text('孤立性纤维性肿瘤'), findsWidgets);
    expect(find.textContaining('找到 1 种疾病'), findsOneWidget);

    // 展开完整解读（本页内联，无跳转）
    await tester.tap(find.text('展开完整解读 ▼'));
    await tester.pumpAndSettle();

    expect(find.text('怎么形成的（形成机制与诱因）'), findsOneWidget);
    expect(find.text('对身体健康的影响'), findsOneWidget);
    expect(find.text('需要排除的疾病'), findsOneWidget);
    expect(find.text('建议进一步检查'), findsOneWidget);
    expect(find.text('出现这些情况，请尽快就医'), findsOneWidget);
    expect(find.text('权威来源（文本引用，无外部链接）'), findsOneWidget);
    expect(find.textContaining('世界卫生组织（WHO）软组织与骨肿瘤分类'),
        findsOneWidget);
    // 免责
    expect(find.textContaining('不构成诊疗建议'), findsOneWidget);

    // 收起
    await tester.tap(find.text('收起 ▲'));
    await tester.pumpAndSettle();
    expect(find.text('怎么形成的（形成机制与诱因）'), findsNothing);
  });

  testWidgets('疾病知识库：分类筛选可用', (tester) async {
    await _pumpPage(tester);
    await _scrollTo(tester, find.textContaining('④ 疾病知识库'));
    // 肿瘤分类 chip
    final tumorChip = find.text('肿瘤 16');
    if (tumorChip.evaluate().isNotEmpty) {
      await tester.tap(tumorChip);
      await tester.pumpAndSettle();
      expect(find.textContaining('找到'), findsOneWidget);
    }
  });

  testWidgets('医药布道模块全页零外部链接按钮', (tester) async {
    await _pumpPage(tester);
    await _scrollTo(tester, find.textContaining('④ 疾病知识库'));
    // v57 起：移除百度检索外链按钮
    expect(find.byIcon(Icons.travel_explore), findsNothing);
    expect(find.textContaining('检索权威医学科普（百度健康等）'), findsNothing);
  });

  // ---- v58：上传图片 → OCR → 自动填写 ----

  TextEditingController _ctrlOf(WidgetTester tester, String labelPart) {
    final f = find.byWidgetPredicate((w) =>
        w is TextField &&
        (w.decoration?.labelText ?? '').contains(labelPart));
    expect(f, findsOneWidget, reason: '找不到字段：$labelPart');
    return tester.widget<TextField>(f).controller!;
  }

  testWidgets('上传诊断证明图片 → OCR 成功 → 自动填写表单并标注待核实', (tester) async {
    // mock OCR 转录（模拟后端返回的诊断证明全文）
    ConsultOcr.fetcherForTest = (bytes, mime) async => 'XX市中心医院\n'
        '诊断证明书\n'
        '临床诊断：2型糖尿病\n'
        '主诉：多饮、多尿、体重下降 3 月余';
    addTearDown(() => ConsultOcr.fetcherForTest = null);

    await _pumpPage(tester);
    final page = tester.state(find.byType(HealthConsultPage)) as dynamic;
    await page.attachAndOcr('诊断证明.jpg', Uint8List.fromList([1, 2, 3]));
    await tester.pumpAndSettle();

    // 附件 chip：已识别文字（不再是「请手动誊写」）
    expect(find.textContaining('已识别文字'), findsOneWidget);
    expect(find.textContaining('请手动誊写'), findsNothing);

    // 自动填写横幅：说明填了什么、要求核实
    expect(find.textContaining('已根据材料自动识别并填入'), findsOneWidget);
    expect(find.textContaining('请逐项核实修改后再核验'), findsOneWidget);

    // 四个字段被自动填写
    expect(_ctrlOf(tester, '诊断名称').text, '2型糖尿病');
    expect(_ctrlOf(tester, '医院名称').text, 'XX市中心医院');
    expect(_ctrlOf(tester, '病人症状与病史描述').text, contains('多饮'));

    // 自动填入的字段带「已自动识别」标记（绿星标 + helperText）
    expect(find.byIcon(Icons.auto_awesome), findsWidgets);
    expect(find.textContaining('根据材料自动填入，请核实后再提交'), findsWidgets);
  });

  testWidgets('上传图片 OCR 失败 → 保留手动誊写提示、不自动填写', (tester) async {
    // OCR 不可用（网络失败/服务关闭）时应退回手动誊写，不阻塞流程
    ConsultOcr.fetcherForTest = (bytes, mime) async => null;
    addTearDown(() => ConsultOcr.fetcherForTest = null);

    await _pumpPage(tester);
    final page = tester.state(find.byType(HealthConsultPage)) as dynamic;
    await page.attachAndOcr('报告.jpg', Uint8List.fromList([9]));
    await tester.pumpAndSettle();

    expect(find.textContaining('识别失败，请手动誊写'), findsOneWidget);
    expect(find.textContaining('已根据材料自动识别并填入'), findsNothing);
    // 表单保持空白
    expect(_ctrlOf(tester, '诊断名称').text, '');
    expect(_ctrlOf(tester, '医院名称').text, '');
  });

  testWidgets('上传 txt 不走 OCR、直接读取并自动填写', (tester) async {
    // txt 有本地文本，不应触发 OCR（fetcher 被调用即失败）
    ConsultOcr.fetcherForTest = (bytes, mime) async => '不应被调用';
    addTearDown(() => ConsultOcr.fetcherForTest = null);

    await _pumpPage(tester);
    final page = tester.state(find.byType(HealthConsultPage)) as dynamic;
    final txt = '门诊病历\n诊断：急性支气管炎\n主诉：咳嗽 5 天';
    await page.attachAndOcr(
        '病历.txt', Uint8List.fromList(utf8.encode(txt)));
    await tester.pumpAndSettle();

    expect(find.textContaining('已识别文字'), findsOneWidget);
    expect(_ctrlOf(tester, '诊断名称').text, '急性支气管炎');
    expect(find.textContaining('识别失败'), findsNothing);
  });

  // v60：修正「诊断证明书」被误抓为「证明书」导致主诊断失效、知识库误报「未收录」
  // 真实用户截图案例：材料含「诊断证明书」+「诊断：孤立性纤维性肿瘤（额、顶部）」，
  // 系统必须把真实疾病名选为主诊断并命中知识库，而非把「证明书」当诊断。
  testWidgets('材料含「诊断证明书」时主诊断应选真实疾病并命中知识库', (tester) async {
    await _pumpPage(tester); // 预加载 ConsultData.diseases

    const material = '首都医科大学三博脑科医院\n'
        '诊断证明书\n'
        '姓名：马玉梅\n'
        '诊断：孤立性纤维性肿瘤（额、顶部）\n'
        '免疫组化：STAT6 阳性';
    final r = ConsultData.verify(materialText: material, symptoms: '');

    // 主诊断不得是文档型假阳性「证明书」
    expect(r.primaryDiagnosis, isNot(equals('证明书')));
    expect(r.primaryDiagnosis, contains('孤立性纤维性肿瘤'));
    // 主诊断应能命中知识库 SFT
    final profile = ConsultData.findProfile(r.primaryDiagnosis);
    expect(profile, isNotNull);
    expect(profile!.id, equals('sft'));
    // 干净后的诊断仅一条，不应误报多家不一致
    expect(r.consistent, isTrue);
  });
}
