import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// 疾病分级
enum DiseaseLevel {
  major('重大疾病', '需至少 2 家三甲/专科医院共同出具的诊断确诊材料'),
  severe('严重疾病', '需三甲医院出具的诊断材料'),
  common('常见慢性病', '需至少 1 家医院出具的诊断材料'),
  unknown('未能确定', '材料中未识别到明确诊断');

  const DiseaseLevel(this.label, this.requirement);
  final String label;
  final String requirement;
}

/// 疾病科普条目（成因/影响/预后 + NEWSTART 医药布道建议）
class DiseaseProfile {
  final String id;
  final String name;
  final List<String> aliases;
  final String category;
  final String severityHint;
  final String overview;
  final List<String> causes;
  final List<String> impacts;
  final String prognosis;
  final List<Map<String, String>> advice; // {pillar, text}
  final List<String> differential; // 需要排除的疾病
  final List<String> furtherExams; // 建议进一步检查
  final List<String> seeDoctor; // 出现这些情况尽快就医
  final List<String> sources; // 权威来源（纯文本引用，无外链）
  final List<String> clinical; // 临床表现（症状/体征）
  final List<String> diagnostic; // 诊断标准（要点）

  const DiseaseProfile({
    required this.id,
    required this.name,
    required this.aliases,
    required this.category,
    required this.severityHint,
    required this.overview,
    required this.causes,
    required this.impacts,
    required this.prognosis,
    required this.advice,
    this.differential = const [],
    this.furtherExams = const [],
    this.seeDoctor = const [],
    this.sources = const [],
    this.clinical = const [],
    this.diagnostic = const [],
  });

  factory DiseaseProfile.fromJson(Map<String, dynamic> j) => DiseaseProfile(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        aliases: (j['aliases'] as List?)?.cast<String>() ?? const [],
        category: (j['category'] ?? '') as String,
        severityHint: (j['severityHint'] ?? 'common') as String,
        overview: (j['overview'] ?? '') as String,
        causes: (j['causes'] as List?)?.cast<String>() ?? const [],
        impacts: (j['impacts'] as List?)?.cast<String>() ?? const [],
        prognosis: (j['prognosis'] ?? '') as String,
        advice: (j['advice'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map((e) => {
                      'pillar': (e['pillar'] ?? '') as String,
                      'text': (e['text'] ?? '') as String,
                    })
                .toList() ??
            const [],
        differential: (j['differential'] as List?)?.cast<String>() ?? const [],
        furtherExams: (j['furtherExams'] as List?)?.cast<String>() ?? const [],
        seeDoctor: (j['seeDoctor'] as List?)?.cast<String>() ?? const [],
        sources: (j['sources'] as List?)?.cast<String>() ?? const [],
        clinical: (j['clinical'] as List?)?.cast<String>() ?? const [],
        diagnostic: (j['diagnostic'] as List?)?.cast<String>() ?? const [],
      );
}

/// 材料级识别规则
class MaterialRules {
  final List<String> tierMarks;
  final List<String> hospitalKeywords;
  final List<String> specialtyKeywords;
  final List<String> diagnosisMarks;
  final List<String> majorDiseaseKeywords;
  final List<String> severeDiseaseKeywords;

  const MaterialRules({
    required this.tierMarks,
    required this.hospitalKeywords,
    required this.specialtyKeywords,
    required this.diagnosisMarks,
    required this.majorDiseaseKeywords,
    required this.severeDiseaseKeywords,
  });

  factory MaterialRules.empty() => const MaterialRules(
        tierMarks: [],
        hospitalKeywords: [],
        specialtyKeywords: [],
        diagnosisMarks: [],
        majorDiseaseKeywords: [],
        severeDiseaseKeywords: [],
      );

  factory MaterialRules.fromJson(Map<String, dynamic> j) => MaterialRules(
        tierMarks: (j['tierMarks'] as List?)?.cast<String>() ?? const [],
        hospitalKeywords:
            (j['hospitalKeywords'] as List?)?.cast<String>() ?? const [],
        specialtyKeywords:
            (j['specialtyKeywords'] as List?)?.cast<String>() ?? const [],
        diagnosisMarks:
            (j['diagnosisMarks'] as List?)?.cast<String>() ?? const [],
        majorDiseaseKeywords:
            (j['majorDiseaseKeywords'] as List?)?.cast<String>() ?? const [],
        severeDiseaseKeywords:
            (j['severeDiseaseKeywords'] as List?)?.cast<String>() ?? const [],
      );
}

/// 核验结果
class VerifyResult {
  final List<String> hospitals; // 识别到的医院证据片段（去重）
  final List<String> diagnoses; // 识别到的诊断（含用户填报）
  final DiseaseLevel level;
  final bool passed;
  final List<String> missing; // 缺件说明
  final bool consistent; // 多家诊断是否一致
  final String primaryDiagnosis; // 材料所示主诊断（非系统诊断）
  final List<String> notes; // 附加提示

  const VerifyResult({
    required this.hospitals,
    required this.diagnoses,
    required this.level,
    required this.passed,
    required this.missing,
    required this.consistent,
    required this.primaryDiagnosis,
    required this.notes,
  });
}

/// 附件
class ConsultAttachment {
  final String name;
  final int size;
  final String status; // text_ok / need_manual / failed
  final String extractedText;
  final String hint;

  const ConsultAttachment({
    required this.name,
    required this.size,
    required this.status,
    required this.extractedText,
    required this.hint,
  });

  /// v58：OCR 成功后把「需手动誊写」占位升级为「已提取文字」。
  ConsultAttachment copyWith({
    String? status,
    String? extractedText,
    String? hint,
  }) {
    return ConsultAttachment(
      name: name,
      size: size,
      status: status ?? this.status,
      extractedText: extractedText ?? this.extractedText,
      hint: hint ?? this.hint,
    );
  }
}

/// 静态数据加载 + 材料核验引擎
class ConsultData {
  ConsultData._();
  static final List<DiseaseProfile> diseases = [];
  static MaterialRules rules = MaterialRules.empty();
  static bool loaded = false;

  static Future<void> load() async {
    if (loaded) return;
    diseases.clear();
    for (final p in const [
      'assets/web/disease_profiles.json',
      'assets/web/disease_profiles_2.json',
      'assets/web/disease_profiles_3.json',
    ]) {
      final raw = await rootBundle.loadString(p);
      final j = jsonDecode(raw) as Map<String, dynamic>;
      for (final d in (j['diseases'] as List? ?? const [])) {
        diseases.add(DiseaseProfile.fromJson(d as Map<String, dynamic>));
      }
    }
    final rraw = await rootBundle.loadString('assets/web/hospital_tier_a.json');
    rules = MaterialRules.fromJson(jsonDecode(rraw) as Map<String, dynamic>);
    loaded = true;
  }

  /// 诊断名 OCR/手写识别常见形近字误认映射：仅用于检索容错，不改变页面展示的原文。
  /// 例：诊断证明 OCR 出「颅立性纤维性肿瘤」→ 归一为「孤立性纤维性肿瘤」即可命中。
  static const Map<String, String> _ocrConfusion = {
    '颅': '孤',
    '胂': '肿',
    '痿': '萎',
    '瘜': '息',
    '疸': '胆',
    '嗝': '隔',
    '痈': '拥',
    '癜': '癫',
    '痫': '闲',
    '痔': '峙',
    '疱': '泡',
    '荨': '寻',
    '裂': '烈',
    '痹': '弊',
    '瘫': '滩',
    '痪': '焕',
    '憩': '息',
    '癣': '鲜',
    '亢': '冗',
  };

  /// 将诊断名中的形近误认字归一为规范字（用于容错检索）。
  static String _normOcr(String s) {
    if (s.isEmpty) return s;
    var out = s;
    for (final e in _ocrConfusion.entries) {
      if (out.contains(e.key)) out = out.replaceAll(e.key, e.value);
    }
    return out;
  }

  /// 按诊断名称匹配疾病科普条目：别名命中最长者优先（避免「瘤」类短别名
  /// 抢先匹配具体病名）。系统不自行诊断：仅做知识库检索。
  /// 检索时对诊断与别名均做 OCR 形近字归一，容忍扫描件/手写件的识别误差。
  static DiseaseProfile? findProfile(String diagnosis) {
    final d = _normOcr(diagnosis.trim());
    if (d.isEmpty) return null;
    DiseaseProfile? best;
    var bestLen = 0;
    for (final p in diseases) {
      for (final a in p.aliases) {
        final na = _normOcr(a);
        if (na.isNotEmpty && d.contains(na) && na.length > bestLen) {
          best = p;
          bestLen = na.length;
        }
      }
      final nn = _normOcr(p.name);
      if (d.contains(nn) && nn.length > bestLen) {
        best = p;
        bestLen = nn.length;
      }
    }
    return best;
  }

  // ---------- 材料核验 ----------

  /// 从 [materialText] 与用户填报的 [declaredHospital]/[declaredDiagnosis]
  /// 综合核验。系统不自行诊断：primaryDiagnosis 仅为材料/填报所示诊断。
  static VerifyResult verify({
    required String materialText,
    required String symptoms,
    String declaredHospital = '',
    String declaredDiagnosis = '',
  }) {
    final text = materialText.trim();
    final notes = <String>[];

    // 1) 医院识别：tierMarks / hospitalKeywords / specialtyKeywords
    final hospitals = <String>{};
    for (final kw in rules.tierMarks) {
      if (text.contains(kw)) {
        hospitals.add(_evidence(text, kw));
      }
    }
    for (final kw in rules.hospitalKeywords) {
      if (text.contains(kw)) {
        hospitals.add(_evidence(text, kw));
      }
    }
    for (final kw in rules.specialtyKeywords) {
      if (text.contains(kw)) {
        hospitals.add(_evidence(text, kw));
      }
    }
    final declaredH = declaredHospital.trim();
    if (declaredH.isNotEmpty) {
      hospitals.add(declaredH);
    }
    final hospitalList = hospitals.toList();

    // 2) 诊断识别：diagnosisMarks 正则 + 用户填报
    final diagnoses = <String>{};
    final dRe = RegExp(
        r'(诊断|诊断为|初步诊断|入院诊断|出院诊断|临床诊断|确诊|印象|检查结论|病理诊断)[:：]?\s*([^\n，。；,;]{2,40})');
    for (final m in dRe.allMatches(text)) {
      final seg = m.group(2)?.trim() ?? '';
      if (seg.isNotEmpty && !_looksLikeNoise(seg)) diagnoses.add(seg);
    }
    final declaredD = declaredDiagnosis.trim();
    if (declaredD.isNotEmpty) diagnoses.add(declaredD);
    final diagnosisList = diagnoses.toList();

    // 3) 分级（按诊断关键词；不按症状自行推断疾病）
    DiseaseLevel level = DiseaseLevel.unknown;
    final joined = diagnosisList.join('；');
    if (diagnosisList.isNotEmpty) {
      if (_hitAny(joined, rules.majorDiseaseKeywords)) {
        level = DiseaseLevel.major;
      } else if (_hitAny(joined, rules.severeDiseaseKeywords)) {
        level = DiseaseLevel.severe;
      } else {
        level = DiseaseLevel.common;
      }
    }

    // 4) 规则核验
    final missing = <String>[];
    var passed = false;
    if (level == DiseaseLevel.unknown) {
      missing.add('材料中未识别到明确诊断。请补充：医院出具的诊断名称，'
          '或在上方「材料关键信息」中手动填写诊断名称');
    } else if (level == DiseaseLevel.major) {
      if (hospitalList.length >= 2) {
        passed = true;
      } else {
        missing.add('重大疾病需至少 2 家三甲或专科医院共同出具的诊断确诊材料，'
            '当前仅识别到 ${hospitalList.length} 家');
      }
    } else if (level == DiseaseLevel.severe) {
      if (hospitalList.isNotEmpty) {
        passed = true;
      } else {
        missing.add('严重疾病需三甲医院出具的诊断材料，请上传报告或在'
            '「材料关键信息」中填写医院名称');
      }
    } else {
      if (hospitalList.isNotEmpty) {
        passed = true;
      } else {
        missing.add('请上传至少 1 家医院出具的诊断材料，或填写医院名称');
      }
    }

    // 5) 多家诊断一致性（归一化后去重）
    final norm = diagnosisList.map(_normDiag).toSet();
    final consistent = norm.length <= 1;
    if (!consistent) {
      notes.add('识别到多家医院诊断表述不一致：${diagnosisList.join(' / ')}。'
          '请以病理诊断或上级医院诊断为准，并回原医院复诊确认');
    }
    if (symptoms.trim().isNotEmpty && level == DiseaseLevel.unknown) {
      notes.add('已记录您描述的症状。系统不依据症状自行推断疾病，'
          '请携带材料至医院门诊确认诊断');
    }
    if (hospitalList.isEmpty && text.isEmpty && declaredH.isEmpty) {
      notes.add('未上传任何可读取材料，以上结论仅依据手动填报信息');
    }

    return VerifyResult(
      hospitals: hospitalList,
      diagnoses: diagnosisList,
      level: level,
      passed: passed,
      missing: missing,
      consistent: consistent,
      primaryDiagnosis: diagnosisList.isNotEmpty ? diagnosisList.first : '',
      notes: notes,
    );
  }

  static String _evidence(String text, String kw) {
    final i = text.indexOf(kw);
    if (i < 0) return kw;
    final s = (i - 18).clamp(0, text.length).toInt();
    final e = (i + kw.length + 18).clamp(0, text.length).toInt();
    if (e <= s) return kw;
    final seg = text.substring(s, e).replaceAll(RegExp(r'\s+'), ' ').trim();
    return seg;
  }

  static bool _looksLikeNoise(String s) {
    final hasCjk = RegExp(r'[\u4e00-\u9fff]').hasMatch(s);
    return !hasCjk && s.length < 4;
  }

  static bool _hitAny(String text, List<String> kws) {
    for (final k in kws) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  static String _normDiag(String s) =>
      s.replaceAll(RegExp(r'[\s，。；、（）()\[\]【】:：,;.]'), '').toLowerCase();
}

/// 附件解析：txt/md 直读；PDF 尽力提取明文流；图片一律引导手动誊写。
class AttachmentParser {
  /// [name] 文件名；[bytes] 文件内容（web 端 pickFiles(withData: true) 可取）。
  static ConsultAttachment parse(String name, Uint8List bytes) {
    final lower = name.toLowerCase();
    final isImage =
        lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') ||
            lower.endsWith('.bmp') || lower.endsWith('.heic') || lower.endsWith('.webp');
    if (isImage) {
      return ConsultAttachment(
        name: name,
        size: bytes.length,
        status: 'need_manual',
        extractedText: '',
        hint: '图片/扫描件需手动誊写：请在下方「材料关键信息」填写医院名称、诊断名称',
      );
    }
    final isText = lower.endsWith('.txt') || lower.endsWith('.md') ||
        lower.endsWith('.csv') || lower.endsWith('.json') || lower.endsWith('.log');
    if (isText) {
      final t = utf8.decode(bytes, allowMalformed: true);
      final ok = RegExp(r'[\u4e00-\u9fff]').hasMatch(t) || t.trim().length > 8;
      return ConsultAttachment(
        name: name,
        size: bytes.length,
        status: ok ? 'text_ok' : 'failed',
        extractedText: ok ? t : '',
        hint: ok ? '' : '文件内容为空或无法识别',
      );
    }
    if (lower.endsWith('.pdf')) {
      final t = _extractPdfPlainText(bytes);
      final cjkRatio = _cjkRatio(t);
      if (t.trim().length >= 8 && cjkRatio > 0.15) {
        return ConsultAttachment(
          name: name,
          size: bytes.length,
          status: 'text_ok',
          extractedText: t,
          hint: '',
        );
      }
      return ConsultAttachment(
        name: name,
        size: bytes.length,
        status: 'need_manual',
        extractedText: '',
        hint: '该 PDF 为扫描件或图片型文字，无法自动读取。请手动誊写关键信息（医院、诊断）',
      );
    }
    return ConsultAttachment(
      name: name,
      size: bytes.length,
      status: 'need_manual',
      extractedText: '',
      hint: '暂不支持自动读取该格式，请手动誊写关键信息',
    );
  }

  /// 极简 PDF 明文文本提取（仅处理未压缩/Flate 的 Tj 字符串）。
  /// 中文 PDF 多为 CID 字形编码，通常提取不到——属预期，转手动誊写。
  static String _extractPdfPlainText(Uint8List bytes) {
    try {
      final s = latin1.decode(bytes, allowInvalid: true);
      final buf = StringBuffer();
      final re = RegExp(r'\(([^()\\]{2,600})\)\s*Tj');
      for (final m in re.allMatches(s)) {
        buf.write(m.group(1) ?? '');
        buf.write('\n');
      }
      return buf.toString();
    } catch (_) {
      return '';
    }
  }

  static double _cjkRatio(String s) {
    if (s.isEmpty) return 0;
    final n = s.replaceAll(RegExp(r'\s'), '').length;
    if (n == 0) return 0;
    final cjk = RegExp(r'[\u4e00-\u9fff]').allMatches(s).length;
    return cjk / n;
  }
}
