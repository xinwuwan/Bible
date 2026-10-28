// disease_library_page_test.dart
// v63：疾病知识库从医药布道页拆为独立导航页后，单独覆盖其渲染与检索。
import 'package:faith_compare_app/consult_models.dart';
import 'package:faith_compare_app/disease_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.runAsync(() => ConsultData.load());
  await tester.pumpWidget(const MaterialApp(home: DiseaseLibraryPage()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('疾病知识库独立页：标题 + 内联说明 + 默认展示全部病种计数',
      (tester) async {
    await _pumpPage(tester);
    expect(find.text('疾病知识库'), findsOneWidget);
    // 无外部链接声明
    expect(find.textContaining('所有解读均在本页内联展开，无外部链接'),
        findsOneWidget);

    // 规模达到预期（>= 80 种）
    final text =
        tester.widget<Text>(find.textContaining('共收录')).data ?? '';
    expect(text.contains('共收录'), true);
    final n =
        int.tryParse(RegExp(r'\d+').firstMatch(text)?.group(0) ?? '0') ?? 0;
    expect(n, greaterThanOrEqualTo(80), reason: '知识库规模: $text');
  });

  testWidgets('检索孤立性纤维性肿瘤并内联展开完整解读', (tester) async {
    await _pumpPage(tester);

    final search = find.byWidgetPredicate((w) =>
        w is TextField &&
        (w.decoration?.hintText ?? '').contains('检索疾病'));
    expect(search, findsOneWidget);
    await tester.enterText(search, '孤立性纤维性肿瘤');
    await tester.pumpAndSettle();

    expect(find.text('孤立性纤维性肿瘤'), findsWidgets);
    expect(find.textContaining('找到 1 种疾病'), findsOneWidget);

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
    expect(find.textContaining('不构成诊疗建议'), findsOneWidget);

    await tester.tap(find.text('收起 ▲'));
    await tester.pumpAndSettle();
    expect(find.text('怎么形成的（形成机制与诱因）'), findsNothing);
  });

  testWidgets('分类筛选可用', (tester) async {
    await _pumpPage(tester);
    // 找一个分类 chip（形如「肿瘤 N」），点击后应显示「找到」
    final chip = find.byWidgetPredicate((w) =>
        w is ChoiceChip &&
        w.label is Text &&
        ((w.label as Text).data ?? '').contains('肿瘤'));
    if (chip.evaluate().isNotEmpty) {
      await tester.tap(chip.first);
      await tester.pumpAndSettle();
      expect(find.textContaining('找到'), findsOneWidget);
    }
  });

  testWidgets('疾病知识库页零外部链接按钮', (tester) async {
    await _pumpPage(tester);
    // v57 起：移除百度检索外链按钮
    expect(find.byIcon(Icons.travel_explore), findsNothing);
    expect(find.textContaining('检索权威医学科普（百度健康等）'), findsNothing);
  });
}
