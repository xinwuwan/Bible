// health_topic_page.dart
// 模块 C：单个 NEWSTART 支柱详情页
//   支柱说明 → 权威依据 → 指导条目（过医学审核闸门）→ 今日打卡

import 'package:flutter/material.dart';
import 'health_checkin_sheet.dart';
import 'health_models.dart';
import 'health_theme.dart';
import 'health_repository.dart';

class HealthTopicPage extends StatefulWidget {
  final HealthRepository repo;
  final HealthTopic topic;
  final List<HealthMetric> metrics;
  final List<HealthLogEntry> logs;
  final String userId;
  final bool previewMode;

  const HealthTopicPage({
    super.key,
    required this.repo,
    required this.topic,
    required this.metrics,
    required this.logs,
    required this.userId,
    this.previewMode = false,
  });

  @override
  State<HealthTopicPage> createState() => _HealthTopicPageState();
}

class _HealthTopicPageState extends State<HealthTopicPage> {
  List<HealthSource> _sources = const [];
  List<HealthGuidance> _guidance = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sources = await widget.repo.loadSources(widget.topic.topicId);
      final guidance = await widget.repo.loadGuidance(widget.topic.topicId);
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _guidance = guidance;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '内容加载失败：$e';
        _loading = false;
      });
    }
  }

  List<HealthLogEntry> get _todayLogs {
    final now = DateTime.now();
    return widget.logs
        .where((e) => e.topicCode == widget.topic.code && e.isSameDay(now))
        .toList();
  }

  /// 经闸门过滤后的可展示条目
  List<HealthGuidance> get _visibleGuidance => _guidance
      .where((g) => HealthGuard.visible(g, previewMode: widget.previewMode))
      .toList();

  int get _blockedCount => _guidance.length - _visibleGuidance.length;

  Future<void> _checkin() async {
    final ok = await showHealthCheckinSheet(
      context: context,
      topic: widget.topic,
      metrics: widget.metrics,
      todayLogs: _todayLogs,
      userId: widget.userId,
      onSave: (entries) async {
        for (final e in entries) {
          await widget.repo.saveLog(e);
        }
      },
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('打卡已保存')));
      setState(() {}); // 触发今日记录区刷新（父级返回时也会整体 _load）
    }
  }

  @override
  Widget build(BuildContext context) {
    final ns = widget.topic.newstart;
    final color = ns?.color ?? Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.displayName),
        actions: [
          IconButton(
            tooltip: '今日打卡',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _checkin,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _checkin,
        icon: const Icon(Icons.check),
        label: const Text('打卡'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _SummaryCard(topic: widget.topic, color: color),
                const SizedBox(height: 14),
                _SectionTitle(text: '权威依据（${_sources.length}）'),
                const SizedBox(height: 6),
                if (_sources.isEmpty)
                  const Text('尚未绑定权威来源（需编辑按权威库逐条补齐）')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sources.map(_sourceChip).toList(),
                  ),
                const SizedBox(height: 18),
                _SectionTitle(text: '今日记录（${_todayLogs.length}）'),
                const SizedBox(height: 6),
                if (_todayLogs.isEmpty)
                  const Text('今日尚未打卡',
                      style: TextStyle(color: Colors.grey))
                else
                  ..._todayLogs.map(_logTile),
                const SizedBox(height: 18),
                _SectionTitle(text: '指导条目（${_visibleGuidance.length}）'),
                const SizedBox(height: 6),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                if (_blockedCount > 0)
                  _BlockedNotice(count: _blockedCount),
                ..._visibleGuidance.map(_guidanceCard),
                if (_visibleGuidance.isEmpty && _error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('暂无可展示的指导条目（均待医学审核）'),
                  ),
                const SizedBox(height: 16),
                Text(
                  HealthGuard.defaultDisclaimer,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
    );
  }

  Widget _sourceChip(HealthSource s) {
    return Chip(
      avatar: Icon(
        s.sourceType == HealthSourceType.bible
            ? Icons.menu_book_outlined
            : (s.sourceType == HealthSourceType.egw
                ? Icons.auto_stories_outlined
                : Icons.account_balance_outlined),
        size: 16,
      ),
      label: Text('${s.sourceType.label} · ${s.sourceId}'),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _logTile(HealthLogEntry e) {
    final m = widget.metrics
        .where((x) => x.metricId == e.metricId)
        .cast<HealthMetric?>()
        .firstWhere((x) => x != null, orElse: () => null);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_circle_outline, size: 18),
      title: Text(m?.nameZh ?? '指标 #${e.metricId}'),
      trailing: Text('${e.value}${m?.unitLabel ?? ''}'),
    );
  }

  Widget _guidanceCard(HealthGuidance g) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(g.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (g.evidenceLevel != null) _EvidenceBadge(g.evidenceLevel!),
              ],
            ),
            const SizedBox(height: 8),
            Text(g.bodyZh,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.5)),
            if (widget.previewMode && !g.medicalReviewed) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('内部预览：本条尚未通过医学审核',
                    style: TextStyle(fontSize: 12, color: Colors.deepOrange)),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.medical_information_outlined,
                    size: 14, color: cs.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(g.disclaimer,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final HealthTopic topic;
  final Color color;

  const _SummaryCard({required this.topic, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(topic.newstart?.icon ?? Icons.health_and_safety_outlined,
                  size: 20, color: color),
              const SizedBox(width: 8),
              Text(topic.displayName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600, color: color)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(topic.code,
                    style: TextStyle(fontSize: 11, color: color)),
              ),
            ],
          ),
          if (topic.summary != null && topic.summary!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(topic.summary!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600));
  }
}

class _EvidenceBadge extends StatelessWidget {
  final String level;

  const _EvidenceBadge(this.level);

  @override
  Widget build(BuildContext context) {
    final color = level.toUpperCase() == 'A'
        ? Colors.green
        : (level.toUpperCase() == 'B' ? Colors.blueGrey : Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('证据 $level', style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

class _BlockedNotice extends StatelessWidget {
  final int count;

  const _BlockedNotice({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '另有 $count 条内容未通过医学审核，依合规闸门不予展示。',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
