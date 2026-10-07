// test/health_models_test.dart
// 模块 C 模型与合规闸门的单元测试

import 'package:flutter_test/flutter_test.dart';
import 'package:faith_compare_app/health_models.dart';

void main() {
  group('NewstartCode', () {
    test('解析八支柱代码', () {
      expect(NewstartCodeX.tryParse('NUT'), NewstartCode.nut);
      expect(NewstartCodeX.tryParse('tru'), NewstartCode.tru);
      expect(NewstartCodeX.tryParse('XXX'), isNull);
      expect(NewstartCodeX.tryParse(null), isNull);
    });

    test('code 与默认中文名', () {
      expect(NewstartCode.wat.code, 'WAT');
      expect(NewstartCode.exe.defaultNameZh, '运动');
      expect(NewstartCode.tru.defaultNameZh, '信靠');
    });
  });

  group('HealthGuard 合规闸门', () {
    const reviewed = HealthGuidance(
      guidanceId: 1,
      topicId: 1,
      title: 't',
      bodyZh: 'b',
      evidenceLevel: 'B',
      medicalReviewed: true,
      disclaimer: HealthGuard.defaultDisclaimer,
    );
    const unreviewed = HealthGuidance(
      guidanceId: 2,
      topicId: 1,
      title: 't2',
      bodyZh: 'b2',
      medicalReviewed: false,
      disclaimer: HealthGuard.defaultDisclaimer,
    );

    test('已审核条目放行', () {
      expect(HealthGuard.checkGuidance(reviewed), isEmpty);
      expect(HealthGuard.visible(reviewed), isTrue);
    });

    test('未审核条目默认拦截', () {
      expect(HealthGuard.checkGuidance(unreviewed), isNotEmpty);
      expect(HealthGuard.visible(unreviewed), isFalse);
    });

    test('未审核条目在预览模式下放行（仅内部联调）', () {
      expect(HealthGuard.checkGuidance(unreviewed, previewMode: true), isEmpty);
      expect(HealthGuard.visible(unreviewed, previewMode: true), isTrue);
    });

    test('缺失免责声明一律拦截（即便已审核）', () {
      final g = HealthGuidance(
        guidanceId: 3,
        topicId: 1,
        title: 't3',
        bodyZh: 'b3',
        medicalReviewed: true,
        disclaimer: '',
      );
      final v = HealthGuard.checkGuidance(g, previewMode: true);
      expect(v.any((s) => s.contains('免责')), isTrue);
      expect(HealthGuard.visible(g, previewMode: true), isFalse);
    });
  });

  group('HealthGuidance.fromRow', () {
    test('SQLite 的 0/1 正确转为 bool', () {
      final g = HealthGuidance.fromRow({
        'guidance_id': 7,
        'topic_id': 1,
        'title': '标题',
        'body_zh': '正文',
        'evidence_level': 'A',
        'medical_reviewed': 1,
        'disclaimer': null,
      });
      expect(g.medicalReviewed, isTrue);
      // disclaimer 为 null 时用默认声明兜底（合规：不得无免责展示）
      expect(g.disclaimer, HealthGuard.defaultDisclaimer);
    });

    test('medical_reviewed=0 视为未审核', () {
      final g = HealthGuidance.fromRow({
        'guidance_id': 8,
        'topic_id': 1,
        'title': 'x',
        'body_zh': 'y',
        'medical_reviewed': 0,
      });
      expect(g.medicalReviewed, isFalse);
    });
  });

  group('HealthLogEntry', () {
    test('isSameDay 按本地日期判断', () {
      final a = DateTime(2026, 10, 6, 7, 5);
      final b = DateTime(2026, 10, 6, 23, 55);
      final c = DateTime(2026, 10, 7, 0, 10);
      expect(HealthLogEntry(userId: 'u', topicCode: 'EXE', value: '30', loggedAt: a)
          .isSameDay(b), isTrue);
      expect(HealthLogEntry(userId: 'u', topicCode: 'EXE', value: '30', loggedAt: a)
          .isSameDay(c), isFalse);
    });

    test('toRow 输出可被落库字段消费', () {
      final e = HealthLogEntry(
        userId: 'u1',
        topicCode: 'WAT',
        metricId: 3,
        value: '1800',
        loggedAt: DateTime(2026, 10, 6),
      );
      final row = e.toRow();
      expect(row['user_id'], 'u1');
      expect(row['topic_code'], 'WAT');
      expect(row['metric_id'], 3);
      expect(row['logged_at'], isA<String>());
    });
  });
}
