// mailto_helper.dart
// 跨平台打开外部链接（mailto 等）：
// Web 构建走 dart:html（唤起邮件客户端）；VM / flutter test 环境为 no-op，
// 保证 widget 测试不依赖平台通道。
export 'mailto_stub.dart' if (dart.library.html) 'mailto_web.dart';
