// health_consult_page_test.dart
// v57：医药布道页测试——材料自动识别填写提示、综合参考报告零外链。
// v58：上传诊断证明图片 → OCR 转录 → 自动填写表单的链路测试
// （用户实报：上传图片后四个字段全空、未自动识别）。
// v63：附件改为「批量入列 + 统一识别」流程——图片先入列（待识别），
// 点「统一识别与分析」后批量 OCR 并从合并文本统一提取诊断；txt 入列即读取。
// 疾病知识库已拆为独立页（disease_library_page_test.dart 单独覆盖）。
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

/// 点「统一识别与分析（N）」按钮（v63 批量 OCR 入口；真实用户流程）
/// 按钮文案带数量括号，用包含「统一识别与分析（」定位其标签文本并直接点按
/// （文本处于按钮可点区域内，点按即触发 onPressed）。
Future<void> _tapAnalyzeAll(WidgetTester tester) async {
  final label = find.textContaining('统一识别与分析（');
  expect(label, findsOneWidget, reason: '未找到「统一识别与分析（N）」按钮');
  await tester.tap(label);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('医药布道页：场景横幅 + 合规横幅 + 三个板块标题（疾病库已拆出）',
      (tester) async {
    await _pumpPage(tester);

    expect(find.text('专业咨询 · 医药布道'), findsOneWidget);
    // 适用场景横幅（v56 加入）
    expect(find.textContaining('已持有病历'), findsOneWidget);
    // 合规横幅
    expect(find.textContaining('不诊断、不替代医生'), findsOneWidget);
    // 板块①（首屏可见）
    expect(find.textContaining('① 上传材料 / 填写关键信息'), findsOneWidget);
    // ② 在屏外，滚动后再断言
    await _scrollTo(tester, find.textContaining('② 材料级别核验'));
    expect(find.textContaining('② 材料级别核验'), findsOneWidget);
    // ③ 综合参考报告：未提交前不显示
    expect(find.textContaining('③ 综合参考报告'), findsNothing);
    // v63：疾病知识库已从本页拆出，本页不应再内联展示知识库浏览器
    expect(find.textContaining('共收录'), findsNothing);
    expect(find.textContaining('④ 疾病知识库'), findsNothing);
  });

  testWidgets('多文件上传入口可见，文案提示可多选', (tester) async {
    await _pumpPage(tester);
    // 选附件按钮（提示可多选）
    expect(find.textContaining('选择附件（可多选）'), findsOneWidget);
    // 多文件说明
    expect(find.textContaining('可一次选择多份材料'), findsOneWidget);
  });

  testWidgets('上传多份图片 → 统一识别与分析 → 合并文本提取诊断/医院',
      (tester) async {
    // mock OCR 转录（模拟两份报告首页 + 次页）
    ConsultOcr.fetcherForTest = (bytes, mime) async {
      // 用字节长度区分两张图（测试用伪字节）
      if (bytes.length == 3) {
        return 'XX市中心医院\n诊断证明书\n临床诊断：2型糖尿病\n'
            '主诉：多饮、多尿、体重下降 3 月余';
      }
      return 'XX市中心医院\n出院小结（续）\n复查空腹血糖 8.6 mmol/L';
    };
    addTearDown(() => ConsultOcr.fetcherForTest = null);

    await _pumpPage(tester);
    final page = tester.state(find.byType(HealthConsultPage)) as dynamic;

    // 模拟一次选多份（页面只暴露单文件注入，循环调用等价于多选）
    await page.addAttachment('诊断证明.jpg', Uint8List.fromList([1, 2, 3]));
    await page.addAttachment('出院小结.jpg', Uint8List.fromList([9, 9]));
    await tester.pumpAndSettle();

    // 两张图片均为「待识别」，按钮显示待识别数量（2）
    expect(find.textContaining('待识别'), findsNWidgets(2));
    expect(find.textContaining('统一识别与分析（2）'), findsOneWidget);

    // 点「统一识别与分析」批量 OCR
    await _tapAnalyzeAll(tester);

    // 附件升级为「已识别文字」（不再是「请手动誊写」）
    expect(find.textContaining('已识别文字'), findsNWidgets(2));
    expect(find.textContaining('请手动誊写'), findsNothing);

    // 自动填写横幅：说明填了什么、要求核实
    expect(find.textContaining('已根据材料自动识别并填入'), findsOneWidget);
    expect(find.textContaining('请逐项核实修改后再核验'), findsOneWidget);

    // 合并两份文本后，诊断与医院均被提取（取首份主诊断）
    expect(_ctrlOf(tester, '诊断名称').text, '2型糖尿病');
    expect(_ctrlOf(tester, '医院名称').text, 'XX市中心医院');
  });

  testWidgets('上传诊断证明图片 → 统一识别 → 自动填写表单并标注待核实',
      (tester) async {
    ConsultOcr.fetcherForTest = (bytes, mime) async => 'XX市中心医院\n'
        '诊断证明书\n'
        '临床诊断：2型糖尿病\n'
        '主诉：多饮、多尿、体重下降 3 月余';
    addTearDown(() => ConsultOcr.fetcherForTest = null);

    await _pumpPage(tester);
    final page = tester.state(find.byType(HealthConsultPage)) as dynamic;
    await page.addAttachment('诊断证明.jpg', Uint8List.fromList([1, 2, 3]));
    await tester.pumpAndSettle();

    // 入列后为「待识别」，按钮出现
    expect(find.textContaining('待识别'), findsOneWidget);
    expect(find.textContaining('统一识别与分析（1）'), findsOneWidget);

    // 点「统一识别与分析」
    await _tapAnalyzeAll(tester);

    // 附件 chip：已识别文字（不再是「请手动誊写」）
    expect(find.textContaining('已识别文字'), findsOneWidget);
    expect(find.textContaining('请手动誊写'), findsNothing);

    // 自动填写横幅：说明填了什么、要求核实
    expect(find.textContaining('已根据材料自动识别并填入'), findsOneWidget);
    expect(find.textContaining('请逐项核实修改后再核验'), findsOneWidget);

    // 字段被自动填写
    expect(_ctrlOf(tester, '诊断名称').text, '2型糖尿病');
    expect(_ctrlOf(tester, '医院名称').text, 'XX市中心医院');
    expect(_ctrlOf(tester, '病人症状与病史描述').text, contains('多饮'));

    // 自动填入的字段带「已自动识别」标记（绿星标 + helperText）
    expect(find.byIcon(Icons.auto_awesome), findsWidgets);
    expect(find.textContaining('根据材料自动填入，请核实后再提交'), findsWidgets);
  });

  testWidgets('上传图片 OCR 失败 → 保留手动誊写提示、不自动填写', (tester) async {
    ConsultOcr.fetcherForTest = (bytes, mime) async => null;
    addTearDown(() => ConsultOcr.fetcherForTest = null);

    await _pumpPage(tester);
    final page = tester.state(find.byType(HealthConsultPage)) as dynamic;
    await page.addAttachment('报告.jpg', Uint8List.fromList([9]));
    await tester.pumpAndSettle();

    // 入列后待识别
    expect(find.textContaining('待识别'), findsOneWidget);

    // 点「统一识别与分析」
    await _tapAnalyzeAll(tester);

    expect(find.textContaining('识别失败，请手动誊写'), findsOneWidget);
    expect(find.textContaining('已根据材料自动识别并填入'), findsNothing);
    // 表单保持空白
    expect(_ctrlOf(tester, '诊断名称').text, '');
    expect(_ctrlOf(tester, '医院名称').text, '');
  });

  testWidgets('上传 txt 不走 OCR、直接读取并自动填写', (tester) async {
    ConsultOcr.fetcherForTest = (bytes, mime) async => '不应被调用';
    addTearDown(() => ConsultOcr.fetcherForTest = null);

    await _pumpPage(tester);
    final page = tester.state(find.byType(HealthConsultPage)) as dynamic;
    final txt = '门诊病历\n诊断：急性支气管炎\n主诉：咳嗽 5 天';
    await page.addAttachment('病历.txt', Uint8List.fromList(utf8.encode(txt)));
    await tester.pumpAndSettle();

    expect(find.textContaining('已识别文字'), findsOneWidget);
    expect(_ctrlOf(tester, '诊断名称').text, '急性支气管炎');
    expect(find.textContaining('识别失败'), findsNothing);
    // 文本类无需统一识别，不应出现「统一识别与分析（N）」按钮
    expect(find.textContaining('统一识别与分析（'), findsNothing);
  });

  // v60：修正「诊断证明书」被误抓为「证明书」导致主诊断失效、知识库误报「未收录」
  testWidgets('材料含「诊断证明书」时主诊断应选真实疾病并命中知识库', (tester) async {
    await _pumpPage(tester); // 预加载 ConsultData.diseases

    const material = '首都医科大学三博脑科医院\n'
        '诊断证明书\n'
        '姓名：马玉梅\n'
        '诊断：孤立性纤维性肿瘤（额、顶部）\n'
        '免疫组化：STAT6 阳性';
    final r = ConsultData.verify(materialText: material, symptoms: '');

    expect(r.primaryDiagnosis, isNot(equals('证明书')));
    expect(r.primaryDiagnosis, contains('孤立性纤维性肿瘤'));
    final profile = ConsultData.findProfile(r.primaryDiagnosis);
    expect(profile, isNotNull);
    expect(profile!.id, equals('sft'));
    expect(r.consistent, isTrue);
  });

  // v61：医药布道建议须给出可量化执行标准
  testWidgets('医药布道建议随每条建议展示可量化执行标准', (tester) async {
    ConsultOcr.fetcherForTest = (bytes, mime) async => '不应被调用';
    addTearDown(() => ConsultOcr.fetcherForTest = null);

    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpPage(tester);
    final page = tester.state(find.byType(HealthConsultPage)) as dynamic;
    final txt = 'XX市第一医院\nYY大学医学院附属第二医院\n'
        '门诊病历\n诊断：偏头痛\n主诉：反复头痛 2 月';
    await page.addAttachment(
        '病历.txt', Uint8List.fromList(utf8.encode(txt)));
    await tester.pumpAndSettle();

    expect(_ctrlOf(tester, '诊断名称').text, contains('偏头痛'));
    expect(_ctrlOf(tester, '医院名称').text, isNotEmpty);

    await tester.tap(find.text('核验材料'));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.textContaining('③ 综合参考报告'));
    expect(find.textContaining('③ 综合参考报告'), findsOneWidget);

    await _scrollTo(tester, find.text('医药布道建议（怀著 · NEWSTART）'));
    expect(find.text('医药布道建议（怀著 · NEWSTART）'), findsOneWidget);

    await _scrollTo(tester, find.text('可量化执行标准').first);
    expect(find.text('可量化执行标准'), findsWidgets);
    expect(find.textContaining('≥150分钟'), findsWidgets);
  });
}

TextEditingController _ctrlOf(WidgetTester tester, String labelPart) {
  final f = find.byWidgetPredicate((w) =>
      w is TextField &&
      (w.decoration?.labelText ?? '').contains(labelPart));
  expect(f, findsOneWidget, reason: '找不到字段：$labelPart');
  return tester.widget<TextField>(f).controller!;
}
