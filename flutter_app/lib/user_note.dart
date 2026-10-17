// user_note.dart
// 用户随手笔记模型（模块 A 对照页的个人心得）。
//
// 定位（与 note_repository.dart 的官方释经注记严格区分）:
//   - 官方注记 ComparisonNote：神学顾问产出、approved 后才展示，客户端只读；
//   - 用户笔记 UserNote：终端用户本人在对照阅读时随手记录，仅存本地，不参与任何
//     权威判定，也不与服务端同步（隐私优先，避免个人心得外传）。
//
// ref 归一化规则与官方注记一致：去空白、统一大写，如 'JHN 3:16'。

class UserNote {
  final String ref;
  final String text;
  /// 最近一次保存的 Unix 毫秒时间戳
  final int updatedAt;

  const UserNote({
    required this.ref,
    required this.text,
    required this.updatedAt,
  });

  UserNote copyWith({String? text, int? updatedAt}) {
    return UserNote(
      ref: ref,
      text: text ?? this.text,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'text': text,
        'updatedAt': updatedAt,
      };

  static UserNote? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final ref = raw['ref'];
    final text = raw['text'];
    if (ref is! String || text is! String || text.trim().isEmpty) return null;
    final at = raw['updatedAt'];
    return UserNote(
      ref: ref,
      text: text,
      updatedAt: at is int ? at : 0,
    );
  }
}

/// 引用归一化：去所有空白并转大写，保证 'JHN 3:16' / 'jhn3:16' 视为同一条。
String normUserNoteRef(String s) =>
    s.replaceAll(RegExp(r'\s+'), '').toUpperCase();
