// test/helpers/test_db.dart
// 测试用：在临时目录构建一个与 build_offline_db.py 同构的离线库，
// 供 widget test 通过 OfflineDbHelper.openPathForTest() 注入，
// 从而不依赖真实 assets/app_offline.db（资产在测试中不好加载）。
//
// ⚠ 真实工程中 import 请用 package 名（见 pubspec_example.yaml 的 name: faith_compare_app）；
//    本工作区文件是平铺的，若直接放根目录跑请改成相对 import。

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const String kTestSchema = '''
CREATE TABLE book (
  book_id INTEGER PRIMARY KEY,
  book_code TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_zh TEXT NOT NULL,
  testament TEXT NOT NULL,
  chapter_count INTEGER NOT NULL
);
CREATE TABLE verse (
  verse_id INTEGER PRIMARY KEY,
  book_id INTEGER NOT NULL,
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  ref TEXT NOT NULL,
  kjv_text TEXT NOT NULL,
  our_zh TEXT,
  cuv_ref_text TEXT,
  UNIQUE(book_id, chapter, verse)
);
CREATE TABLE doctrine (
  belief_id INTEGER PRIMARY KEY,
  code TEXT NOT NULL,
  title_en TEXT NOT NULL,
  title_zh TEXT,
  en_text TEXT NOT NULL,
  zh_text TEXT
);
''';

const String kTestFts = '''
CREATE VIRTUAL TABLE verse_fts USING fts5(
  ref UNINDEXED, kjv_text, our_zh, tokenize='unicode61'
);
''';

/// 与打包脚本 _fts_zh 对称：CJK 逐字空格分词，否则 unicode61 会丢弃连续汉字。
String ftsZhIndex(String? text) {
  if (text == null || text.isEmpty) return '';
  final buf = StringBuffer();
  for (final rune in text.runes) {
    final s = String.fromCharCode(rune);
    if ((rune >= 0x3400 && rune <= 0x9FFF) ||
        (rune >= 0x3000 && rune <= 0x303F) ||
        (rune >= 0xFF00 && rune <= 0xFFEF)) {
      buf.write('$s ');
    } else {
      buf.write(s);
    }
  }
  return buf.toString().trim();
}

/// 构建临时离线库，返回 db 文件路径。
/// [verses] 元素字段: verse_id, book_id, chapter, verse, ref, kjv_text, our_zh, cuv_ref_text
String buildTempOfflineDb({
  List<Map<String, Object?>>? books,
  List<Map<String, Object?>>? verses,
  List<Map<String, Object?>>? doctrines,
  bool withFts = true,
}) {
  final dir = Directory.systemTemp.createTempSync('faith_test_');
  final file = p.join(dir.path, 'app_offline.db');
  final f = File(file);
  if (f.existsSync()) f.deleteSync();

  final db = sqlite3.open(file);
  db.execute(kTestSchema);

  final bks = books ??
      [
        {
          'book_id': 1,
          'book_code': 'GEN',
          'name_en': 'Genesis',
          'name_zh': '创世记',
          'testament': 'OT',
          'chapter_count': 50,
        },
        {
          'book_id': 2,
          'book_code': 'JHN',
          'name_en': 'John',
          'name_zh': '约翰福音',
          'testament': 'NT',
          'chapter_count': 21,
        },
      ];
  for (final b in bks) {
    db.execute(
      'INSERT INTO book (book_id, book_code, name_en, name_zh, testament, chapter_count) '
      'VALUES (?,?,?,?,?,?)',
      [
        b['book_id'],
        b['book_code'],
        b['name_en'],
        b['name_zh'],
        b['testament'],
        b['chapter_count'],
      ],
    );
  }

  final vvs = verses ??
      [
        {
          'verse_id': 1,
          'book_id': 1,
          'chapter': 1,
          'verse': 1,
          'ref': 'GEN 1:1',
          'kjv_text': 'In the beginning God created the heaven and the earth.',
          'our_zh': '起初，神创造天地。',
          'cuv_ref_text': '起初神创造天地。',
        },
        {
          'verse_id': 2,
          'book_id': 2,
          'chapter': 3,
          'verse': 16,
          'ref': 'JHN 3:16',
          'kjv_text': 'For God so loved the world, that he gave his only begotten Son.',
          'our_zh': '神爱世人，甚至将他的独生子赐给他们。',
          'cuv_ref_text': '神爱世人，甚至将他的独生子赐给他们。',
        },
      ];
  for (final v in vvs) {
    db.execute(
      'INSERT INTO verse (verse_id, book_id, chapter, verse, ref, kjv_text, our_zh, cuv_ref_text) '
      'VALUES (?,?,?,?,?,?,?,?)',
      [
        v['verse_id'],
        v['book_id'],
        v['chapter'],
        v['verse'],
        v['ref'],
        v['kjv_text'],
        v['our_zh'],
        v['cuv_ref_text'],
      ],
    );
  }

  final docs = doctrines ??
      [
        {
          'belief_id': 1,
          'code': 'D01',
          'title_en': 'Holy Scriptures',
          'title_zh': '圣经',
          'en_text': 'The Holy Scriptures are the inspired Word of God.',
          'zh_text': '圣经是神所默示的话语。',
        },
      ];
  for (final d in docs) {
    db.execute(
      'INSERT INTO doctrine (belief_id, code, title_en, title_zh, en_text, zh_text) '
      'VALUES (?,?,?,?,?,?)',
      [
        d['belief_id'],
        d['code'],
        d['title_en'],
        d['title_zh'],
        d['en_text'],
        d['zh_text'],
      ],
    );
  }

  // FTS5 可能不可用（sqlite3 编译未启用），失败则降级为不可检索，不影响其它用例
  if (withFts) {
    try {
      db.execute(kTestFts);
      for (final v in vvs) {
        db.execute(
          'INSERT INTO verse_fts (rowid, ref, kjv_text, our_zh) VALUES (?,?,?,?)',
          [v['verse_id'], v['ref'], v['kjv_text'], ftsZhIndex(v['our_zh'] as String?)],
        );
      }
    } catch (_) {
      // 忽略：环境不支持 FTS5 时检索用例需跳过
    }
  }

  db.dispose();
  return file;
}

/// 测试结束清理（可选）
void deleteTempDb(String path) {
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  final parent = f.parent;
  if (parent.existsSync()) parent.deleteSync(recursive: true);
}
