import 'dart:io';

Future<void> main() async {
  // 1) 默认（直连）
  await _try('DIRECT', null);
  // 2) 显式使用环境变量里的代理
  final proxy = Platform.environment['https_proxy'] ??
      Platform.environment['HTTPS_PROXY'] ??
      '';
  if (proxy.isNotEmpty) {
    await _try('PROXY($proxy)', proxy);
  } else {
    print('PROXY: 环境变量里没有代理');
  }
}

Future<void> _try(String tag, String? proxy) async {
  final uri = Uri.parse('https://pub.dev/api/packages/path');
  try {
    final c = HttpClient();
    c.connectionTimeout = const Duration(seconds: 8);
    if (proxy != null) {
      c.findProxy = (Uri u) => 'PROXY ${Uri.parse(proxy).host}:${Uri.parse(proxy).port}';
    }
    final req = await c.getUrl(uri).timeout(const Duration(seconds: 10));
    final resp = await req.close().timeout(const Duration(seconds: 15));
    print('$tag -> STATUS=${resp.statusCode}');
    await resp.drain();
  } catch (e) {
    print('$tag -> ERR=${e.runtimeType}: $e');
  }
}
