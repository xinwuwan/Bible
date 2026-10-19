// external_link_helper.dart
// 跨平台打开外部链接（SDA 圣经注释等）：
// Web 构建走 dart:html（新标签打开，不离开 App）；VM / flutter test 环境为 no-op，
// 保证 widget 测试不依赖平台通道。
export 'external_link_stub.dart' if (dart.library.html) 'external_link_web.dart';
