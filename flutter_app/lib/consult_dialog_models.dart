// consult_dialog_models.dart
// AI 医生助手 —— 问诊数据模型（纯 Dart：无 Flutter 依赖，可被 dart run 直接测试）。
// 数据来源：flutter_app/assets/web/consult_scripts.json（问诊剧本）
//         + disease_profiles*.json（疾病完整资料，页面负责合并为 DiseaseKnowledge）
//         + hospital_tier_a.json（材料级别识别关键词）

/// 问题类型：单选 / 多选 / 自由文本
enum QuestionKind { choice, multi, free }

/// 问诊问题
class ConsultQuestion {
  final String id;
  final QuestionKind kind;
  final String ask;
  final List<String> options;
  final List<String> redFlags; // 选项包含该子串 → 该题触发急症中断

  const ConsultQuestion({
    required this.id,
    required this.kind,
    required this.ask,
    required this.options,
    required this.redFlags,
  });

  factory ConsultQuestion.fromJson(Map<String, dynamic> j) {
    var kind = QuestionKind.free;
    final k = (j['kind'] ?? 'free') as String;
    if (k == 'choice') kind = QuestionKind.choice;
    if (k == 'multi') kind = QuestionKind.multi;
    return ConsultQuestion(
      id: (j['id'] ?? '') as String,
      kind: kind,
      ask: (j['ask'] ?? '') as String,
      options: (j['options'] as List?)?.cast<String>() ?? const [],
      redFlags: (j['redFlags'] as List?)?.cast<String>() ?? const [],
    );
  }
}

/// 证据规则：答案文本包含 [opt] 或 [kw] 即命中，权重 [w]
class EvidenceRule {
  final String qid;
  final String? opt;
  final String? kw;
  final int w;

  const EvidenceRule({
    required this.qid,
    this.opt,
    this.kw,
    required this.w,
  });

  factory EvidenceRule.fromJson(Map<String, dynamic> j) => EvidenceRule(
        qid: (j['qid'] ?? '') as String,
        opt: j['opt'] as String?,
        kw: j['kw'] as String?,
        w: (j['w'] ?? 0) as int,
      );

  bool matches(String answer) {
    if (answer.isEmpty) return false;
    final o = opt;
    if (o != null && o.isNotEmpty && answer.contains(o)) return true;
    final k = kw;
    if (k != null && k.isNotEmpty && answer.contains(k)) return true;
    return false;
  }
}

/// 急症规则：allOf 全部命中才触发
class RedFlagRule {
  final List<EvidenceRule> allOf;
  final String msg;
  final String level; // emergency / urgent

  const RedFlagRule({
    required this.allOf,
    required this.msg,
    required this.level,
  });

  factory RedFlagRule.fromJson(Map<String, dynamic> j) => RedFlagRule(
        allOf: ((j['allOf'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(EvidenceRule.fromJson)
            .toList(),
        msg: (j['msg'] ?? '') as String,
        level: (j['level'] ?? 'urgent') as String,
      );
}

/// 简版疾病资料（剧本内置，profileId 为空时使用）
class DiffBrief {
  final String overview;
  final List<String> causes;
  final List<String> impacts;
  final List<String> care;
  final String prognosis;

  const DiffBrief({
    required this.overview,
    required this.causes,
    required this.impacts,
    required this.care,
    required this.prognosis,
  });

  factory DiffBrief.fromJson(Map<String, dynamic> j) => DiffBrief(
        overview: (j['overview'] ?? '') as String,
        causes: (j['causes'] as List?)?.cast<String>() ?? const [],
        impacts: (j['impacts'] as List?)?.cast<String>() ?? const [],
        care: (j['care'] as List?)?.cast<String>() ?? const [],
        prognosis: (j['prognosis'] ?? '') as String,
      );
}

/// 鉴别诊断条目
class Differential {
  final String name;
  final String profileId;
  final DiffBrief? brief;
  final List<EvidenceRule> support;
  final List<EvidenceRule> against;
  final List<String> exclude;
  final List<String> exams;

  const Differential({
    required this.name,
    required this.profileId,
    this.brief,
    required this.support,
    required this.against,
    required this.exclude,
    required this.exams,
  });

  factory Differential.fromJson(Map<String, dynamic> j) => Differential(
        name: (j['name'] ?? '') as String,
        profileId: (j['profileId'] ?? '') as String,
        brief: j['brief'] == null
            ? null
            : DiffBrief.fromJson(j['brief'] as Map<String, dynamic>),
        support: ((j['support'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(EvidenceRule.fromJson)
            .toList(),
        against: ((j['against'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(EvidenceRule.fromJson)
            .toList(),
        exclude: (j['exclude'] as List?)?.cast<String>() ?? const [],
        exams: (j['exams'] as List?)?.cast<String>() ?? const [],
      );
}

/// 主诉问诊剧本
class ComplaintScript {
  final String id;
  final String label;
  final String greeting;
  final String department;
  final String emergency;
  final List<String> keywords;
  final List<ConsultQuestion> questions;
  final List<RedFlagRule> redFlagRules;
  final List<Differential> differentials;

  const ComplaintScript({
    required this.id,
    required this.label,
    required this.greeting,
    required this.department,
    required this.emergency,
    required this.keywords,
    required this.questions,
    required this.redFlagRules,
    required this.differentials,
  });

  factory ComplaintScript.fromJson(Map<String, dynamic> j) => ComplaintScript(
        id: (j['id'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        greeting: (j['greeting'] ?? '') as String,
        department: (j['department'] ?? '') as String,
        emergency: (j['emergency'] ?? '') as String,
        keywords: (j['keywords'] as List?)?.cast<String>() ?? const [],
        questions: ((j['questions'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ConsultQuestion.fromJson)
            .toList(),
        redFlagRules: ((j['redFlagRules'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(RedFlagRule.fromJson)
            .toList(),
        differentials: ((j['differentials'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Differential.fromJson)
            .toList(),
      );
}

/// 剧本集合 + 主诉匹配（命中关键词最长者优先）
class ConsultScripts {
  final List<ComplaintScript> complaints;

  const ConsultScripts(this.complaints);

  factory ConsultScripts.fromJson(Map<String, dynamic> j) => ConsultScripts(
        ((j['complaints'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ComplaintScript.fromJson)
            .toList(),
      );

  /// 从自由文本中识别主诉；无法识别返回 null
  ComplaintScript? matchComplaint(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    ComplaintScript? best;
    var bestLen = 0;
    for (final c in complaints) {
      for (final kw in c.keywords) {
        if (kw.isNotEmpty && t.contains(kw) && kw.length > bestLen) {
          best = c;
          bestLen = kw.length;
        }
      }
    }
    return best;
  }

  /// 快捷主诉按钮（label 去重，保持顺序）
  List<String> get quickLabels {
    final seen = <String>{};
    final out = <String>[];
    for (final c in complaints) {
      if (seen.add(c.label)) out.add(c.label);
    }
    return out;
  }
}

/// 疾病完整资料（由 disease_profiles*.json 映射；NEWSTART 建议为可选）
class DiseaseKnowledge {
  final String id;
  final String name;
  final String overview;
  final String prognosis;
  final List<String> causes;
  final List<String> impacts;
  final List<String> sources;
  final List<String> differential;
  final List<String> furtherExams;
  final List<String> seeDoctor;
  final List<Map<String, String>> advice; // NEWSTART {pillar, text}

  const DiseaseKnowledge({
    required this.id,
    required this.name,
    required this.overview,
    required this.prognosis,
    required this.causes,
    required this.impacts,
    required this.sources,
    required this.differential,
    required this.furtherExams,
    required this.seeDoctor,
    required this.advice,
  });

  factory DiseaseKnowledge.fromJson(Map<String, dynamic> j) => DiseaseKnowledge(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        overview: (j['overview'] ?? '') as String,
        prognosis: (j['prognosis'] ?? '') as String,
        causes: (j['causes'] as List?)?.cast<String>() ?? const [],
        impacts: (j['impacts'] as List?)?.cast<String>() ?? const [],
        sources: (j['sources'] as List?)?.cast<String>() ?? const [],
        differential: (j['differential'] as List?)?.cast<String>() ?? const [],
        furtherExams: (j['furtherExams'] as List?)?.cast<String>() ?? const [],
        seeDoctor: (j['seeDoctor'] as List?)?.cast<String>() ?? const [],
        advice: ((j['advice'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((e) => {
                  'pillar': (e['pillar'] ?? '') as String,
                  'text': (e['text'] ?? '') as String,
                })
            .toList(),
      );
}

/// 材料（上传附件）扫描结果 —— 仅呈现材料所示信息，不构成系统诊断
class MaterialScan {
  final List<String> hospitals;
  final List<String> diagnoses;
  final String level; // major / severe / common / unknown
  final List<String> notes;

  const MaterialScan({
    required this.hospitals,
    required this.diagnoses,
    required this.level,
    required this.notes,
  });
}

/// 分析结论中的单条疾病判断
class ConsultFinding {
  final String name;
  final String tier; // 可能性较大 / 有可能 / 需排除
  final int score;
  final List<String> evidence; // 判断依据（对应问句摘要）
  final List<String> exclude;
  final List<String> exams;
  final String knowledgeId; // 命中完整资料的 id（可空）

  const ConsultFinding({
    required this.name,
    required this.tier,
    required this.score,
    required this.evidence,
    required this.exclude,
    required this.exams,
    required this.knowledgeId,
  });
}

/// 问诊分析报告
class ConsultReport {
  final List<ConsultFinding> findings;
  final String? redFlagLevel; // emergency / urgent / null
  final String? redFlagMsg;
  final MaterialScan? material;
  final String department;
  final List<String> uncertainties;

  const ConsultReport({
    required this.findings,
    this.redFlagLevel,
    this.redFlagMsg,
    this.material,
    required this.department,
    required this.uncertainties,
  });
}
