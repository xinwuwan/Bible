// egw_verses.dart
// 怀爱伦（Ellen G. White）经文论述数据模型。
//
// 数据源：EGW 著作为公有领域，可合法内嵌。实际文本由 _egw_fetch.py 从
// EGH Research 本地 API 或 egwwritings.org OAuth API 抓取后生成 egw_verses.json。
// 本文件只定义结构，不依赖任何网络。

class EgwVerseRef {
  final String book; // 著作名，如 "The Desire of Ages"
  final String ref; // 段落编号，如 "DA 175.3"
  final String text; // 论述正文

  const EgwVerseRef({
    required this.book,
    required this.ref,
    required this.text,
  });

  factory EgwVerseRef.fromJson(Map<String, dynamic> j) => EgwVerseRef(
        book: (j['book'] as String?) ?? '',
        ref: (j['ref'] as String?) ?? '',
        text: (j['text'] as String?) ?? '',
      );
}
