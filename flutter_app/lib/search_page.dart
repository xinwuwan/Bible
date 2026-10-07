// search_page.dart
// 检索入口：复用离线 SQLite 的 FTS5（中英文均可检索）。
// 查询串经 OfflineDbHelper.ftsQuery 做 CJK 逐字空格分词，与打包脚本对称。
//
// 点击结果 → 解析 ref（如 'JHN 3:16'）→ 回传 {bookId, chapter, name, count}
// 供首页直接跳转到对照页对应章节。

import 'package:flutter/material.dart';

import 'offline_db_helper.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _hits = [];
  List<Map<String, dynamic>> _books = [];
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _books = OfflineDbHelper.getBooks();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _run(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    setState(() {
      _searched = true;
      _error = null;
    });
    try {
      final res = OfflineDbHelper.search(query, limit: 80);
      setState(() => _hits = res);
    } catch (e) {
      setState(() {
        _hits = [];
        _error = '检索失败：${e.toString()}';
      });
    }
  }

  /// 把 'JHN 3:16' 解析为可跳转的章节定位
  Map<String, dynamic>? _resolve(String ref) {
    final parts = ref.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final code = parts[0].toUpperCase();
    final chapter = int.tryParse(parts[1].split(':').first);
    if (chapter == null) return null;
    for (final b in _books) {
      if ((b['book_code'] as String).toUpperCase() == code) {
        return {
          'bookId': b['book_id'] as int,
          'chapter': chapter,
          'name': b['name_zh'] as String,
          'count': b['chapter_count'] as int,
        };
      }
    }
    return null;
  }

  String _snippet(String? text, String q) {
    if (text == null || text.isEmpty) return '';
    final i = text.indexOf(q);
    if (i < 0) return text.length > 90 ? '${text.substring(0, 90)}…' : text;
    final start = i > 30 ? i - 30 : 0;
    // 避免 clamp 返回 num 导致 substring 传参类型不匹配
    final end = (start + 120) > text.length ? text.length : start + 120;
    return '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final q = _ctrl.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索经文（中文 / 英文均可）',
            border: InputBorder.none,
          ),
          onSubmitted: _run,
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (q.isNotEmpty)
            IconButton(icon: const Icon(Icons.search), onPressed: () => _run(q)),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : (!_searched
              ? const Center(child: Text('输入关键词后回车检索（离线可用）'))
              : (_hits.isEmpty
                  ? const Center(child: Text('没有匹配的经文'))
                  : ListView.separated(
                      itemCount: _hits.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final h = _hits[i];
                        final ref = h['ref'] as String? ?? '';
                        final kjv = h['kjv_text'] as String? ?? '';
                        final zh = h['our_zh'] as String? ?? '';
                        return ListTile(
                          title: Text(ref, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (zh.isNotEmpty)
                                Text(_snippet(zh, q), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                _snippet(kjv, q),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                          onTap: () {
                            final loc = _resolve(ref);
                            if (loc == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('无法定位：$ref')),
                              );
                              return;
                            }
                            Navigator.of(context).pop(loc);
                          },
                        );
                      },
                    ))),
    );
  }
}
