// 跨平台文本输入统一入口。
//
// 桌面 Web 使用浏览器原生 <textarea>（见 native_text_field_web.dart）：Flutter Web
// 3.22 的 HybridTextEditing 把真实文字放在一个「透明 DOM 输入框」里、再由框架把
// TextEditingValue 画到画布上；Windows 中文输入法的组合态与该桥接层不同步时会出现
// 「输入框不回显 + 每次上屏插到光标 0 → 片段倒序」。原生输入框由浏览器自己完成
// 组合、上屏与光标维护，从根上不经过这段桥接。
//
// 非 Web（含 flutter test）与移动端 Web 仍使用 Flutter 的 TextField。
export 'native_text_field_stub.dart'
    if (dart.library.html) 'native_text_field_web.dart';
