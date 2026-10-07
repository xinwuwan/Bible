// health_topic_card.dart
// 模块 C：NEWSTART 单支柱卡片（首页九宫格中的一个格子）

import 'package:flutter/material.dart';
import 'health_models.dart';
import 'health_theme.dart';

class HealthTopicCard extends StatelessWidget {
  final HealthTopic topic;
  final int loggedCount; // 今日已打卡项数
  final int metricCount; // 该支柱定义的指标总数
  final VoidCallback onTap;

  const HealthTopicCard({
    super.key,
    required this.topic,
    required this.loggedCount,
    required this.metricCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ns = topic.newstart;
    final color = ns?.color ?? Theme.of(context).colorScheme.primary;
    final icon = ns?.icon ?? Icons.health_and_safety_outlined;
    final done = metricCount > 0 && loggedCount >= metricCount;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      topic.displayName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (done)
                    Icon(Icons.check_circle, size: 18, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  topic.summary ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade700, height: 1.35),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              _ProgressLine(
                logged: loggedCount,
                total: metricCount,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final int logged;
  final int total;
  final Color color;

  const _ProgressLine(
      {required this.logged, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final text = total == 0
        ? '今日 0/0（本支柱暂无指标）'
        : '今日 $logged/$total';
    final value = total == 0 ? 0.0 : (logged / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: value,
          minHeight: 4,
          backgroundColor: color.withOpacity(0.12),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 4),
        Text(text, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
