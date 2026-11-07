// 非 Web（含 flutter test）实现：保持 Flutter 原生 TextField 行为。

import 'package:flutter/material.dart';

/// 回车是否可作为「提交」处理：输入法组合态尚未结束时，回车只是候选词上屏。
/// 抽成公开函数便于单元/组件测试直接断言，不依赖 EditableText 内部状态机。
bool shouldSubmitOnEnter(TextEditingValue value) =>
    value.composing.isCollapsed;

class NativeTextField extends StatefulWidget {
  const NativeTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSubmitted,
    this.maxLines = 4,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final int maxLines;
  final bool enabled;

  @override
  State<NativeTextField> createState() => _NativeTextFieldState();
}

class _NativeTextFieldState extends State<NativeTextField> {
  void _submit(String _) {
    // 输入法组合尚未结束时按回车属于「候选词上屏」，不是提交动作。
    // 统一以 controller 为唯一文本来源，避免框架回传值与输入框实际值不一致。
    if (!shouldSubmitOnEnter(widget.controller.value)) return;
    widget.onSubmitted(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      minLines: 1,
      maxLines: widget.maxLines,
      enabled: widget.enabled,
      textInputAction: TextInputAction.send,
      onSubmitted: _submit,
      decoration: InputDecoration(
        hintText: widget.hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
