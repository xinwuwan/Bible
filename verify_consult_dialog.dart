// verify_consult_dialog.dart
// AI 医生助手问诊引擎（Dart 侧）纯逻辑验证：不依赖 Flutter 引擎，可在沙箱用 dart 直接跑。
// 运行：dart run verify_consult_dialog.dart
import 'dart:convert';
import 'dart:io';

import 'flutter_app/lib/consult_dialog_engine.dart';
import 'flutter_app/lib/consult_dialog_models.dart';

int passed = 0;
int failed = 0;

void check(String name, bool cond) {
  if (cond) {
    passed++;
    print('  PASS  $name');
  } else {
    failed++;
    print('  FAIL  $name');
  }
}

ConsultDialogEngine buildEngine() {
  final base = 'flutter_app/assets/web/';
  final scripts = ConsultScripts.fromJson(
      jsonDecode(File('${base}consult_scripts.json').readAsStringSync())
          as Map<String, dynamic>);
  final knowledge = <DiseaseKnowledge>[];
  for (final p in const [
    'disease_profiles.json',
    'disease_profiles_2.json',
  ]) {
    final j = jsonDecode(File('$base$p').readAsStringSync()) as Map<String, dynamic>;
    for (final d in (j['diseases'] as List).cast<Map<String, dynamic>>()) {
      knowledge.add(DiseaseKnowledge.fromJson(d));
    }
  }
  final rules = jsonDecode(File('${base}hospital_tier_a.json').readAsStringSync())
      as Map<String, dynamic>;
  return ConsultDialogEngine(
    scripts: scripts,
    knowledge: knowledge,
    tierMarks: (rules['tierMarks'] as List).cast<String>(),
    hospitalKeywords: (rules['hospitalKeywords'] as List).cast<String>(),
    majorKeywords: (rules['majorDiseaseKeywords'] as List).cast<String>(),
    severeKeywords: (rules['severeDiseaseKeywords'] as List).cast<String>(),
  );
}

void chief(ConsultDialogEngine e, String s) {
  final r = e.submit(s);
  if (r.phase != ConsultPhase.interviewing) {
    throw StateError('主诉未识别: "$s"（phase=${r.phase}）');
  }
}

void main() {
  print('== 数据规模 ==');
  final e0 = buildEngine();
  check('剧本已加载 (>=10)', e0.scripts.complaints.length >= 10);
  check('知识库已加载 (>=20)', e0.knowledge.length >= 20);
  check('知识库含多来源字段',
      e0.knowledge.every((k) => k.sources.isNotEmpty && k.furtherExams.isNotEmpty));

  // ---------- 场景 A：偏头痛（头痛剧本 8 题） ----------
  print('== 场景 A：偏头痛 ==');
  final a = buildEngine();
  a.start();
  chief(a, '我头痛三天了，一跳一跳地痛');
  a.submit('几小时内逐渐加重');
  a.submit('一跳一跳的搏动性疼痛');
  a.submit('固定在左边或右边一侧');
  a.submit('4～6 分，影响做事和睡觉');
  a.submit('恶心或呕吐、怕光、怕声音');
  a.submit('活动、上楼时加重，休息后减轻');
  a.submit('以前也有类似头痛（偏头痛体质）');
  final ra = a.submit('没吃药');
  check('A 产出报告', ra.report != null);
  check('A 首位是偏头痛',
      ra.report!.findings.isNotEmpty && ra.report!.findings.first.name == '偏头痛');
  check('A 偏头痛分级为可能性较大',
      ra.report!.findings.first.tier == '可能性较大');
  check('A 无红旗', ra.report!.redFlagMsg == null);
  check('A 有科室建议', ra.report!.department.isNotEmpty);
  check('A 有不确定性说明', ra.report!.uncertainties.length >= 3);
  check('A 有判断依据', ra.report!.findings.first.evidence.isNotEmpty);
  check('A 有需排除疾病', ra.report!.findings.first.exclude.isNotEmpty);
  check('A 有检查建议', ra.report!.findings.first.exams.isNotEmpty);

  // ---------- 场景 B：紧张性头痛 ----------
  print('== 场景 B：紧张性头痛 ==');
  final b = buildEngine();
  b.start();
  chief(b, '我头疼');
  b.submit('超过 3 天，时好时坏');
  b.submit('紧箍样或戴了紧帽子的感觉');
  b.submit('整个头都痛');
  b.submit('1～3 分，能忍受');
  b.submit('都没有');
  b.submit('睡一觉就明显好转');
  b.submit('长期睡眠不好或压力大');
  final rb = b.submit('没吃药');
  check('B 首位是紧张性头痛',
      rb.report!.findings.isNotEmpty && rb.report!.findings.first.name == '紧张性头痛');

  // ---------- 场景 C：突发剧烈头痛 → 选项级急症 ----------
  print('== 场景 C：突发剧烈头痛（急症） ==');
  final c = buildEngine();
  c.start();
  chief(c, '我头痛');
  final rc = c.submit('突然发生，几秒到几分钟内达到最痛');
  check('C 触发急症标记', rc.isRedFlag);
  check('C 急症文案含 120', rc.text.contains('120'));

  // ---------- 场景 D：胸痛超 20 分钟 → 选项级急症 ----------
  print('== 场景 D：胸痛 ==');
  final d = buildEngine();
  d.start();
  chief(d, '我胸痛');
  final rd = d.submit('持续超过 20 分钟不缓解');
  check('D 触发心梗急症', rd.isRedFlag && rd.text.contains('120'));

  // ---------- 场景 D2：典型心绞痛 ----------
  print('== 场景 D2：典型心绞痛（胸痛剧本 7 题） ==');
  final d2 = buildEngine();
  d2.start();
  chief(d2, '我胸闷');
  d2.submit('几分钟，休息后缓解');
  d2.submit('压榨样、石头压住感');
  d2.submit('胸骨后，放射到左臂/下巴/背');
  d2.submit('都没有');
  d2.submit('上楼、快走、情绪激动时出现，休息几分钟缓解');
  d2.submit('高血压/糖尿病/高血脂');
  final rd2 = d2.submit('没吃药');
  check('D2 首位是冠心病',
      rd2.report!.findings.isNotEmpty && rd2.report!.findings.first.name == '心绞痛 / 冠心病');
  check('D2 冠心病有完整资料 id',
      rd2.report!.findings.first.knowledgeId == 'chd');

  // ---------- 场景 E：痛风（关节剧本 6 题） ----------
  print('== 场景 E：痛风 ==');
  final g = buildEngine();
  g.start();
  chief(g, '我关节痛');
  g.submit('大脚趾根部的单个关节');
  g.submit('几小时到几天，来去如风');
  g.submit('红、肿、发热、碰不得');
  g.submit('尿酸体检高');
  g.submit('爱吃海鲜、动物内脏、肉汤、喝酒');
  final re = g.submit('以前关节痛发作过');
  check('E 首位是痛风',
      re.report!.findings.isNotEmpty && re.report!.findings.first.name == '痛风');
  check('E 痛风命中完整资料', re.report!.findings.first.knowledgeId == 'gout');

  // ---------- 场景 F：糖尿病 + 追问资料（血糖剧本 7 题） ----------
  print('== 场景 F：血糖问题 + 追问 ==');
  final f = buildEngine();
  f.start();
  chief(f, '我血糖有点高');
  f.submit('体检发现血糖偏高');
  f.submit('空腹血糖 8.2');
  f.submit('经常口渴、喝水多、尿多、夜尿增加');
  f.submit('3～12 个月');
  f.submit('父母或兄弟姐妹有糖尿病、体重超标（尤其是肚子大）');
  f.submit('基本不运动、爱吃精制米面、甜食、含糖饮料');
  final rf = f.submit('目前在吃二甲双胍');
  check('F 首位是 2 型糖尿病',
      rf.report!.findings.isNotEmpty && rf.report!.findings.first.name == '2 型糖尿病');
  final rf2 = f.submit('这个病严重吗？生活中要注意什么');
  check('F 追问返回完整资料卡', rf2.knowledge != null && rf2.knowledge!.id == 't2dm');
  check('F 资料卡含多来源', rf2.knowledge!.sources.length >= 3);
  check('F 资料卡含 NEWSTART 建议', rf2.knowledge!.advice.isNotEmpty);

  // ---------- 场景 G：抑郁 + 自伤红旗 ----------
  print('== 场景 G：情绪低落（自伤红旗） ==');
  final m = buildEngine();
  m.start();
  chief(m, '我情绪低落');
  m.submit('情绪低落、高兴不起来');
  m.submit('2 周以上，几乎每天');
  final rm = m.submit('有想伤害自己的念头');
  check('G 触发自伤急症', rm.isRedFlag && rm.text.contains('12356'));

  // ---------- 场景 H：胃部报警（胃剧本 6 题） ----------
  print('== 场景 H：胃部不适（报警症状） ==');
  final h = buildEngine();
  h.start();
  chief(h, '我胃胀');
  h.submit('上腹隐痛、闷痛');
  h.submit('和吃饭关系不大');
  h.submit('2 周～3 个月');
  final rh = h.submit('体重明显下降、大便发黑或呕血');
  check('H 触发报警红旗', rh.isRedFlag);
  h.submit('一向规律健康');
  final rh2 = h.submit('吃过铝碳酸镁');
  check('H 首位是胃癌',
      rh2.report!.findings.isNotEmpty && rh2.report!.findings.first.name == '胃癌');

  // ---------- 场景 I：附件融合 ----------
  print('== 场景 I：附件材料融合 ==');
  final i = buildEngine();
  i.start();
  chief(i, '我血糖高');
  i.submit('体检发现血糖偏高');
  final ri = i.addMaterial(
      '检验报告.txt',
      '首都医科大学宣武医院 检验报告\n临床诊断：2型糖尿病\n糖化血红蛋白 8.1\n空腹血糖 9.4');
  check('I 附件确认回复', ri.text.contains('已收到'));
  i.submit('空腹血糖 8.2');
  i.submit('经常口渴、喝水多、尿多、夜尿增加');
  i.submit('3～12 个月');
  i.submit('父母或兄弟姐妹有糖尿病、体重超标（尤其是肚子大）');
  i.submit('基本不运动');
  final ri2 = i.submit('没吃西药');
  check('I 报告含材料扫描', ri2.report!.material != null);
  check('I 材料识别出诊断', ri2.report!.material != null &&
      ri2.report!.material!.diagnoses.any((x) => x.contains('糖尿病')));
  check('I 材料识别出医院', ri2.report!.material != null &&
      ri2.report!.material!.hospitals.isNotEmpty);
  check('I 材料备注说明非系统诊断', ri2.report!.material != null &&
      ri2.report!.material!.notes.any((x) => x.contains('不是我的诊断结论')));
  check('I 材料含指标摘录', ri2.report!.material != null &&
      ri2.report!.material!.notes.any((x) => x.contains('糖化血红蛋白')));

  // ---------- 场景 J：边界情况 ----------
  print('== 场景 J：边界情况 ==');
  final j = buildEngine();
  final rj0 = j.start();
  check('J 开场含免责声明', rj0.text.contains('不能替代医生'));
  final rj1 = j.submit('今天天气不错');
  check('J 未识别主诉给快捷选项', rj1.quickOptions.isNotEmpty && rj1.text.contains('常见主诉'));
  chief(j, '我头痛');
  final rj2 = j.submit('重新开始');
  check('J 问诊中可重新开始', rj2.phase == ConsultPhase.chiefComplaint);
  final rj3 = j.submit('');
  check('J 空输入温和提示', rj3.text.contains('没有收到内容'));

  // ---------- 场景 K：弱证据 + 诚实兜底 ----------
  print('== 场景 K：资料不足时诚实回答 ==');
  final k = buildEngine();
  k.start();
  chief(k, '我头痛');
  k.submit('超过 3 天，时好时坏');
  k.submit('胀痛、发沉');
  k.submit('说不清楚');
  k.submit('1～3 分，能忍受');
  k.submit('都没有');
  k.submit('没什么规律');
  k.submit('都没有，一向健康');
  final rk = k.submit('没吃药');
  check('K 弱证据也产出报告', rk.report != null);
  final rk2 = k.submit('量子力学怎么入门');
  check('K 超范围问题诚实兜底', rk2.text.contains('超出') || rk2.text.contains('不想随便猜测'));

  print('');
  print('RESULT passed=$passed failed=$failed');
  if (failed > 0) exit(2);
}
