// 桌面 Web 实现：用浏览器原生 <textarea> 承接中文输入法。
//
// 为什么不继续用 TextField：
//   Flutter Web 3.22 的 HybridTextEditing 在 flt-text-editing-host 里放一个
//   color:transparent 的 DOM 输入框，真正的文字由框架按 TextEditingValue 画出来。
//   引擎在 compositionupdate 时用「文本长度 - 组合串长度」倒推 composing 区间，
//   并在 TextInput.setEditingState 时把框架状态（含光标）回写 DOM；Windows 拼音
//   输入法逐词上屏时两者会失配：框架侧仍认为输入框为空（画布上无字），DOM 侧
//   光标被回写到 0，后一个词就被插到最前面 —— 即「不回显 + 片段倒序」。
//   引擎的 keydown 处理还对 keyCode===13 无条件触发 TextInputAction，导致组合态
//   的回车把半成品直接提交。
//
// 这里换成原生 textarea：组合、上屏、光标全部由浏览器负责，Dart 侧只在 input /
// compositionend 时读取最终值，回车只在「非组合态」才触发提交。
// 移动端 Web 与微信 X5 仍走 TextField（其 IME 走另一套策略，且平台视图兼容风险高）。
// 本文件只由 native_text_field.dart 在 dart.library.html 存在时被导入，非 Web 不会编译；
// analysis_options.yaml 已将本文件从 VM 分析上下文排除，由 flutter build web 编译把关。

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _viewSeq = 0;

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
  static final bool _isMobile = RegExp(
    r'Android|iPhone|iPad|iPod|Mobile|Windows Phone',
    caseSensitive: false,
  // toString() 兼容不同 SDK 版本里 userAgent 的可空性，避免空值合并运算符告警。
  ).hasMatch(html.window.navigator.userAgent.toString());

  static const double _minHeight = 48;
  static const double _lineHeight = 22;
  // 用字符串整体设置内联样式：dart:html 的 CssStyleDeclaration 并非暴露全部
  // CSS 属性（如 resize / boxSizing 在不同 SDK 版本里有差异），避免编译期歧义。
  static const String _baseStyle = 'width:100%;box-sizing:border-box;'
      'resize:none;overflow-y:auto;border:1px solid #9E9E9E;'
      'border-radius:4px;padding:10px 12px;font-family:inherit;'
      'font-size:14px;line-height:1.4;color:#2D2A26;'
      'background:#FFFFFF;outline:none;';

  late final String _viewType;
  html.TextAreaElement? _input;
  bool _composing = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'app-native-composer-${_viewSeq++}';
    if (!_isMobile) {
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => _createInput(),
      );
      widget.controller.addListener(_fromController);
    }
  }

  html.TextAreaElement _createInput() {
    final el = html.TextAreaElement();
    _input = el;
    el.rows = 1;
    _setEnabled(el);
    el.setAttribute('spellcheck', 'false');
    el.setAttribute('placeholder', widget.hint);
    // 供 index.html 的全局组合态守卫识别：原生输入框必须放行，由本文件自己守卫。
    el.setAttribute('data-native-composer', '1');
    el.value = widget.controller.text;
    _applyStyle();

    // 回调参数保持隐式 dynamic：dart:html 的 EventListener 在不同 SDK 版本里
    // 的事件类型签名略有差异，隐式参数可稳定赋给任意单参数 listener typedef。
    el.addEventListener('compositionstart', (event) {
      _composing = true;
    });
    el.addEventListener('compositionend', (event) {
      _composing = false;
      _toController(el.value ?? '');
    });
    el.onInput.listen((html.Event event) {
      _toController(el.value ?? '');
    });
    el.onKeyDown.listen((html.KeyboardEvent event) {
      // Windows 拼音在组合态按回车是「确认候选词」：Chrome 会给 keyCode=229，
      // 或者 compositionend 尚未到达。此时绝不能触发提交；同时阻止事件冒泡到
      // 引擎的全局 keydown 监听（它同样会把 13 当成 TextInputAction）。
      // 不调用 preventDefault：IME 候选词上屏与 compositionend 必须照常发生。
      if (event.keyCode == 229 || _composing) {
        event.stopPropagation();
        return;
      }
      if (event.keyCode != 13 || event.shiftKey) return;
      event.preventDefault();
      event.stopPropagation();
      final text = el.value ?? '';
      _toController(text);
      widget.onSubmitted(text);
    });
    return el;
  }

  void _applyStyle() {
    _input?.setAttribute('style', _baseStyle + 'height:100%;');
  }

  /// 用属性而非 dart:html 的 disabled setter，兼容不同 SDK 版本的可空签名。
  void _setEnabled(html.TextAreaElement el) {
    if (widget.enabled) {
      el.removeAttribute('disabled');
    } else {
      el.setAttribute('disabled', 'disabled');
    }
  }

  /// 按换行数与粗略折行数估算高度，保持在 1..maxLines 行之间。
  /// 这里只做视觉高度估算，绝不改写文本内容与光标位置。
  double _heightFor(String text) {
    final lineBreaks = '\n'.allMatches(text).length;
    // 14px 汉字 + 左右 padding，按每行约 24 字粗估自动折行。
    final wrapped = (text.length / 24).floor();
    final lines = (1 + lineBreaks + wrapped).clamp(1, widget.maxLines).toInt();
    return _minHeight + (lines - 1) * _lineHeight;
  }

  void _toController(String text) {
    if (_syncing) return;
    _syncing = true;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _syncing = false;
  }

  void _fromController() {
    final el = _input;
    if (el == null || _syncing || _composing) return;
    if (el.value != widget.controller.text) {
      el.value = widget.controller.text;
      final n = widget.controller.text.length;
      el.setSelectionRange(n, n);
    }
  }

  @override
  void didUpdateWidget(covariant NativeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final el = _input;
    if (el != null) {
      _setEnabled(el);
      if (oldWidget.hint != widget.hint) {
        el.setAttribute('placeholder', widget.hint);
      }
    }
  }

  @override
  void dispose() {
    if (!_isMobile) widget.controller.removeListener(_fromController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isMobile) return _fallback();
    // TextEditingController 本身是 ValueNotifier：文本变化时只重建 SizedBox 高度，
    // 平台视图（textarea）与焦点、组合态都保持不变。
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        return SizedBox(
          height: _heightFor(value.text),
          child: HtmlElementView(viewType: _viewType),
        );
      },
    );
  }

  Widget _fallback() {
    return TextField(
      controller: widget.controller,
      minLines: 1,
      maxLines: widget.maxLines,
      enabled: widget.enabled,
      textInputAction: TextInputAction.send,
      onSubmitted: (String _) {
        if (!widget.controller.value.composing.isCollapsed) return;
        widget.onSubmitted(widget.controller.text);
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
