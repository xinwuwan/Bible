// egw_compare_page.dart
// 怀爱伦著作（怀著）中英对照阅读器。
//
// 重要事实：英文原著与中文译本分属 egwwritings.org 上两个相互独立的版本（不同书号、不同
// 分段、不同章节划分）。二者之间没有可靠的段落级对齐主键（英文 refcode 如 "MH 17.1" 与
// 中文 "MHF 1.9" 无法对应；且中文版 API 对部分英文章节仅暴露碎片段段）。因此本页**不强求
// 逐段 1:1 配对**，而是把英文原著与中文译本各自按原文顺序忠实呈现于独立栏，避免任何错配、
// 误译对照，确保「所见的英文即英文原文、所见的译文即中文译文」的准确性。
//
// 数据：assets/web/*.json（kEgwWorks 中 ready=true 的著作），结构为
//   [{ sec, kind, chapter, en_title, zh_title, en_count, zh_count,
//      en_paras:[{pid,etype,text}], zh_paras:[{pid,etype,text}] }, ...]
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
  bool _showEn = false; // 窄屏单语模式下默认显示中文（用户主语言）

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

  /// 归一化某一侧的段落列表：剔除标题类（etype 以 h 开头）、空文本，以及中文侧过短、
  /// 无句末标点的小节标题行（如「我们的榜样」「弟兄之爱」），避免它们造成偏移或孤立显示。
  List<dynamic> _cleanBody(List? paras) {
    final list = paras ?? [];
    final out = <dynamic>[];
    for (final p in list) {
      final et = (p['etype'] ?? 'p').toString();
      if (et.startsWith('h')) continue; // 标题不计入正文栏
      final t = (p['text'] ?? '').toString().trim();
      if (t.isEmpty) continue;
      // 中文短标题行：长度 <= 8 且无中文句末标点 → 视为小节标题，剔除
      if (t.length <= 8 && !RegExp(r'[。！？；：、，]').hasMatch(t)) continue;
      out.add(p);
    }
    return out;
  }

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
    final sec = _section;
    final enBody = _cleanBody(sec['en_paras'] as List?);
    final zhBody = _cleanBody(sec['zh_paras'] as List?);

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
        // 图例 + 窄屏语言切换
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
          child: Row(
            children: [
              Expanded(
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
              LayoutBuilder(
                builder: (ctx, c) {
                  if (c.maxWidth >= 720) return const SizedBox.shrink();
                  return ToggleButtons(
                    isSelected: [!_showEn, _showEn],
                    onPressed: (i) => setState(() => _showEn = i == 1),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
                    borderRadius: BorderRadius.circular(8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    selectedColor: Colors.white,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('中文', style: TextStyle(color: _showEn ? Colors.grey : AppTheme.zhTeal)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('英文', style: TextStyle(color: _showEn ? AppTheme.scriptureBlue : Colors.grey)),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        // 版本独立性说明（诚实提示：两版结构不同，按原文顺序并排，不强行逐段配对）
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Text(
            '英文原著与中文译本分属不同版本，段落结构独立；此处按各自原文顺序并排呈现，便于对照，不作强行逐段配对。',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
          ),
        ),
        const Divider(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 720) {
                return _buildTwoColumns(enBody, zhBody);
              }
              return _buildNarrow(enBody, zhBody);
            },
          ),
        ),
      ],
    );
  }

  /// 宽屏：左右双栏，各自按原文顺序忠实呈现，整页同步滚动（无逐段配对，杜绝错配）。
  Widget _buildTwoColumns(List<dynamic> enBody, List<dynamic> zhBody) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _langColumn('英文原著', AppTheme.scriptureBlue, enBody)),
          const SizedBox(width: 12),
          Expanded(child: _langColumn('中文译本', AppTheme.zhTeal, zhBody)),
        ],
      ),
    );
  }

  Widget _langColumn(String label, Color color, List<dynamic> body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColHeader(label: label, color: color),
        const SizedBox(height: 6),
        for (final p in body) _LangBlock(para: p, color: color),
      ],
    );
  }

  /// 窄屏：按语言切换，整章以该语言原文顺序呈现（默认中文）。
  Widget _buildNarrow(List<dynamic> enBody, List<dynamic> zhBody) {
    final body = _showEn ? enBody : zhBody;
    final color = _showEn ? AppTheme.scriptureBlue : AppTheme.zhTeal;
    final label = _showEn ? '英文原著' : '中文译本';
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColHeader(label: label, color: color),
          const SizedBox(height: 6),
          for (final p in body) _LangBlock(para: p, color: color),
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

/// 章节栏目标题（英文原著 / 中文译本）。
class _ColHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _ColHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// 单语块：正文用带左侧色条的卡片并标注语言。
class _LangBlock extends StatelessWidget {
  final dynamic para;
  final Color color;

  const _LangBlock({required this.para, required this.color});

  @override
  Widget build(BuildContext context) {
    final text = (para['text'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14.5, height: 1.7, color: AppTheme.ink),
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
