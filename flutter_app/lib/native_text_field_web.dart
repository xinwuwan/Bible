// Web 实现：桌面 / 手机 / 微信 X5 一律使用浏览器原生 <textarea>。
//
// 为什么不继续用 TextField：
//   Flutter Web 3.22 的 HybridTextEditing 在 flt-text-editing-host 里放一个
//   color:transparent 的 DOM 输入框，真正的文字由框架按 TextEditingValue 画出来。
//   引擎在 compositionupdate 时用「文本长度 - 组合串长度」倒推 composing 区间，
//   并在 TextInput.setEditingState 时把框架状态（含光标）回写 DOM；中文拼音逐词
//   上屏时两者失配：框架侧仍认为输入框为空（画布上无字），DOM 侧光标被回写到 0，
//   后一个词就被插到最前面 —— 即「不回显 + 片段倒序」。引擎的 keydown 处理还对
//   keyCode===13 无条件触发 TextInputAction，导致组合态回车把半成品直接提交。
//
// 这里换成原生 textarea：组合、上屏、光标、可见文字全部由浏览器负责，Dart 侧只在
// input / compositionend 时读取最终值，回车只在「非组合态」才触发提交。
//
// 重要（曾经踩过的坑）：
//   1) 早期版本按 UA 判断设备类型，手机/微信直接回退到 Flutter 文本输入框，
//      等于没修 —— 移动端与微信 X5 恰恰是中文 IME 问题最集中的环境。现在统一走
//      原生输入框，不再有任何平台回退分支。
//   2) 早期版本让文本变化触发平台视图重建并改变
//      外层 SizedBox 高度。平台视图的 DOM slot 一旦被重新布局/移动，浏览器会中断
//      正在进行的 IME 组合，同样可能造成丢字与顺序错乱。现在尺寸在生命周期内
//      固定，platform view 只创建一次，DOM 元素永不重挂。
//
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
  static const double _minHeight = 48;
  static const double _lineHeight = 22;
  // 用字符串整体设置内联样式：dart:html 的 CssStyleDeclaration 并非暴露全部
  // CSS 属性（如 resize / boxSizing 在不同 SDK 版本里有差异），避免编译期歧义。
  static const String _baseStyle = 'width:100%;height:100%;box-sizing:border-box;'
      'display:block;position:relative;z-index:1;'
      'resize:none;overflow-y:auto;-webkit-appearance:none;appearance:none;'
      'border:1px solid #9E9E9E;border-radius:4px;padding:10px 12px;'
      'font-family:inherit;font-size:14px;line-height:1.4;color:#2D2A26;'
      'background:#FFFFFF;outline:none;';

  late final String _viewType;
  late final double _fixedHeight;
  html.TextAreaElement? _input;
  bool _composing = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'app-native-composer-${_viewSeq++}';
    // 高度只在这里计算一次。文本变化绝不触发重建，平台视图的 DOM 槽位因此稳定。
    final lines = widget.maxLines < 1
        ? 1
        : (widget.maxLines > 3 ? 3 : widget.maxLines);
    _fixedHeight = _minHeight + (lines - 1) * _lineHeight;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _createInput(),
    );
    // 外部（例如提交后 _ctrl.clear()）改动 controller 时，同步回 DOM。
    widget.controller.addListener(_fromController);
  }

  html.TextAreaElement _createInput() {
    final el = html.TextAreaElement();
    _input = el;
    el.rows = 1;
    _setEnabled(el);
    el.setAttribute('spellcheck', 'false');
    el.setAttribute('autocapitalize', 'off');
    el.setAttribute('autocorrect', 'off');
    el.setAttribute('autocomplete', 'off');
    // 手机软键盘把右下角按键显示成「发送」。
    el.setAttribute('enterkeyhint', 'send');
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
      // 少数输入法在 compositionend 之后才把最终值写入 value，下一微任务再读一次。
      Future<void>.delayed(Duration.zero, () {
        final cur = _input;
        if (cur != null) _toController(cur.value ?? '');
      });
    });
    el.onInput.listen((html.Event event) {
      _toController(el.value ?? '');
    });
    el.onKeyDown.listen((html.KeyboardEvent event) {
      // 中文拼音组合态按回车是「确认候选词」：Chrome 会给 keyCode=229，
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
    _input?.setAttribute('style', _baseStyle);
  }

  /// 用属性而非 dart:html 的 disabled setter，兼容不同 SDK 版本的可空签名。
  void _setEnabled(html.TextAreaElement el) {
    if (widget.enabled) {
      el.removeAttribute('disabled');
    } else {
      el.setAttribute('disabled', 'disabled');
    }
  }

  /// DOM -> controller。文本没变化时不写 controller，避免无谓通知干扰组合态。
  /// controller 的 selection 只用于 composing 判定；真实光标始终由 DOM 自己维护，
  /// 因此这里不会把用户的光标强行拽到末尾（否则「修改中间文字」会再次错乱）。
  void _toController(String text) {
    if (_syncing || widget.controller.text == text) return;
    _syncing = true;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _syncing = false;
  }

  /// controller -> DOM。组合态下不动 DOM，避免打断 IME。
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
    widget.controller.removeListener(_fromController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 尺寸恒定：HtmlElementView 在整个生命周期只创建一次，DOM textarea 不会被
    // 移动或重建，浏览器可完整接管 IME 组合、光标与可见文字。
    return SizedBox(
      width: double.infinity,
      height: _fixedHeight,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
