// comparison_note_sheet.dart
// 释经对照注记详情（底部弹层）。
//
// 语气红线（与 comparison_note 撰写规范一致）:
//   - 对事不对人：只陈述某处表述与权威原文的差异，不评价译者/教派；
//   - 结论中性：不使用「唯有本应用正确」一类绝对化表述；
//   - basis 必填：注记必须给出原文词形/语法/底本依据，否则视为无效。

import 'package:flutter/material.dart';

import 'app_models.dart';

class ComparisonNoteSheet extends StatelessWidget {
  final ComparisonNote note;
  final VoidCallback? onFeedback;

  const ComparisonNoteSheet({super.key, required this.note, this.onFeedback});

  static Future<void> show(
    BuildContext context, {
    required ComparisonNote note,
    VoidCallback? onFeedback,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          child: ComparisonNoteSheet(note: note, onFeedback: onFeedback),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(Icons.menu_book_outlined, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.ref,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: note.diffType.dbValue == null
                      ? const Color(0xFFFFF3E0)
                      : cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  note.diffType.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: note.diffType.dbValue == null
                        ? const Color(0xFFE65100)
                        : cs.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(note.diffType.hint, style: TextStyle(fontSize: 12, color: cs.outline)),

          // 数据治理告警：diff_type 非规范取值，无法入库
          if (note.needsNormalize) ...[
            const SizedBox(height: 12),
            _Banner(
              color: const Color(0xFFFFF3E0),
              border: const Color(0xFFE65100),
              icon: Icons.warning_amber_rounded,
              title: '差异类型取值不在规范枚举内',
              body: '当前取值「${note.rawDiffType}」不满足 comparison_note 的 CHECK 约束 '
                  '(archaic_kjv / mistranslation / text_tradition / consistent)，'
                  '无法入库。需由神学顾问重新判定归类后回填。',
            ),
          ],

          // draft 提醒
          if (note.status != 'approved') ...[
            const SizedBox(height: 12),
            _Banner(
              color: const Color(0xFFF3E5F5),
              border: const Color(0xFF6A1B9A),
              icon: Icons.gpp_maybe_outlined,
              title: '草稿状态：未经审核，不得对外发布',
              body: '当前 status = ${note.status}${note.author != null ? '（${note.author}）' : ''}。'
                  '仅开发联调可见，正式构建必须过滤为 approved。',
            ),
          ],

          const Divider(height: 24),

          _Section(title: '观察', body: note.observation),
          _Section(
            title: '依据（必填）',
            body: note.basis,
            highlight: true,
            helper: '原文词形 / 语法 / 底本依据，是判定差异性质的唯一凭据。',
          ),
          if (note.implication != null && note.implication!.isNotEmpty)
            _Section(title: '影响', body: note.implication!),
          if (note.conclusion != null && note.conclusion!.isNotEmpty)
            _Section(title: '结论', body: note.conclusion!),

          const SizedBox(height: 16),
          // 合规声明
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '本注记以 KJV 英文原文为唯一权威依据。和合本仅作参照展示，'
              '不作为权威来源，也不参与任何推理。对照结论只针对具体经文的译法，'
              '不构成对任何译本或群体的整体评价。',
              style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.5),
            ),
          ),
          if (onFeedback != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onFeedback,
                icon: const Icon(Icons.feedback_outlined),
                label: const Text('反馈此注记'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  final bool highlight;
  final String? helper;

  const _Section({
    required this.title,
    required this.body,
    this.highlight = false,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlight ? const Color(0xFF00695C) : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: highlight ? const Color(0xFFE0F2F1) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(body, style: const TextStyle(fontSize: 14, height: 1.55)),
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(helper!, style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final Color border;
  final IconData icon;
  final String title;
  final String body;

  const _Banner({
    required this.color,
    required this.border,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: border),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: border),
                ),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(fontSize: 12, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
