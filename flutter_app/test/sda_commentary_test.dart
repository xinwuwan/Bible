// test/sda_commentary_test.dart
// v54：SDA 圣经注释中英双语切换测试。
// 覆盖：
//   ① sdaCommentaryApiUrl 语言参数（默认 en / zh / 异常输入）
//   ② fetchSdaCommentary 假 client：请求 URL 带 lang、成功/失败解析
//   ③ VerseCompareCard 注入假 fetcher：展开→英文→切中文→切回英文（缓存不重复请求）
//      与失败重试路径。
// 运行: flutter test test/sda_commentary_test.dart

import 'dart:convert';

import 'package:faith_compare_app/app_models.dart';
import 'package:faith_compare_app/rag_config.dart';
import 'package:faith_compare_app/sda_commentary.dart';
import 'package:faith_compare_app/verse_compare_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 记录请求 URL 的假 client，按 handler 返回响应。
http.Client _clientReturning(String Function(Uri url) body,
    {int status = 200, List<Uri>? log}) {
  return MockClient((req) async {
    log?.add(req.url);
    return http.Response(body(req.url), status,
        headers: {'content-type': 'application/json'});
  });
}

String _enBody(String ref) => jsonEncode({
      'ok': true,
      'ref': ref,
      'text': 'In the beginning. These words remind us of the fact that everything human has a beginning.',
      'source': 'SDA Bible Commentary (bible-strong.app 镜像)',
      'url': 'https://bible-strong.app/commentary/en/sdabc/gen/1',
    });

String _zhBody(String ref) => jsonEncode({
      'ok': true,
      'ref': ref,
      'text': '起初，上帝创造了天地。',
      'source': 'SDA 圣经注释（简体中文 · read.sdabible.org）',
      'url': 'https://read.sdabible.org/read/genesis/1',
    });

/// 面板用的假 fetcher：按 lang 返回不同内容，并记录调用次数。
_FakeFetcher _fakeFetcher() => _FakeFetcher();

class _FakeFetcher {
  int calls = 0;
  final List<String> langs = [];

  Future<SdaCommentaryResult> call(String ref, {String lang = 'en'}) async {
    calls++;
    langs.add(lang);
    if (lang == 'zh') {
      return SdaCommentaryResult.ok(SdaCommentary(
        ref: ref,
        text: '起初，上帝创造了天地。〔中文注释正文〕',
        source: 'SDA 圣经注释（简体中文 · read.sdabible.org）',
        url: 'https://read.sdabible.org/read/genesis/1',
        lang: 'zh',
      ));
    }
    return SdaCommentaryResult.ok(SdaCommentary(
      ref: ref,
      text: 'In the beginning. These words remind us of the fact that everything human has a beginning.',
      source: 'SDA Bible Commentary (bible-strong.app 镜像)',
      url: 'https://bible-strong.app/commentary/en/sdabc/gen/1',
      lang: 'en',
    ));
  }
}

VerseView _verse() => const VerseView(
      verse: 1,
      ref: 'GEN 1:1',
      kjvText: 'In the beginning God created the heaven and the earth.',
      ourZh: '起初，上帝创造了天地。',
    );

Future<void> _pump(WidgetTester tester, _FakeFetcher f) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 800,
            child: VerseCompareCard(
              verse: _verse(),
              commentaryFetcher: f.call,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('sdaCommentaryApiUrl 语言参数', () {
    test('默认 en', () {
      final u = sdaCommentaryApiUrl('GEN 1:1');
      expect(u.contains('lang=en'), isTrue);
      expect(u.contains('book=GEN'), isTrue);
      expect(u.contains('chapter=1'), isTrue);
      expect(u.contains('verse=1'), isTrue);
    });

    test('lang=zh 显式传入', () {
      expect(sdaCommentaryApiUrl('GEN 1:1', lang: 'zh').contains('lang=zh'),
          isTrue);
    });

    test('带数字前缀书卷（1CO）', () {
      final u = sdaCommentaryApiUrl('1CO 13:4', lang: 'zh');
      expect(u.contains('book=1CO'), isTrue);
      expect(u.contains('chapter=13'), isTrue);
      expect(u.contains('verse=4'), isTrue);
      expect(u.contains('lang=zh'), isTrue);
    });

    test('空 / 畸形输入返回空串（禁用按钮）', () {
      expect(sdaCommentaryApiUrl(''), isEmpty);
      expect(sdaCommentaryApiUrl('GEN'), isEmpty);
      expect(sdaCommentaryApiUrl('GEN 1'), isEmpty);
    });
  });

  group('fetchSdaCommentary 假 client', () {
    test('默认请求 URL 带 lang=en，解析成功', () async {
      final log = <Uri>[];
      final r = await fetchSdaCommentary('GEN 1:1',
          client: _clientReturning((u) => _enBody('GEN 1:1'), log: log));
      expect(r.commentary, isNotNull);
      expect(r.commentary!.lang, 'en');
      expect(r.commentary!.text, contains('In the beginning'));
      expect(r.commentary!.source, contains('bible-strong'));
      expect(log.single.toString().contains('lang=en'), isTrue);
    });

    test('lang=zh 请求带 lang=zh，拿到中文正文', () async {
      final log = <Uri>[];
      final r = await fetchSdaCommentary('GEN 1:1',
          lang: 'zh',
          client: _clientReturning((u) => _zhBody('GEN 1:1'), log: log));
      expect(r.commentary, isNotNull);
      expect(r.commentary!.lang, 'zh');
      expect(r.commentary!.text, contains('起初，上帝创造了天地'));
      expect(r.commentary!.url, contains('read.sdabible.org'));
      expect(log.single.toString().contains('lang=zh'), isTrue);
    });

    test('ok:false 返回 fail（该节暂无注释）', () async {
      final r = await fetchSdaCommentary('GEN 1:7',
          lang: 'zh',
          client: _clientReturning(
              (u) => jsonEncode({'ok': false, 'error': 'no commentary section'})));
      expect(r.commentary, isNull);
      expect(r.error, 'no commentary section');
    });

    test('HTTP 502 返回 fail', () async {
      final r = await fetchSdaCommentary('GEN 1:1',
          client: _clientReturning((u) => 'oops', status: 502));
      expect(r.commentary, isNull);
      expect(r.error, contains('502'));
    });

    test('空正文返回 fail', () async {
      final r = await fetchSdaCommentary('GEN 1:1',
          lang: 'zh',
          client: _clientReturning((u) =>
              jsonEncode({'ok': true, 'ref': 'GEN 1:1', 'text': '   '})));
      expect(r.commentary, isNull);
      expect(r.error, '该节暂无注释');
    });
  });

  group('VerseCompareCard 中英切换 widget 流', () {
    testWidgets('展开默认英文 → 切中文 → 切回英文（缓存不重复请求）', (tester) async {
      final f = _fakeFetcher();
      await _pump(tester, f);

      await tester.tap(find.text('SDA 圣经注释'));
      await tester.pumpAndSettle();

      // 默认英文
      expect(find.textContaining('SDA 圣经注释 · GEN 1:1'), findsOneWidget);
      expect(find.textContaining('英文原著'), findsOneWidget);
      expect(find.textContaining('These words remind us'), findsOneWidget);
      expect(find.textContaining('bible-strong'), findsOneWidget);
      expect(f.calls, 1);
      expect(f.langs, ['en']);

      // 切中文
      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      expect(find.textContaining('GEN 1:1（简体中文）'), findsOneWidget);
      expect(find.textContaining('中文注释正文'), findsOneWidget);
      expect(find.textContaining('read.sdabible.org'), findsOneWidget);
      expect(f.calls, 2);
      expect(f.langs, ['en', 'zh']);

      // 切回英文：命中缓存，不再请求
      await tester.tap(find.text('英文'));
      await tester.pumpAndSettle();
      expect(find.textContaining('英文原著'), findsOneWidget);
      expect(find.textContaining('These words remind us'), findsOneWidget);
      expect(f.calls, 2);
    });

    testWidgets('中文取失败 → 重试后恢复成功', (tester) async {
      var failZh = true;
      final f = _FakeFetcher();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 800,
                child: VerseCompareCard(
                  verse: _verse(),
                  commentaryFetcher: (ref, {lang = 'en'}) async {
                    if (lang == 'zh' && failZh) {
                      return const SdaCommentaryResult.fail('注释服务返回 502');
                    }
                    return f.call(ref, lang: lang);
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // 展开默认英文
      await tester.tap(find.text('SDA 圣经注释'));
      await tester.pumpAndSettle();
      expect(find.textContaining('These words remind us'), findsOneWidget);

      // 切中文：失败态
      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      expect(find.text('注释服务返回 502'), findsOneWidget);
      expect(find.textContaining('中文注释正文'), findsNothing);

      // 恢复后点重试：中文显示
      failZh = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.textContaining('中文注释正文'), findsOneWidget);
      expect(find.text('注释服务返回 502'), findsNothing);
    });

    testWidgets('收起再展开：显示缓存内容，不重复请求', (tester) async {
      final f = _fakeFetcher();
      await _pump(tester, f);

      await tester.tap(find.text('SDA 圣经注释'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      expect(f.calls, 2);

      await tester.tap(find.text('收起注释'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SDA 圣经注释'));
      await tester.pumpAndSettle();
      expect(find.textContaining('中文注释正文'), findsOneWidget);
      expect(f.calls, 2); // 缓存命中，无新请求
    });

    testWidgets('失败态显示重试与兜底外链', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 800,
                child: VerseCompareCard(
                  verse: _verse(),
                  commentaryFetcher: (ref, {lang = 'en'}) async =>
                      SdaCommentaryResult.fail('该节暂无注释'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('SDA 圣经注释'));
      await tester.pumpAndSettle();
      expect(find.text('该节暂无注释'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('打开原页面 ↗'), findsOneWidget);
    });
  });
}
