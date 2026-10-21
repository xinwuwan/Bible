// consult_dialog_engine.dart
// AI 医生助手 —— 多轮问诊对话引擎（纯 Dart：不依赖 Flutter，可被 dart run 直接测试）。
//
// 设计原则（合规边界，不可逾越）：
// - 系统不做确定性诊断：只给出「可能性判断 + 依据 + 需排除疾病 + 建议检查」；
// - 急症信号（红旗规则）一旦触发，立即中断常规流程、优先输出就医指导；
// - 附件材料仅「呈现材料所示诊断/医院」，不把材料信息当作系统已确诊；
// - 每次结论必须带不确定性说明与免责声明；知识不足时诚实说明，不编造。

import 'consult_dialog_models.dart';

/// 问诊阶段
enum ConsultPhase {
  greeting, // 开场（自我介绍 + 询问主诉）
  chiefComplaint, // 等待主诉
  interviewing, // 逐题问诊中
  report, // 已出具分析报告
  followUp, // 报告后追问
}

/// 医生回复（一回合）
class DoctorReply {
  final String text;
  final List<String> quickOptions; // 快捷回复按钮（空 = 不显示）
  final ConsultPhase phase;
  final ConsultReport? report; // 结构化报告（UI 渲染卡片）
  final DiseaseKnowledge? knowledge; // 追问命中疾病资料（UI 渲染资料卡）
  final bool isRedFlag; // 急症样式
  final bool isSystemCard; // 免责/提示卡样式

  const DoctorReply({
    required this.text,
    this.quickOptions = const [],
    required this.phase,
    this.report,
    this.knowledge,
    this.isRedFlag = false,
    this.isSystemCard = false,
  });
}

class ConsultDialogEngine {
  final ConsultScripts scripts;
  final List<DiseaseKnowledge> knowledge;

  /// 材料级别识别关键词（来自 hospital_tier_a.json；可空）
  final List<String> tierMarks;
  final List<String> hospitalKeywords;
  final List<String> majorKeywords;
  final List<String> severeKeywords;

  ConsultPhase _phase = ConsultPhase.greeting;
  ComplaintScript? _script;
  int _qIndex = 0;
  final Map<String, String> _answers = {}; // choice/free 题答案
  final Map<String, List<String>> _multi = {}; // multi 题所选
  final List<String> _materialTexts = [];
  final List<String> _materialNames = [];
  ConsultReport? _lastReport;
  int _transIdx = 0;

  ConsultDialogEngine({
    required this.scripts,
    required this.knowledge,
    this.tierMarks = const [],
    this.hospitalKeywords = const [],
    this.majorKeywords = const [],
    this.severeKeywords = const [],
  });

  ConsultPhase get phase => _phase;
  int get answeredCount => _answers.length + _multi.length;
  int get totalQuestions => _script?.questions.length ?? 0;
  List<String> get materialNames => List.unmodifiable(_materialNames);

  /// 当前问题是否为多选（UI 用来决定选项是即发还是累积多选）
  bool get currentQuestionIsMulti {
    final s = _script;
    if (s == null ||
        _phase != ConsultPhase.interviewing ||
        _qIndex >= s.questions.length) {
      return false;
    }
    return s.questions[_qIndex].kind == QuestionKind.multi;
  }

  static const _disclaimer = '我是您的 AI 健康咨询助手，可以陪您逐步梳理症状、解读报告、'
      '科普疾病知识。需要先说明：我不能替代医生面诊与检查，任何判断都仅供您参考；'
      '情况严重或紧急时，请及时就医或拨打 120。';

  static const _transitions = [
    '谢谢您的信任，我了解了。',
    '别担心，我们一步一步来。',
    '您描述得很清楚，对我帮助很大。',
    '这些问题可能有点细，但每一条都关系到判断准不准。',
    '我在听，您慢慢说，不着急。',
    '嗯，我记下了，还想再和您确认一个细节。',
  ];

  /// 开场白 + 询问主诉（附快捷主诉按钮）
  DoctorReply start() {
    _phase = ConsultPhase.chiefComplaint;
    final labels = scripts.quickLabels;
    return DoctorReply(
      text: '$_disclaimer\n\n为了帮您分析，请先告诉我：**这次主要是哪里不舒服？'
          '\n（直接描述即可，比如「我头痛三天了」，也可以点下面的常见主诉）',
      quickOptions: labels,
      phase: _phase,
      isSystemCard: true,
    );
  }

  /// 上传附件：记录材料文本，医生确认收到
  DoctorReply addMaterial(String name, String text) {
    _materialNames.add(name);
    if (text.trim().isNotEmpty) {
      _materialTexts.add(text);
    }
    _phase = _phase == ConsultPhase.report || _phase == ConsultPhase.followUp
        ? ConsultPhase.followUp
        : _phase;
    final note = text.trim().isNotEmpty
        ? '我已经读到材料内容，分析时会把它和问答信息放在一起综合考虑。'
        : '这份材料我还读不到具体内容（图片或扫描件），方便的话请您把上面的'
            '关键信息（医院名称、诊断名称、主要异常指标）打字告诉我。';
    return DoctorReply(
      text: '已收到您的材料「$name」。$note',
      phase: _phase,
    );
  }

  /// 病人发来一条消息 → 医生回复
  DoctorReply submit(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return DoctorReply(
        text: '我没有收到内容～您把情况写给我，或者点下面的选项，我继续为您分析。',
        quickOptions: _currentQuickOptions(),
        phase: _phase,
      );
    }
    // 任何阶段都允许重新开始
    if ((text.contains('重新开始') || text.contains('重新问诊') || text == '重来') &&
        _phase != ConsultPhase.greeting &&
        _phase != ConsultPhase.chiefComplaint) {
      reset();
      return start();
    }
    switch (_phase) {
      case ConsultPhase.greeting:
      case ConsultPhase.chiefComplaint:
        return _onChiefComplaint(text);
      case ConsultPhase.interviewing:
        return _onAnswer(text);
      case ConsultPhase.report:
      case ConsultPhase.followUp:
        return _onFollowUp(text);
    }
  }

  /// 重置，重新开始一回合问诊
  void reset() {
    _phase = ConsultPhase.greeting;
    _script = null;
    _qIndex = 0;
    _answers.clear();
    _multi.clear();
    _materialTexts.clear();
    _materialNames.clear();
    _lastReport = null;
    _transIdx = 0;
  }

  // ---------------------------------------------------------------- 主诉

  DoctorReply _onChiefComplaint(String text) {
    final c = scripts.matchComplaint(text);
    if (c == null) {
      return DoctorReply(
        text: '抱歉，我没有从您的话里识别出明确的不适部位。'
            '您可以换一种说法（比如把最主要的症状放在最前面），'
            '或者直接点选下面的常见主诉：',
        quickOptions: scripts.quickLabels,
        phase: ConsultPhase.chiefComplaint,
      );
    }
    _script = c;
    _qIndex = 0;
    _phase = ConsultPhase.interviewing;
    _answers.clear();
    _multi.clear();

    final buf = StringBuffer();
    buf.write(c.greeting);
    if (c.emergency.isNotEmpty) {
      buf.write('\n\n⚠️ 先提醒一句：${c.emergency}');
    }
    final first = c.questions.isNotEmpty ? c.questions[0] : null;
    if (first == null) {
      return DoctorReply(text: buf.toString(), phase: _phase);
    }
    buf.write('\n\n${first.ask}');
    return DoctorReply(
      text: buf.toString(),
      quickOptions: _optionsOf(first),
      phase: _phase,
    );
  }

  // ---------------------------------------------------------------- 问诊

  DoctorReply _onAnswer(String text) {
    final script = _script;
    if (script == null) return start();
    final q = script.questions[_qIndex];

    if (q.kind == QuestionKind.multi) {
      _multi[q.id] = text
          .split(RegExp(r'[，,；;\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      _answers[q.id] = text;
    }

    // 本题选项级红旗（选择即触发）
    for (final rf in q.redFlags) {
      if (text.contains(rf)) {
        return _redFlagReply(_optionRedFlagMsg(rf));
      }
    }

    _qIndex += 1;
    if (_qIndex >= script.questions.length) {
      return _buildReport();
    }
    final next = script.questions[_qIndex];
    final transition = _transitions[_transIdx % _transitions.length];
    _transIdx += 1;
    return DoctorReply(
      text: '$transition\n\n${next.ask}',
      quickOptions: _optionsOf(next),
      phase: _phase,
    );
  }

  DoctorReply _redFlagReply(String msg) {
    _qIndex += 1;
    final script = _script;
    if (script == null || _qIndex >= script.questions.length) {
      return _buildReport(redFlagOverride: msg);
    }
    final next = script.questions[_qIndex];
    final transition = _transitions[_transIdx % _transitions.length];
    _transIdx += 1;
    return DoctorReply(
      text: '$msg\n\n$transition\n\n${next.ask}',
      quickOptions: _optionsOf(next),
      phase: _phase,
      isRedFlag: true,
    );
  }

  /// 选项级急症提示（自伤类信号优先给心理援助热线）
  static String _optionRedFlagMsg(String rf) {
    if (rf.contains('伤害自己') || rf.contains('自杀')) {
      return '**您刚才提到的「$rf」是一个需要认真对待的信号，请让我认真地对您说：'
          '这不是软弱，是疾病在说话，专业帮助很有效。请立即拨打心理援助热线 12356 '
          '或 120，或前往最近医院急诊——您的生命很重要，请给自己一次被帮助的机会。**';
    }
    return '**您刚才的选择提示可能存在急症风险。如果这些症状正在发生，'
        '请立即拨打 120 或前往最近医院急诊，不要等待后续问诊。**';
  }

  // ---------------------------------------------------------------- 分析

  DoctorReply _buildReport({String? redFlagOverride}) {
    final script = _script!;
    _phase = ConsultPhase.report;

    // 1) 组合红旗（跨题目条件）
    String? rfLevel;
    String? rfMsg = redFlagOverride;
    if (rfMsg == null) {
      for (final rule in script.redFlagRules) {
        var all = true;
        for (final cond in rule.allOf) {
          if (!cond.matches(_answerText(cond.qid))) {
            all = false;
            break;
          }
        }
        if (all) {
          rfLevel = rule.level;
          rfMsg = rule.msg;
          break;
        }
      }
    } else {
      rfLevel = 'emergency';
    }

    // 2) 鉴别评分
    final findings = <ConsultFinding>[];
    for (final d in script.differentials) {
      var score = 0;
      var hits = 0;
      final evidence = <String>[];
      for (final r in d.support) {
        if (r.matches(_answerText(r.qid))) {
          score += r.w;
          hits += 1;
          final key = r.opt ?? r.kw ?? '';
          if (key.isNotEmpty && !evidence.contains(key)) evidence.add(key);
        }
      }
      for (final r in d.against) {
        if (r.matches(_answerText(r.qid))) score -= r.w;
      }
      if (score < 1) continue;
      String tier;
      if (score >= 6 && hits >= 4) {
        tier = '可能性较大';
      } else if (score >= 3) {
        tier = '有可能';
      } else {
        tier = '需排除';
      }
      findings.add(ConsultFinding(
        name: d.name,
        tier: tier,
        score: score,
        evidence: evidence,
        exclude: d.exclude,
        exams: d.exams,
        knowledgeId: d.profileId,
      ));
    }
    findings.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return a.name.compareTo(b.name);
    });
    final top = findings.length > 4 ? findings.sublist(0, 4) : findings;

    // 3) 材料扫描（仅呈现材料所示信息）
    final material = _materialTexts.isEmpty ? null : _scanMaterial(_materialTexts.join('\n'));

    // 4) 不确定性与免责
    final total = script.questions.length;
    final answered = answeredCount;
    final uncertainties = <String>[
      '文字问诊无法完成体格检查与检验，以上判断仅基于您提供的信息，'
          '存在遗漏或偏差的可能；',
      '本次共 $total 个问题，您已回答 $answered 个——回答越完整，参考价值越高；',
      '相同的症状可能对应完全不同的病因（可轻可重），这就是需要医生面诊的原因。',
    ];

    final report = ConsultReport(
      findings: top,
      redFlagLevel: rfLevel,
      redFlagMsg: rfMsg,
      material: material,
      department: script.department,
      uncertainties: uncertainties,
    );
    _lastReport = report;

    final intro = StringBuffer();
    intro.write('好的，我们的问诊完成了。**根据您以上的回答，我整理出下面的分析——'
        '请把它当作就诊前的参考，而不是最终诊断。**');
    if (rfMsg != null) {
      intro.write('\n\n🚨 $rfMsg');
    }
    if (top.isEmpty) {
      intro.write('\n\n坦白说，以目前的信息我还不足以给出有意义的方向性判断。'
          '建议您补充更具体的症状描述（部位、持续时间、诱发缓解因素），'
          '或直接到${script.department}就诊，让医生当面评估。');
    }
    return DoctorReply(
      text: intro.toString(),
      report: report,
      phase: _phase,
      isRedFlag: rfMsg != null,
    );
  }

  // ---------------------------------------------------------------- 追问

  DoctorReply _onFollowUp(String text) {
    final t = text.trim();
    if (t.contains('重新开始') || t.contains('重新问诊') || t == '重来') {
      reset();
      return start();
    }

    // 1) 点名问某个病 → 直接给资料
    final byName = _findKnowledge(t);
    if (byName != null) {
      return DoctorReply(
        text: '关于「${byName.name}」，我为您整理了以下资料。'
            '这些内容综合自权威医学科普与指南，供您了解：',
        knowledge: byName,
        phase: ConsultPhase.followUp,
      );
    }

    // 2) 泛泛问「严重吗/怎么办/注意什么」→ 答当前报告首位疾病
    final askingAdvice = t.contains('严重') ||
        t.contains('怎么办') ||
        t.contains('注意') ||
        t.contains('怎么治') ||
        t.contains('怎么改善') ||
        t.contains('调理') ||
        t.contains('预防');
    if (askingAdvice && _lastReport != null && _lastReport!.findings.isNotEmpty) {
      final top = _lastReport!.findings.first;
      DiseaseKnowledge? k;
      if (top.knowledgeId.isNotEmpty) {
        k = _knowledgeById(top.knowledgeId);
      }
      k ??= _knowledgeByName(top.name);
      if (k != null) {
        return DoctorReply(
          text: '结合刚才的分析，您目前最需要了解的是「${k.name}」。'
              '关于它的成因、影响和日常改善，我为您整理如下：',
          knowledge: k,
          phase: ConsultPhase.followUp,
        );
      }
      final matched = (_script?.differentials ?? const <Differential>[])
          .where((e) => e.name == top.name)
          .toList();
      if (matched.isNotEmpty && matched.first.brief != null) {
        final d = matched.first;
        return DoctorReply(
          text: '结合刚才的分析，您目前最需要了解的是「$top.name」。'
              '我把整理到的信息先简要告诉您：',
          knowledge: _knowledgeFromBrief(d.name, d.brief!),
          phase: ConsultPhase.followUp,
        );
      }
    }

    // 3) 问「还要做什么检查/看什么科」
    if (t.contains('检查') || t.contains('科室') || t.contains('挂号') || t.contains('看哪个')) {
      final r = _lastReport;
      if (r != null) {
        final dept = r.department;
        final exams = r.findings.isEmpty
            ? const <String>[]
            : r.findings.first.exams;
        final buf = StringBuffer('**建议您挂${dept}。**');
        if (exams.isNotEmpty) {
          buf.write('\n\n就诊前可以先和医生沟通这些检查的必要性与顺序：');
          for (final e in exams) {
            buf.write('\n· $e');
          }
        }
        buf.write('\n\n就诊时建议带上：身份证/医保卡、既往病历、正在服用的药物清单，'
            '以及您在本模块上传过的材料。');
        return DoctorReply(
          text: buf.toString(),
          phase: ConsultPhase.followUp,
        );
      }
    }

    // 4) 诚实兜底
    return DoctorReply(
      text: '这个问题超出了我目前资料库能可靠回答的范围，我不想随便猜测误导您。'
          '建议您：① 把问题带到${_script?.department ?? '相应专科'}门诊当面问医生；'
          '② 如果症状正在加重，请不要等待，及时就医。'
          '\n\n您也可以继续问我关于刚才分析中某种疾病的情况（直接说病名即可），'
          '或者回复「重新开始」再梳理一次症状。',
      quickOptions: const ['重新开始'],
      phase: ConsultPhase.followUp,
    );
  }

  DiseaseKnowledge? _findKnowledge(String text) {
    final names = <String>{
      ...knowledge.map((k) => k.name),
      ...(_script?.differentials.map((d) => d.name) ?? const <String>[]),
    };
    DiseaseKnowledge? best;
    var bestLen = 0;
    for (final n in names) {
      if (n.isNotEmpty && text.contains(n) && n.length > bestLen) {
        bestLen = n.length;
        best = _knowledgeByName(n);
      }
    }
    return best;
  }

  DiseaseKnowledge? _knowledgeByName(String name) {
    for (final k in knowledge) {
      if (k.name == name) return k;
    }
    for (final k in knowledge) {
      if (name.contains(k.name)) return k;
    }
    return null;
  }

  DiseaseKnowledge? _knowledgeById(String id) {
    for (final k in knowledge) {
      if (k.id == id) return k;
    }
    return null;
  }

  DiseaseKnowledge _knowledgeFromBrief(String name, DiffBrief brief) =>
      DiseaseKnowledge(
        id: '',
        name: name,
        overview: brief.overview,
        prognosis: brief.prognosis,
        causes: brief.causes,
        impacts: brief.impacts,
        sources: const [],
        differential: const [],
        furtherExams: const [],
        seeDoctor: const [],
        advice: const [],
      );

  // ---------------------------------------------------------------- 材料扫描

  MaterialScan _scanMaterial(String text) {
    final notes = <String>[];
    final hospitals = <String>{};
    // 通用医院名识别：「xx医院/门诊部/诊所/医疗中心」
    final hospRe = RegExp(r'[\u4e00-\u9fffA-Za-z]{2,25}(?:医院|门诊部|诊所|卫生服务中心|医疗中心)');
    for (final m in hospRe.allMatches(text)) {
      final seg = m.group(0) ?? '';
      if (seg.length >= 4) hospitals.add(seg);
    }
    // 知名医院关键词佐证
    for (final kw in [...tierMarks, ...hospitalKeywords]) {
      if (kw.isNotEmpty && text.contains(kw)) {
        final i = text.indexOf(kw);
        final s = (i - 15) < 0 ? 0 : i - 15;
        final e = i + kw.length + 15;
        final seg = text
            .substring(s, e > text.length ? text.length : e)
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        hospitals.add(seg);
      }
    }

    final diagnoses = <String>{};
    final re = RegExp(
        r'(诊断|诊断为|初步诊断|入院诊断|出院诊断|临床诊断|确诊|检查结论|病理诊断)[:：]?\s*([^\n，。；,;]{2,40})');
    for (final m in re.allMatches(text)) {
      final seg = (m.group(2) ?? '').trim();
      if (seg.isNotEmpty) diagnoses.add(seg);
    }

    final joined = diagnoses.join('；');
    var level = 'unknown';
    if (joined.isNotEmpty) {
      if (_hitAny(joined, majorKeywords)) {
        level = 'major';
      } else if (_hitAny(joined, severeKeywords)) {
        level = 'severe';
      } else {
        level = 'common';
      }
    }

    // 指标提示（常见检验项）
    final metrics = <String>[];
    final metricRe = RegExp(
        r'(空腹血糖|餐后血糖|糖化血红蛋白|HbA1c|血压|收缩压|舒张压|白细胞|中性粒细胞|C反应蛋白|CRP|血红蛋白|血小板|尿酸|肌酐|转氨酶|ALT|AST|总胆固醇|甘油三酯|低密度脂蛋白|LDL-C)\s*[:：]?\s*([0-9]{1,3}(\.[0-9]+)?)');
    for (final m in metricRe.allMatches(text)) {
      metrics.add('${m.group(1)} ${m.group(2)}');
    }
    if (metrics.isNotEmpty) {
      notes.add('材料中读到的指标：${metrics.take(8).join('、')}'
          '（具体意义请由医生结合临床判断）');
    }
    if (diagnoses.isNotEmpty) {
      notes.add('材料所示诊断：${diagnoses.join(' / ')}'
          '（这是材料上的信息，供您核对，不是我的诊断结论）');
    }
    if (hospitals.isNotEmpty) {
      notes.add('识别到出具医院：${hospitals.take(3).join(' / ')}');
    }
    if (diagnoses.isEmpty && hospitals.isEmpty && metrics.isEmpty) {
      notes.add('这份材料里我没有读到明确的诊断或指标信息，'
          '请您把关键内容打字补充给我。');
    }

    return MaterialScan(
      hospitals: hospitals.toList(),
      diagnoses: diagnoses.toList(),
      level: level,
      notes: notes,
    );
  }

  bool _hitAny(String text, List<String> kws) {
    for (final k in kws) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------- 工具

  String _answerText(String qid) {
    final m = _multi[qid];
    if (m != null) return m.join('；');
    return _answers[qid] ?? '';
  }

  List<String> _optionsOf(ConsultQuestion q) =>
      q.kind == QuestionKind.free ? const [] : q.options;

  List<String> _currentQuickOptions() {
    final s = _script;
    if (s == null || _phase != ConsultPhase.interviewing) return const [];
    if (_qIndex >= s.questions.length) return const [];
    return _optionsOf(s.questions[_qIndex]);
  }
}
