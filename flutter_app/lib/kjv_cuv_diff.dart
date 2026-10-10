// kjv_cuv_diff.dart
// 模块 A「对照阅读」的增强：标出 KJV 英文与和合本(CUV)中文意思不一致（或底本传统不同）
// 的经节，减少人工逐节核对的精力消耗。
//
// 数据来源：assets/web/kjv_cuv_diffs.json
//   - 初版为手工校订的种子清单（kjv_cuv_diffs_seed.json 由 analyze_kjv_cuv.py 扩展为全本）。
//   - 每行：{ type, severity, note, kjv_focus?, cuv_focus? }，key 为 "BOOK CH:VERSE"。
//
// 合规：本文件只读、不生成；差异标注只说明「两译所据底本/措辞不同」，绝不断言谁对谁错，
//       也绝不把和合本当作权威来源。KJV 始终是权威底本。

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// 单节差异记录
class KjvCuvDiff {
  final String ref;
  final String type; // text_tradition | archaic_kjv | wording
  final String severity; // high | medium | low
  final String note;
  final String? kjvFocus; // 需要加粗提示的 KJV 片段（可为空）
  final String? cuvFocus; // 需要加粗提示的和合本片段（可为空）

  const KjvCuvDiff({
    required this.ref,
    required this.type,
    required this.severity,
    required this.note,
    this.kjvFocus,
    this.cuvFocus,
  });

  factory KjvCuvDiff.fromJson(String ref, Map<String, dynamic> j) => KjvCuvDiff(
        ref: ref,
        type: (j['type'] as String?) ?? 'wording',
        severity: (j['severity'] as String?) ?? 'low',
        note: (j['note'] as String?) ?? '',
        kjvFocus: j['kjv_focus'] as String?,
        cuvFocus: j['cuv_focus'] as String?,
      );

  /// 中文类型标签
  String get typeLabel {
    switch (type) {
      case 'text_tradition':
        return '底本传统不同';
      case 'archaic_kjv':
        return 'KJV 古词';
      case 'wording':
        return '译法有异';
      default:
        return '含义有差异';
    }
  }

  /// 严重度排序值（high > medium > low）
  int get severityRank => {'high': 2, 'medium': 1, 'low': 0}[severity] ?? 0;

  /// 是否需要视觉强调（high/medium 用更明显的描边）
  bool get emphasised => severityRank >= 1;
}

/// 差异数据仓储（离线资产，rootBundle 加载，全局单例）
class KjvCuvDiffStore {
  static final Map<String, KjvCuvDiff> _byRef = {};
  static bool _loaded = false;

  /// 是否已加载（加载成功且有数据才为真）
  static bool get isAvailable => _byRef.isNotEmpty;

  /// 加载资产；重复调用安全（仅首次真正读取）。失败静默降级为「不标记任何差异」。
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final s =
          await rootBundle.loadString('assets/web/kjv_cuv_diffs.json');
      final data = jsonDecode(s) as Map<String, dynamic>;
      final items = data['items'] as Map<String, dynamic>? ?? {};
      for (final e in items.entries) {
        if (e.value is Map<String, dynamic>) {
          _byRef[_norm(e.key)] = KjvCuvDiff.fromJson(e.key, e.value);
        }
      }
    } catch (_) {
      // 资产缺失/损坏：不标记，不阻断阅读
    }
  }

  /// 取某节差异（ref 形如 "JHN 3:16" 或 "JHN3:16" 均可）
  static KjvCuvDiff? get(String ref) => _byRef[_norm(ref)];

  static String _norm(String s) =>
      s.replaceAll(RegExp(r'\s+'), '').toUpperCase();
}
