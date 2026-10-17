// user_note_sheet.dart
// 用户随手笔记编辑弹层（对照页每节经文可呼出）。
//
// 与 comparison_note_sheet.dart（官方注记，只读）刻意区分:
//   - 本弹层是可读写的：多行输入 + 保存 / 删除；
//   - 不含任何权威声明——个人心得仅本人可见，不作为任何引用依据。

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'user_note.dart';
import 'user_note_repository.dart';

class UserNoteSheet extends StatefulWidget {
  final String ref;
  final String? initialText;

  const UserNoteSheet({super.key, required this.ref, this.initialText});

  /// 打开编辑弹层。返回 true 表示笔记有变更（新增/修改/删除），调用方据此刷新。
  static Future<bool?> show(
    BuildContext context, {
    required String ref,
    String? initialText,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => UserNoteSheet(ref: ref, initialText: initialText),
    );
  }

  @override
  State<UserNoteSheet> createState() => _UserNoteSheetState();
}

class _UserNoteSheetState extends State<UserNoteSheet> {
  late final TextEditingController _controller;
  late final bool _isExisting;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    _isExisting =
        (widget.initialText ?? '').trim().isNotEmpty;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写点什么再保存吧')),
      );
      return;
    }
    setState(() => _saving = true);
    // 先取 messenger：pop 之后当前 context 失效，无法再弹提示
    final messenger = ScaffoldMessenger.of(context);
    try {
      await UserNoteRepository.instance.save(
        UserNote(ref: widget.ref, text: text, updatedAt: 0),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('已保存到本机')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('保存失败：浏览器存储不可用（隐私模式或存储已满）'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条笔记？'),
        content: const Text('删除后不可恢复，仅影响本机保存的笔记。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await UserNoteRepository.instance.delete(widget.ref);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('已删除')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('删除失败：浏览器存储不可用')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      // 底部留出键盘高度，避免输入框被键盘遮挡
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_outlined, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '我的笔记 · ${widget.ref}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '随手记录此刻的感动与思考，仅保存在本机，不作任何引用依据。',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 8,
            minLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: '例如：这节让我想到……',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: AppTheme.bg,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_isExisting)
                TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('删除'),
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                ),
              const Spacer(),
              TextButton(
                onPressed:
                    _saving ? null : () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
