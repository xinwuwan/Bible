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
import 'kjv_cuv_diff.dart';

/// 差异标示用的琥珀色系
const Color _diffBorder = Color(0xFFE0A100);
const Color _diffBg = Color(0xFFFFF8E6);
const Color _diffChipBg = Color(0xFFFDE7C8);
const Color _diffChipFg = Color(0xFF8A5A00);
const Color _diffHiBg = Color(0xFFFFF0B3);

class VerseCompareCard extends StatelessWidget {
  final VerseView verse;
  final ComparisonNote? note;
  final bool showCuv; // 是否显示和合本参照栏
  final bool draftMode; // 开发联调：允许展示 draft 注记（发布必须 false）
  final VoidCallback? onTapNote;
  final KjvCuvDiff? diff; // 非 null 表示该节 KJV 与和合本存在需留意的差异

  const VerseCompareCard({
    super.key,
    required this.verse,
    this.note,
    this.showCuv = true,
    this.draftMode = false,
    this.onTapNote,
    this.diff,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiff = diff != null;
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
                    style: TextStyle(
                      fontSize: 12,
                      color: hasDiff ? _diffChipFg : AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  verse.ref,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.inkSoft,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                if (note != null)
                  _NoteChip(note: note!, draftMode: draftMode, onTap: onTapNote),
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
