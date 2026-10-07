// app_models.dart
// 模块 A 数据模型 —— 字段严格对齐 mvp-breakdown.html 的接口契约与
// 001_init_schema.sql 的 comparison_note 表结构。
//
// 权威层级（UI 必须让用户一眼看懂，不可混淆）:
//   1. KJV 英文       → 权威来源（唯一底本）
//   2. our_zh         → 本应用中文译文（应用独立产出，绝不采用任何现有
//                      中文译本；未产出时显示「译文待补充」）
//   3. cuv_ref_text   → 和合本(1919)参照栏（仅作参照展示，非权威、非译文）

/// 单节视图（来自离线 SQLite verse 表）
class VerseView {
  final int verse;
  final String ref;
  final String kjvText;
  final String? ourZh;
  final String? cuvRefText;

  const VerseView({
    required this.verse,
    required this.ref,
    required this.kjvText,
    this.ourZh,
    this.cuvRefText,
  });

  factory VerseView.fromDbRow(Map<String, dynamic> r) => VerseView(
        verse: r['verse'] as int,
        ref: r['ref'] as String,
        kjvText: r['kjv_text'] as String,
        ourZh: r['our_zh'] as String?,
        cuvRefText: r['cuv_ref_text'] as String?,
      );
}

/// 差异类型（canonical 取值以 DDL 的 CHECK 约束为准）
///   diff_type IN ('archaic_kjv','mistranslation','text_tradition','consistent')
enum DiffType {
  archaicKjv,      // KJV 早期现代英语古词导致的表述差异
  mistranslation,  // 译本偏离原意（须由顾问据原文词形/语法举证）
  textTradition,   // 所依底本/文本传统不同（如 TR vs 批判本），非译本对错
  consistent,      // 三者实质一致，无分歧
  unclassified,    // ⚠ 非规范取值（数据治理用，不应出现在已入库数据里）
}

extension DiffTypeX on DiffType {
  /// 中文标签
  String get label {
    switch (this) {
      case DiffType.archaicKjv:
        return 'KJV 古词';
      case DiffType.mistranslation:
        return '译法偏离原意';
      case DiffType.textTradition:
        return '底本传统不同';
      case DiffType.consistent:
        return '实质一致';
      case DiffType.unclassified:
        return '待规范化';
    }
  }

  /// 一句中性说明（用于对用户解释差异性质，避免"谁对谁错"的论战化表述）
  String get hint {
    switch (this) {
      case DiffType.archaicKjv:
        return '差异源于 1611 年英语词义变化，非译本错误。';
      case DiffType.mistranslation:
        return '据原文词形/语法，该处译法与原意存在偏差。';
      case DiffType.textTradition:
        return '所依据的原文抄本传统不同，属文本批判范畴，非译本对错。';
      case DiffType.consistent:
        return '各处译法实质一致，无神学分歧。';
      case DiffType.unclassified:
        return '差异类型取值不在规范枚举内，需顾问审核后重新归类。';
    }
  }

  /// 写入数据库时应当使用的 canonical 取值；unclassified 返回 null（不可入库）
  String? get dbValue {
    switch (this) {
      case DiffType.archaicKjv:
        return 'archaic_kjv';
      case DiffType.mistranslation:
        return 'mistranslation';
      case DiffType.textTradition:
        return 'text_tradition';
      case DiffType.consistent:
        return 'consistent';
      case DiffType.unclassified:
        return null;
    }
  }
}

/// 解析 diff_type：接受 canonical 值，并容忍历史/遗留别名。
/// ⚠ 重要：pilot 草稿里出现的 'wording' / 'archaism' / 'structure' 并非规范取值，
///   会被归为 unclassified 并在 UI 上显式标出「待规范化」，
///   而不是悄悄映射成某个看似合理的类型——避免替顾问做神学判断。
DiffType parseDiffType(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'archaic_kjv':
    case 'archaism':
      return DiffType.archaicKjv;
    case 'mistranslation':
      return DiffType.mistranslation;
    case 'text_tradition':
    case 'textual':
      return DiffType.textTradition;
    case 'consistent':
      return DiffType.consistent;
    default:
      return DiffType.unclassified;
  }
}

/// 释经对照注记（comparison_note）
class ComparisonNote {
  final String ref;
  final DiffType diffType;
  final String rawDiffType; // 保留原始取值，便于数据治理与排查
  final String observation; // 观察：具体差异是什么
  final String basis;       // 必填：原文词形/语法/底本依据
  final String? implication;
  final String? conclusion;
  final String status; // draft | approved | rejected
  final String? author;

  const ComparisonNote({
    required this.ref,
    required this.diffType,
    required this.rawDiffType,
    required this.observation,
    required this.basis,
    this.implication,
    this.conclusion,
    required this.status,
    this.author,
  });

  /// 合规红线：只有 approved 的注记才能对终端用户展示。
  bool get isApproved => status == 'approved';
  bool get needsNormalize => diffType == DiffType.unclassified;

  factory ComparisonNote.fromJson(Map<String, dynamic> j) {
    final raw = j['diff_type'] as String?;
    return ComparisonNote(
      ref: (j['ref'] ?? j['verse_ref'] ?? '') as String,
      diffType: parseDiffType(raw),
      rawDiffType: raw ?? '',
      observation: (j['observation'] ?? '') as String,
      basis: (j['basis'] ?? '') as String,
      implication: j['implication'] as String?,
      conclusion: j['conclusion'] as String?,
      status: (j['status'] ?? 'draft') as String,
      author: j['author'] as String?,
    );
  }
}

/// 书卷目录项（来自离线 SQLite book 表）
class BookMeta {
  final int bookId;
  final String bookCode;
  final String nameZh;
  final String testament; // OT / NT
  final int chapterCount;

  const BookMeta({
    required this.bookId,
    required this.bookCode,
    required this.nameZh,
    required this.testament,
    required this.chapterCount,
  });

  factory BookMeta.fromDbRow(Map<String, dynamic> r) => BookMeta(
        bookId: r['book_id'] as int,
        bookCode: r['book_code'] as String,
        nameZh: r['name_zh'] as String,
        testament: r['testament'] as String,
        chapterCount: r['chapter_count'] as int,
      );
}
