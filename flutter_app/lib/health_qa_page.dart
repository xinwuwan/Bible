// health_qa_page.dart
// 模块 C 健康问答对话页（离线优先，本地 NEWSTART 知识库）
//
// 与模块 B 牧师问答同源的「回信」式渲染：结论加粗强调条 + 序号自动分行 +
// 结尾祝福暖色斜体；每条回答附权威出处（圣经 KJV / 怀爱伦著作）。
// 不提供医疗诊断，涉及具体症状/用药必引导就医。

import 'package:flutter/material.dart';

import 'health_qa_logic.dart';

/// 把 **加粗** 渲染为粗体（与牧师问答一致）
Widget buildHealthRichText(String text, TextStyle base) {
  final spans = <TextSpan>[];
  final boldRe = RegExp(r'\*\*(.+?)\*\*');
  var last = 0;
  for (final m in boldRe.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
    }
    spans.add(TextSpan(
      text: m.group(1),
      style: base.copyWith(fontWeight: FontWeight.bold),
    ));
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last)));
  }
  return Text.rich(
    TextSpan(style: base, children: spans),
    style: base,
    textAlign: TextAlign.start,
  );
}

class HealthQaPage extends StatefulWidget {
  const HealthQaPage({super.key});

  @override
  State<HealthQaPage> createState() => _HealthQaPageState();
}

class _HealthQaPageState extends State<HealthQaPage> {
  final _ctrl = TextEditingController();
  HealthQaLogic? _logic;
  final List<_Turn> _turns = [];
  bool _sending = false;

  static const _accent = Color(0xFF2E7D32);
  static const _warm = Color(0xFF8D6E63);
  static const _teal = Color(0xFF00796B);

  @override
  void initState() {
    super.initState();
    HealthQaLogic.load().then((l) {
      if (mounted) setState(() => _logic = l);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final q = _ctrl.text.trim();
    if (q.isEmpty || _sending || _logic == null) return;
    _ctrl.clear();
    final idx = _turns.length;
    setState(() {
      _turns.add(_Turn(question: q, loading: true));
      _sending = true;
    });
    final ans = _logic!.ask(q);
    if (mounted) {
      setState(() {
        _turns[idx] = _Turn(question: q, answer: ans);
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('健康问答')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFE8F5E9),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: const Text(
              '回答依据 NEWSTART 健康原则、圣经与怀爱伦著作，并附权威出处；'
              '本内容不替代专业医疗诊断，如有健康问题请咨询医生。',
              style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), height: 1.4),
            ),
          ),
          Expanded(
            child: _logic == null
                ? const Center(child: CircularProgressIndicator())
                : _turns.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 28),
                          child: Text(
                            '关于健康，有任何想问的都可以问我：\n'
                            '怎么开始健康饮食？每天该喝多少水？睡不好怎么办？\n'
                            '我愿陪你一起，从 NEWSTART 八个支点慢慢改善。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: Colors.black54, height: 1.6),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: _turns.length,
                        itemBuilder: (_, i) => _TurnView(
                          turn: _turns[i], accent: _accent, warm: _warm, teal: _teal,
                        ),
                      ),
          ),
          _Composer(ctrl: _ctrl, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class _Turn {
  final String question;
  final bool loading;
  final HealthQaAnswer? answer;
  _Turn({required this.question, this.loading = false, this.answer});
}

class _TurnView extends StatelessWidget {
  final _Turn turn;
  final Color accent;
  final Color warm;
  final Color teal;

  const _TurnView(
      {required this.turn, required this.accent, required this.warm, required this.teal});

  @override
  Widget build(BuildContext context) {
    final base = const TextStyle(fontSize: 14, height: 1.55);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFC5CAE9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(turn.question, style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(height: 6),
          if (turn.loading)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _AnswerCard(
                  answer: turn.answer!, base: base, accent: accent, warm: warm, teal: teal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 健康顾问回信卡片：结论强调条 + 序号分行 + 结尾祝福斜体 + 出处
class _AnswerCard extends StatelessWidget {
  final HealthQaAnswer answer;
  final TextStyle base;
  final Color accent;
  final Color warm;
  final Color teal;

  const _AnswerCard({
    required this.answer,
    required this.base,
    required this.accent,
    required this.warm,
    required this.teal,
  });

  List<String> get _lines {
    final t = answer.answerZh.replaceAllMapped(
        RegExp(r'([①②③④⑤⑥⑦⑧⑨⑩])'), (m) => '\n${m.group(1)}');
    return t
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  bool _isCloser(String line) =>
      line.length <= 44 &&
      !line.contains('**') &&
      !line.contains('（') &&
      RegExp(r'^(愿|若|如果|欢迎|把|主必|主与|让|你|在|弟兄|祝愿|安康)').hasMatch(line);

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    final conclusionIdx = lines.indexWhere((l) => l.contains('**'));
    final lastIdx = lines.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            SizedBox(
              width: 22, height: 22,
              child: CircleAvatar(
                radius: 11, backgroundColor: Color(0xFF2E7D32),
                child: Icon(Icons.health_and_safety, size: 13, color: Colors.white),
              ),
            ),
            SizedBox(width: 6),
            Text('健康顾问',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
          ],
        ),
        const Divider(height: 12),
        for (var i = 0; i < lines.length; i++) ...[
          if (i == conclusionIdx)
            Container(
              margin: const EdgeInsets.only(top: 2, bottom: 6),
              padding: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFF2E7D32), width: 3)),
              ),
              child: buildHealthRichText(
                lines[i],
                base.copyWith(fontSize: 14.5, height: 1.6, fontWeight: FontWeight.w500),
              ),
            )
          else if (i == lastIdx && lines.length > 1 && _isCloser(lines[i]))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: buildHealthRichText(
                lines[i],
                base.copyWith(fontStyle: FontStyle.italic, color: Color(0xFF8D6E63), fontSize: 13.5),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: buildHealthRichText(lines[i], base),
            ),
        ],
        if (answer.citations.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final c in answer.citations)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: teal.withOpacity(0.4)),
                  ),
                  child: Text(
                    '${c.sourceType.label} · ${c.ref}',
                    style: TextStyle(fontSize: 11.5, color: teal),
                  ),
                ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text('（无具体出处，已诚实转介医生）',
              style: TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({required this.ctrl, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: '问问健康：怎么吃更营养？怎样睡得好？',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: sending
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              onPressed: sending ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}
