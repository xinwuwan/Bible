// egw_compare_page.dart
// 怀爱伦著作（怀著）中英对照阅读器：以英文原著为基准，逐段呈现中文译本，并附已核实的译校差异备注。
//
// 数据：assets/web/*.json（kEgwWorks 中 ready=true 的著作），结构为
//   [{ sec, en_title, zh_title, en_count, zh_count,
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
    final sec = _section;
    final enParas = (sec['en_paras'] as List?) ?? [];
    final zhParas = (sec['zh_paras'] as List?) ?? [];
    final maxLen = enParas.length >= zhParas.length
        ? enParas.length
        : zhParas.length;

    return Column(
      children: [
        // 章节选择（胶囊容器，复用圣经模块的弹性布局思路）
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
        // 英中对照图例
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
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
        const Divider(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: maxLen,
            itemBuilder: (context, i) {
              final en = i < enParas.length ? enParas[i] : null;
              final zh = i < zhParas.length ? zhParas[i] : null;
              return _ParaRow(en: en, zh: zh);
            },
          ),
        ),
      ],
    );
  }

  String _sectionLabel(int i) {
    final s = _sections[i];
    final zh = (s['zh_title'] ?? '').toString();
    final en = (s['en_title'] ?? '').toString();
    final head = zh.isNotEmpty ? zh : en;
    return '${i == 0 ? "前言 · " : "第 $i 章 · "}$head';
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

/// 单段对照：宽屏双栏（英 | 中），窄屏上下堆叠。
class _ParaRow extends StatelessWidget {
  final dynamic en;
  final dynamic zh;

  const _ParaRow({this.en, this.zh});

  @override
  Widget build(BuildContext context) {
    final enBlock = _LangBlock(
      label: '英文原著',
      para: en,
      color: AppTheme.scriptureBlue,
    );
    final zhBlock = _LangBlock(
      label: '中文译本',
      para: zh,
      color: AppTheme.zhTeal,
    );
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        if (wide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: enBlock),
                const SizedBox(width: 12),
                Expanded(child: zhBlock),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              enBlock,
              const SizedBox(height: 8),
              zhBlock,
            ],
          ),
        );
      },
    );
  }
}

/// 单语块：标题（etype 以 h 开头）用粗体居中；正文用带左侧色条的卡片并标注语言。
class _LangBlock extends StatelessWidget {
  final String label;
  final dynamic para;
  final Color color;

  const _LangBlock({required this.label, required this.para, required this.color});

  @override
  Widget build(BuildContext context) {
    if (para == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          '（本段 $label 无对应内容）',
          style: TextStyle(fontSize: 12, color: color.withOpacity(0.7), fontStyle: FontStyle.italic),
        ),
      );
    }
    final text = (para['text'] ?? '').toString();
    final isHeading = (para['etype'] ?? 'p').toString().startsWith('h');
    if (isHeading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.4,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 14.5, height: 1.7, color: AppTheme.ink),
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
