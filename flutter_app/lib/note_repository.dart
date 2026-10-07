// note_repository.dart
// 模块 A 释经注记数据源抽象 + 两种实现。
//
// 设计要点:
//   - 注记由神学顾问在审核台产出、经 review_queue 审批后下发；客户端只读取、不生成。
//   - 【合规红线】只有 status == 'approved' 的注记允许展示给终端用户；
//     includeDraft 仅供开发联调，发布构建必须为 false。
//   - 离线优先：本地 SQLite 提供经文，注记优先取本地缓存/资产，联网时再拉远端。

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'app_models.dart';

abstract class NoteRepository {
  /// 按经节引用批量取注记。refs 形如 ['JHN 3:16','ROM 3:23']
  Future<List<ComparisonNote>> fetchForRefs(
    List<String> refs, {
    bool includeDraft = false,
  });
}

/// 远端实现：调用后端 GET /compare/verses?refs=... （契约见 mvp-breakdown.html）
/// 返回: {items:[{ref, kjv_text, our_zh, cuv_ref_text, note:{...}}]}
class RemoteNoteRepository implements NoteRepository {
  final String baseUrl;
  final http.Client client;
  final Duration timeout;

  RemoteNoteRepository({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : client = client ?? http.Client();

  @override
  Future<List<ComparisonNote>> fetchForRefs(
    List<String> refs, {
    bool includeDraft = false,
  }) async {
    if (refs.isEmpty) return const [];
    final uri = Uri.parse('$baseUrl/compare/verses').replace(
      queryParameters: {'refs': refs.join(',')},
    );
    final resp = await client.get(uri).timeout(timeout);
    if (resp.statusCode != 200) {
      throw Exception('取注记失败: HTTP ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const []);
    final out = <ComparisonNote>[];
    for (final raw in items) {
      final m = raw as Map<String, dynamic>;
      final noteJson = m['note'];
      if (noteJson is! Map<String, dynamic>) continue;
      final note = ComparisonNote.fromJson({
        ...noteJson,
        // 后端若未在 note 内回带 ref，则用外层 ref 兜底
        if (noteJson['ref'] == null && noteJson['verse_ref'] == null)
          'ref': m['ref'],
      });
      out.add(note);
    }
    return _gate(out, includeDraft);
  }
}

/// 资产实现：从 assets/notes.json 读取（离线演示 / CI / 无后端环境）。
/// JSON 结构为 [{ref, diff_type, observation, basis, implication, conclusion, status}]
class AssetNoteRepository implements NoteRepository {
  final String assetPath;

  const AssetNoteRepository({this.assetPath = 'assets/notes.json'});

  @override
  Future<List<ComparisonNote>> fetchForRefs(
    List<String> refs, {
    bool includeDraft = false,
  }) async {
    String text;
    try {
      text = await rootBundle.loadString(assetPath);
    } catch (_) {
      return const []; // 未打包注记资产时静默降级为「注记待补充」
    }
    final decoded = jsonDecode(text);
    final list = (decoded is List)
        ? decoded
        : (decoded is Map ? (decoded['items'] as List<dynamic>? ?? []) : []);
    final wanted = refs.map(_norm).toSet();
    final out = list
        .whereType<Map<String, dynamic>>()
        .map(ComparisonNote.fromJson)
        .where((n) => wanted.isEmpty || wanted.contains(_norm(n.ref)))
        .toList();
    return _gate(out, includeDraft);
  }
}

/// 内存实现：用于 widget 测试 / 本地联调，不依赖网络与资产。
class InMemoryNoteRepository implements NoteRepository {
  final List<ComparisonNote> notes;

  const InMemoryNoteRepository(this.notes);

  @override
  Future<List<ComparisonNote>> fetchForRefs(
    List<String> refs, {
    bool includeDraft = false,
  }) async {
    final wanted = refs.map(_norm).toSet();
    final out =
        notes.where((n) => wanted.isEmpty || wanted.contains(_norm(n.ref))).toList();
    return _gate(out, includeDraft);
  }
}

/// 发布闸门：过滤掉未审核通过的注记
List<ComparisonNote> _gate(List<ComparisonNote> src, bool includeDraft) {
  if (includeDraft) return src;
  return src.where((n) => n.isApproved).toList();
}

/// 归一化引用，便于比较（去空格、统一大写）
String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '').toUpperCase();
