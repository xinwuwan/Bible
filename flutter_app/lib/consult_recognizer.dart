// consult_recognizer.dart
// 材料识别器（v57）：从已提取的材料文本中识别医院 / 诊断 / 材料类型 / 主诉，
// 用于「医药布道」模块上传材料后自动填写表单，减少人工输入。
//
// 纯 Dart：不依赖 Flutter，可被 dart run 直接测试（与 health_qa_matcher 同模式）。
// 合规边界：只整理材料上「写了什么」供用户核实，不代表系统观点，不据此下诊断。
//
// 运行测试：dart run verify_consult_dialog.dart 之外，另有独立用例见
// test/consult_recognize_test.dart。

/// 材料自动识别结果：仅把材料上「写了什么」整理出来供表单预填，
/// 不代表系统观点，最终以用户核实后的填写为准。
class RecognizedMaterial {
  final String hospital; // 最可能的医院全称（已清洗）
  final List<String> hospitals; // 全部候选（按出现顺序，最多 5 个）
  final String diagnosis; // 最可能的主诊断（已清洗）
  final List<String> diagnoses; // 全部候选（按可信度排序）
  final String materialType; // 推测的材料类型（对应表单选项；空=推测不出）
  final String chiefComplaint; // 主诉（如有）
  final bool hasAny; // 是否识别到任何可用信息

  const RecognizedMaterial({
    this.hospital = '',
    this.hospitals = const [],
    this.diagnosis = '',
    this.diagnoses = const [],
    this.materialType = '',
    this.chiefComplaint = '',
    this.hasAny = false,
  });

  /// 可自动填写的表单项数量（医院/诊断/材料类型/主诉）
  int get filledCount =>
      (hospital.isNotEmpty ? 1 : 0) +
      (diagnosis.isNotEmpty ? 1 : 0) +
      (materialType.isNotEmpty ? 1 : 0) +
      (chiefComplaint.isNotEmpty ? 1 : 0);
}

/// 材料识别器：从材料文本中识别关键信息，供表单预填。
class MaterialRecognizer {
  MaterialRecognizer._();

  /// 医院名称候选：以「医院/卫生院/保健院/门诊部/诊所/医学中心/医疗中心」等结尾
  static final RegExp _hospitalRe = RegExp(
      r'[\u4e00-\u9fffA-Za-z0-9·．.（）()]{2,25}?'
      r'(?:附属第一医院|附属第二医院|附属第三医院|附属医院|医院|卫生院|保健院|'
      r'门诊部|诊所|医学中心|医疗中心|卫生服务中心)');

  /// 诊断标签 → 诊断内容
  static final RegExp _diagRe = RegExp(
      r'(?:初步诊断|入院诊断|出院诊断|临床诊断|病理诊断|诊断为|诊断|确诊|'
      r'检查结论|诊疗意见|意见|印象)[:：]?\s*([^\n，。；,;：:]{2,30})');

  /// 主诉
  static final RegExp _chiefRe = RegExp(r'主诉[:：]?\s*([^\n]{2,60})');

  /// 疑似非诊断内容的标记（命中任一即剔除候选）
  static const List<String> _diagNoise = [
    '请结合', '建议', '详见', '签名', '医师', '日期', '编号', '正常', '未见',
    '如上', '如下', '资料', '医生', '审核', '开单', '申请', '电话', '病案',
    '住院号', '门诊号', '标本', '回报', '报告日期', '检查日期', '核对',
  ];

  /// 医院名中的等级/评审词（命中说明是「三级甲等」类自证，不是医院名）
  static const List<String> _tierNoise = ['甲等', '三级', '叁级', '三甲', '乙等', '二甲', '合格', '评审'];

  /// 疾病名常见语素（用于候选排序）
  static const List<String> _diseaseMorphemes = [
    '病', '症', '炎', '瘤', '癌', '肿瘤', '结石', '纤维', '卒', '中风',
    '瘫痪', '麻痹', '震颤', '衰竭', '梗死', '出血', '损伤', '感染', '贫血',
    '骨折', '突出', '狭窄', '扩张', '息肉', '囊肿', '淋巴', '糖尿', '高压',
    '痛风', '哮喘', '癫痫', '抑郁', '失眠', '肥胖', '白内', '青光',
  ];

  /// 句首虚词/动词，清洗医院名时剥掉（长的放前面，优先剥）
  static const List<String> _leadingStrip = [
    '送往', '送至', '送到', '转入', '转至', '转到', '我院', '病人', '患者',
    '送', '往', '赴', '由', '经', '自', '从', '被', '将', '把', '给', '让',
    '向', '对', '与', '和', '及', '请', '去', '来', '在', '到', '于', '是',
    '为', '称',
  ];

  static const List<String> _typePathology = ['病理', '免疫组化', '镜下', '活检'];
  static const List<String> _typeImaging = [
    'CT', 'ct', '磁共振', 'MRI', '超声', '彩超', 'B超', 'X线', 'DR', 'CR',
    '放射', '影像', 'PET', '胸片', '拍片',
  ];
  static const List<String> _typeLab = [
    '血常规', '尿常规', '检验', '生化', '血糖', '血脂', '肿瘤标志物', '甲功',
    '凝血', 'CRP', '化验', '核酸', '电解质', '肝肾功能', '糖化',
  ];
  static const List<String> _typeInpatient = ['出院', '住院', '病案', '入院记录', '病程'];
  static const List<String> _typeOutpatient = ['门诊', '诊断证明', '证明', '急诊'];

  /// 表单可选项（与 health_consult_page 的 _materialTypes 保持一致）
  static const List<String> materialTypes = [
    '门诊报告/诊断证明',
    '住院小结/出院记录',
    '病理报告',
    '检验单（血/尿等）',
    '影像报告（CT/彩超等）',
    '其他',
  ];

  /// 从材料全文识别信息。[text] 为已提取的文本（可含多个附件拼接）。
  static RecognizedMaterial recognize(String text) {
    final t = text.trim();
    if (t.isEmpty) return const RecognizedMaterial();
    final hospitals = _findHospitals(t);
    final diagnoses = _findDiagnoses(t);
    final chief = _findChiefComplaint(t);
    final type = _guessType(t);
    return RecognizedMaterial(
      hospital: hospitals.isNotEmpty ? hospitals.first : '',
      hospitals: hospitals,
      diagnosis: diagnoses.isNotEmpty ? diagnoses.first : '',
      diagnoses: diagnoses,
      materialType: type,
      chiefComplaint: chief,
      hasAny: hospitals.isNotEmpty ||
          diagnoses.isNotEmpty ||
          chief.isNotEmpty ||
          type.isNotEmpty,
    );
  }

  static List<String> _findHospitals(String text) {
    final out = <String>[];
    final seen = <String>{};
    for (final m in _hospitalRe.allMatches(text)) {
      var name = (m.group(0) ?? '').trim();
      if (name.isEmpty) continue;
      // 标签词后面跟冒号（如「送检医院：」「报告医院：」）→ 是字段名，跳过
      final after = text.length > m.end ? text[m.end] : '';
      if (after == '：' || after == ':') continue;
      // 等级自证词（三级甲等医院）不是医院名
      if (_tierNoise.any((w) => name.contains(w))) continue;
      name = _cleanHospital(name);
      if (name.length < 4) continue; // 「××医院」最短 4 字
      if (_tierNoise.any((w) => name.contains(w))) continue;
      if (seen.add(name)) out.add(name);
      if (out.length >= 5) break;
    }
    return out;
  }

  static String _cleanHospital(String name) {
    var s = name;
    // 剥掉句首虚词/动词（如「送至北京协和医院」→「北京协和医院」）
    var changed = true;
    while (changed && s.length > 4) {
      changed = false;
      for (final w in _leadingStrip) {
        if (s.startsWith(w) && s.length - w.length >= 4) {
          s = s.substring(w.length);
          changed = true;
          break;
        }
      }
    }
    return s;
  }

  static List<String> _findDiagnoses(String text) {
    final cands = <(String, int)>[]; // (内容, 得分)
    final seen = <String>{};
    for (final m in _diagRe.allMatches(text)) {
      var seg = (m.group(1) ?? '').trim();
      if (seg.isEmpty) continue;
      seg = _cleanDiagnosis(seg);
      if (seg.length < 2 || seg.length > 20) continue;
      if (!RegExp(r'[\u4e00-\u9fff]').hasMatch(seg)) continue;
      if (_diagNoise.any((n) => seg.contains(n))) continue;
      if (seen.add(seg)) cands.add((seg, _diagScore(seg)));
    }
    cands.sort((a, b) => b.$2.compareTo(a.$2));
    return cands.map((e) => e.$1).toList();
  }

  static String _cleanDiagnosis(String seg) {
    var s = seg.trim();
    s = s.replaceAll(RegExp(r'^[「」“”\s]+'), '');
    s = s.replaceAll(RegExp(r'[「」“”\s]+$'), '');
    // 剥掉句首推测性动词（「考虑2型糖尿病」→「2型糖尿病」）
    const lead = ['考虑', '拟诊', '怀疑', '提示', '示', '诊为', '为', '是', '见'];
    var changed = true;
    while (changed && s.length > 2) {
      changed = false;
      for (final w in lead) {
        if (s.startsWith(w) && s.length - w.length >= 2) {
          s = s.substring(w.length);
          changed = true;
          break;
        }
      }
    }
    // 去掉尾部的「待查」等
    s = s.replaceAll(RegExp(r'(待查|待排|待明确|？|\?)+$'), '').trim();
    return s;
  }

  static int _diagScore(String seg) {
    var score = 0;
    for (final m in _diseaseMorphemes) {
      if (seg.contains(m)) score += 3;
    }
    if (seg.length >= 3 && seg.length <= 12) score += 1;
    if (seg.length >= 13) score -= 1;
    return score;
  }

  static String _findChiefComplaint(String text) {
    final m = _chiefRe.firstMatch(text);
    var s = (m?.group(1) ?? '').trim();
    s = s.replaceAll(RegExp(r'[。；;\s]+$'), '');
    if (s.length > 60) s = s.substring(0, 60);
    return s;
  }

  static String _guessType(String text) {
    if (_hitAny(text, _typePathology)) return '病理报告';
    if (_hitAny(text, _typeImaging)) return '影像报告（CT/彩超等）';
    if (_hitAny(text, _typeLab)) return '检验单（血/尿等）';
    if (_hitAny(text, _typeInpatient)) return '住院小结/出院记录';
    if (_hitAny(text, _typeOutpatient)) return '门诊报告/诊断证明';
    return '';
  }

  static bool _hitAny(String text, List<String> kws) {
    for (final k in kws) {
      if (text.contains(k)) return true;
    }
    return false;
  }
}
