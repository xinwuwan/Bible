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

  /// 保守同义词归一组（组内首词为规范词）。只归一根词，避免语义漂移。
  ///
  /// v51 扩充（7 组，均经 FMM 平局规则验证无回归）：
  ///   - 只收「指代同一实体的口语变体」，不收宽泛概念（防跨条目串味）；
  ///   - 裸「奉献」绝不入组（v49 铁律：防撞 idx242 幼儿奉献礼）；
  ///   - 「称义/救恩」不并入「得救」（idx22 因信称义条目会被 idx9 抢答）；
  ///   - 「医治/治病」不建组（idx6 已同持，归一无增益）。
  static const List<List<String>> _synGroups = [
    ['怀爱伦', 'egw', '预言之灵', '怀师母'],
    ['医疗布道', '健康事工', '医药布道', '健康布道', '医疗宣教', 'medical missionary'],
    ['祷告', '祈祷', '祈求'],
    ['洗礼', '受洗', '浸礼', '施洗'],
    ['得救', '怎么能得救', '怎样得救', '咋得救'],
    ['耶稣再来', '基督再来', '主再来', '耶稣再临'],
    ['悔改', '忏悔'],
    ['十一奉献', '什一', '纳什一'],
    ['圣灵', '保惠师'],
  ];

  /// 概念词典（全部条目的原始关键词 + 归一词），供正向最大匹配切分。
  late final Set<String> _conceptDict;
  late final int _maxConceptLen;

  OfflineQaLogic(this.faq, this.verseIndex) {
    _conceptDict = <String>{};
    var maxLen = 1;
    // 同义词组全体成员必须先入词典：否则非规范变体（如「忏悔」「施洗」「祈求」）
    // 若不在任何条目关键词中，FMM 永远切不出它们，归一组将形同虚设。
    for (final g in _synGroups) {
      for (final w in g) {
        final wl = w.toLowerCase();
        if (wl.isEmpty) continue;
        _conceptDict.add(wl);
        if (wl.length > maxLen) maxLen = wl.length;
      }
    }
    for (final entry in faq) {
      for (final raw in (entry['keywords'] as List<dynamic>? ?? const [])) {
        final kw = (raw as String).trim();
        if (kw.isEmpty) continue;
        final kl = kw.toLowerCase();
        final cl = _canon(kl);
        _conceptDict.add(kl);
        _conceptDict.add(cl);
        if (kl.length > maxLen) maxLen = kl.length;
        if (cl.length > maxLen) maxLen = cl.length;
      }
    }
    _maxConceptLen = maxLen;
  }

  static String _canon(String w) {
    final l = w.toLowerCase();
    for (final g in _synGroups) {
      if (g.contains(l)) return g[0].toLowerCase();
    }
    return l;
  }

  // ---------------------------------------------------------------------------
  // v53 未覆盖主题否决（与 kb.py unknown_topic_veto 完全一致）
  //
  // 根因（2026-10-24 实测）：覆盖率 = 命中概念数/问题概念数，而问题概念只能来自
  // 词典内切分——「怀爱伦的著作中，有哪些是关于家庭的？」里「家庭」不在任何
  // 关键词中，FMM 切不出它，对覆盖率完全不可见，cov=1.00 误判全覆盖，直接答了
  // 「入门路线」条目（答非所问）。同为「著作中关于X」的问句，问「饮食」时因
  // 「饮食」在词典中被切出、cov 降到 0.5 才正确转 RAG。
  // 否决后转 RAG/人工：检索仍可命中相关条目作 context，只是不硬答。
  //
  // 精化（防误伤）：残留词若已出现在最佳条目的答案文本中（如亚伯拉罕条目的
  // 答案写明「由父亲他拉带领」），说明条目确实覆盖了该词，不否决。
  // ---------------------------------------------------------------------------

  /// 疑问/功能填充词：切分后剩余的这些片段不构成「未覆盖实义主题」。
  static const List<String> _questionFiller = [
    '请问', '一下', '想问', '问一下', '告诉我', '讲讲', '说说', '指教', '指点',
    '解释', '介绍', '关于', '对于', '来说', '说来', '看来', '根据', '按照',
    '怎么样', '为什么', '能不能', '可不可以', '有没有', '是不是', '与否',
    '什么意思', '是什么意思', '啥意思', '意思',
    '可以', '应该', '应当', '该', '就', '够', '不够', '足以',
    '多少', '哪些', '哪个', '哪里', '哪儿', '哪来', '哪些人', '什么', '啥', '怎么',
    '怎样', '如何', '能否', '时候', '何时', '吗', '呢', '吧', '啊', '呀', '哦',
    '不', '没', '无', '别', '甭',
    '我们', '你们', '他们', '她们', '咱们', '大家', '我的', '你的', '他的',
    '我', '你', '他', '她', '它', '咱',
    '是', '有', '在', '和', '与', '及', '或', '而', '并', '的', '了', '着',
    '过', '把', '被', '让', '使', '会', '能', '要', '想', '得', '这', '那',
    '之', '其', '以', '为', '于', '从', '到', '对', '跟', '同', '向', '往',
  ];

  static final RegExp _punctRe = RegExp(
      "[\\s\\-_,.?!;:'\"()\\[\\]{}<>/\\\\|@#\$%^&*+=~`，。？！、；：「」『』（）《》〈〉…—·0-9]+");

  static String _stripFiller(String text) {
    final fillers = List<String>.from(_questionFiller)
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final f in fillers) {
      if (text.contains(f)) text = text.replaceAll(f, '');
    }
    return text;
  }

  /// FMM 切分，返回被概念词典吃掉的字符区间（与 _concepts 同一走法）。
  List<(int, int)> _cutSpans(String question) {
    final ql = question.toLowerCase();
    final spans = <(int, int)>[];
    var i = 0;
    while (i < ql.length) {
      var hitLen = 0;
      final room = ql.length - i;
      final limit = _maxConceptLen < room ? _maxConceptLen : room;
      for (var L = limit; L >= 2; L--) {
        if (_conceptDict.contains(ql.substring(i, i + L))) {
          hitLen = L;
          break;
        }
      }
      if (hitLen > 0) {
        spans.add((i, i + hitLen));
        i += hitLen;
      } else {
        i += 1;
      }
    }
    return spans;
  }

  /// FMM 切分后未被任何概念吃掉的字符，去填充词与标点后的实义残留。
  String _uncoveredResidue(String question) {
    final q = question;
    if (q.isEmpty) return '';
    final covered = List<bool>.filled(q.length, false);
    for (final (s, e) in _cutSpans(q)) {
      for (var k = s; k < e; k++) {
        covered[k] = true;
      }
    }
    final rest = StringBuffer();
    for (var k = 0; k < q.length; k++) {
      if (!covered[k]) rest.write(q[k]);
    }
    return _stripFiller(rest.toString()).replaceAll(_punctRe, '');
  }

  /// 残留实义词是否已被该条目答案文本涵盖（任一 2 字窗口命中即算）。
  static bool _residueCoveredBy(String residue, Map<String, dynamic> entry) {
    if (residue.length < 2) return true;
    final text = ((entry['answer_zh'] as String?) ?? '').toLowerCase();
    if (text.isEmpty) return false;
    final r = residue.toLowerCase();
    for (var i = 0; i < r.length - 1; i++) {
      if (text.contains(r.substring(i, i + 2))) return true;
    }
    return false;
  }

  /// 问题中存在未被概念词典覆盖、且未被最佳条目答案文本涵盖的实义片段(>=2字)
  /// -> true（不敢直接答，转 RAG/人工）。
  bool unknownTopicVeto(String question) {
    final q = question;
    if (q.isEmpty) return false;
    final residue = _uncoveredResidue(q);
    if (residue.length < 2) return false;
    final concepts = _concepts(q);
    if (concepts.isEmpty) return false;
    // 找无否决假设下的最佳条目，检查其文本是否涵盖残留词
    final best = _bestFaqIgnoringVeto(q);
    if (best == null) return false;
    return !_residueCoveredBy(residue, best);
  }

  /// _bestFaq 的无否决版（供 unknownTopicVeto 判断残留词是否被最佳条目覆盖）。
  Map<String, dynamic>? _bestFaqIgnoringVeto(String question) {
    final q = _concepts(question);
    if (q.isEmpty) return null;
    Map<String, dynamic>? best;
    var bestCov = 0.0;
    var bestScore = 0;
    var bestN = 0;
    for (final entry in faq) {
      final matched = _entryConcepts(entry).intersection(q);
      if (matched.isEmpty) continue;
      var score = 0;
      for (final m in matched) {
        score += m.length;
      }
      final cov = matched.length / q.length;
      if (best == null ||
          cov > bestCov ||
          (cov == bestCov && score > bestScore) ||
          (cov == bestCov && score == bestScore && matched.length > bestN)) {
        best = entry;
        bestCov = cov;
        bestScore = score;
        bestN = matched.length;
      }
    }
    return best;
  }

  /// 正向最大匹配（FMM）切分问题中的概念集合；空集表示无已知概念。
  Set<String> _concepts(String question) {
    final ql = question.toLowerCase();
    final out = <String>{};
    var i = 0;
    while (i < ql.length) {
      var hitLen = 0;
      final room = ql.length - i;
      final limit = _maxConceptLen < room ? _maxConceptLen : room;
      for (var L = limit; L >= 2; L--) {
        if (_conceptDict.contains(ql.substring(i, i + L))) {
          hitLen = L;
          break;
        }
      }
      if (hitLen > 0) {
        out.add(_canon(ql.substring(i, i + hitLen)));
        i += hitLen;
      } else {
        i += 1;
      }
    }
    return out;
  }

  Set<String> _entryConcepts(Map<String, dynamic> entry) {
    final kw = <String>{};
    for (final raw in (entry['keywords'] as List<dynamic>? ?? const [])) {
      final k = (raw as String).trim().toLowerCase();
      if (k.isNotEmpty) kw.add(_canon(k));
    }
    return kw;
  }

  /// 最佳 FAQ 匹配：按 (coverage, score) 双键排序。
  /// coverage = 被同一条目覆盖的问题概念数 / 问题概念总数。
  /// 返回 {'entry','score','coverage'}；无命中返回 null。
  /// v53：unknownTopicVeto 命中（问题含未覆盖实义主题）时返回 null——
  /// 宁可转 RAG/人工，不拿答非所问的条目硬答。
  Map<String, dynamic>? _bestFaq(String question) {
    final q = _concepts(question);
    if (q.isEmpty) return null;
    if (unknownTopicVeto(question)) return null;
    Map<String, dynamic>? best;
    var bestCov = 0.0;
    var bestScore = 0;
    var bestN = 0;
    for (final entry in faq) {
      final matched = _entryConcepts(entry).intersection(q);
      if (matched.isEmpty) continue;
      var score = 0;
      for (final m in matched) {
        score += m.length;
      }
      final cov = matched.length / q.length;
      if (best == null ||
          cov > bestCov ||
          (cov == bestCov && score > bestScore) ||
          (cov == bestCov && score == bestScore && matched.length > bestN)) {
        best = entry;
        bestCov = cov;
        bestScore = score;
        bestN = matched.length;
      }
    }
    if (best == null) return null;
    return {'entry': best, 'score': bestScore, 'coverage': bestCov};
  }

  /// 覆盖率门控：仅当问题概念被同一条目高比例覆盖时才直接回答，
  /// 否则宁缺毋滥（转 RAG 综合 / 人工），避免答非所问。
  static bool _shouldAnswerDirect(double coverage, int score) {
    if (coverage >= 0.999 && score >= 2) return true;
    if (coverage >= 0.6 && score >= 4) return true;
    return false;
  }

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
        answerZh: '【$ref】这是神的话语。KJV 为权威底本，本应用中文译文为独立产出（非现有中文译本，和合本仅作参照）。愿这段经文安慰你：\n\n**$zh**',
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

    // 2) FAQ 概念匹配（FMM 切分 + 同义词归一 + 覆盖率门控）。
    //    旧实现只累加命中关键词长度分：问题「怀爱伦的著作中哪些是关于
    //    健康事工的？」中「怀爱伦」即可命中教义条目（答非所问）。现在要求
    //    问题概念被同一条目高比例覆盖才直接答，否则转 RAG/人工。
    final m = _bestFaq(q);
    if (m != null) {
      final cov = m['coverage'] as double;
      final score = m['score'] as int;
      if (_shouldAnswerDirect(cov, score)) {
        final best = m['entry'] as Map<String, dynamic>;
        final citations = (best['citations'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(QaCitation.fromJson)
            .toList();
        final ans = QaAnswer(
          answerId: 'qa_offline_faq',
          answerZh: (best['answer_zh'] as String?) ?? '',
          citations: citations,
          confidence: (0.70 + 0.05 * score).clamp(0.0, 0.92),
          needsHuman: false,
        );
        return _enforce(ans);
      }
    }

    // 3) 无命中 -> 转人工（不臆测），但给出可操作的指引
    final ans = QaAnswer(
      answerId: 'qa_offline_needs_human',
      answerZh: '**亲爱的，这个问题我暂时没有在已审核的知识库中检索到确切依据；'
          '我不想凭空揣测、更不愿误导你，所以诚实地把不知道的留给你我都不敢妄言之处。** 在你等候真实牧者的回复之前，你可以：\n'
          '① 直接输入经文引用（如「路加福音3:23」或「Luke 3:23」），我立刻陪你查考并附上权威出处；\n'
          '② 换一个角度再问，例如围绕安息日、救恩、洗礼、耶稣的降生与复活、'
          '祷告、健康原则、末世预兆等主题；\n'
          '③ 点击下方「转人工顾问」，由真实的牧者亲自回复你。主必赐你平安。',
      citations: const [],
      confidence: 0.0,
      needsHuman: true,
    );
    return _enforce(ans);
  }

  /// 离线检索 top-K FAQ 条目（供 RAG 兜底作 context 用）。
  /// 返回条目本身（含 answer_zh / citations），调用方负责转成 RagContextItem。
  /// 排序与直接答一致：覆盖率优先、长度加权分次之。
  List<Map<String, dynamic>> retrieve(String question, {int topK = 3}) {
    final q = _concepts(question.trim());
    if (q.isEmpty) return const [];
    final scored = <Map<String, dynamic>>[];
    for (final entry in faq) {
      final matched = _entryConcepts(entry).intersection(q);
      if (matched.isEmpty) continue;
      var score = 0;
      for (final m in matched) {
        score += m.length;
      }
      scored.add({
        'entry': entry,
        'cov': matched.length / q.length,
        'score': score,
        'n': matched.length,
      });
    }
    scored.sort((a, b) {
      final c = (b['cov'] as double).compareTo(a['cov'] as double);
      if (c != 0) return c;
      final s = (b['score'] as int).compareTo(a['score'] as int);
      if (s != 0) return s;
      return (b['n'] as int).compareTo(a['n'] as int);
    });
    return scored
        .take(topK)
        .map((e) => e['entry'] as Map<String, dynamic>)
        .toList();
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
