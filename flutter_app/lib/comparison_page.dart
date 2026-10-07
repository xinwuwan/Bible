// comparison_page.dart
// 模块 A 主页面：对照阅读（KJV / 中文译文·和合本 + 释经注记）
//
// 数据流:
//   经文  ← 本地离线 SQLite（OfflineDbHelper.getChapter，离线可用）
//   注记  ← NoteRepository（远端优先，可降级为资产/内存实现）
//
// 合规:
//   - 中文译文采用公共领域和合本(1919)，标注出处；KJV 为唯一权威底本；
//   - 注记默认只显示 approved；draftMode 仅供联调，发布构建必须 false。

import 'package:flutter/material.dart';

import 'app_models.dart';
import 'app_theme.dart';
import 'comparison_note_sheet.dart';
import 'note_repository.dart';
import 'offline_db_helper.dart';
import 'verse_compare_card.dart';

class ComparisonPage extends StatefulWidget {
  final int bookId;
  final String bookName;
  final int chapterCount;
  final int initialChapter;
  final NoteRepository notes;
  final bool draftMode; // 发布必须为 false

  const ComparisonPage({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.chapterCount,
    this.initialChapter = 1,
    required this.notes,
    this.draftMode = false,
  });

  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  late int _chapter;
  List<VerseView> _verses = [];
  final Map<String, ComparisonNote> _noteMap = {};
  bool _loadingNotes = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _chapter = widget.initialChapter;
    _loadChapter();
  }

  void _loadChapter() {
    final rows = OfflineDbHelper.getChapter(widget.bookId, _chapter);
    setState(() {
      _verses = rows.map(VerseView.fromDbRow).toList();
      _noteMap.clear();
      _error = null;
    });
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (_verses.isEmpty) return;
    final refs = _verses.map((v) => v.ref).toList();
    setState(() => _loadingNotes = true);
    try {
      final list = await widget.notes.fetchForRefs(
        refs,
        includeDraft: widget.draftMode,
      );
      if (!mounted) return;
      setState(() {
        _noteMap
          ..clear()
          ..addEntries(list.map((n) => MapEntry(_normRef(n.ref), n)));
        _loadingNotes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingNotes = false;
        _error = '注记加载失败：${e.toString()}（经文本地仍可阅读）';
      });
    }
  }

  String _normRef(String s) => s.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  void _goto(int ch) {
    // clamp 返回 num，需 toInt() 才能赋给 int 字段
    final c = ch.clamp(1, widget.chapterCount).toInt();
    if (c == _chapter) return;
    setState(() => _chapter = c);
    _loadChapter();
  }

  void _openNote(ComparisonNote note) {
    ComparisonNoteSheet.show(
      context,
      note: note,
      onFeedback: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已记录反馈，将进入复核队列（review_queue）')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.bookName} 第 $_chapter 章'),
      ),
      body: Column(
        children: [
          // 章节导航（胶囊容器）
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.line),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 22),
                    onPressed: _chapter > 1 ? () => _goto(_chapter - 1) : null,
                  ),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _chapter,
                        isExpanded: true,
                        alignment: Alignment.center,
                        items: List.generate(
                          widget.chapterCount,
                          (i) => DropdownMenuItem<int>(
                            value: i + 1,
                            child: Text(
                              '第 ${i + 1} 章 / 共 ${widget.chapterCount} 章',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.ink,
                              ),
                            ),
                          ),
                        ),
                        onChanged: (v) => _goto(v ?? 1),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 22),
                    onPressed: _chapter < widget.chapterCount
                        ? () => _goto(_chapter + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          // 权威层级图例
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Row(
              children: [
                _LegendDot(color: AppTheme.scriptureBlue, text: 'KJV 权威底本'),
                const SizedBox(width: 10),
                _LegendDot(color: AppTheme.zhTeal, text: '中文译文·和合本'),
                const Spacer(),
                if (_loadingNotes)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: cs.error),
              ),
            ),
          const Divider(height: 8),
          // 经文列表
          Expanded(
            child: _verses.isEmpty
                ? const Center(child: Text('本章暂无离线数据'))
                : ListView.builder(
                    itemCount: _verses.length,
                    itemBuilder: (context, i) {
                      final v = _verses[i];
                      final note = _noteMap[_normRef(v.ref)];
                      return VerseCompareCard(
                        verse: v,
                        note: note,
                        draftMode: widget.draftMode,
                        onTapNote: note == null ? null : () => _openNote(note),
                      );
                    },
                  ),
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
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}
