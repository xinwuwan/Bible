// verify_web_data.dart
// 纯 Dart 验证器（不依赖 Flutter 引擎，可在沙箱用 `dart run` 直接跑）。
// 目的：在无法运行 `flutter build/test` 的环境里，仍能验证 web 数据层逻辑正确——
// 即 App 在网页端实际会调用的解析 / 查询 / 反序列化路径全部成立。

import 'dart:io';

import 'flutter_app/lib/web_data_core.dart' as core;
import 'flutter_app/lib/app_models.dart' as am;
import 'flutter_app/lib/health_models.dart' as hm;

void check(bool cond, String msg) {
  if (!cond) {
    print('FAIL: $msg');
    exit(1);
  }
  print('  ok: $msg');
}

void main() {
  final file = File('flutter_app/assets/web/app_data.json');
  if (!file.existsSync()) {
    print('FAIL: 找不到 $file');
    exit(1);
  }

  final store = core.AppDataStore();
  store.parse(file.readAsStringSync());
  check(store.isAvailable, '解析 JSON 后 store 可用');

  // ---- 模块 A：书卷 / 章节 / 检索 ----
  final books = store.getBooks();
  check(books.length == 2, 'getBooks == 2（实际 ${books.length}）');
  final gen = books.firstWhere((b) => b['book_code'] == 'GEN');
  check(gen['testament'] == 'OT', 'GEN 属旧约(OT)');
  final bm = am.BookMeta.fromDbRow(gen);
  check(bm.nameZh == '创世记' && bm.chapterCount == 50, 'BookMeta.fromDbRow 还原 GEN');

  final ch = store.getChapter(1, 1);
  check(ch.isNotEmpty, 'GEN 第1章有经文');
  final v0 = am.VerseView.fromDbRow(ch.first);
  check(v0.ref == 'GEN 1:1', 'ref == GEN 1:1');
  check(v0.kjvText.startsWith('In the beginning'),
      'KJV 为权威底本（英文原文）');
  check(v0.ourZh != null && v0.cuvRefText != null, '本应用中文 + 和合本参照均在');

  final en = store.search('God');
  check(en.isNotEmpty, '英文检索 "God" 命中');
  check(en.any((h) => h['ref'] == 'GEN 1:1'), '检索命中 GEN 1:1');
  final zh = store.search('神');
  check(zh.isNotEmpty, '中文检索 "神" 命中（CJK 逐字分词生效）');

  check(store.getDoctrines().length == 1, '教义条款 == 1');

  // ---- 模块 C：NEWSTART 健康 ----
  final topics = store.getHealthTopics();
  check(topics.length == 8, '健康支柱 == 8（NEWSTART）');
  final t0 = hm.HealthTopic.fromRow(topics.first);
  check(t0.newstart != null, '支柱 code 映射到 NEWSTART 枚举（${t0.code}）');
  final sources = store.getHealthSources(topics.first['topic_id'] as int);
  check(sources.isNotEmpty, '健康权威来源存在');
  final src0 = hm.HealthSource.fromRow(sources.first);
  check(src0.sourceType != hm.HealthSourceType.unknown, '来源类型正确解析');
  final metrics = store.getHealthMetrics();
  check(metrics.length == 8, '打卡指标 == 8');
  hm.HealthMetric.fromRow(metrics.first);
  final guidance = store.getHealthGuidance(topics.first['topic_id'] as int);
  check(guidance.isEmpty, '暂无已审核健康条目（合规闸门：未审核不展示）');

  // ---- CJK 分词 ----
  final tq = core.AppDataStore.ftsQuery('神创造');
  check(tq.contains('神') && tq.contains('创') && tq.contains('造'),
      'ftsQuery 对中文逐字分词: "$tq"');

  print(
      '\n全部断言通过 ✅  '
      '(${books.length} 书卷 / ${ch.length} 节 / ${topics.length} 支柱 / '
      '${metrics.length} 指标)');
}
