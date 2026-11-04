// egw_compare_page.dart

// 怀爱伦著作（怀著）中英对照阅读器。

//

// 重要事实：英文原著与中文译本分属 egwwritings.org 上两个相互独立的版本（不同书号、不同

// 分段、不同章节划分）。二者之间没有可靠的段落级对齐主键（英文 refcode 如 "MH 17.1" 与

// 中文 "MHF 1.9" 无法对应）。因此本页采用**「内容长度平衡对齐」**：按原文顺序同时推进

// 英、中两侧，每当两侧累计字数接近时归为一组「对应单元」，逐组呈现。这样每一组英文块与

// 中文块都明确成组（宽屏左右并排、窄屏上下堆叠），用户一眼即可看出「这段英文 ↔ 这段中文」，

// 同时在无法严格逐句对应的地方保持诚实标注。

//

// 数据：assets/web/*.json（kEgwWorks 中 ready=true 的著作），结构为

//   [{ sec, kind, chapter, en_title, zh_title, en_count, zh_count,

//      en_paras:[{pid,etype,text}], zh_paras:[{pid,etype,text}],

//      pairs:[[en_idx...],[zh_idx...]], ... }]

// 其中 pairs 为「对应单元」：每组含英文侧若干段索引与中文侧若干段索引，均指向清洗后的

// en_paras / zh_paras 数组。

//

// 合规：英文原著与中文译本均取自 egwwritings.org 官方标准版（公有领域）；

// 译校备注仅客观标注偏差，不改动原文。



import 'dart:convert';



import 'package:flutter/material.dart';

import 'package:flutter/services.dart' show rootBundle;



import 'app_theme.dart';

import 'egw_works.dart';



/// 已核实的译校差异备注（按著作 code 索引，目前仅 SC 收录）。

const Map<String, List<String>> kEgwDeviationNotes = {

  'SC': [

    '【第3章·悔改】犹大认罪所引经文，英文为 Matthew 27:4，中文误标「太27:41」（太27:41 是祭司长戏弄耶稣，并非犹大）。',

    '【第3章】诗篇 51 篇结尾，中文误标「诗5:-14」，正确应为「诗 51」。',

    '【第4章·认罪】希伯来书 4:15（体恤我们的软弱），中文误标「来4:5」。',

    '【第6章·献身】耶利米书 31:3（我以永远的爱爱你），中文误标「耶3:3」（语义相反）。',

    '【第7章·信徒身份】哥林多后书 5:17（若有人在基督里，他就是新造的人），中文误标「林前15:17」。',

    '【第8章·成长】哥林多后书 3:18（荣上加荣），中文误标「林后2:17」。',

    '【第8章】以赛亚书 61:3（称为公义树），中文译文正确但误标「赛6:3」。',

    '【第11章·祈祷】马可福音 11:24（信是得着的），中文误标「可1:24」。',

    '【第13章·喜乐】马太福音 25:34（承受为你们所预备的国），中文误标「太25:24」（语义相反）。',

    '【第3章·诗篇51:7】"hyssop" 应译「牛膝草」，中文误作「牛藤草」（二者为不同植物）。',

    '【结构差异】英文出版前言（Foreword，含发行量与作者生平）在中文版被一篇独立的「序言」（福音呼召文）取代，英文前言无对应中译——二者并非同一文本。',

  ],

};



class EgwComparePage extends StatefulWidget {

  final EgwWork work;



  const EgwComparePage({super.key, required this.work});



  @override

  State<EgwComparePage> createState() => _EgwComparePageState();

}



class _EgwComparePageState extends State<EgwComparePage> {

  List<dynamic> _sections = [];

  int _secIndex = 1; // 默认进入第 1 章（索引 1 为 Chapter 1；索引 0 为前言）

  bool _loading = true;

  String? _error;



  @override

  void initState() {

    super.initState();

    _load();

  }



  Future<void> _load() async {

    try {

      final s = await rootBundle.loadString(widget.work.asset!);

      final data = jsonDecode(s);

      if (data is List && data.isNotEmpty) {

        _sections = data;

        // 默认跳到第 1 章（排除索引 0 的前言，除非全书只有前言）

        _secIndex = _sections.length > 1 ? 1 : 0;

      } else {

        _error = '对照数据为空';

      }

    } catch (e) {

      _error = '对照数据加载失败：${e.toString()}';

    }

    if (mounted) setState(() => _loading = false);

  }



  Map<String, dynamic> get _section => _sections[_secIndex];



  @override

  Widget build(BuildContext context) {

    final cs = Theme.of(context).colorScheme;

    return Scaffold(

      appBar: AppBar(

        title: Text('${widget.work.nameZh} · 中英对照'),

        centerTitle: false,

        actions: [

          if (kEgwDeviationNotes.containsKey(widget.work.code))

            IconButton(

              tooltip: '译校备注',

              icon: const Icon(Icons.rate_review_outlined),

              onPressed: _showDeviationNotes,

            ),

        ],

      ),

      body: _loading

          ? const Center(child: CircularProgressIndicator())

          : _error != null

              ? Center(

                  child: Padding(

                    padding: const EdgeInsets.all(24),

                    child: Text(_error!,

                        textAlign: TextAlign.center,

                        style: TextStyle(color: cs.error, fontSize: 14, height: 1.5)),

                  ),

                )

              : _buildBody(),

    );

  }



  Widget _buildBody() {

    return Column(

      children: [

        // 章节选择

        Padding(

          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),

          child: Container(

            constraints: const BoxConstraints(minHeight: 46),

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius: BorderRadius.circular(14),

              border: Border.all(color: AppTheme.line),

            ),

            child: Row(

              children: [

                const SizedBox(width: 10),

                const Icon(Icons.menu_book_outlined, size: 18, color: AppTheme.zhTeal),

                const SizedBox(width: 8),

                Expanded(

                  child: DropdownButtonHideUnderline(

                    child: DropdownButton<int>(

                      value: _secIndex,

                      isExpanded: true,

                      alignment: Alignment.centerLeft,

                      items: [

                        for (int i = 0; i < _sections.length; i++)

                          DropdownMenuItem<int>(

                            value: i,

                            child: Text(

                              _sectionLabel(i),

                              style: const TextStyle(

                                fontSize: 14,

                                fontWeight: FontWeight.w600,

                                color: AppTheme.ink,

                              ),

                            ),

                          ),

                      ],

                      onChanged: (v) => setState(() => _secIndex = v ?? _secIndex),

                    ),

                  ),

                ),

              ],

            ),

          ),

        ),

        // 图例

        Padding(

          padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),

          child: Wrap(

            spacing: 12,

            runSpacing: 4,

            crossAxisAlignment: WrapCrossAlignment.center,

            children: [

              _LegendDot(color: AppTheme.scriptureBlue, text: '英文原著'),

              _LegendDot(color: AppTheme.zhTeal, text: '中文译本'),

            ],

          ),

        ),

        // 对齐说明（诚实提示：两组文本源自不同版本，按内容块对照，非严格逐句对应）

        Padding(

          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),

          child: Text(

            '英文原著与中文译本分属不同版本、段落结构独立，无法逐句精确对应。此处按内容长度归为「对应组」，组内以整段英文 + 整段中文分块呈现（非逐句交错），便于对照阅读；若只需权威中译，可读下方「中文译本」整段。',

            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),

          ),

        ),

        // [Item 1·权威层级] 怀著(EGW)权威层级低于圣经 + 来源透明
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.zhTeal.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.zhTeal.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, size: 15, color: AppTheme.zhTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '怀爱伦著作（EGW）为灵修与神学辅助，权威层级低于圣经；本对照以英文原著为基准，中文译本取自 egwwritings.org 官方标准版（英文 book ' + '${widget.work.enBookId}' + '／中文 book ' + '${widget.work.zhBookId}' + '）。',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.inkSoft, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        // [Item 2·偏差可发现性] 本书有已核实译校偏差时，给出显眼内联提示（AppBar 另有详情弹层）
        if (kEgwDeviationNotes.containsKey(widget.work.code))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _showDeviationNotes,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.rate_review_outlined, size: 15, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '本书已核实 ' + '${kEgwDeviationNotes[widget.work.code]!.length}' + ' 处译校偏差（含个别经文引注误标与词语误译）。点此查看详情。',
                        style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900, height: 1.5),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: Colors.amber.shade700),
                  ],
                ),
              ),
            ),
          ),

        const Divider(height: 8),

        Expanded(child: _buildPairs()),

      ],

    );

  }



  /// 以「对应单元」为单位，逐组呈现英文与中文的明确配对。

  Widget _buildPairs() {

    final sec = _section;

    final en = (sec['en_paras'] as List?) ?? [];

    final zh = (sec['zh_paras'] as List?) ?? [];

    final rawPairs = (sec['pairs'] as List?) ?? [];



    // 退化处理：若数据缺少 pairs（旧格式），退化为整体两段并排。

    final pairs = <List<dynamic>>[];

    for (final p in rawPairs) {

      if (p is List && p.length == 2) pairs.add(p);

    }



    if (pairs.isEmpty) {

      pairs.add([

        [for (int i = 0; i < en.length; i++) i],

        [for (int i = 0; i < zh.length; i++) i],

      ]);

    }



    // 前言：英文版常含作者/出版者原序，中文数字版普遍未收录对应中译。

    final isForeword = (sec['kind'] ?? '').toString() == 'foreword';

    final zhMissing = isForeword && zh.isEmpty;



    return LayoutBuilder(

      builder: (ctx, c) {

        final wide = c.maxWidth >= 720;

        final list = ListView.separated(

          padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),

          itemCount: pairs.length,

          separatorBuilder: (_, __) => const SizedBox(height: 10),

          itemBuilder: (ctx, i) {

            final pair = pairs[i];

            final enIdx = (pair[0] as List?) ?? [];

            final zhIdx = (pair[1] as List?) ?? [];

            final enParas = <dynamic>[

              for (final ix in enIdx)

                if (ix is int && ix >= 0 && ix < en.length) en[ix]

            ];

            final zhParas = <dynamic>[

              for (final ix in zhIdx)

                if (ix is int && ix >= 0 && ix < zh.length) zh[ix]

            ];

            return _PairCard(

              index: i,

              wide: wide,

              enParas: enParas,

              zhParas: zhParas,

              isForeword: isForeword,

            );

          },

        );

        // 前言缺失中译时，列表顶部加一条温和说明，避免用户误以为缺数据。

        if (!zhMissing) return list;

        return Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            Padding(

              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),

              child: _forewordNote(),

            ),

            Expanded(child: list),

          ],

        );

      },

    );

  }



  /// 前言无对应中译时的温和说明条。

  Widget _forewordNote() {

    return Container(

      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(

        color: Colors.amber.shade50,

        borderRadius: BorderRadius.circular(10),

        border: Border.all(color: Colors.amber.shade200),

      ),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),

          const SizedBox(width: 8),

          Expanded(

            child: Text(

              '本篇前言为中文版未收录内容（英文原版序言，无对应中译），右栏中文将显示「中文版无前言」。',

              style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900, height: 1.5),

            ),

          ),

        ],

      ),

    );

  }



  String _sectionLabel(int i) {

    final s = _sections[i];

    final kind = (s['kind'] ?? (i == 0 ? 'foreword' : 'chapter')).toString();

    final ch = s['chapter'] ?? i;

    final zh = (s['zh_title'] ?? '').toString();

    final en = (s['en_title'] ?? '').toString();

    final head = zh.isNotEmpty ? zh : en;

    if (kind == 'foreword') return '前言 · $head';

    return '第 $ch 章 · $head';

  }



  void _showDeviationNotes() {

    final notes = kEgwDeviationNotes[widget.work.code]!;

    showModalBottomSheet<void>(

      context: context,

      isScrollControlled: true,

      shape: const RoundedRectangleBorder(

        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),

      ),

      builder: (ctx) => SizedBox(

        height: MediaQuery.of(ctx).size.height * 0.78,

        child: Column(

          children: [

            Padding(

              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),

              child: Row(

                children: [

                  const Icon(Icons.rate_review_outlined, size: 18, color: AppTheme.zhTeal),

                  const SizedBox(width: 6),

                  Expanded(

                    child: Text(

                      '《${widget.work.nameZh}》译校备注（${notes.length} 条）',

                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),

                    ),

                  ),

                  IconButton(

                    icon: const Icon(Icons.close, size: 18),

                    onPressed: () => Navigator.of(ctx).pop(),

                  ),

                ],

              ),

            ),

            const Divider(height: 1),

            Expanded(

              child: ListView.separated(

                padding: const EdgeInsets.all(16),

                itemCount: notes.length,

                separatorBuilder: (_, __) => const Divider(height: 12),

                itemBuilder: (_, i) => Text(

                  notes[i],

                  style: const TextStyle(fontSize: 13, height: 1.6),

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

}



/// 英文常见缩写集合（句子切分时保护，避免误在缩写句点处断句）。

const Set<String> _enAbbrev = {

  'mr', 'mrs', 'ms', 'dr', 'st', 'rev', 'no', 'vs', 'etc', 'fig', 'vol',

  'inc', 'ltd', 'ph', 'gen', 'exo', 'lev', 'num', 'deu', 'jos', 'jdg', 'rut',

  'sa1', 'sa2', 'ki1', 'ki2', 'ch1', 'ch2', 'ezr', 'neh', 'est', 'job', 'psa',

  'pro', 'ecc', 'sos', 'isa', 'jer', 'lam', 'eze', 'dan', 'hos', 'joe', 'amo',

  'oba', 'jon', 'mic', 'nah', 'hab', 'zep', 'hag', 'zec', 'mal', 'mat', 'mar',

  'luk', 'joh', 'act', 'rom', 'co1', 'co2', 'gal', 'eph', 'php', 'col', 'th1',

  'th2', 'ti1', 'ti2', 'tit', 'phm', 'heb', 'jas', 'pe1', 'pe2', 'jo1', 'jo2',

  'jo3', 'jud',

};



bool _isCjk(int cp) =>

    (cp >= 0x4E00 && cp <= 0x9FFF) ||

    (cp >= 0x3400 && cp <= 0x4DBF) ||

    (cp >= 0xF900 && cp <= 0xFAFF) ||

    (cp >= 0x3000 && cp <= 0x303F) ||

    (cp >= 0xFF00 && cp <= 0xFFEF);



/// 把一组段落合并为连续文本（英文段间补空格，纯中文段间直接相连，避免汉字间隙）。

String _mergeParas(List<dynamic> paras) {

  final buf = StringBuffer();

  for (final p in paras) {

    final t = (p is Map ? (p['text'] ?? '') : p.toString()).toString();

    if (t.isEmpty) continue;

    if (buf.isNotEmpty) {

      final last = buf.toString().runes.last;

      final first = t.runes.first;

      // 非「中文接中文」时才补空格（英文/数字/中英文边界都需要空格分隔）

      if (!_isCjk(last) || !_isCjk(first)) buf.write(' ');

    }

    buf.write(t);

  }

  return buf.toString();

}



/// 按句子拆分文本（中英文标点通用）。

/// 保护两类易误断的句点（均以不可见占位符 \u2063 临时替代，最后还原）：

///  1) 常见拉丁缩写（e.g./i.e./etc./圣经书卷缩写等）后的句点；

///  2) 紧贴右引号、且其后紧跟小写字母（句中引用而非真正句末）的句点，

///     例如 the phrase "the end." refers —— 避免把引号内容误拆成两句。

///     保护时连同其后的空白一并保留，避免粘连。

/// 真正句末的「句点+右引号」（其后为大写字母或文末）在主切分时断在引号之后，

/// 即整组 "…." 作为一句的收尾，不会把右引号甩到下一句。

/// 主切分采用「消费式」匹配（句界 = 句末标点 + 可选右引号 + 其后空白），

/// 并将标点并回前句，避免使用变宽后顾（Dart/JS 正则不支持）。

List<String> splitSentences(String text) {

  if (text.trim().isEmpty) return const [];

  var s = text

      .replaceAll('e.g.', 'e\u2063g\u2063')

      .replaceAll('i.e.', 'i\u2063e\u2063')

      .replaceAll('etc.', 'etc\u2063')

      .replaceAll(RegExp(r'\n+'), ' ');

  // 省略号（连续 2+ 个句点，或单字符 …）不当作句末，避免把 "…" 拆成空句。

  s = s.replaceAllMapped(RegExp(r'\.{2,}'), (_) => '…');

  s = s.replaceAllMapped(RegExp(r'\b([A-Za-z][A-Za-z0-9]{0,3})\.(?=\s)'), (m) {

    final tok = m.group(1)!.toLowerCase();

    return _enAbbrev.contains(tok) ? '${m.group(1)}\u2063' : m.group(0)!;

  });

  // 保护「句中引用」的句点：句点 + 右引号(含直角/弯角) + 其后空白 + 小写字母。

  // 捕获空白并重放，避免 "...end."refers 这类粘连。

  s = s.replaceAllMapped(RegExp(r'''(\.)(['’”])(\s*)(?=[a-z])'''),

      (m) => '\u2063${m.group(2)}${m.group(3)}');

  // 主切分：句界 = 句末标点 + 可选右引号 + 其后空白；标点并回前句。

  final delim = RegExp(r'''([.!?。！？]['’”"]?)\s*''');

  final out = <String>[];

  var last = 0;

  for (final m in delim.allMatches(s)) {

    final sentence = s.substring(last, m.end).replaceAll('\u2063', '.').trim();

    // 仅含标点/空白（如引用标记残留的孤立句点）的句子丢弃，避免空行。

    if (sentence.replaceAll(RegExp(r'[.!?。！？”’"\s]'), '').isNotEmpty) {

      out.add(sentence);

    }

    last = m.end;

  }

  final tail = s.substring(last).replaceAll('\u2063', '.').trim();

  if (tail.replaceAll(RegExp(r'[.!?。！？”’"\s]'), '').isNotEmpty) out.add(tail);

  return out;

}





/// 单个「对应组」卡片：组内英文与中文以整段分块呈现（窄屏上下、宽屏左右），

/// 避免逐句位置交错造成的「英句≠中句」错位错觉，便于对照阅读。

class _PairCard extends StatelessWidget {

  final int index;

  final bool wide;

  final List<dynamic> enParas;

  final List<dynamic> zhParas;

  final bool isForeword;



  const _PairCard({

    required this.index,

    required this.wide,

    required this.enParas,

    required this.zhParas,

    this.isForeword = false,

  });



  @override

  Widget build(BuildContext context) {

    // 前言且整组中文缺失：显示「中文版无前言」，不进入句子级渲染。

    final zhMissing = isForeword && zhParas.isEmpty;

    if (zhMissing) {

      return Container(

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius: BorderRadius.circular(12),

          border: Border.all(color: AppTheme.line),

        ),

        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            _groupTag(index),

            const SizedBox(height: 8),

            Padding(

              padding: const EdgeInsets.symmetric(vertical: 6),

              child: Text('（中文版无前言）',

                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),

            ),

          ],

        ),

      );

    }



    final enText = _mergeParas(enParas);

    final zhText = _mergeParas(zhParas);

    final enSents = splitSentences(enText);

    final zhSents = splitSentences(zhText);



    // 本组中文确实缺失（非前言、却无任何中文句子）：仅显示英文并温和提示，

    // 不再把英文句子配成空白中文（避免「英文缺对应中译」的观感）。

    if (zhSents.isEmpty && !isForeword) {

      final rows = <Widget>[];

      rows.add(Padding(

        padding: const EdgeInsets.only(bottom: 6),

        child: Text('（本组中文译本缺失，仅显示英文原著）',

            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),

      ));

      for (int i = 0; i < enSents.length; i++) {

        rows.add(_SentenceRow(en: enSents[i], zh: null, wide: wide));

        if (i < enSents.length - 1) rows.add(const SizedBox(height: 10));

      }

      return Container(

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius: BorderRadius.circular(12),

          border: Border.all(color: AppTheme.line),

        ),

        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [_groupTag(index), const SizedBox(height: 8), ...rows],

        ),

      );

    }



    // 中英分块呈现：英文整段 + 中文整段（均清晰标注），不再逐句位置交错。

    // 原因：EN/ZH 为相互独立的官方译本，段落/句子粒度不同；若按位置逐句配对，

    // 「英句3」与「中句3」常不对应，产生「翻译不准」的错位观感（实为对照机制所致）。

    // 改为分块呈现可消除该错觉，且中文（官方译本）得以完整、准确呈现。

    final scale = AppTheme.readingScale(context);

    final enBlock = _passageBlock('英文原著', AppTheme.scriptureBlue, enText, scale);

    final zhBlock = _passageBlock('中文译本', AppTheme.zhTeal, zhText, scale);

    final body = wide

        ? Row(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Expanded(child: enBlock),

              Container(

                width: 1,

                color: AppTheme.line,

                margin: const EdgeInsets.symmetric(horizontal: 10),

              ),

              Expanded(child: zhBlock),

            ],

          )

        : Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              enBlock,

              const SizedBox(height: 12),

              zhBlock,

            ],

          );



    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: AppTheme.line),

      ),

      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          _groupTag(index),

          const SizedBox(height: 8),

          body,

        ],

      ),

    );

  }



  /// 单语整段呈现：顶部小标签 + 左侧色条 + 整段正文。用于「对应组」内中英分块显示，

  /// 避免逐句位置交错造成的「英句≠中句」错位错觉。

  Widget _passageBlock(String label, Color color, String text, double scale) {

    return Container(

      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(

        color: color.withOpacity(0.04),

        borderRadius: BorderRadius.circular(8),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Padding(

            padding: const EdgeInsets.only(bottom: 6),

            child: Row(

              children: [

                Icon(Icons.menu_book_outlined, size: 14, color: color),

                const SizedBox(width: 6),

                Text(label,

                    style: TextStyle(

                        fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),

              ],

            ),

          ),

          Text(

            text,

            style: TextStyle(

                fontSize: 14.5 * scale, height: 1.7, color: AppTheme.ink),

          ),

        ],

      ),

    );

  }



  /// 组号标签行（对应 N）

  Widget _groupTag(int index) {

    return Row(

      children: [

        Container(

          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

          decoration: BoxDecoration(

            color: Colors.grey.shade100,

            borderRadius: BorderRadius.circular(20),

          ),

          child: Text('对应 ${index + 1}',

              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),

        ),

        const Spacer(),

        const Icon(Icons.compare_arrows_rounded, size: 14, color: Colors.grey),

      ],

    );

  }

}



/// 单句对照行：一句英文 + 一句中文（窄屏上下、宽屏左右）。任一侧缺失则仅显示另一侧。

class _SentenceRow extends StatelessWidget {

  final String? en;

  final String? zh;

  final bool wide;



  const _SentenceRow({required this.en, required this.zh, required this.wide});



  @override

  Widget build(BuildContext context) {

    final scale = AppTheme.readingScale(context);

    final enSide = _sentenceSide(context, '英文', AppTheme.scriptureBlue, en, scale);

    final zhSide = _sentenceSide(context, '中文', AppTheme.zhTeal, zh, scale);

    if (wide) {

      return Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Expanded(child: enSide ?? const SizedBox.shrink()),

          Container(width: 1, color: AppTheme.line, margin: const EdgeInsets.symmetric(horizontal: 10)),

          Expanded(child: zhSide ?? const SizedBox.shrink()),

        ],

      );

    }

    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        if (enSide != null) enSide,

        if (enSide != null && zhSide != null) const SizedBox(height: 8),

        if (zhSide != null) zhSide,

      ],

    );

  }



  /// 单句一侧：顶部小标签 + 左侧色条 + 正文。文本为 null（该侧句子缺失）时返回 null。

  /// [scale] 为屏幕宽度自适应系数（见 AppTheme.readingScale）。

  Widget? _sentenceSide(BuildContext context, String label, Color color, String? text, double scale) {

    if (text == null) return null;

    return Container(

      padding: const EdgeInsets.all(8),

      decoration: BoxDecoration(

        color: color.withOpacity(0.04),

        borderRadius: BorderRadius.circular(8),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Padding(

            padding: const EdgeInsets.only(bottom: 5),

            child: Row(

              children: [

                Container(width: 4, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),

                const SizedBox(width: 6),

                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),

              ],

            ),

          ),

          Text(

            text,

            style: label == '英文'

                // 英文一侧走系统无衬线（见 scriptureEn），半角空格正常、绝不粘连；

                // 中文一侧用通用衬线（含中文回退）。字号按屏幕宽度自适应。

                ? AppTheme.scriptureEn(size: 14.5 * scale, height: 1.7)

                : AppTheme.scripture(size: 14.5 * scale, height: 1.7),

          ),

        ],

      ),

    );

  }

}



class _LegendDot extends StatelessWidget {

  final Color color;

  final String text;



  const _LegendDot({required this.color, required this.text});



  @override

  Widget build(BuildContext context) {

    return Row(

      mainAxisSize: MainAxisSize.min,

      children: [

        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),

        const SizedBox(width: 4),

        Text(text, style: const TextStyle(fontSize: 11, color: Colors.black54)),

      ],

    );

  }

}

