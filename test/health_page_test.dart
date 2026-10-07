// test/health_page_test.dart
// 模块 C 健康首页 / 支柱详情页的 widget 测试
// 重点验证：医学审核闸门（未审条目不得露出）、预览开关、打卡闭环

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faith_compare_app/health_page.dart';
import 'package:faith_compare_app/health_repository.dart';

Widget _app(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('健康首页展示八支柱与医疗免责声明', (tester) async {
    await tester.pumpWidget(
        _app(HealthPage(repo: MockHealthRepository(), userId: 'u1')));
    await tester.pumpAndSettle();

    expect(find.text('健康 · NEWSTART'), findsOneWidget);
    for (final name in ['营养', '运动', '水', '阳光', '节制', '空气', '休息', '信靠']) {
      expect(find.text(name), findsWidgets, reason: '应展示支柱：$name');
    }
    expect(find.textContaining('不替代专业医疗诊断'), findsWidgets);
  });

  testWidgets('进入支柱详情页：未过医学审核的条目被闸门拦截', (tester) async {
    await tester.pumpWidget(
        _app(HealthPage(repo: MockHealthRepository(), userId: 'u1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('营养').first);
    await tester.pumpAndSettle();

    // 已审条目正常展示
    expect(find.text('以植物性食物为日常饮食基础'), findsOneWidget);
    // 未审条目不得出现（Go/No-Go 否决项：未审健康条目漏出）
    expect(find.text('示例：待审核条目'), findsNothing);
    // 且明确告知用户有多少条被拦下
    expect(find.textContaining('未通过医学审核'), findsWidgets);
    // 权威依据区可见
    expect(find.textContaining('GEN 1:29'), findsWidgets);
  });

  testWidgets('预览模式：未审核条目可见并带内部预览徽标', (tester) async {
    await tester.pumpWidget(_app(HealthPage(
      repo: MockHealthRepository(),
      userId: 'u1',
      previewMode: true, // 仅内部联调
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('营养').first);
    await tester.pumpAndSettle();

    expect(find.text('示例：待审核条目'), findsOneWidget);
    expect(find.text('内部预览：本条尚未通过医学审核'), findsOneWidget);
  });

  testWidgets('打卡：填写指标后可保存', (tester) async {
    final repo = MockHealthRepository();
    await tester
        .pumpWidget(_app(HealthPage(repo: repo, userId: 'u1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('营养').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('打卡').last); // FAB（AppBar 也有图标按钮）
    await tester.pumpAndSettle();

    expect(find.text('保存打卡'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '6');
    await tester.tap(find.text('保存打卡'));
    await tester.pumpAndSettle();

    expect(find.text('打卡已保存'), findsOneWidget);
    expect(repo.logs.length, 1);
    expect(repo.logs.first.value, '6');
    expect(repo.logs.first.topicCode, 'NUT');
  });

  testWidgets('无数据时给出空态而非崩溃', (tester) async {
    await tester.pumpWidget(_app(HealthPage(
      repo: MockHealthRepository(topics: const [], metrics: const []),
      userId: 'u1',
    )));
    await tester.pumpAndSettle();

    expect(find.text('暂无健康内容'), findsOneWidget);
  });
}
