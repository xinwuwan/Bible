// consult_hub_page_test.dart
// v55：专业咨询整合模块（原两个平铺入口合并为一个模块）的渲染测试。
// 只验 Hub 页自身：标题、两张功能卡、流程步骤、合规文案。
// 不测点击导航——子页 initState 有异步资源加载，沙箱 pumpAndSettle 不稳定，
// 且导航就是标准 Navigator.push（analyze 已保证类型正确）。
import 'package:faith_compare_app/consult_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('专业咨询整合模块：一张总入口卡 + 两个子功能卡', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ConsultHubPage()));
    await tester.pump();

    // 标题
    expect(find.text('专业咨询'), findsOneWidget);

    // 模块说明（整合 + 合规）
    expect(find.textContaining('两项能力放在同一个模块'), findsOneWidget);
    // 「不替代医生」出现 3 次：模块说明 + 两张卡副标题
    expect(find.textContaining('不替代医生'), findsNWidgets(3));

    // 子功能卡 1：材料核验
    expect(find.text('材料核验 · 医药布道'), findsOneWidget);
    expect(find.textContaining('上传病历 / 报告'), findsOneWidget);
    expect(find.textContaining('分级与多家一致性核验'), findsOneWidget);

    // 子功能卡 2：多轮问诊
    expect(find.text('AI 医生 · 多轮问诊'), findsOneWidget);
    expect(find.textContaining('描述主要不适'), findsOneWidget);
    expect(find.textContaining('可能性 + 依据 + 检查建议'), findsOneWidget);

    // 两张卡各自的适用场景标注
    expect(find.textContaining('适用场景'), findsNWidgets(2));
    expect(find.textContaining('已持有病历'), findsOneWidget);
    expect(find.textContaining('说不清是什么问题'), findsOneWidget);

    // 两个进入箭头（每张卡一个）
    expect(find.byIcon(Icons.arrow_forward_ios), findsNWidgets(2));

    // 配合使用小贴士
    expect(find.textContaining('小贴士'), findsOneWidget);
  });
}
