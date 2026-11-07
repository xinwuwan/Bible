// 输入框回归测试（非 Web 路径；Web 路径由浏览器端 IME 实测覆盖）。
//
// 覆盖：中文正常输入回显、连续逐段输入顺序、修改后重新提交、
//       输入法组合态回车不提交、组合结束后按原顺序完整提交。
// 运行: flutter test test/native_text_field_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:faith_compare_app/native_text_field.dart';

const String kQuestion = '怀爱伦有哪些儿童教育的书籍';

Widget _harness(TextEditingController ctrl, List<String> log) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: NativeTextField(
          controller: ctrl,
          hint: '输入你的问题…',
          onSubmitted: log.add,
        ),
      ),
    ),
  );
}

Future<void> _submit(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pump();
}

/// 让 EditableText 建立测试用 TextInput 连接，之后才能收到 send action。
Future<void> _attach(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), '');
  await tester.pump();
}

void main() {
  // 组合态守卫本身是纯函数，直接断言，不依赖 EditableText 的内部状态机。
  test('shouldSubmitOnEnter：组合态不允许提交，组合结束后允许提交', () {
    const composing = TextEditingValue(
      text: '怀爱伦',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 0, end: 3),
    );
    const settled = TextEditingValue(
      text: '怀爱伦',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange.empty,
    );
    expect(shouldSubmitOnEnter(composing), isFalse);
    expect(shouldSubmitOnEnter(settled), isTrue);
    expect(shouldSubmitOnEnter(TextEditingValue.empty), isTrue);
  });

  testWidgets('中文正常输入：输入框回显全文，回车按原顺序提交', (tester) async {
    final ctrl = TextEditingController();
    final log = <String>[];
    await tester.pumpWidget(_harness(ctrl, log));

    await tester.enterText(find.byType(TextField), kQuestion);
    await tester.pump();

    expect(ctrl.text, kQuestion);
    // EditableText 由 RenderEditable 直接绘制，不用 find.text；
    // 检查挂在输入框上的 controller 即为「回显」的真实来源。
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        kQuestion,
        reason: '输入框必须显示已输入文字');
    await _submit(tester);
    expect(log, [kQuestion]);
  });

  testWidgets('连续逐段输入：每次上屏都追加到末尾，不倒序', (tester) async {
    final ctrl = TextEditingController();
    final log = <String>[];
    await tester.pumpWidget(_harness(ctrl, log));
    await _attach(tester);

    const segments = ['怀爱伦', '有哪些', '儿童', '教育', '的', '书籍'];
    var text = '';
    for (final seg in segments) {
      // 模拟一次 IME 组合 + 上屏：组合态 -> 组合结束。
      final start = text.length;
      text += seg;
      ctrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange(start: start, end: text.length),
      );
      await tester.pump();
      ctrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty,
      );
      await tester.pump();
    }

    expect(ctrl.text, kQuestion);
    expect(ctrl.text, isNot('书籍的教育儿童有哪些怀爱伦'));
    await _submit(tester);
    expect(log, [kQuestion]);
  });

  testWidgets('修改后重新提交：以最新文本为准，不残留上一次内容', (tester) async {
    final ctrl = TextEditingController();
    final log = <String>[];
    await tester.pumpWidget(_harness(ctrl, log));

    await tester.enterText(find.byType(TextField), kQuestion);
    await tester.pump();
    await _submit(tester);
    ctrl.clear();

    const revised = '怀爱伦关于儿童教育的著作有哪些';
    await tester.enterText(find.byType(TextField), revised);
    await tester.pump();
    await _submit(tester);

    expect(log, [kQuestion, revised]);
    expect(ctrl.text, revised);
  });

  testWidgets('输入法组合态回车不提交，组合结束后正常提交', (tester) async {
    final ctrl = TextEditingController();
    final log = <String>[];
    await tester.pumpWidget(_harness(ctrl, log));
    await _attach(tester);

    ctrl.value = const TextEditingValue(
      text: '怀爱伦',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 0, end: 3),
    );
    await tester.pump();
    await _submit(tester);
    expect(log, isEmpty, reason: '组合态回车只应上屏候选词，不能提交');

    ctrl.value = TextEditingValue(
      text: kQuestion,
      selection: TextSelection.collapsed(offset: kQuestion.length),
      composing: TextRange.empty,
    );
    await tester.pump();
    await _submit(tester);
    expect(log, [kQuestion], reason: '组合结束后回车应提交完整且顺序正确的原文');
  });
}
