import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'consult_dialog_engine.dart';
import 'consult_dialog_models.dart';
import 'consult_models.dart' show AttachmentParser;

/// AI 医生助手 —— 多轮对话式问诊页。
///
/// 合规边界（不可逾越）：
/// - 系统不做确定性诊断：只给「可能性判断 + 依据 + 需排除 + 建议检查」；
/// - 急症信号立即输出就医指导（120 / 心理援助热线 12356）；
/// - 附件材料仅呈现材料所示信息；结论必带不确定性与免责声明；
/// - 疾病科普全部由内置多来源资料整合生成，不跳转外部网页。
class ConsultChatPage extends StatefulWidget {
  const ConsultChatPage({super.key});

  @override
  State<ConsultChatPage> createState() => _ConsultChatPageState();
}

class _Msg {
  final bool fromDoctor;
  final String text;
  final DoctorReply? reply;
  final String? attachmentName;
  final bool isRedFlag;
  final bool isSystem;

  const _Msg({
    required this.fromDoctor,
    required this.text,
    this.reply,
    this.attachmentName,
    this.isRedFlag = false,
    this.isSystem = false,
  });
}

class _ConsultChatPageState extends State<ConsultChatPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [];
  final Set<String> _pendingMulti = {};

  ConsultDialogEngine? _engine;
  bool _loaded = false;
  bool _picking = false;
  DoctorReply? _lastReply;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final base = 'assets/web/';
    final scriptsJson =
        jsonDecode(await rootBundle.loadString('${base}consult_scripts.json'))
            as Map<String, dynamic>;
    final scripts = ConsultScripts.fromJson(scriptsJson);
    final knowledge = <DiseaseKnowledge>[];
    for (final p in const [
      'disease_profiles.json',
      'disease_profiles_2.json',
    ]) {
      final j = jsonDecode(await rootBundle.loadString('$base$p'))
          as Map<String, dynamic>;
      for (final d in (j['diseases'] as List).cast<Map<String, dynamic>>()) {
        knowledge.add(DiseaseKnowledge.fromJson(d));
      }
    }
    final rules = jsonDecode(await rootBundle.loadString('${base}hospital_tier_a.json'))
        as Map<String, dynamic>;
    final engine = ConsultDialogEngine(
      scripts: scripts,
      knowledge: knowledge,
      tierMarks: (rules['tierMarks'] as List).cast<String>(),
      hospitalKeywords: (rules['hospitalKeywords'] as List).cast<String>(),
      majorKeywords: (rules['majorDiseaseKeywords'] as List).cast<String>(),
      severeKeywords: (rules['severeDiseaseKeywords'] as List).cast<String>(),
    );
    if (!mounted) return;
    setState(() {
      _engine = engine;
      _loaded = true;
    });
    _pushDoctor(engine.start());
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _pushDoctor(DoctorReply r) {
    setState(() {
      _messages.add(_Msg(
        fromDoctor: true,
        text: r.text,
        reply: r,
        isRedFlag: r.isRedFlag,
        isSystem: r.isSystemCard,
      ));
      _lastReply = r;
      if (!(engineCurrentIsMulti)) _pendingMulti.clear();
    });
    _scrollToEnd();
  }

  bool get engineCurrentIsMulti => _engine?.currentQuestionIsMulti ?? false;

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty || _engine == null) return;
    setState(() {
      _messages.add(_Msg(fromDoctor: false, text: t));
      _inputCtrl.clear();
      _pendingMulti.clear();
    });
    final reply = _engine!.submit(t);
    _pushDoctor(reply);
  }

  void _onQuickOption(String opt) {
    final e = _engine;
    if (e == null) return;
    if (engineCurrentIsMulti) {
      setState(() {
        if (_pendingMulti.contains(opt)) {
          _pendingMulti.remove(opt);
        } else {
          _pendingMulti.add(opt);
        }
      });
      return;
    }
    _send(opt);
  }

  Future<void> _pickFiles() async {
    final e = _engine;
    if (e == null) return;
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
        setState(() {
          _messages.add(_Msg(
            fromDoctor: false,
            text: '上传了材料：${f.name}',
            attachmentName: f.name,
          ));
        });
        _pushDoctor(e.addMaterial(f.name, att.extractedText));
      }
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件失败：$err')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _restart() {
    final e = _engine;
    if (e == null) return;
    setState(() {
      _messages.clear();
      _pendingMulti.clear();
    });
    _pushDoctor(e.start());
  }

  @override
  Widget build(BuildContext context) {
    final e = _engine;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 医生助手'),
        actions: [
          if (_loaded)
            IconButton(
              tooltip: '重新开始',
              icon: const Icon(Icons.refresh),
              onPressed: _restart,
            ),
        ],
      ),
      body: _loaded
          ? Column(
              children: [
                const _ChatBanner(),
                if (e != null && e.phase == ConsultPhase.interviewing)
                  _ProgressBar(done: e.answeredCount, total: e.totalQuestions),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _messageView(_messages[i]),
                  ),
                ),
                if (_lastReply != null && _lastReply!.quickOptions.isNotEmpty)
                  _QuickOptions(
                    options: _lastReply!.quickOptions,
                    multiMode: engineCurrentIsMulti,
                    pending: engineCurrentIsMulti ? _pendingMulti : const <String>{},
                    onTap: _onQuickOption,
                    onSendMulti: () => _send(_pendingMulti.join('、')),
                  ),
                _InputBar(
                  controller: _inputCtrl,
                  picking: _picking,
                  onSend: () => _send(_inputCtrl.text),
                  onAttach: _pickFiles,
                  multiCount: engineCurrentIsMulti ? _pendingMulti.length : 0,
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _messageView(_Msg m) {
    if (m.fromDoctor && m.reply != null && m.reply!.report != null) {
      return _ReportCard(m.reply!.report!);
    }
    if (m.fromDoctor && m.reply != null && m.reply!.knowledge != null) {
      return _KnowledgeCard(m.reply!.knowledge!);
    }
    if (m.fromDoctor && m.isRedFlag) {
      return _Bubble(
        fromDoctor: true,
        red: true,
        child: _RichText(m.text),
      );
    }
    if (m.fromDoctor && m.isSystem) {
      return _Bubble(
        fromDoctor: true,
        system: true,
        child: _RichText(m.text),
      );
    }
    return _Bubble(
      fromDoctor: m.fromDoctor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.attachmentName != null) _AttachmentTag(m.attachmentName!),
          if (m.text.isNotEmpty) _RichText(m.text),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 基础组件
// ---------------------------------------------------------------------------

class _Bubble extends StatelessWidget {
  final bool fromDoctor;
  final Widget child;
  final bool red;
  final bool system;

  const _Bubble({
    required this.fromDoctor,
    required this.child,
    this.red = false,
    this.system = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = red
        ? const Color(0xFFFDECEA)
        : system
            ? const Color(0xFFFFF8E1)
            : fromDoctor
                ? const Color(0xFFE8F0FE)
                : const Color(0xFFF3E5F5);
    final border = red
        ? const Color(0xFFD93025)
        : system
            ? const Color(0xFFF9AB00)
            : Colors.transparent;
    return Align(
      alignment: fromDoctor ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: red || system ? 1 : 0),
        ),
        child: child,
      ),
    );
  }
}

/// 解析 **加粗** 的简易富文本
class _RichText extends StatelessWidget {
  final String text;
  const _RichText(this.text);

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontWeight: i.isOdd ? FontWeight.bold : FontWeight.normal,
          color: Colors.black87,
          height: 1.45,
          fontSize: 14,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _AttachmentTag extends StatelessWidget {
  final String name;
  const _AttachmentTag(this.name);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF6A1B9A).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, size: 13, color: Color(0xFF6A1B9A)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF6A1B9A)),
              ),
            ),
          ],
        ),
      );
}

class _ChatBanner extends StatelessWidget {
  const _ChatBanner();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xFFFFF3E0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: const Row(
          children: [
            Icon(Icons.health_and_safety, size: 15, color: Color(0xFFE8710A)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                '本助手仅供健康咨询参考：不诊断、不替代医生；'
                '材料真实性由上传者负责；紧急情况请拨打 120。',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF8C4A00)),
              ),
            ),
          ],
        ),
      );
}

class _ProgressBar extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressBar({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final v = (done / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          const Icon(Icons.fact_check_outlined, size: 14, color: Color(0xFF6A1B9A)),
          const SizedBox(width: 6),
          Text('问诊进度 $done / $total',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: v,
              minHeight: 4,
              backgroundColor: const Color(0xFFEDE7F6),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6A1B9A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickOptions extends StatelessWidget {
  final List<String> options;
  final bool multiMode;
  final Set<String> pending;
  final void Function(String) onTap;
  final VoidCallback onSendMulti;

  const _QuickOptions({
    required this.options,
    required this.multiMode,
    required this.pending,
    required this.onTap,
    required this.onSendMulti,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 0,
        children: [
          for (final opt in options)
            FilterChip(
              label: Text(opt, style: const TextStyle(fontSize: 12)),
              selected: multiMode && pending.contains(opt),
              onSelected: (_) => onTap(opt),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFFEDE7F6),
              checkmarkColor: const Color(0xFF6A1B9A),
              side: const BorderSide(color: Color(0xFFD1C4E9)),
            ),
          if (multiMode && pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: onSendMulti,
                child: Text('发送所选 ${pending.length} 项',
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool picking;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final int multiCount;

  const _InputBar({
    required this.controller,
    required this.picking,
    required this.onSend,
    required this.onAttach,
    required this.multiCount,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
          color: Colors.white,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '上传检查报告/图片',
              icon: Icon(picking ? Icons.hourglass_empty : Icons.attach_file,
                  color: const Color(0xFF6A1B9A)),
              onPressed: picking ? null : onAttach,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: multiCount > 0 ? '已选 $multiCount 项，点右侧发送' : '输入您的症状或回答…',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFF6A1B9A),
              child: IconButton(
                icon: const Icon(Icons.send, size: 17, color: Colors.white),
                onPressed: onSend,
              ),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// 报告卡 / 资料卡
// ---------------------------------------------------------------------------

class _ReportCard extends StatelessWidget {
  final ConsultReport report;
  const _ReportCard(this.report);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1C4E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader('📋 初步分析报告', '仅供参考 · 不能替代医生面诊', const Color(0xFF6A1B9A)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.redFlagMsg != null) _redBlock(report.redFlagMsg!),
                if (report.material != null) _materialBlock(report.material!),
                if (report.findings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('以目前的信息，暂不足以形成有依据的方向性判断。'
                        '建议补充症状细节，或直接就诊由医生当面评估。',
                        style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5)),
                  ),
                for (final f in report.findings) _findingBlock(f),
                const SizedBox(height: 6),
                _sectionTitle('⚠️ 判断的局限性'),
                for (final u in report.uncertainties) _bullet(u),
                const SizedBox(height: 8),
                _sectionTitle('🏥 就医指引'),
                _bullet('建议挂号科室：${report.department}'),
                _bullet('就诊时带上既往病历、用药清单与本模块内的问诊记录'),
                _bullet('症状持续或加重、出现急症信号时，请立即就医或拨打 120'),
                const SizedBox(height: 8),
                _footer('本报告由 AI 基于您提供的信息生成，未经医生面诊与检验确认，'
                    '不构成诊断或治疗建议。'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _redBlock(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD93025)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD93025), size: 18),
            const SizedBox(width: 6),
            Expanded(child: _RichText(msg)),
          ],
        ),
      );

  Widget _materialBlock(MaterialScan m) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📎 您上传的材料（材料所示信息，非本系统诊断）',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20))),
            for (final n in m.notes) _bullet(n, color: const Color(0xFF1B5E20)),
          ],
        ),
      );

  Widget _findingBlock(ConsultFinding f) {
    final tierColor = f.tier == '可能性较大'
        ? const Color(0xFFD93025)
        : f.tier == '有可能'
            ? const Color(0xFFE8710A)
            : const Color(0xFF5F6368);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(f.name,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(f.tier,
                    style: TextStyle(fontSize: 11, color: tierColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (f.evidence.isNotEmpty) ...[
            const SizedBox(height: 5),
            const Text('判断依据：', style: TextStyle(fontSize: 12, color: Colors.black54)),
            for (final ev in f.evidence) _bullet('您提到「$ev」'),
          ],
          if (f.exclude.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('需要排除：', style: TextStyle(fontSize: 12, color: Colors.black54)),
            for (final ex in f.exclude) _bullet(ex),
          ],
          if (f.exams.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('建议检查：', style: TextStyle(fontSize: 12, color: Colors.black54)),
            for (final ex in f.exams) _bullet(ex),
          ],
        ],
      ),
    );
  }
}

class _KnowledgeCard extends StatelessWidget {
  final DiseaseKnowledge k;
  const _KnowledgeCard(this.k);

  static const _pillarNames = {
    'NUT': '营养', 'EXE': '运动', 'WAT': '水', 'TEM': '节制',
    'RES': '休息', 'AIR': '空气', 'TRU': '信心',
  };

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC8E6C9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader('📚 ${k.name}', '综合权威医学科普资料整理', const Color(0xFF2E7D32)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (k.overview.isNotEmpty) _para(k.overview),
                  if (k.causes.isNotEmpty) ...[
                    _sectionTitle('为什么会这样'),
                    for (final c in k.causes) _bullet(c),
                  ],
                  if (k.impacts.isNotEmpty) ...[
                    _sectionTitle('对身体的影响'),
                    for (final c in k.impacts) _bullet(c),
                  ],
                  if (k.prognosis.isNotEmpty) _para('发展趋势：${k.prognosis}'),
                  if (k.advice.isNotEmpty) ...[
                    _sectionTitle('NEWSTART 八大自然疗法建议'),
                    for (final a in k.advice)
                      _bullet('[${_pillarNames[a['pillar']] ?? a['pillar']}] ${a['text']}'),
                  ],
                  if (k.furtherExams.isNotEmpty) ...[
                    _sectionTitle('建议检查'),
                    for (final c in k.furtherExams) _bullet(c),
                  ],
                  if (k.differential.isNotEmpty) ...[
                    _sectionTitle('需要排除的疾病'),
                    for (final c in k.differential) _bullet(c),
                  ],
                  if (k.seeDoctor.isNotEmpty) ...[
                    _sectionTitle('出现这些情况请尽快就医'),
                    for (final c in k.seeDoctor) _bullet(c),
                  ],
                  if (k.sources.isNotEmpty) ...[
                    _sectionTitle('资料整合来源'),
                    for (final s in k.sources)
                      _bullet(s, color: const Color(0xFF2E7D32)),
                  ],
                  const SizedBox(height: 8),
                  _footer('以上为权威资料的通俗整合，仅供了解；'
                      '具体诊疗请以医生面诊为准。'),
                ],
              ),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// 小组件
// ---------------------------------------------------------------------------

Widget _cardHeader(String title, String subtitle, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.black45)),
        ],
      ),
    );

Widget _sectionTitle(String t) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 3),
      child: Text(t,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
    );

Widget _bullet(String t, {Color color = Colors.black87}) => Padding(
      padding: const EdgeInsets.only(left: 6, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('· ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(t,
                style: TextStyle(fontSize: 12.5, color: color, height: 1.45)),
          ),
        ],
      ),
    );

Widget _para(String t) => Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(t, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.55)),
    );

Widget _footer(String t) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(t,
          style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.4)),
    );
