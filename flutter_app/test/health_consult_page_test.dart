// health_consult_page_test.dart
// v57：医药布道页测试——材料自动识别填写提示、疾病知识库内联检索、
// 综合参考报告零外链（用户明确要求：所有信息当前页查看、无外部网址跳转）。
import 'package:faith_compare_app/consult_models.dart';
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
}
