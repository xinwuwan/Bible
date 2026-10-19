// sda_commentary.dart
// 复临安息日会圣经注释（SDA Bible Commentary）外链构造。
//
// 数据源：bible-strong.app 第三方镜像（实测 HTTP 200、国内可达、不含 CF 挑战页）。
// 实测 URL 形态：https://bible-strong.app/commentary/en/sdabc/<osis>/<chapter>
//   - 书卷用 OSIS 码小写：gen / matt / john / 1cor …（已逐一验证 gen、matt、john、1cor 均 200）
//   - 章节为阿拉伯数字
//
// 合规说明：此处仅生成「跳转第三方页面的外链」，不内嵌任何 SDA 注释正文，
// 规避 SDA 注释（Nichol / Review and Herald）的版权风险。

/// 应用内 bookCode（3 字母，含数字前缀如 1CO）→ bible-strong 的 OSIS 小写码。
const Map<String, String> _bookCodeToOsis = {
  // 律法书
  'GEN': 'gen', 'EXO': 'exod', 'LEV': 'lev', 'NUM': 'num', 'DEU': 'deut',
  // 历史书
  'JOS': 'josh', 'JDG': 'judg', 'RUT': 'ruth', '1SA': '1sam', '2SA': '2sam',
  '1KI': '1kgs', '2KI': '2kgs', '1CH': '1chr', '2CH': '2chr', 'EZR': 'ezra',
  'NEH': 'neh', 'EST': 'esth',
  // 诗歌·智慧书
  'JOB': 'job', 'PSA': 'ps', 'PRO': 'prov', 'ECC': 'eccl', 'SNG': 'song',
  // 先知书
  'ISA': 'isa', 'JER': 'jer', 'LAM': 'lam', 'EZK': 'ezek', 'DAN': 'dan',
  'HOS': 'hos', 'JOL': 'joel', 'AMO': 'amos', 'OBA': 'obad', 'JON': 'jonah',
  'MIC': 'mic', 'NAM': 'nah', 'HAB': 'hab', 'ZEP': 'zeph', 'HAG': 'hag',
  'ZEC': 'zech', 'MAL': 'mal',
  // 福音书·使徒行传
  'MAT': 'matt', 'MRK': 'mark', 'LUK': 'luke', 'JHN': 'john', 'ACT': 'acts',
  // 保罗书信
  'ROM': 'rom', '1CO': '1cor', '2CO': '2cor', 'GAL': 'gal', 'EPH': 'eph',
  'PHP': 'phil', 'COL': 'col', '1TH': '1thess', '2TH': '2thess', '1TI': '1tim',
  '2TI': '2tim', 'TIT': 'titus', 'PHM': 'phlm',
  // 普通书信·启示录
  'HEB': 'heb', 'JAS': 'jas', '1PE': '1pet', '2PE': '2pet', '1JN': '1john',
  '2JN': '2john', '3JN': '3john', 'JUD': 'jude', 'REV': 'rev',
};

/// 由经文 ref（如 "JHN 3:16" / "1CO 13:4"）构造 SDA 注释外链；
/// 解析失败（书卷不在表内 / 缺章节）返回 null，调用方据此不显示按钮。
String? sdaCommentaryUrl(String ref) {
  final trimmed = ref.trim();
  if (trimmed.isEmpty) return null;
  // ref 首段为书卷码（"JHN" 或 "1CO"），空格后为 "章:节"
  final bookCode = trimmed.split(RegExp(r'\s+')).first.toUpperCase();
  final osis = _bookCodeToOsis[bookCode];
  if (osis == null) return null;
  // 取章节：优先匹配 "章:节"，否则取首个数字（容错无节号情形）
  final m = RegExp(r'(\d+)\s*:\s*\d+').firstMatch(trimmed) ??
      RegExp(r'(\d+)').firstMatch(trimmed);
  if (m == null) return null;
  final chapter = m.group(1)!;
  return 'https://bible-strong.app/commentary/en/sdabc/$osis/$chapter';
}
