// health_page.dart
// 模块 C 健康首页：NEWSTART 八支柱总览 + 今日打卡进度

import 'package:flutter/material.dart';
import 'health_models.dart';
import 'health_repository.dart';
import 'health_topic_card.dart';
import 'health_topic_page.dart';

class HealthPage extends StatefulWidget {
  final HealthRepository repo;
  final String userId;

  /// 内部预览开关（dart-define SHOW_UNREVIEWED_HEALTH=true）。
  /// 正式构建必须为 false —— 未过医学审核的条目不得展示。
  final bool previewMode;

  const HealthPage({
    super.key,
    required this.repo,
    required this.userId,
    this.previewMode = false,
  });

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  List<HealthTopic> _topics = const [];
  List<HealthMetric> _metrics = const [];
  List<HealthLogEntry> _logs = const [];
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
      final topics = await widget.repo.loadTopics();
      final metrics = await widget.repo.loadMetrics();
      final logs = await widget.repo.loadLogs(widget.userId);
      if (!mounted) return;
      setState(() {
        _topics = topics;
        _metrics = metrics;
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '健康内容加载失败：$e';
        _loading = false;
      });
    }
  }

  List<HealthLogEntry> get _todayLogs {
    final now = DateTime.now();
    return _logs.where((e) => e.isSameDay(now)).toList();
  }

  int _loggedCount(String topicCode) => _todayLogs
      .where((e) => e.topicCode == topicCode)
      .map((e) => e.metricId)
      .toSet()
      .length;

  int _metricCount(String topicCode) =>
      _metrics.where((m) => m.topicCode == topicCode).length;

  int get _totalDone {
    var n = 0;
    for (final t in _topics) {
      n += _loggedCount(t.code);
    }
    return n;
  }

  void _openTopic(HealthTopic t) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HealthTopicPage(
        repo: widget.repo,
        topic: t,
        metrics: _metrics.where((m) => m.topicCode == t.code).toList(),
        logs: _logs,
        userId: widget.userId,
        previewMode: widget.previewMode,
      ),
    ));
    // 从详情页返回后刷新打卡进度
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康 · NEWSTART'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final cross = c.maxWidth >= 900
                          ? 4
                          : (c.maxWidth >= 560 ? 3 : 2);
                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _DisclaimerBanner(total: _metrics.length, done: _totalDone),
                          ),
                          if (_topics.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(child: Text('暂无健康内容')),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => HealthTopicCard(
                                    topic: _topics[i],
                                    loggedCount: _loggedCount(_topics[i].code),
                                    metricCount: _metricCount(_topics[i].code),
                                    onTap: () => _openTopic(_topics[i]),
                                  ),
                                  childCount: _topics.length,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cross,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 1.15,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  final int total;
  final int done;

  const _DisclaimerBanner({required this.total, required this.done});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Text('今日完成 $done / $total 项',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            HealthGuard.defaultDisclaimer,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
