import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'consult_models.dart';
import 'consult_recognizer.dart';

/// 专业咨询页：面向医药布道士的「材料核验 + 疾病解读 + 医药布道建议」参考工具。
///
/// 合规边界（不可逾越）：
/// - 系统不自行诊断疾病。「材料所示诊断」仅为医院/上传者提供信息的呈现与交叉核对；
/// - 疾病解读为权威医学科普通识，不替代医生面诊；
/// - 建议部分结合怀著（NEWSTART 八大自然疗法）与圣经原则，属于生活方式参考；
/// - 急症（胸痛、卒中信号、大出血等）立即拨打 120。
class HealthConsultPage extends StatefulWidget {
  const HealthConsultPage({super.key});

  @override
  State<HealthConsultPage> createState() => _HealthConsultPageState();
}

class _HealthConsultPageState extends State<HealthConsultPage> {
  bool _loaded = false;
  bool _picking = false;
  final List<ConsultAttachment> _attachments = [];

  final _hospitalCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _symptomsCtrl = TextEditingController();
  String? _materialType;

  /// 最近一次材料自动识别结果（供展示与「重新识别填入」）
  RecognizedMaterial? _recognized;
  /// 哪些字段是自动填入的（用户改动后自动摘除标记）
  final Set<String> _autoFields = {};

  VerifyResult? _result;
  DiseaseProfile? _profile;

  static const _materialTypes = [
    '门诊报告/诊断证明',
    '住院小结/出院记录',
    '病理报告',
    '检验单（血/尿等）',
    '影像报告（CT/彩超等）',
    '其他',
  ];

  @override
  void initState() {
    super.initState();
    _diagnosisCtrl.addListener(() => _markManual('diagnosis'));
    _hospitalCtrl.addListener(() => _markManual('hospital'));
    _symptomsCtrl.addListener(() => _markManual('symptoms'));
    ConsultData.load().then((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  /// 用户手动改动某字段后，摘除「自动填入」标记
  void _markManual(String key) {
    if (_filling) return; // 程序化自动填写不触发
    if (_autoFields.remove(key)) {
      if (mounted) setState(() {});
    }
  }

  bool _filling = false;

  /// 上传材料后：识别关键信息并自动填写空白字段（已有用户输入不覆盖）
  void _recognizeAndFill({bool force = false}) {
    final text = _materialText;
    if (text.trim().isEmpty) return;
    final rec = MaterialRecognizer.recognize(text);
    if (!rec.hasAny) return;
    setState(() {
      _recognized = rec;
      _filling = true;
      void fill(String key, TextEditingController ctrl, String value) {
        if (value.isEmpty) return;
        if (force ? (_autoFields.contains(key) || ctrl.text.isEmpty)
                  : ctrl.text.isEmpty) {
          ctrl.text = value;
          _autoFields.add(key);
        }
      }

      fill('diagnosis', _diagnosisCtrl, rec.diagnosis);
      fill('hospital', _hospitalCtrl, rec.hospital);
      fill('symptoms', _symptomsCtrl, rec.chiefComplaint);
      if (_materialType == null && rec.materialType.isNotEmpty) {
        _materialType = rec.materialType;
      }
      _filling = false;
    });
  }

  @override
  void dispose() {
    _hospitalCtrl.dispose();
    _diagnosisCtrl.dispose();
    _symptomsCtrl.dispose();
    super.dispose();
  }

  String get _materialText => _attachments
      .where((a) => a.status == 'text_ok')
      .map((a) => a.extractedText)
      .join('\n');

  Future<void> _pickFiles() async {
    setState(() => _picking = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: true,
      );
      if (res == null) return;
      for (final f in res.files) {
        final b = f.bytes;
        if (b == null) continue;
        final att = AttachmentParser.parse(f.name, b);
        if (!mounted) return;
        setState(() => _attachments.add(att));
      }
      _recognizeAndFill();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _verify() {
    final r = ConsultData.verify(
      materialText: _materialText,
      symptoms: _symptomsCtrl.text,
      declaredHospital: _hospitalCtrl.text,
      declaredDiagnosis: _diagnosisCtrl.text,
    );
    setState(() {
      _result = r;
      _profile = ConsultData.findProfile(r.primaryDiagnosis);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('专业咨询 · 医药布道'),
      ),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                const _ScenarioBanner(),
                const SizedBox(height: 10),
                const _ComplianceBanner(),
                const SizedBox(height: 10),
                _sectionCard(
                  icon: Icons.upload_file,
                  title: '① 上传材料 / 填写关键信息',
                  children: [
                    const Text(
                      '上传病历、诊断证明、检验报告等材料（txt 自动读取；PDF/图片需手动誊写关键信息）。',
                      style: TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _picking ? null : _pickFiles,
                          icon: const Icon(Icons.attach_file, size: 16),
                          label: Text(_picking ? '读取中…' : '选择附件'),
                        ),
                      ],
                    ),
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final a in _attachments) _attachmentChip(a),
                      if (_recognized != null && _recognized!.hasAny) ...[
                        const SizedBox(height: 8),
                        _autoFillBanner(),
                      ],
                    ],
                    const SizedBox(height: 10),
                    _field(
                      controller: _diagnosisCtrl,
                      label: '诊断名称（必填）',
                      hint: '誊写材料上的诊断，如「2型糖尿病」',
                      icon: Icons.medical_information,
                      autoTag: _autoFields.contains('diagnosis'),
                    ),
                    const SizedBox(height: 8),
                    _field(
                      controller: _hospitalCtrl,
                      label: '医院名称',
                      hint: '出具诊断的医院全称',
                      icon: Icons.local_hospital,
                      autoTag: _autoFields.contains('hospital'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _materialType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _materialType != null &&
                                _recognized != null &&
                                _recognized!.materialType == _materialType
                            ? '材料类型（已识别，请核实）'
                            : '材料类型',
                        prefixIcon: const Icon(Icons.description, size: 20),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final t in _materialTypes)
                          DropdownMenuItem(value: t, child: Text(t)),
                      ],
                      onChanged: (v) => setState(() => _materialType = v),
                    ),
                    const SizedBox(height: 8),
                    _field(
                      controller: _symptomsCtrl,
                      label: '病人症状与病史描述',
                      hint: '哪里不舒服、持续多久、既往病史…',
                      icon: Icons.person_outline,
                      maxLines: 3,
                      autoTag: _autoFields.contains('symptoms'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _sectionCard(
                  icon: Icons.verified,
                  title: '② 材料级别核验',
                  children: [
                    const Text(
                      '规则：严重疾病需三甲医院诊断材料；重大疾病需至少 2 家三甲或专科医院共同确诊。',
                      style: TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _verify,
                          icon: const Icon(Icons.fact_check, size: 16),
                          label: const Text('核验材料'),
                        ),
                      ],
                    ),
                    if (_result != null) ...[
                      const SizedBox(height: 10),
                      _verifyCard(_result!),
                    ],
                  ],
                ),
                if (_result != null && _result!.passed) ...[
                  const SizedBox(height: 10),
                  _sectionCard(
                    icon: Icons.auto_stories,
                    title: '③ 综合参考报告',
                    children: _reportChildren(_result!, _profile),
                  ),
                ],
                const SizedBox(height: 10),
                _sectionCard(
                  icon: Icons.local_library,
                  title: '④ 疾病知识库（可检索，全部内容本页查看）',
                  children: const [
                    Text(
                      '收录常见疾病的形成机制、对健康的影响、检查方向与就医信号。'
                      '在上方检索或选择分类查看；所有解读均在本页内展示，无外部链接。',
                      style: TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                    SizedBox(height: 10),
                    _DiseaseBrowser(),
                  ],
                ),
                const SizedBox(height: 10),
                _sectionCard(
                  icon: Icons.self_improvement,
                  title: '通用健康原则（NEWSTART 八大自然疗法）',
                  children: const [
                    _Bullet('营养：全谷物、蔬果、豆类、坚果为主，少油腻少糖'),
                    _Bullet('运动：每日适量活动，户外步行最有益'),
                    _Bullet('水：每日足量洁净饮水，少喝含糖饮料'),
                    _Bullet('阳光：适度日晒，愉悦心情'),
                    _Bullet('节制：戒烟限酒，饮食作息有节'),
                    _Bullet('空气：深呼吸新鲜空气，居室常通风'),
                    _Bullet('休息：充足睡眠，每周有一日安息'),
                    _Bullet('信靠：信靠上帝，喜乐平安是健康之基'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  HealthConsultDisclaimer.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, height: 1.5, color: Colors.grey.shade600),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  // ---------- 组件 ----------

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(14)),
        border: Border.fromBorderSide(BorderSide(color: Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool autoTag = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: autoTag ? '$label（已自动识别）' : label,
        hintText: hint,
        helperText: autoTag ? '根据材料自动填入，请核实后再提交' : null,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: autoTag
            ? const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF2E7D32))
            : null,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  /// 自动识别结果横幅：告知填了什么、请核实，可重新识别
  Widget _autoFillBanner() {
    final rec = _recognized!;
    final parts = <String>[];
    if (rec.diagnosis.isNotEmpty) parts.add('诊断');
    if (rec.hospital.isNotEmpty) parts.add('医院');
    if (rec.materialType.isNotEmpty) parts.add('材料类型');
    if (rec.chiefComplaint.isNotEmpty) parts.add('主诉');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_fix_high, size: 16, color: Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '已根据材料自动识别并填入：${parts.join('、')}。'
              '请逐项核实修改后再核验（识别有误可直接改写）。',
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: () => _recognizeAndFill(force: true),
            child: const Text('重新识别', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _attachmentChip(ConsultAttachment a) {
    final (IconData icon, Color color, String label) = switch (a.status) {
      'text_ok' => (Icons.check_circle, const Color(0xFF2E7D32), '已读取文本'),
      'failed' => (Icons.error, Colors.red, '无法读取'),
      _ => (Icons.edit_note, const Color(0xFFEF6C00), '请手动誊写'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text('${a.name}（${label}）',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => _attachments.remove(a)),
            child: const Icon(Icons.close, size: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _verifyCard(VerifyResult r) {
    final levelColor = switch (r.level) {
      DiseaseLevel.major => Colors.red,
      DiseaseLevel.severe => const Color(0xFFEF6C00),
      DiseaseLevel.common => const Color(0xFF1565C0),
      DiseaseLevel.unknown => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: r.passed
            ? const Color(0xFF2E7D32).withOpacity(0.08)
            : const Color(0xFFB71C1C).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: (r.passed
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFB71C1C))
                .withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(r.passed ? Icons.task_alt : Icons.gpp_maybe,
                  size: 18,
                  color: r.passed
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFB71C1C)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  r.passed ? '材料核验通过' : '材料尚不符合要求',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: r.passed
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFB71C1C)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _tag('分级：${r.level.label}', levelColor),
              _tag('要求：${r.level.requirement}', Colors.blueGrey),
            ],
          ),
          if (r.primaryDiagnosis.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('材料所示诊断：${r.primaryDiagnosis}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          if (r.hospitals.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('识别到的医院/机构：',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            for (final h in r.hospitals)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('· $h', style: const TextStyle(fontSize: 12)),
              ),
          ],
          if (r.diagnoses.length > 1) ...[
            const SizedBox(height: 6),
            Text('多处诊断记载：${r.diagnoses.join(' / ')}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
          for (final m in r.missing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('✗ $m',
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFFB71C1C))),
            ),
          for (final n in r.notes)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('ℹ $n',
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFFEF6C00))),
            ),
          if (!r.passed) ...[
            const SizedBox(height: 8),
            const Text('补齐材料后请再次核验；如情况紧急请直接就医。',
                style: TextStyle(fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  List<Widget> _reportChildren(VerifyResult r, DiseaseProfile? p) {
    final children = <Widget>[];
    children.add(Text(
      '材料所示诊断：${r.primaryDiagnosis}',
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ));
    children.add(const SizedBox(height: 4));
    children.add(const Text(
      '以下为基于权威医学科普的通俗解读，帮助病人与家属理解疾病；'
      '具体诊疗请遵循主治医生。全部内容在本页内查看，无外部链接。',
      style: TextStyle(fontSize: 12, color: Colors.black54),
    ));
    children.add(const SizedBox(height: 10));

    if (p != null) {
      children.addAll(_profileSections(p));
    } else {
      children.add(const _SubTitle('知识库暂未收录该诊断'));
      children.add(const Text(
        '内置疾病知识库暂未覆盖此病名（可能为罕见病或写法不同）。'
        '你仍可在下方「④ 疾病知识库」中检索相近疾病查看通识解读；'
        '该诊断的具体诊疗，请引导病人携带材料至正规医院复诊确认。',
        style: TextStyle(fontSize: 13, height: 1.6),
      ));
      children.add(const SizedBox(height: 8));
    }

    children.add(const Text(
      '温馨提示：信仰与祈祷是康复路上的重要力量，请勿因此延误必要的诊疗。'
      '把检查治疗交给专业医生，把心安息在上帝里面。',
      style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.6),
    ));
    return children;
  }

  /// 疾病完整解读 sections（报告区与知识库浏览区共用）。
  /// 全部内容内联展示，不含任何外部链接。
  static List<Widget> _profileSections(DiseaseProfile p) {
    final children = <Widget>[];
    if (p.overview.isNotEmpty) {
      children.add(const _SubTitle('这是什么病'));
      children.add(Text(p.overview,
          style: const TextStyle(fontSize: 13, height: 1.6)));
      children.add(const SizedBox(height: 10));
    }
    if (p.causes.isNotEmpty) {
      children.add(const _SubTitle('怎么形成的（形成机制与诱因）'));
      for (final c in p.causes) children.add(_Bullet(c));
      children.add(const SizedBox(height: 10));
    }
    if (p.impacts.isNotEmpty) {
      children.add(const _SubTitle('对身体健康的影响'));
      for (final i in p.impacts) children.add(_Bullet(i));
      children.add(const SizedBox(height: 10));
    }
    if (p.prognosis.isNotEmpty) {
      children.add(const _SubTitle('后续可能的发展'));
      children.add(Text(p.prognosis,
          style: const TextStyle(fontSize: 13, height: 1.6)));
      children.add(const SizedBox(height: 10));
    }
    if (p.differential.isNotEmpty) {
      children.add(const _SubTitle('需要排除的疾病'));
      for (final d in p.differential) children.add(_Bullet(d));
      children.add(const SizedBox(height: 10));
    }
    if (p.furtherExams.isNotEmpty) {
      children.add(const _SubTitle('建议进一步检查'));
      for (final e in p.furtherExams) children.add(_Bullet(e));
      children.add(const SizedBox(height: 10));
    }
    if (p.seeDoctor.isNotEmpty) {
      children.add(const _SubTitle('出现这些情况，请尽快就医'));
      for (final s in p.seeDoctor) children.add(_Bullet(s));
      children.add(const SizedBox(height: 10));
    }
    if (p.advice.isNotEmpty) {
      children.add(const _SubTitle('医药布道建议（怀著 · NEWSTART）'));
      children.add(const Text(
        '结合怀爱伦著作倡导的八大自然疗法原则与圣经健康律，'
        '以下建议作为生活方式参考，不替代药物治疗：',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ));
      children.add(const SizedBox(height: 6));
      for (final a in p.advice) {
        children.add(_AdviceRow(
            pillar: a['pillar'] ?? '', text: a['text'] ?? ''));
      }
      children.add(const SizedBox(height: 10));
    }
    if (p.sources.isNotEmpty) {
      children.add(const _SubTitle('权威来源（文本引用，无外部链接）'));
      for (final s in p.sources) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text('· $s',
              style: TextStyle(
                  fontSize: 11, height: 1.4, color: Colors.grey.shade700)),
        ));
      }
    }
    return children;
  }
}

class _ScenarioBanner extends StatelessWidget {
  const _ScenarioBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Color(0xFF6A1B9A)),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              '适用场景：已持有病历、报告、检验单等诊断材料时使用。'
              '如还没有材料、说不清是什么问题，可先用「AI 医生 · 多轮问诊」梳理主要不适。',
              style: TextStyle(
                  fontSize: 12, height: 1.5, color: Color(0xFF6A1B9A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplianceBanner extends StatelessWidget {
  const _ComplianceBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF6C00).withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield, size: 16, color: Color(0xFFEF6C00)),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              '本工具为医药布道参考：不诊断、不替代医生；'
              '材料真实性由上传者负责；急症请立即拨打 120。',
              style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  final String text;
  const _SubTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const _MarkBar(),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6A1B9A))),
        ],
      ),
    );
  }
}

/// _SubTitle 左侧紫色竖条（全 const，规避 lint）
class _MarkBar extends StatelessWidget {
  const _MarkBar();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 3,
        height: 14,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFF6A1B9A),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
      );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 6),
            child: Icon(Icons.circle, size: 5, color: Color(0xFF6A1B9A)),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12.5, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  final String pillar;
  final String text;
  const _AdviceRow({required this.pillar, required this.text});

  static const _pillarNames = {
    'NUT': '营养',
    'EXE': '运动',
    'WAT': '水',
    'SUN': '阳光',
    'TEM': '节制',
    'AIR': '空气',
    'RES': '休息',
    'TRU': '信靠',
  };
  static const _pillarColors = {
    'NUT': Color(0xFF2E7D32),
    'EXE': Color(0xFF1565C0),
    'WAT': Color(0xFF0097A7),
    'SUN': Color(0xFFF9A825),
    'TEM': Color(0xFF6A1B9A),
    'AIR': Color(0xFF00796B),
    'RES': Color(0xFF3949AB),
    'TRU': Color(0xFF8D6E63),
  };

  @override
  Widget build(BuildContext context) {
    final color = _pillarColors[pillar] ?? const Color(0xFF6A1B9A);
    final name = _pillarNames[pillar] ?? pillar;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(name,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12.5, height: 1.55)),
          ),
        ],
      ),
    );
  }
}

/// 疾病知识库浏览器：按名称/别名/分类检索，完整解读在本页内联展开。
/// 数据来自 ConsultData.diseases（离线 JSON），无任何外部链接。
class _DiseaseBrowser extends StatefulWidget {
  const _DiseaseBrowser();

  @override
  State<_DiseaseBrowser> createState() => _DiseaseBrowserState();
}

class _DiseaseBrowserState extends State<_DiseaseBrowser> {
  String _query = '';
  String _category = 'all';
  String? _expandedId;

  static const _categoryLabels = {
    'cardio': '心血管', 'neuro': '神经', 'resp': '呼吸', 'gi': '消化',
    'renal': '泌尿', 'blood': '血液', 'immune': '风湿免疫', 'endo': '内分泌',
    'metabolic': '代谢', 'tumor': '肿瘤', 'mental': '精神心理', 'derm': '皮肤',
    'eye': '眼科', 'ent': '耳鼻喉', 'ortho': '骨科', 'gyne': '妇科',
    'peds': '儿科', 'infect': '感染', 'other': '其他',
  };

  static const _severityLabels = {
    'major': ('重大', Color(0xFFB71C1C)),
    'severe': ('严重', Color(0xFFEF6C00)),
    'common': ('常见', Color(0xFF1565C0)),
  };

  List<DiseaseProfile> get _filtered {
    final q = _query.trim();
    return ConsultData.diseases.where((d) {
      if (_category != 'all' && d.category != _category) return false;
      if (q.isEmpty) return true;
      if (d.name.contains(q)) return true;
      for (final a in d.aliases) {
        if (a.contains(q)) return true;
      }
      final label = _categoryLabels[d.category] ?? '';
      return label.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (ConsultData.diseases.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('知识库加载中…', style: TextStyle(fontSize: 12.5)),
      );
    }
    // 分类计数（按出现顺序）
    final counts = <String, int>{};
    for (final d in ConsultData.diseases) {
      counts[d.category] = (counts[d.category] ?? 0) + 1;
    }
    final results = _filtered;
    final shown = results.take(30).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: '检索疾病名称 / 别名 / 分类，如「糖尿病」「肿瘤」「甲亢」',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _query = ''),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _catChip('全部', ConsultData.diseases.length, 'all'),
              for (final e in counts.entries)
                _catChip(_categoryLabels[e.key] ?? e.key, e.value, e.key),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _query.isEmpty && _category == 'all'
              ? '共收录 ${ConsultData.diseases.length} 种疾病'
              : '找到 ${results.length} 种疾病',
          style: const TextStyle(fontSize: 11.5, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('未找到匹配疾病，请换个关键词或分类试试。',
                style: TextStyle(fontSize: 12.5)),
          ),
        for (final d in shown) _diseaseCard(d),
        if (results.length > shown.length)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('结果较多，仅显示前 30 种，请细化检索条件。',
                style: TextStyle(fontSize: 11.5, color: Colors.black54)),
          ),
      ],
    );
  }

  Widget _catChip(String label, int count, String key) {
    final selected = _category == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text('$label $count', style: const TextStyle(fontSize: 11.5)),
        selected: selected,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(() => _category = key),
      ),
    );
  }

  Widget _diseaseCard(DiseaseProfile d) {
    final expanded = _expandedId == d.id;
    final sev = _severityLabels[d.severityHint] ??
        const ('', Color(0xFF1565C0));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: expanded ? const Color(0xFFF3E5F5).withOpacity(0.4) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: expanded
                ? const Color(0xFF6A1B9A).withOpacity(0.4)
                : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(d.name,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
              _tag('${_categoryLabels[d.category] ?? d.category}', Colors.blueGrey),
              const SizedBox(width: 4),
              _tag(sev.$1, sev.$2),
            ],
          ),
          const SizedBox(height: 4),
          Text(d.overview,
              maxLines: expanded ? null : 2,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.5)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  setState(() => _expandedId = expanded ? null : d.id),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(
                expanded ? '收起 ▲' : '展开完整解读 ▼',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 12),
            // _profileSections 已含「权威来源」小节，这里不重复渲染
            ..._HealthConsultPageState._profileSections(d),
            if (d.aliases.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('别称：${d.aliases.join('、')}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ),
            const SizedBox(height: 6),
            Text(
              '以上为医学科普通识，不构成诊疗建议；诊断与治疗请以正规医院和医生意见为准。',
              style: TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

/// 常驻免责声明
class HealthConsultDisclaimer {
  static const String text =
      '本工具不提供医疗诊断，所有信息仅供参考；'
      '疾病的诊断与治疗请以正规医院和医生意见为准。';
}
