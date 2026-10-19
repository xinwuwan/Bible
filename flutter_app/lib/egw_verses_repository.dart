// egw_verses_repository.dart
// 怀爱伦经文论述离线仓库：读取 assets/web/egw_verses.json（{ref:[{book,ref,text}]}）。
// 空文件 / 缺失 / 解析失败均不阻塞应用——有数据才展示（见 verse_compare_card）。
//
// 数据由 _egw_fetch.py 生成；初次为 {}（空），用户本地跑抓取脚本后自动填充。

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'egw_verses.dart';

class EgwVersesRepository {
  static final EgwVersesRepository instance = EgwVersesRepository._();
  EgwVersesRepository._();

  final Map<String, List<EgwVerseRef>> _map = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final s = await rootBundle.loadString('assets/web/egw_verses.json');
      final data = jsonDecode(s) as Map<String, dynamic>;
      data.forEach((k, v) {
        if (v is List) {
          _map[k.trim().toUpperCase()] = v
              .whereType<Map<String, dynamic>>()
              .map((e) => EgwVerseRef.fromJson(e))
              .toList();
        }
      });
    } catch (_) {
      // 空 / 缺失 / 解析失败的兜底：保持 _map 为空，不抛异常
    }
    _loaded = true;
  }

  /// 取某经文的怀爱伦论述；未加载或不存在返回 null。
  List<EgwVerseRef>? get(String ref) {
    if (!_loaded) return null;
    return _map[ref.trim().toUpperCase()];
  }

  bool has(String ref) => get(ref) != null;
}
