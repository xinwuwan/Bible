// user_note_repository.dart
// 用户随手笔记的本地仓库：shared_preferences 持久化（Web 落 localStorage，
// APK 落本地存储），单例供对照页 / 我的笔记页共用。
//
// 设计:
//   - 懒加载：首次使用时异步读盘，之后全内存操作，写入即时落盘；
//   - 合规：仅本地存储，不上传、不进任何引用审计链路——个人心得与权威内容隔离；
//   - 变更通知：version 自增 + 回调列表，页面据此刷新（避免引入 ValueNotifier 依赖）。

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'user_note.dart';

class UserNoteRepository {
  UserNoteRepository._();

  static final UserNoteRepository instance = UserNoteRepository._();

  static const String _prefsKey = 'user_notes_v1';

  final Map<String, UserNote> _map = {};
  bool _loaded = false;

  /// 每次增删改自增，页面可用来判断数据是否变化
  int version = 0;

  final List<void Function()> _listeners = [];

  void addListener(void Function() cb) => _listeners.add(cb);

  void removeListener(void Function() cb) => _listeners.remove(cb);

  void _notify() {
    version++;
    for (final cb in List<void Function()>.from(_listeners)) {
      cb();
    }
  }

  /// 异步预加载（应用启动或对照页 initState 调用一次即可）
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _map.clear();
          decoded.forEach((key, value) {
            final note = UserNote.fromJson(
              value is Map ? {...value, 'ref': key} : value,
            );
            if (note != null) _map[normUserNoteRef(key)] = note;
          });
        }
      } catch (_) {
        // 数据损坏时静默重置，不阻塞用户继续记笔记
        _map.clear();
      }
    }
    _loaded = true;
    _notify();
  }

  UserNote? get(String ref) => _map[normUserNoteRef(ref)];

  bool has(String ref) => _map.containsKey(normUserNoteRef(ref));

  /// 全部笔记，按更新时间倒序（新的在前）
  List<UserNote> get all {
    final list = _map.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  int get count => _map.length;

  Future<void> save(UserNote note) async {
    final key = normUserNoteRef(note.ref);
    final prev = _map[key];
    _map[key] = note.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await _persist();
    } catch (_) {
      // 落盘失败：回滚内存，避免「显示了却没存上」的假象
      if (prev != null) {
        _map[key] = prev;
      } else {
        _map.remove(key);
      }
      rethrow;
    }
    _notify();
  }

  Future<void> delete(String ref) async {
    final key = normUserNoteRef(ref);
    final prev = _map[key];
    if (prev == null) return;
    _map.remove(key);
    try {
      await _persist();
    } catch (_) {
      // 落盘失败：恢复内存中的原值
      _map[key] = prev;
      rethrow;
    }
    _notify();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{};
    _map.forEach((key, note) {
      payload[key] = note.toJson();
    });
    await prefs.setString(_prefsKey, jsonEncode(payload));
  }
}
