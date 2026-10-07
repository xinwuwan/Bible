// test/search_page_test.dart
// 检索页 widget 测试：中英文检索（Dart 侧实现，CJK 逐字分词）+ 结果点击回传跳转定位。
// 运行: flutter test test/search_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:faith_compare_app/offline_db_helper.dart';
import 'package:faith_compare_app/search_page.dart';
import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await OfflineDbHelper.load(buildTestDataJson());
  });

  tearDown(() {
    OfflineDbHelper.close();
  });

  Future<void> pumpSearch(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: const SearchPage())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('初始态显示引导文案', (tester) async {
    await pumpSearch(tester);
    expect(find.textContaining('输入关键词后回车检索'), findsOneWidget);
  });

  testWidgets('英文检索命中（God）', (tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField).first, 'God');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('GEN 1:1'), findsWidgets);
    expect(find.text('JHN 3:16'), findsWidgets);
  });

  testWidgets('中文检索命中（神，验证 CJK 逐字分词索引）', (tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField).first, '神');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // 若 FTS5 未对中文建索引（未做逐字空格分词），这里会命中 0 条
    expect(find.text('JHN 3:16'), findsWidgets);
  });

  testWidgets('无结果时给出空态', (tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField).first, 'zzzznotexist');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('没有匹配的经文'), findsOneWidget);
  });

  testWidgets('点击结果回传章节定位（bookId + chapter）', (tester) async {
    final captured = <Map<String, dynamic>?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              final r = await Navigator.of(ctx).push<Map<String, dynamic>>(
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
              captured.add(r);
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'God');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.text('JHN 3:16').first);
    await tester.pumpAndSettle();

    expect(captured.length, 1);
    expect(captured.single?['chapter'], 3);
    expect(captured.single?['name'], '约翰福音');
  });
}
