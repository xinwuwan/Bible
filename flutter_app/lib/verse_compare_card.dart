// verse_compare_card.dart
// 模块 A 核心展示组件：单节「三栏对照」卡片。
//
// 三栏定位（视觉上必须层级分明，防止用户把和合本误当权威）:
//   ① KJV 英文        —— 权威来源（唯一底本）
//   ② 本应用中文译文  —— 本应用独立产出（非任何现有中文译本）
//   ③ 和合本          —— 仅参照展示，灰色弱化，标注「不作为权威来源」
//
// 增强：当某节 KJV 与和合本(CUV)含义有差异（底本传统不同 / KJV 古词）时，
//   以琥珀色描边 + 「⚠ 中英差异」标签 + 说明条 明确标示，并把差异片段加粗，
//   大幅减少人工逐节核对的精力消耗。
//
// 跨平台：宽度 >= 720 时三栏并排（平板/桌面），否则纵向堆叠（手机）。

import 'package:flutter/material.dart';

import 'app_models.dart';
import 'app_theme.dart';
import 'egw_verses.dart';
import 'external_link_helper.dart';
import 'kjv_cuv_diff.dart';
import 'sda_commentary.dart';
import 'user_note.dart';

/// 差异标示用的琥珀色系
const Color _diffBorder = Color(0xFFE0A100);
const Color _diffBg = Color(0xFFFFF8E6);
const Color _diffChipBg = Color(0xFFFDE7C8);
const Color _diffChipFg = Color(0xFF8A5A00);
const Color _diffHiBg = Color(0xFFFFF0B3);

class VerseCompareCard extends StatefulWidget {
  final VerseView verse;
  final ComparisonNote? note;
  final bool showCuv; // 是否显示和合本参照栏
  final bool draftMode; // 开发联调：允许展示 draft 注记（发布必须 false）
  final VoidCallback? onTapNote;
  final KjvCuvDiff? diff; // 非 null 表示该节 KJV 与和合本存在需留意的差异
  final UserNote? userNote; // 用户本人对该节的随手笔记（本地）
  final VoidCallback? onTapUserNote; // 始终可点：无笔记则打开空白编辑器
  final List<EgwVerseRef>? egw; // 怀爱伦(EGW)对该节的论述（离线，有数据才展示）

  const VerseCompareCard({
    super.key,
    required this.verse,
    this.note,
    this.showCuv = true,
    this.draftMode = false,
    this.onTapNote,
    this.diff,
    this.userNote,
    this.onTapUserNote,
    this.egw,
  });

  @override
  State<VerseCompareCard> createState() => _VerseCompareCardState();
}

class _VerseCompareCardState extends State<VerseCompareCard> {
  // v53：SDA 注释内联展示状态（点击按钮在本条经文下方展开，不外跳网页）
  bool _commentaryOpen = false;
  bool _commentaryLoading = false;
  SdaCommentary? _commentary;
  String? _commentaryError;

  Future<void> _toggleCommentary() async {
    if (_commentaryOpen) {
      setState(() => _commentaryOpen = false);
      return;
    }
    if (_commentary != null) {
      setState(() => _commentaryOpen = true);
      return;
    }
    setState(() {
      _commentaryLoading = true;
      _commentaryError = null;
    });
    final result = await fetchSdaCommentary(widget.verse.ref);
    if (!mounted) return;
    setState(() {
      _commentaryLoading = false;
      if (result.commentary != null) {
        _commentary = result.commentary;
        _commentaryOpen = true;
      } else {
        _commentaryError = result.error;
        _commentaryOpen = true; // 展开以展示错误 + 外链兜底
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasDiff = widget.diff != null;
    final sdaUrl = sdaCommentaryUrl(widget.verse.ref);
    // 局部别名：StatelessWidget 改 StatefulWidget 后，原 build 体内的字段
    // 引用经别名桥接，避免大范围加 widget. 前缀。
    final verse = widget.verse;
    final egw = widget.egw;
    final note = widget.note;
    final userNote = widget.userNote;
    final draftMode = widget.draftMode;
    final showCuv = widget.showCuv;
    final diff = widget.diff;
    final onTapNote = widget.onTapNote;
    final onTapUserNote = widget.onTapUserNote;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      elevation: hasDiff ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasDiff
            ? BorderSide(color: _diffBorder, width: diff!.emphasised ? 2 : 1.3)
            : BorderSide.none,
      ),
      color: hasDiff ? _diffBg : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 节号 + 引用
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasDiff
                        ? _diffBorder.withOpacity(0.18)
                        : AppTheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${verse.verse}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasDiff ? _diffChipFg : AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Flexible + ellipsis：ref 与右侧注记 chip/铅笔按钮同处一行，
                // 大字号时 chip 变宽，ref 必须可收缩，否则整行横向溢出
                Flexible(
                  child: Text(
                    verse.ref,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.inkSoft,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const Spacer(),
                if (note != null)
                  _NoteChip(note: note, draftMode: draftMode, onTap: onTapNote),
                if (onTapUserNote != null)
                  IconButton(
                    tooltip: userNote != null ? '我的笔记' : '记一笔',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    iconSize: 18,
                    onPressed: onTapUserNote,
                    icon: Icon(
                      userNote != null
                          ? Icons.edit_note
                          : Icons.edit_note_outlined,
                      color: userNote != null
                          ? AppTheme.primary
                          : AppTheme.inkSoft,
                    ),
                  ),
              ],
            ),
            // 差异标签
            if (hasDiff)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _diffChipBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _diffBorder.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: _diffChipFg),
                      const SizedBox(width: 5),
                      Text(
                        '中英差异·${diff!.typeLabel}',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: _diffChipFg,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 720;
                final blocks = <Widget>[
                  _Block(
                    label: 'KJV（权威底本）',
                    badge: '权威',
                    text: verse.kjvText,
                    color: AppTheme.scriptureBlue,
                    emphasis: true,
                    highlight: diff?.kjvFocus,
                  ),
                  _Block(
                    label: '本应用中文译文',
                    badge: '本应用产出',
                    text: verse.ourZh ?? '（译文待补充）',
                    color: AppTheme.zhTeal,
                    emphasis: true,
                    pending: verse.ourZh == null,
                  ),
                  if (showCuv)
                    _Block(
                      label: '和合本（仅参照）',
                      badge: '仅参照·非权威',
                      text: verse.cuvRefText ?? '（无参照文本）',
                      color: AppTheme.cuvGrey,
                      emphasis: false,
                      muted: true,
                      highlight: diff?.cuvFocus,
                    ),
                ];
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: blocks
                        .map((b) => Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: b,
                              ),
                            ))
                        .toList(),
                  );
                }
                return Column(children: blocks);
              },
            ),
            // 差异说明条
            if (hasDiff)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _diffChipBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _diffBorder.withOpacity(0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1, right: 6),
                        child: Icon(Icons.info_outline,
                            size: 15, color: _diffChipFg),
                      ),
                      Expanded(
                        child: Text(
                          diff!.note,
                          style: const TextStyle(
                              fontSize: 12, color: _diffChipFg, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // 用户笔记预览（本机随手记，点击继续编辑）
            if (userNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Material(
                  color: AppTheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onTapUserNote,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1, right: 6),
                            child: Icon(Icons.edit_note,
                                size: 15, color: AppTheme.primary),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '我的笔记',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  userNote.text,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.5,
                                    color: AppTheme.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // 怀爱伦论述（EGW，离线数据，有数据才展示）
            if (egw != null && egw.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Material(
                  color: const Color(0xFFF3E5F5).withOpacity(0.45),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_stories,
                                size: 15, color: Color(0xFF6A1B9A)),
                            SizedBox(width: 6),
                            const Text(
                              '怀爱伦论述',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6A1B9A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...egw.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.text,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.5,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                if (e.book.isNotEmpty || e.ref.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      '— ${e.book}${e.ref.isNotEmpty ? ' ${e.ref}' : ''}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontStyle: FontStyle.italic,
                                        color: AppTheme.inkSoft,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // SDA 圣经注释（v53：内联展开显示本条注释，不外跳网页；
            // 保留「查看完整章节」外链作为兜底入口）
            if (sdaUrl != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _toggleCommentary,
                    icon: _commentaryLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _commentaryOpen
                                ? Icons.expand_less
                                : Icons.menu_book_outlined,
                            size: 16),
                    label: Text(_commentaryOpen ? '收起注释' : 'SDA 圣经注释'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ),
              if (_commentaryOpen)
                _SdaCommentaryPanel(
                  commentary: _commentary,
                  error: _commentaryError,
                  loading: _commentaryLoading,
                  ref: verse.ref,
                  sourceUrl: sdaUrl,
                  onRetry: _toggleCommentary,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 差异类型标签（点击展开注记详情）
class _NoteChip extends StatelessWidget {
  final ComparisonNote note;
  final bool draftMode;
  final VoidCallback? onTap;

  const _NoteChip({required this.note, required this.draftMode, this.onTap});

  @override
  Widget build(BuildContext context) {
    final unclassified = note.needsNormalize;
    final draft = note.status != 'approved';
    final bg = unclassified
        ? const Color(0xFFFFF3E0)
        : (draft ? const Color(0xFFF3E5F5) : const Color(0xFFE8F5E9));
    final fg = unclassified
        ? const Color(0xFFE65100)
        : (draft ? const Color(0xFF6A1B9A) : const Color(0xFF2E7D32));
    final label = unclassified
        ? '待规范化'
        : (draft && draftMode ? '${note.diffType.label}·草稿' : note.diffType.label);
    return ActionChip(
      backgroundColor: bg,
      label: Text(label, style: TextStyle(fontSize: 12, color: fg)),
      avatar: Icon(
        unclassified ? Icons.warning_amber_rounded : Icons.menu_book_outlined,
        size: 16,
        color: fg,
      ),
      onPressed: onTap,
    );
  }
}

/// 单个文本块（带来源徽标）
class _Block extends StatelessWidget {
  final String label;
  final String badge;
  final String text;
  final Color color;
  final bool emphasis;
  final bool muted;
  final bool pending;
  final String? highlight; // 差异片段：命中则加粗 + 浅底，辅助肉眼定位

  const _Block({
    required this.label,
    required this.badge,
    required this.text,
    required this.color,
    required this.emphasis,
    this.muted = false,
    this.pending = false,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.scripture(
      size: muted ? 13.5 : 15,
      color: muted ? AppTheme.inkSoft : AppTheme.ink,
      weight: emphasis ? FontWeight.w500 : FontWeight.w400,
      height: muted ? 1.55 : 1.65,
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
        color: muted
            ? const Color(0xFFF7F5F0)
            : color.withOpacity(0.035),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
          bottomLeft: Radius.circular(2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(muted ? 0.08 : 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.inkSoft,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _buildText(text, highlight, style, pending),
        ],
      ),
    );
  }

  /// 渲染正文：若 highlight 命中则把该片段加粗 + 浅琥珀底，便于一眼定位差异。
  Widget _buildText(
      String text, String? highlight, TextStyle style, bool pending) {
    final base = style.copyWith(
      fontStyle: pending ? FontStyle.italic : FontStyle.normal,
    );
    if (highlight == null ||
        highlight.isEmpty ||
        !text.contains(highlight)) {
      return Text(text, style: base);
    }
    final spans = <TextSpan>[];
    final idx = text.indexOf(highlight);
    if (idx > 0) spans.add(TextSpan(text: text.substring(0, idx)));
    spans.add(TextSpan(
      text: highlight,
      style: base.copyWith(
        fontWeight: FontWeight.bold,
        backgroundColor: _diffHiBg,
      ),
    ));
    final end = idx + highlight.length;
    if (end < text.length) spans.add(TextSpan(text: text.substring(end)));
    return Text.rich(TextSpan(children: spans, style: base));
  }
}

/// v53：SDA 圣经注释内联面板（经文卡片下方展开，不跳转网页）。
///
/// 注释原文为英文（SDA Bible Commentary 官方英文版），标题明确标注「英文原著」；
/// 附「查看完整章节」外链兜底（跳转源镜像页）。长文默认折叠，可展开全文。
class _SdaCommentaryPanel extends StatefulWidget {
  final SdaCommentary? commentary;
  final String? error;
  final bool loading;
  final String ref;
  final String sourceUrl;
  final VoidCallback onRetry;

  const _SdaCommentaryPanel({
    required this.commentary,
    required this.error,
    required this.loading,
    required this.ref,
    required this.sourceUrl,
    required this.onRetry,
  });

  @override
  State<_SdaCommentaryPanel> createState() => _SdaCommentaryPanelState();
}

class _SdaCommentaryPanelState extends State<_SdaCommentaryPanel> {
  bool _fullOpen = false;
  static const int _previewChars = 420;

  @override
  Widget build(BuildContext context) {
    final text = widget.commentary?.text ?? '';
    final clamped = !_fullOpen && text.length > _previewChars;
    final shown =
        clamped ? '${text.substring(0, _previewChars)}……' : text;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0FA),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book, size: 15, color: Color(0xFF6A1B9A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'SDA 圣经注释 · ${widget.ref}（英文原著）',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6A1B9A),
                    ),
                  ),
                ),
                if (widget.loading)
                  const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.loading)
              const Text(
                '正在按节抽取本条注释…',
                style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
              )
            else if (widget.commentary != null) ...[
              SelectableText(
                shown,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: AppTheme.ink,
                ),
              ),
              if (text.length > _previewChars)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _fullOpen = !_fullOpen),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text(
                      _fullOpen ? '收起全文 ▴' : '展开全文 ▾',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '来源：${widget.commentary!.source}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.inkSoft,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => openExternalLink(widget.sourceUrl),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                    ),
                    child: const Text(
                      '查看完整章节 ↗',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                widget.error ?? '注释获取失败',
                style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  TextButton(
                    onPressed: widget.onRetry,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                    ),
                    child: const Text(
                      '重试',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  TextButton(
                    onPressed: () => openExternalLink(widget.sourceUrl),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                    ),
                    child: const Text(
                      '打开原页面 ↗',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
