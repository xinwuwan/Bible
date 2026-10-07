// test/comparison_page_test.dart
// 模块 A 对照页 widget 测试：章节读取、注记 chip、draft 过滤、注记详情弹层。
// 运行: flutter test test/comparison_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:faith_compare_app/app_models.dart';
import 'package:faith_compare_app/comparison_page.dart';
import 'package:faith_compare_app/note_repository.dart';
import 'package:faith_compare_app/offline_db_helper.dart';
import 'helpers/test_db.dart';

void main() {
  late String dbPath;

  setUp(() {
    dbPath = buildTempOfflineDb();
    OfflineDbHelper.openPathForTest(dbPath);
  });

  tearDown(() {
    OfflineDbHelper.close();
    deleteTempDb(dbPath);
  });

  Widget buildPage({
    required NoteRepository notes,
    bool draftMode = false,
  }) =>
      MaterialApp(
        home: ComparisonPage(
          bookId: 2, // JHN
          bookName: '约翰福音',
          chapterCount: 21,
          initialChapter: 3,
          notes: notes,
          draftMode: draftMode,
        ),
      );

  testWidgets('读取本章经文（离线库）', (tester) async {
    await tester.pumpWidget(buildPage(notes: const InMemoryNoteRepository([])));
    await tester.pumpAndSettle();

    expect(find.text('JHN 3:16'), findsOneWidget);
    expect(find.textContaining('For God so loved'), findsOneWidget);
    expect(find.textContaining('神爱世人'), findsWidgets);
  });

  testWidgets('approved 注记显示类型 chip，点击展开详情', (tester) async {
    final note = ComparisonNote.fromJson({
      'ref': 'JHN 3:16',
      'diff_type': 'consistent',
      'observation': 'μονογενής 表“独一”。',
      'basis': '希腊原文 μονογενής。',
      'conclusion': '实质一致。',
      'status': 'approved',
    });
    await tester.pumpWidget(buildPage(notes: InMemoryNoteRepository([note])));
    await tester.pumpAndSettle();

    expect(find.text('实质一致'), findsOneWidget);

    await tester.tap(find.text('实质一致'));
    await tester.pumpAndSettle();

    // 弹层内容
    expect(find.text('依据（必填）'), findsOneWidget);
    expect(find.text('希腊原文 μονογενής。'), findsOneWidget);
    expect(find.textContaining('和合本仅作参照展示'), findsOneWidget);
  });

  testWidgets('draft 注记默认不展示（合规闸门）', (tester) async {
    final draft = ComparisonNote.fromJson({
      'ref': 'JHN 3:16',
      'diff_type': 'consistent',
      'observation': '…',
      'basis': '…',
      'status': 'draft',
    });
    await tester.pumpWidget(buildPage(notes: InMemoryNoteRepository([draft])));
    await tester.pumpAndSettle();

    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('JHN 3:16'), findsOneWidget);
  });

  testWidgets('draftMode=true 时 draft 注记可见且标草稿', (tester) async {
    final draft = ComparisonNote.fromJson({
      'ref': 'JHN 3:16',
      'diff_type': 'consistent',
      'observation': '…',
      'basis': '…',
      'status': 'draft',
      'author': 'pilot-draft(AI)',
    });
    await tester.pumpWidget(
      buildPage(notes: InMemoryNoteRepository([draft]), draftMode: true),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('草稿'), findsOneWidget);
  });

  testWidgets('注记加载失败时降级：经文仍可读', (tester) async {
    await tester.pumpWidget(buildPage(notes: _ThrowingNoteRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('注记加载失败'), findsOneWidget);
    expect(find.text('JHN 3:16'), findsOneWidget); // 经文不受影响
  });
}

/// 模拟注记接口异常，验证降级路径
class _ThrowingNoteRepository implements NoteRepository {
  @override
  Future<List<ComparisonNote>> fetchForRefs(List<String> refs,
      {bool includeDraft = false}) async {
    throw Exception('mock failure');
  }
}
