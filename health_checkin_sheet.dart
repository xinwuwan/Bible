// health_checkin_sheet.dart
// 模块 C：每日打卡弹层（按支柱的指标逐项填写）

import 'package:flutter/material.dart';
import 'health_models.dart';

/// 打开打卡弹层；返回 true 表示已保存。
Future<bool> showHealthCheckinSheet({
  required BuildContext context,
  required HealthTopic topic,
  required List<HealthMetric> metrics,
  required List<HealthLogEntry> todayLogs,
  required String userId,
  required void Function(List<HealthLogEntry>) onSave,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => HealthCheckinSheet(
      topic: topic,
      metrics: metrics,
      todayLogs: todayLogs,
      userId: userId,
      onSave: onSave,
    ),
  );
  return ok ?? false;
}

class HealthCheckinSheet extends StatefulWidget {
  final HealthTopic topic;
  final List<HealthMetric> metrics;
  final List<HealthLogEntry> todayLogs;
  final String userId;
  final void Function(List<HealthLogEntry>) onSave;

  const HealthCheckinSheet({
    super.key,
    required this.topic,
    required this.metrics,
    required this.todayLogs,
    required this.userId,
    required this.onSave,
  });

  @override
  State<HealthCheckinSheet> createState() => _HealthCheckinSheetState();
}

class _HealthCheckinSheetState extends State<HealthCheckinSheet> {
  final Map<int, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();
    for (final m in widget.metrics) {
      final prev = widget.todayLogs
          .where((e) => e.metricId == m.metricId)
          .map((e) => e.value)
          .cast<String?>()
          .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
      _ctrls[m.metricId] = TextEditingController(text: prev ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final now = DateTime.now();
    final entries = <HealthLogEntry>[];
    for (final m in widget.metrics) {
      final v = (_ctrls[m.metricId]?.text ?? '').trim();
      if (v.isEmpty) continue;
      entries.add(HealthLogEntry(
        userId: widget.userId,
        topicCode: m.topicCode,
        metricId: m.metricId,
        value: v,
        loggedAt: now,
      ));
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少填写一项')),
      );
      return;
    }
    widget.onSave(entries);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.topic.displayName} · 今日打卡',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('记录昨日/今日的实际情况即可，无需追求完美。',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          if (widget.metrics.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('本支柱暂未定义打卡指标')),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: widget.metrics.map(_metricField).toList(),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check),
            label: const Text('保存打卡'),
          ),
        ],
      ),
    );
  }

  Widget _metricField(HealthMetric m) {
    final target = (m.targetValue == null || m.targetValue!.isEmpty)
        ? ''
        : '（建议 ${m.targetValue}）';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _ctrls[m.metricId],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '${m.nameZh}${m.unitLabel}$target',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
