// offline_qa_logic.dart
// 模块 B 离线问答的纯 Dart 逻辑（不依赖 Flutter，可在沙箱用 dart 直接单测）。
// noqa: unused_import 已移除 dart:convert 依赖。
//
// 设计：与 backend/app/responder.py 的 OfflineResponder、kb.py 完全对齐。
// 数据来源：已加载的 KJV 经文（app_data.json）+ 打包的 qa_faq.json 信仰问答。
//
// 合规铁律：
//   - CUV 绝不进入引用（任何 CUV id 被强制剔除）
//   - 非人工回答若失去全部引用，强制转人工（绝不展示无依据的回答）
//   - 无命中直接转人工，不臆测
import 'qa_models.dart';

/// 书卷别名 -> 标准 3 字母代码（用于"约翰福音3章16节"这类中文引用解析）
const Map<String, String> bookAliases = {
  'genesis': 'GEN', '创世记': 'GEN', '創世記': 'GEN',
  'exodus': 'EXO', '出埃及记': 'EXO', '出埃及記': 'EXO',
  'leviticus': 'LEV', '利未记': 'LEV', '利未記': 'LEV',
  'numbers': 'NUM', '民数记': 'NUM', '民數記': 'NUM',
  'deuteronomy': 'DEU', '申命记': 'DEU', '申命記': 'DEU',
  'joshua': 'JOS', '约书亚记': 'JOS', '約書亞記': 'JOS',
  'judges': 'JDG', '士师记': 'JDG', '士師記': 'JDG',
  'ruth': 'RUT', '路得记': 'RUT', '路得記': 'RUT',
  '1 samuel': '1SA', '撒母耳记上': '1SA', '撒母耳記上': '1SA',
  '2 samuel': '2SA', '撒母耳记下': '2SA', '撒母耳記下': '2SA',
  '1 kings': '1KI', '列王纪上': '1KI', '列王紀上': '1KI',
  '2 kings': '2KI', '列王纪下': '2KI', '列王紀下': '2KI',
  '1 chronicles': '1CH', '历代志上': '1CH', '歷代志上': '1CH',
  '2 chronicles': '2CH', '历代志下': '2CH', '歷代志下': '2CH',
  'ezra': 'EZR', '以斯拉记': 'EZR', '以斯拉記': 'EZR',
  'nehemiah': 'NEH', '尼希米记': 'NEH', '尼希米記': 'NEH',
  'esther': 'EST', '以斯帖记': 'EST', '以斯帖記': 'EST',
  'job': 'JOB', '约伯记': 'JOB', '約伯記': 'JOB',
  'psalms': 'PSA', '诗篇': 'PSA', '詩篇': 'PSA',
  'proverbs': 'PRO', '箴言': 'PRO',
  'ecclesiastes': 'ECC', '传道书': 'ECC', '傳道書': 'ECC',
  'song of solomon': 'SNG', '雅歌': 'SNG',
  'isaiah': 'ISA', '以赛亚书': 'ISA', '以賽亞書': 'ISA',
  'jeremiah': 'JER', '耶利米书': 'JER', '耶利米書': 'JER',
  'lamentations': 'LAM', '耶利米哀歌': 'LAM',
  'ezekiel': 'EZK', '以西结书': 'EZK', '以西結書': 'EZK',
  'daniel': 'DAN', '但以理书': 'DAN', '但以理書': 'DAN',
  'hosea': 'HOS', '何西阿书': 'HOS', '何西阿書': 'HOS',
  'joel': 'JOL', '约珥书': 'JOL', '約珥書': 'JOL',
  'amos': 'AMO', '阿摩司书': 'AMO', '阿摩司書': 'AMO',
  'obadiah': 'OBA', '俄巴底亚书': 'OBA', '俄巴底亞書': 'OBA',
  'jonah': 'JON', '约拿书': 'JON', '約拿書': 'JON',
  'micah': 'MIC', '弥迦书': 'MIC', '彌迦書': 'MIC',
  'nahum': 'NAM', '那鸿书': 'NAM', '那鴻書': 'NAM',
  'habakkuk': 'HAB', '哈巴谷书': 'HAB', '哈巴谷書': 'HAB',
  'zephaniah': 'ZEP', '西番雅书': 'ZEP', '西番雅書': 'ZEP',
  'haggai': 'HAG', '哈该书': 'HAG', '哈該書': 'HAG',
  'zechariah': 'ZEC', '撒迦利亚书': 'ZEC', '撒迦利亞書': 'ZEC',
  'malachi': 'MAL', '玛拉基书': 'MAL', '瑪拉基書': 'MAL',
  'matthew': 'MAT', '马太福音': 'MAT', '馬太福音': 'MAT',
  'mark': 'MRK', '马可福音': 'MRK', '馬可福音': 'MRK',
  'luke': 'LUK', '路加福音': 'LUK',
  'john': 'JHN', '约翰福音': 'JHN', '約翰福音': 'JHN',
  'acts': 'ACT', '使徒行传': 'ACT', '使徒行傳': 'ACT',
  'romans': 'ROM', '罗马书': 'ROM', '羅馬書': 'ROM',
  '1 corinthians': '1CO', '哥林多前书': '1CO', '哥林多前書': '1CO',
  '2 corinthians': '2CO', '哥林多后书': '2CO', '哥林多後書': '2CO',
  'galatians': 'GAL', '加拉太书': 'GAL', '加拉太書': 'GAL',
  'ephesians': 'EPH', '以弗所书': 'EPH', '以弗所書': 'EPH',
  'philippians': 'PHP', '腓立比书': 'PHP', '腓立比書': 'PHP',
  'colossians': 'COL', '歌罗西书': 'COL', '歌羅西書': 'COL',
  '1 thessalonians': '1TH', '帖撒罗尼迦前书': '1TH', '帖撒羅尼迦前書': '1TH',
  '2 thessalonians': '2TH', '帖撒罗尼迦后书': '2TH', '帖撒羅尼迦後書': '2TH',
  '1 timothy': '1TI', '提摩太前书': '1TI', '提摩太前書': '1TI',
  '2 timothy': '2TI', '提摩太后书': '2TI', '提摩太後書': '2TI',
  'titus': 'TIT', '提多书': 'TIT', '提多書': 'TIT',
  'philemon': 'PHM', '腓利门书': 'PHM', '腓利門書': 'PHM',
  'hebrews': 'HEB', '希伯来书': 'HEB', '希伯來書': 'HEB',
  'james': 'JAS', '雅各书': 'JAS', '雅各書': 'JAS',
  '1 peter': '1PE', '彼得前书': '1PE', '彼得前書': '1PE',
  '2 peter': '2PE', '彼得后书': '2PE', '彼得後書': '2PE',
  '1 john': '1JN', '约翰一书': '1JN', '約翰一書': '1JN',
  '2 john': '2JN', '约翰二书': '2JN', '約翰二書': '2JN',
  '3 john': '3JN', '约翰三书': '3JN', '約翰三書': '3JN',
  'jude': 'JUD', '犹大书': 'JUD', '猶大書': 'JUD',
  'revelation': 'REV', '启示录': 'REV', '啟示錄': 'REV',
};

class OfflineQaLogic {
  final List<Map<String, dynamic>> faq;
  final Map<String, Map<String, dynamic>> verseIndex; // "gen 1:1" -> verse row

  OfflineQaLogic(this.faq, this.verseIndex);

  /// 从已加载的经文 + faq 列表构建（book_id -> book_code 映射索引经文）。
  factory OfflineQaLogic.build({
    required List<Map<String, dynamic>> verses,
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> faq,
  }) {
    final codeById = <int, String>{};
    for (final b in books) {
      final id = b['book_id'];
      final code = b['book_code'];
      if (id is int && code is String) codeById[id] = code;
    }
    final index = <String, Map<String, dynamic>>{};
    for (final v in verses) {
      final bid = v['book_id'];
      final code = bid is int ? codeById[bid] : null;
      if (code != null && v['chapter'] is int && v['verse'] is int) {
        index['${code.toLowerCase()} ${v['chapter']}:${v['verse']}'] = v;
      }
    }
    return OfflineQaLogic(faq, index);
  }

  QaAnswer answer(String question, {String locale = 'zh'}) {
    final q = question.trim();

    // 1) 经文引用直查（中英）
    final v = _lookupVerse(q);
    if (v != null) {
      final ref = (v['ref'] as String?) ?? '';
      final kjv = (v['kjv_text'] as String?) ?? '';
      final zhRaw = v['our_zh'];
      final zh = (zhRaw is String && zhRaw.isNotEmpty)
          ? zhRaw
          : '（中文译文待补充）';
      final ans = QaAnswer(
        answerId: 'qa_offline_${ref.replaceAll(' ', '')}',
        answerZh: '【$ref】KJV 英文底本（本应用中文译文为独立产出，非现有中文译本；和合本仅作参照）\n\n$zh',
        citations: [
          QaCitation(
            sourceType: QaSourceType.bible,
            sourceId: 'KJV-${ref.replaceAll(' ', '')}',
            ref: ref,
            snippet: kjv,
          ),
        ],
        confidence: 0.97,
        needsHuman: false,
      );
      return _enforce(ans);
    }

    // 2) FAQ 关键词匹配
    Map<String, dynamic>? best;
    var bestScore = 0;
    for (final entry in faq) {
      var score = 0;
      for (final raw in (entry['keywords'] as List<dynamic>? ?? const [])) {
        final kw = (raw as String).toLowerCase();
        if (q.toLowerCase().contains(kw)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }
    if (best != null && bestScore > 0) {
      final citations = (best['citations'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(QaCitation.fromJson)
          .toList();
      final ans = QaAnswer(
        answerId: 'qa_offline_faq',
        answerZh: (best['answer_zh'] as String?) ?? '',
        citations: citations,
        confidence: (0.70 + 0.05 * bestScore).clamp(0.0, 0.92),
        needsHuman: false,
      );
      return _enforce(ans);
    }

    // 3) 无命中 -> 转人工（不臆测），但给出可操作的指引
    final ans = QaAnswer(
      answerId: 'qa_offline_needs_human',
      answerZh: '这个问题我暂时没有在已审核的知识库中检索到确切依据。'
          '为避免臆测，我不会凭空作答。你可以：\n'
          '① 直接输入经文引用（如「路加福音3:23」或「Luke 3:23」），可立即查经并给出权威出处；\n'
          '② 换一种问法，例如围绕安息日、救恩、洗礼、耶稣的降生/复活/钉十字架、'
          '祷告、健康原则、末世预兆等主题提问；\n'
          '③ 点击下方按钮转交人工顾问答复。',
      citations: const [],
      confidence: 0.0,
      needsHuman: true,
    );
    return _enforce(ans);
  }

  Map<String, dynamic>? _lookupVerse(String q) {
    if (q.isEmpty) return null;
    final en = RegExp(r"([A-Za-z]{2,4})\s*(\d{1,3})\s*[:：]\s*(\d{1,3})")
        .firstMatch(q);
    if (en != null) {
      var code = en.group(1)!.toUpperCase();
      code = bookAliases[code.toLowerCase()] ?? code;
      final key = '${code.toLowerCase()} ${en.group(2)}:${en.group(3)}';
      if (verseIndex.containsKey(key)) return verseIndex[key];
    }
    for (final e in bookAliases.entries) {
      final name = e.key;
      if (name.length <= 2) continue; // 跳过过短别名（如"约"）避免误匹配
      if (q.contains(name)) {
        final m1 = RegExp(
                "${RegExp.escape(name)}\\s*第?\\s*(\\d{1,3})\\s*章\\s*第?\\s*(\\d{1,3})\\s*节?")
            .firstMatch(q);
        if (m1 != null) {
          final key = '${e.value.toLowerCase()} ${m1.group(1)}:${m1.group(2)}';
          if (verseIndex.containsKey(key)) return verseIndex[key];
        }
        final m2 = RegExp(
                "${RegExp.escape(name)}\\s*(\\d{1,3})\\s*[:：]\\s*(\\d{1,3})")
            .firstMatch(q);
        if (m2 != null) {
          final key = '${e.value.toLowerCase()} ${m2.group(1)}:${m2.group(2)}';
          if (verseIndex.containsKey(key)) return verseIndex[key];
        }
      }
    }
    return null;
  }

  QaAnswer _enforce(QaAnswer a) {
    final cites = a.citations.where((c) => !c.isCuv).toList();
    if (!a.needsHuman && cites.isEmpty) {
      return QaAnswer(
        answerId: a.answerId,
        answerZh: '（答案缺少权威引用，已转交人工顾问复核）${a.answerZh}',
        citations: const [],
        confidence: 0.0,
        needsHuman: true,
      );
    }
    if (cites.length != a.citations.length) {
      return QaAnswer(
        answerId: a.answerId,
        answerZh: a.answerZh,
        citations: cites,
        confidence: a.confidence,
        needsHuman: a.needsHuman,
      );
    }
    return a;
  }
}
