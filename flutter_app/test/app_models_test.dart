// test/app_models_test.dart
// 纯逻辑单测：diff_type 解析、注记模型、模块 B 客户端校验闸门。
// 运行: flutter test test/app_models_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:faith_compare_app/app_models.dart';
import 'package:faith_compare_app/qa_models.dart';

void main() {
  group('parseDiffType', () {
    test('canonical 取值原样映射', () {
      expect(parseDiffType('archaic_kjv'), DiffType.archaicKjv);
      expect(parseDiffType('mistranslation'), DiffType.mistranslation);
      expect(parseDiffType('text_tradition'), DiffType.textTradition);
      expect(parseDiffType('consistent'), DiffType.consistent);
    });

    test('已知别名归入对应 canonical', () {
      expect(parseDiffType('archaism'), DiffType.archaicKjv);
      expect(parseDiffType('textual'), DiffType.textTradition);
    });

    test('非规范取值不擅自归类，标为 unclassified', () {
      // pilot 草稿里的 wording / structure 不在 DDL 的 CHECK 枚举内，
      // 不允许悄悄映射成"看起来合理"的类型 —— 那是替顾问做神学判断。
      expect(parseDiffType('wording'), DiffType.unclassified);
      expect(parseDiffType('structure'), DiffType.unclassified);
      expect(parseDiffType(null), DiffType.unclassified);
    });

    test('unclassified 的 dbValue 为 null（不可入库）', () {
      expect(DiffType.consistent.dbValue, 'consistent');
      expect(DiffType.unclassified.dbValue, isNull);
    });
  });

  group('ComparisonNote', () {
    test('fromJson 兼容 ref 与 verse_ref', () {
      final a = ComparisonNote.fromJson({'ref': 'JHN 3:16', 'status': 'approved'});
      expect(a.ref, 'JHN 3:16');
      final b = ComparisonNote.fromJson({'verse_ref': 'JHN.3.16', 'status': 'draft'});
      expect(b.ref, 'JHN.3.16');
      expect(b.isApproved, isFalse);
    });

    test('isApproved 只看 approved', () {
      expect(ComparisonNote.fromJson({'ref': 'x', 'status': 'approved'}).isApproved, isTrue);
      expect(ComparisonNote.fromJson({'ref': 'x', 'status': 'draft'}).isApproved, isFalse);
      expect(ComparisonNote.fromJson({'ref': 'x', 'status': 'rejected'}).isApproved, isFalse);
    });
  });

  group('CitationGuard（模块 B 客户端闸门）', () {
    QaAnswer ans({
      List<QaCitation> citations = const [],
      double confidence = 0.9,
      bool needsHuman = false,
    }) =>
        QaAnswer(
          answerId: 'qa_1',
          answerZh: '示例回答',
          citations: citations,
          confidence: confidence,
          needsHuman: needsHuman,
        );

    const bible = QaCitation(
      sourceType: QaSourceType.bible,
      sourceId: 'KJV-JHN3:16',
      ref: 'JHN 3:16',
      snippet: 'For God so loved the world...',
    );

    test('有合法引用且高置信 → 放行', () {
      expect(CitationGuard.check(ans(citations: [bible])), isEmpty);
    });

    test('引用缺失 → 拦截（无来源即臆测）', () {
      final v = CitationGuard.check(ans(citations: []));
      expect(v.length, 1);
      expect(v.first, contains('引用缺失'));
    });

    test('cuv 前缀 id 出现在 citations → 拦截', () {
      final cuv = QaCitation(
        sourceType: QaSourceType.bible,
        sourceId: 'CUV-JHN3:16',
        ref: 'JHN 3:16',
        snippet: '神爱世人',
      );
      final v = CitationGuard.check(ans(citations: [bible, cuv]));
      expect(v.any((s) => s.contains('来源非法')), isTrue);
    });

    test('置信低于 0.70 → 提示转人工', () {
      final v = CitationGuard.check(ans(citations: [bible], confidence: 0.42));
      expect(v.any((s) => s.contains('置信过低')), isTrue);
    });

    test('needs_human=true 时允许无引用（仅引导语）', () {
      final v = CitationGuard.check(ans(citations: [], needsHuman: true));
      expect(v, isEmpty);
    });

    test('needs_human=true 但含 cuv id 仍拦截', () {
      final cuv = QaCitation(
        sourceType: QaSourceType.bible,
        sourceId: 'cuv-rom3:23',
        ref: 'ROM 3:23',
        snippet: '…',
      );
      final v = CitationGuard.check(ans(citations: [cuv], needsHuman: true));
      expect(v.any((s) => s.contains('来源非法')), isTrue);
    });
  });

  group('QaCitation.isCuv', () {
    test('大小写不敏感识别 cuv 前缀', () {
      expect(
        QaCitation(
          sourceType: QaSourceType.bible,
          sourceId: 'CUV-JHN3:16',
          ref: '',
          snippet: '',
        ).isCuv,
        isTrue,
      );
      expect(
        QaCitation(
          sourceType: QaSourceType.bible,
          sourceId: 'cuv-jhn3:16',
          ref: '',
          snippet: '',
        ).isCuv,
        isTrue,
      );
      expect(
        QaCitation(
          sourceType: QaSourceType.bible,
          sourceId: 'KJV-JHN3:16',
          ref: '',
          snippet: '',
        ).isCuv,
        isFalse,
      );
    });
  });
}
