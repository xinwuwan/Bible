// qa_page.dart
// 模块 B 牧师问答对话页
//
// 关键行为（对齐后端校验闸门，前端再拦一道）:
//   1. needs_human=true        → 只展示引导语 + 「转人工顾问」入口，不把模型回答当定论
//   2. citations 为空 / 含 cuv → 判定 blocked，【不展示 answer_zh】，只显示拦截原因
//   3. confidence < 0.70       → 展示低置信提示与转人工建议
//   4. 每条回答附权威引用，点击跳回原文（产出 → 来源闭环）
//   5. 用户可纠错/评分 → qa_feedback → 必要时进 review_queue

import 'package:flutter/material.dart';

import 'citation_list.dart';
import 'mailto_helper.dart';
import 'qa_models.dart';
import 'qa_repository.dart';

/// 人工顾问答复邮箱：转人工时，用户的问题将以邮件形式发送到此地址。
/// 留空 = 人工通道尚未配置（点击按钮会给出诚实提示，绝不假装"已提交"）。
const String kHumanReviewEmail = '';

/// 将答案文本中的 **加粗** 标记渲染为粗体（轻量 Markdown 支持，不引入额外依赖）。
/// 用于「结论先行」——把每条回答的开头结论用 **...** 标粗，让用户一眼看到重点。
Widget buildAnswerRichText(String text, TextStyle base) {
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

class QaPage extends StatefulWidget {
  final QaRepository repo;
  final ValueChanged<QaCitation>? onOpenCitation;

  const QaPage({super.key, required this.repo, this.onOpenCitation});

  @override
  State<QaPage> createState() => _QaPageState();
}

class _QaPageState extends State<QaPage> {
  final _ctrl = TextEditingController();
  final List<QaTurn> _turns = [];
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty || _sending) return;
    _ctrl.clear();
    final idx = _turns.length;
    setState(() {
      _turns.add(QaTurn(question: q, loading: true));
      _sending = true;
    });
    try {
      final answer = await widget.repo.ask(q);
      final violations = CitationGuard.check(answer);
      if (!mounted) return;
      setState(() {
        _turns[idx] = QaTurn(question: q, answer: answer, guardViolations: violations);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _turns[idx] = QaTurn(question: q, error: e.toString());
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _feedback(QaAnswer a, int rating) async {
    String? comment;
    if (rating <= 2) {
      comment = await showDialog<String>(
        context: context,
        builder: (_) => _FeedbackDialog(),
      );
      if (comment == null) return; // 取消
    }
    try {
      await widget.repo.sendFeedback(a.answerId, rating, comment: comment);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('感谢反馈，已记入 qa_feedback 并进入复核流程')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('反馈提交失败：$e')),
      );
    }
  }

  void _requestHuman(QaAnswer a, String question) {
    // 转人工：配置了答复邮箱 → 打开邮件客户端并预填问题（真实送达站长）；
    // 未配置 → 诚实告知问题不会被发送，不假装"已提交顾问台"。
    if (kHumanReviewEmail.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('人工顾问暂未开通'),
          content: const Text(
            '当前版本的人工通道尚未配置答复邮箱，你的问题不会被发送。\n\n'
            '你可以：\n'
            '① 直接输入经文引用（如「创世记11:31」），立即查经并附权威出处；\n'
            '② 稍后再试；\n'
            '③ 通过其他渠道联系站长。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    final subject = '【圣经应用·转人工】问题（answer_id=${a.answerId}）';
    final body = '问题原文：\n$question\n\n'
        '——来自圣经应用「牧师问答」的人工答复请求（answer_id=${a.answerId}）';
    final url = 'mailto:$kHumanReviewEmail'
        '?subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}';
    openExternalUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已打开邮件应用，问题将发送至 $kHumanReviewEmail，由站长人工答复')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('牧师问答')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFE8F5E9),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: const Text(
              '回答依据 KJV 圣经、怀爱伦原版著作与教会教义，'
              '并附权威出处；涉及医疗的内容不构成诊断建议。',
              style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), height: 1.4),
            ),
          ),
          Expanded(
            child: _turns.isEmpty
                ? const Center(child: Text('提出你的信仰或教义问题'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _turns.length,
                    itemBuilder: (_, i) => _TurnView(
                      turn: _turns[i],
                      onOpenCitation: widget.onOpenCitation,
                      onFeedback: _feedback,
                      onRequestHuman: _requestHuman,
                    ),
                  ),
          ),
          _Composer(ctrl: _ctrl, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

/// 单轮对话视图
class _TurnView extends StatelessWidget {
  final QaTurn turn;
  final ValueChanged<QaCitation>? onOpenCitation;
  final void Function(QaAnswer, int) onFeedback;
  final void Function(QaAnswer answer, String question) onRequestHuman;

  const _TurnView({
    required this.turn,
    this.onOpenCitation,
    required this.onFeedback,
    required this.onRequestHuman,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 用户提问
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
          _answerArea(context),
        ],
      ),
    );
  }

  Widget _answerArea(BuildContext context) {
    if (turn.loading) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (turn.error != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text('请求失败：${turn.error}', style: const TextStyle(color: Colors.red)),
      );
    }
    final a = turn.answer;
    if (a == null) return const SizedBox.shrink();

    // 闸门拦截：不展示回答正文
    if (turn.blocked) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE65100).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.gpp_maybe_outlined, size: 16, color: Color(0xFFE65100)),
                  SizedBox(width: 6),
                  Text('已拦截（未通过校验闸门）',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE65100))),
                ],
              ),
              const SizedBox(height: 6),
              ...turn.guardViolations.map(
                (v) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('· $v', style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 28,
                child: OutlinedButton(
                  onPressed: () => onRequestHuman(a, turn.question),
                  child: const Text('转人工顾问', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 正常回答（或 needs_human 的引导语）
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildAnswerRichText(
              a.answerZh,
              const TextStyle(fontSize: 14, height: 1.55),
            ),
            if (a.needsHuman) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  onPressed: () => onRequestHuman(a, turn.question),
                  icon: const Icon(Icons.support_agent, size: 14),
                  label: const Text('转人工顾问', style: TextStyle(fontSize: 12)),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              CitationList(citations: a.citations, onTap: onOpenCitation),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '置信度 ${(a.confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => onFeedback(a, 5),
                    child: const Icon(Icons.thumb_up_off_alt, size: 16),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => onFeedback(a, 1),
                    child: const Icon(Icons.thumb_down_off_alt, size: 16),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 底部输入栏
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
                  hintText: '输入你的问题…',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
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

/// 差评时的补充说明对话框
class _FeedbackDialog extends StatefulWidget {
  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('哪里不准确？'),
      content: TextField(
        controller: _c,
        maxLines: 3,
        decoration: const InputDecoration(hintText: '可选：补充说明，将进入复核队列'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_c.text.trim()),
          child: const Text('提交'),
        ),
      ],
    );
  }
}
