// verify_disease_kb.dart
// v57：疾病知识库数据闸门（Dart 直跑，不依赖 Flutter 引擎）。
// 校验：规模、字段完整性、分类/分级/支柱合法、id 与别名唯一、零外链、
//       关键诊断可检索（含用户遇到的孤立性纤维性肿瘤）。
// 运行：dart run verify_disease_kb.dart
import 'dart:convert';
import 'dart:io';

const base = 'flutter_app/assets/web';

const categories = {
  'cardio', 'neuro', 'resp', 'gi', 'renal', 'blood', 'immune', 'endo',
  'metabolic', 'tumor', 'mental', 'derm', 'eye', 'ent', 'ortho', 'gyne',
  'peds', 'infect', 'other',
};
const severity = {'major', 'severe', 'common'};
const pillars = {'NUT', 'EXE', 'WAT', 'SUN', 'TEM', 'AIR', 'RES', 'TRU'};

int passed = 0;
int failed = 0;
final errors = <String>[];

void check(String name, bool cond, [String detail = '']) {
  if (cond) {
    passed++;
    print('  PASS  $name');
  } else {
    failed++;
    print('  FAIL  $name ${detail.isNotEmpty ? '($detail)' : ''}');
  }
}

class Entry {
  final Map<String, dynamic> j;
  Entry(this.j);
  String get id => (j['id'] ?? '') as String;
  String get name => (j['name'] ?? '') as String;
  List<String> get aliases => (j['aliases'] as List?)?.cast<String>() ?? const [];
  List<String> get causes => (j['causes'] as List?)?.cast<String>() ?? const [];
  List<String> get impacts => (j['impacts'] as List?)?.cast<String>() ?? const [];
  List<String> get sources => (j['sources'] as List?)?.cast<String>() ?? const [];
  List<dynamic> get advice => (j['advice'] as List?) ?? const [];
}

bool hasUrl(String s) =>
    s.contains('http://') || s.contains('https://') || s.contains('www.');

List<Entry> loadAll() {
  final out = <Entry>[];
  for (final f in const [
    'disease_profiles.json',
    'disease_profiles_2.json',
    'disease_profiles_3.json',
  ]) {
    final j = jsonDecode(File('$base/$f').readAsStringSync()) as Map<String, dynamic>;
    for (final d in (j['diseases'] as List).cast<Map<String, dynamic>>()) {
      out.add(Entry(d));
    }
  }
  return out;
}

/// 最长别名匹配（双向包含：诊断含别名，或别名含诊断简称）
Entry? find(List<Entry> all, String diag) {
  Entry? best;
  var bestLen = 0;
  for (final p in all) {
    for (final a in [p.name, ...p.aliases]) {
      if (a.isEmpty) continue;
      final hit = diag.contains(a) || a.contains(diag);
      if (hit && a.length > bestLen) {
        best = p;
        bestLen = a.length;
      }
    }
  }
  return best;
}

void main() {
  print('== 规模 ==');
  final all = loadAll();
  check('知识库总规模 >= 85', all.length >= 85, 'actual=${all.length}');
  check('第三批 >= 60', all.length - 23 >= 60, 'actual=${all.length - 23}');

  print('== 字段完整性 ==');
  var schemaOk = true;
  var linkOk = true;
  final ids = <String>{};
  final aliasOwner = <String, String>{};
  for (final e in all) {
    final j = e.j;
    void bad(String m) {
      schemaOk = false;
      errors.add('[${e.id}] $m');
    }

    if (e.id.isEmpty || !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(e.id)) bad('id 非法');
    if (!ids.add(e.id)) bad('id 重复');
    if (e.name.length < 2) bad('name 过短');
    if (e.aliases.isEmpty) bad('aliases 为空');
    for (final a in e.aliases) {
      final prev = aliasOwner[a];
      if (prev != null && prev != e.id) bad('alias 与 $prev 冲突: $a');
      aliasOwner[a] = e.id;
    }
    if (!categories.contains(j['category'])) bad('category 非法: ${j['category']}');
    if (!severity.contains(j['severityHint'])) bad('severityHint 非法');
    if ((j['overview'] as String? ?? '').length < 20) bad('overview 过短');
    if (e.causes.length < 3) bad('causes < 3');
    if (e.impacts.length < 3) bad('impacts < 3');
    if ((j['prognosis'] as String? ?? '').length < 15) bad('prognosis 过短');
    if (e.sources.length < 2) bad('sources < 2');
    if (((j['differential'] as List?) ?? const []).length < 2) bad('differential < 2');
    if (((j['furtherExams'] as List?) ?? const []).length < 3) bad('furtherExams < 3');
    if (((j['seeDoctor'] as List?) ?? const []).length < 3) bad('seeDoctor < 3');
    if (e.advice.length < 3) bad('advice < 3');
    for (final a in e.advice) {
      final m = a as Map<String, dynamic>;
      if (!pillars.contains(m['pillar'])) bad('pillar 非法: ${m['pillar']}');
      if ((m['text'] as String? ?? '').length < 8) bad('advice.text 过短');
    }
    // 零外链（用户要求：全部内联、无外部网址）
    void walk(Object? v) {
      if (v is String) {
        if (hasUrl(v)) {
          linkOk = false;
          errors.add('[${e.id}] 疑似外链: ${v.substring(0, v.length > 40 ? 40 : v.length)}');
        }
      } else if (v is List) {
        v.forEach(walk);
      } else if (v is Map) {
        v.values.forEach(walk);
      }
    }

    walk(j);
  }
  check('全部条目 schema 合法', schemaOk,
      errors.where((e) => !e.contains('外链')).take(5).join(' | '));
  check('全库零外链', linkOk);

  print('== 关键诊断可检索 ==');
  for (final diag in const [
    '孤立性纤维性肿瘤', // 用户实际遇到的诊断（截图案例）
    '2型糖尿病', '肺炎', '甲亢', '带状疱疹', '乙肝', '痛风', '荨麻疹',
    '宫颈癌', '脑膜瘤', '脂肪瘤', '子宫肌瘤', '卵巢囊肿', '腰椎间盘突出症',
    '青光眼', '过敏性鼻炎', '失眠', '乳腺癌', '肺癌', '胃癌', '心梗',
    '房颤', '心衰', '肺结核', '肝硬化', '肾结石', '白血病', '淋巴瘤',
    '红斑狼疮', '强直性脊柱炎', '骨质疏松', '偏头痛', '紧张性头痛',
    '癫痫', '帕金森', '阿尔茨海默', '胃食管反流', '炎症性肠病',
    '肠易激', '胆石症', '胰腺炎', '痔疮', '幽门螺杆菌', '慢性肾炎',
    '尿路感染', '前列腺增生', '血小板减少', '甲减', '肥胖', '代谢综合征',
    '肝癌', '食管癌', '胰腺癌', '甲状腺癌', '卵巢癌', '手足口', '流感',
    '湿疹', '银屑病', '白内障', '颈椎病', '多囊卵巢', '乳腺纤维腺瘤',
  ]) {
    final p = find(all, diag);
    check('检索「$diag」', p != null, p?.name ?? 'NOT FOUND');
  }

  print('== 孤立性纤维性肿瘤专项（用户截图案例） ==');
  final sft = find(all, '孤立性纤维性肿瘤');
  check('SFT 可检索', sft != null);
  if (sft != null) {
    check('SFT id=sft', sft.id == 'sft', sft.id);
    check('SFT 含形成机制（>=3 条）', sft.causes.length >= 3);
    check('SFT 含健康影响（>=3 条）', sft.impacts.length >= 3);
    check('SFT 含权威来源（>=2 条）', sft.sources.length >= 2);
    check('SFT 别名覆盖 SFT', sft.aliases.contains('SFT'));
  }

  print('');
  if (failed > 0) {
    print('RESULT passed=$passed failed=$failed');
    for (final e in errors.take(20)) {
      print('  ERR $e');
    }
    exit(2);
  }
  print('RESULT passed=$passed failed=0');
}
