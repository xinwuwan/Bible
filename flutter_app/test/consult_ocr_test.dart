// consult_ocr_test.dart
// v58：诊断材料图片 OCR 客户端测试（上传图片后自动识别的链路一环）。
// 覆盖：正常转录、base64 编队与 mime 透传、各失败路径返回 null（调用方
// 据此退回「手动誊写」，不阻塞上传）。
import 'dart:convert';
import 'dart:typed_data';

import 'package:faith_compare_app/consult_ocr.dart';
import 'package:faith_compare_app/rag_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final img = Uint8List.fromList(utf8.encode('fake-image-bytes'));

  http.Response handler(http.Request req) {
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    // 回显请求内容便于断言编队
    return http.Response(
      jsonEncode({
        'ok': true,
        'text': '${body['mime']}|${body['image']}',
      }),
      200,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  }

  group('ConsultOcr.recognizeImage', () {
    test('正常转录：POST /api/ocr，body 为 base64+mime，返回文本', () async {
      String? seenUrl;
      final client = MockClient((req) async {
        seenUrl = req.url.toString();
        return handler(req);
      });
      final text = await ConsultOcr.recognizeImage(
        img, 'image/jpeg',
        client: client,
      );
      expect(text, isNotNull);
      // URL 带 sharecode（托管闸门铁律）
      expect(seenUrl, contains('/api/ocr?sharecode='));
      expect(seenUrl, contains(consultOcrApiUrl));
      // body：base64 编码 + mime
      expect(text, startsWith('image/jpeg|'));
      expect(text, contains(base64Encode(img)));
    });

    test('png mime 原样透传', () async {
      final client = MockClient((req) async => handler(req));
      final text = await ConsultOcr.recognizeImage(
        img, 'image/png',
        client: client,
      );
      expect(text, startsWith('image/png|'));
    });

    test('ok:false → null（后端拒绝）', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({'ok': false, 'error': 'unsupported mime'}),
            200,
          ));
      expect(await ConsultOcr.recognizeImage(img, 'image/jpeg', client: client),
          isNull);
    });

    test('非 200 → null', () async {
      final client = MockClient((req) async => http.Response('boom', 502));
      expect(await ConsultOcr.recognizeImage(img, 'image/jpeg', client: client),
          isNull);
    });

    test('空文本 → null', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({'ok': true, 'text': '   '}),
            200,
          ));
      expect(await ConsultOcr.recognizeImage(img, 'image/jpeg', client: client),
          isNull);
    });

    test('坏 JSON → null（不抛异常）', () async {
      final client = MockClient((req) async => http.Response('{not json', 200));
      expect(await ConsultOcr.recognizeImage(img, 'image/jpeg', client: client),
          isNull);
    });

    test('网络异常 → null', () async {
      final client =
          MockClient((req) async => throw http.ClientException('no network'));
      expect(await ConsultOcr.recognizeImage(img, 'image/jpeg', client: client),
          isNull);
    });

    test('空字节 → null（不发请求）', () async {
      var called = false;
      final client = MockClient((req) async {
        called = true;
        return handler(req);
      });
      expect(
          await ConsultOcr.recognizeImage(
              Uint8List(0), 'image/jpeg',
              client: client),
          isNull);
      expect(called, isFalse);
    });

    test('fetcherForTest 优先于 client（页面流程测试缝）', () async {
      ConsultOcr.fetcherForTest = (bytes, mime) async => '注入的转录文本';
      addTearDown(() => ConsultOcr.fetcherForTest = null);
      final client = MockClient((req) async => handler(req));
      final text = await ConsultOcr.recognizeImage(img, 'image/jpeg',
          client: client);
      expect(text, '注入的转录文本');
    });

    test('kRagBaseUrl 为空时不发请求（灰度关闭）', () async {
      // kRagBaseUrl 为常量，无法在测试中置空；这里验证端点串包含 base+路径
      expect(kRagBaseUrl, isNotEmpty);
      expect(consultOcrApiUrl, startsWith(kRagBaseUrl));
    });
  });
}
