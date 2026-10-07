// verse_compare_card.dart
// 模块 A 核心展示组件：单节「三栏对照」卡片。
//
// 三栏定位（视觉上必须层级分明，防止用户把和合本误当权威）:
//   ① KJV 英文        —— 权威来源（唯一底本）
//   ② 本应用中文译文  —— 本应用独立产出
//   ③ 和合本          —— 仅参照，灰色弱化，标注「不作为权威来源」
//
// 跨平台：宽度 >= 720 时三栏并排（平板/桌面），否则纵向堆叠（手机）。

import 'package:flutter/material.dart';

import 'app_models.dart';
import 'app_theme.dart';

class VerseCompareCard extends StatelessWidget {
  final VerseView verse;
  final ComparisonNote? note;
  final bool showCuv;      // 是否显示和合本参照栏
  final bool draftMode;    // 开发联调：允许展示 draft 注记（发布必须 false）
  final VoidCallback? onTapNote;

  const VerseCompareCard({
    super.key,
    required this.verse,
    this.note,
    this.showCuv = true,
    this.draftMode = false,
    this.onTapNote,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
                    color: AppTheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${verse.verse}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primary,
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
                if (note != null) _NoteChip(note: note!, draftMode: draftMode, onTap: onTapNote),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 720;
                final blocks = <Widget>[
                  _Block(
                    label: 'KJV（权威来源）',
                    badge: '权威',
                    text: verse.kjvText,
                    color: AppTheme.scriptureBlue,
                    emphasis: true,
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
                    ),
                ];
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: blocks
                        .map((b) => Expanded(child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: b,
                            )))
                        .toList(),
                  );
                }
                return Column(children: blocks);
              },
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

  const _Block({
    required this.label,
    required this.badge,
    required this.text,
    required this.color,
    required this.emphasis,
    this.muted = false,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            text,
            style: AppTheme.scripture(
              size: muted ? 13.5 : 15,
              color: muted ? AppTheme.inkSoft : AppTheme.ink,
              weight: emphasis ? FontWeight.w500 : FontWeight.w400,
              height: muted ? 1.55 : 1.65,
            ).copyWith(
              fontStyle: pending ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
