// test/qa_page_test.dart
// 模块 B 问答页 widget 测试：正常回答 / 引用 / 拦截 / 转人工 / 反馈。
// 运行: flutter test test/qa_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:faith_compare_app/qa_models.dart';
import 'package:faith_compare_app/qa_page.dart';
import 'package:faith_compare_app/qa_repository.dart';

const bible = QaCitation(
  sourceType: QaSourceType.bible,
  sourceId: 'KJV-JHN3:16',
  ref: 'JHN 3:16',
  snippet: 'For God so loved the world...',
);

const cuv = QaCitation(
  sourceType: QaSourceType.bible,
  sourceId: 'CUV-JHN3:16',
  ref: 'JHN 3:16',
  snippet: '神爱世人',
);

MockQaRepository buildRepo() => MockQaRepository(
      scripted: {
        '正常': QaAnswer(
          answerId: 'qa_ok',
          answerZh: '这是有权威依据的回答内容。',
          citations: [bible],
          confidence: 0.85,
          needsHuman: false,
        ),
        '无引用': QaAnswer(
          answerId: 'qa_no_cite',
          answerZh: '不应展示的无来源回答。',
          citations: [],
          confidence: 0.9,
          needsHuman: false,
        ),
        '和合本': QaAnswer(
          answerId: 'qa_cuv',
          answerZh: '引用了和合本的回答，必须被拦截。',
          citations: [cuv],
          confidence: 0.9,
          needsHuman: false,
        ),
        '转人工': QaAnswer(
          answerId: 'qa_human',
          answerZh: '这个问题建议由顾问亲自答复。',
          citations: [],
          confidence: 0.3,
          needsHuman: true,
        ),
      },
    );

Future<MockQaRepository> pumpQa(WidgetTester tester) async {
  final repo = buildRepo();
  await tester.pumpWidget(
    MaterialApp(home: QaPage(repo: repo)),
  );
  return repo;
}

Future<void> ask(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(TextField).first, q);
  await tester.tap(find.byIcon(Icons.send));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('正常回答：显示正文 + 权威依据 + 置信度', (tester) async {
    await pumpQa(tester);
    await ask(tester, '正常');

    expect(find.text('这是有权威依据的回答内容。'), findsOneWidget);
    expect(find.textContaining('权威依据 1 条'), findsOneWidget);
    expect(find.text('KJV-JHN3:16'), findsOneWidget);
    expect(find.textContaining('置信度 85%'), findsOneWidget);
  });

  testWidgets('引用缺失 → 拦截且不展示回答正文', (tester) async {
    await pumpQa(tester);
    await ask(tester, '无引用');

    expect(find.textContaining('已拦截'), findsOneWidget);
    expect(find.textContaining('引用缺失'), findsOneWidget);
    // 关键：无来源的回答正文绝不能露出
    expect(find.text('不应展示的无来源回答。'), findsNothing);
    expect(find.text('转人工顾问'), findsOneWidget);
  });

  testWidgets('citations 含 cuv 前缀 → 拦截', (tester) async {
    await pumpQa(tester);
    await ask(tester, '和合本');

    expect(find.textContaining('已拦截'), findsOneWidget);
    expect(find.textContaining('来源非法'), findsOneWidget);
    expect(find.text('引用了和合本的回答，必须被拦截。'), findsNothing);
  });

  testWidgets('needs_human=true → 显示转人工入口，不列引用', (tester) async {
    await pumpQa(tester);
    await ask(tester, '转人工');

    expect(find.text('这个问题建议由顾问亲自答复。'), findsOneWidget);
    expect(find.text('转人工顾问'), findsOneWidget);
    expect(find.textContaining('权威依据'), findsNothing);
  });

  testWidgets('点赞写入反馈（qa_feedback）', (tester) async {
    final repo = await pumpQa(tester);
    await ask(tester, '正常');

    expect(repo.feedbackLog, isEmpty);
    await tester.tap(find.byIcon(Icons.thumb_up_off_alt));
    await tester.pumpAndSettle();

    expect(repo.feedbackLog.length, 1);
    expect(repo.feedbackLog.first['rating'], 5);
    expect(repo.feedbackLog.first['answer_id'], 'qa_ok');
  });

  testWidgets('点踩弹出补充说明框，取消则不记录', (tester) async {
    final repo = await pumpQa(tester);
    await ask(tester, '正常');

    await tester.tap(find.byIcon(Icons.thumb_down_off_alt));
    await tester.pumpAndSettle();
    expect(find.text('哪里不准确？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repo.feedbackLog, isEmpty);
  });
}
