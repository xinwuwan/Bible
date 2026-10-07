// test/verse_compare_card_test.dart
// 模块 A 三栏对照卡片的 widget 测试。
// 覆盖: 三栏徽标/文本、和合本可隐藏、注记 chip 显示与点击回调。
// 运行: flutter test test/verse_compare_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:faith_compare_app/app_models.dart';
import 'package:faith_compare_app/verse_compare_card.dart';

VerseView sampleVerse() => const VerseView(
      verse: 16,
      ref: 'JHN 3:16',
      kjvText: 'For God so loved the world, that he gave his only begotten Son.',
      ourZh: '神爱世人，甚至将他的独生子赐给他们。',
      cuvRefText: '神爱世人，甚至将他的独生子赐给他们。',
    );

Future<void> pumpCard(
  WidgetTester tester, {
  ComparisonNote? note,
  bool showCuv = true,
  VoidCallback? onTapNote,
  double width = 800,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: VerseCompareCard(
              verse: sampleVerse(),
              note: note,
              showCuv: showCuv,
              onTapNote: onTapNote,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('三栏都渲染：权威 / 本应用产出 / 仅参照', (tester) async {
    await pumpCard(tester);
    expect(find.text('权威'), findsOneWidget);
    expect(find.text('本应用产出'), findsOneWidget);
    expect(find.text('仅参照·非权威'), findsOneWidget);
    expect(find.text('JHN 3:16'), findsOneWidget);
    expect(find.textContaining('For God so loved'), findsOneWidget);
    expect(find.textContaining('神爱世人'), findsWidgets);
  });

  testWidgets('showCuv=false 时隐藏和合本栏', (tester) async {
    await pumpCard(tester, showCuv: false);
    expect(find.text('仅参照·非权威'), findsNothing);
    expect(find.text('权威'), findsOneWidget);
  });

  testWidgets('无注记时不显示注记 chip', (tester) async {
    await pumpCard(tester);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('有 approved 注记时显示类型 chip，点击回调触发', (tester) async {
    var tapped = 0;
    final note = ComparisonNote.fromJson({
      'ref': 'JHN 3:16',
      'diff_type': 'consistent',
      'observation': 'μονογενής 表独一。',
      'basis': '原文词形依据。',
      'conclusion': '实质一致。',
      'status': 'approved',
    });
    await pumpCard(tester, note: note, onTapNote: () => tapped++);

    expect(find.byType(ActionChip), findsOneWidget);
    expect(find.text('实质一致'), findsOneWidget);

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('diff_type 非规范时显示「待规范化」而非臆断类型', (tester) async {
    final note = ComparisonNote.fromJson({
      'ref': 'JHN 3:16',
      'diff_type': 'wording', // 不在 DDL CHECK 枚举内
      'observation': '…',
      'basis': '…',
      'status': 'approved',
    });
    await pumpCard(tester, note: note);
    expect(find.text('待规范化'), findsOneWidget);
    expect(find.text('实质一致'), findsNothing);
  });

  testWidgets('译文缺失时显示待补充占位', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: VerseCompareCard(
              verse: const VerseView(
                verse: 1,
                ref: 'GEN 1:1',
                kjvText: 'In the beginning God created the heaven and the earth.',
                ourZh: null,
              ),
              showCuv: false,
            ),
          ),
        ),
      ),
    );
    expect(find.text('（译文待补充）'), findsOneWidget);
  });
}
