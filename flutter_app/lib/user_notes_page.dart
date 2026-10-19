// user_notes_page.dart
// 「我的笔记」列表页：汇总本机保存的全部随手笔记。
//
// 能力:
//   - 点击条目 → 继续编辑（复用 UserNoteSheet，含删除）；
//   - 右侧「跳转到经文」→ 回调 onJumpToRef，由调用方打开对应对照页；
//   - 空状态引导用户去对照页记第一笔。
//
// 数据仅存本地（shared_preferences），不做任何服务端同步。

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'user_note.dart';
import 'user_note_repository.dart';
import 'user_note_sheet.dart';

class UserNotesPage extends StatefulWidget {
  /// 跳转到某条引用对应的对照页
  final void Function(String ref) onJumpToRef;

  const UserNotesPage({super.key, required this.onJumpToRef});

  @override
  State<UserNotesPage> createState() => _UserNotesPageState();
}

class _UserNotesPageState extends State<UserNotesPage> {
  @override
  void initState() {
    super.initState();
    UserNoteRepository.instance.ensureLoaded();
    UserNoteRepository.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    UserNoteRepository.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final List<UserNote> notes = UserNoteRepository.instance.all;
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的笔记'),
      ),
      body: notes.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              itemCount: notes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = notes[i];
                // ref 形如 'JHN 3:16'：拆成书卷代码 + 章:节
                final parts = n.ref.split(' ');
                final code = parts.isNotEmpty ? parts.first : n.ref;
                final cv =
                    parts.length > 1 ? parts.sublist(1).join(' ') : '';
                return ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    // FittedBox(scaleDown)：书卷代码/章:节文字随字号放大
                    // 超出 44px 徽章盒时自动缩小，永远完整可见（不裁切）
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            code,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                          if (cv.isNotEmpty)
                            Text(
                              cv,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.inkSoft,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  title: Text(
                    n.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _formatTime(n.updatedAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.inkSoft),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: '跳转到经文',
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    color: AppTheme.inkSoft,
                    onPressed: () => widget.onJumpToRef(n.ref),
                  ),
                  onTap: () {
                    // 编辑后的刷新由仓库 listener 统一驱动
                    UserNoteSheet.show(
                      context,
                      ref: n.ref,
                      initialText: n.text,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note_outlined,
                size: 56, color: AppTheme.inkSoft.withOpacity(0.5)),
            const SizedBox(height: 14),
            const Text(
              '还没有笔记',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink),
            ),
            const SizedBox(height: 6),
            const Text(
              '在对照页阅读时，点每节经文旁的铅笔图标，\n就能把此刻的感动与思考记下来。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.inkSoft, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
