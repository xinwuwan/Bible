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
              // 不用 Expanded：卡片已改为高度自适应（Wrap 网格），
              // Expanded 在无边界高度约束下会抛布局异常
              Text(
                topic.summary ?? '',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade700, height: 1.35),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // 极简进度线：只留进度条不带文字，汇总进度由顶部 Hero 区承担
              LinearProgressIndicator(
                value: metricCount == 0
                    ? 0.0
                    : (loggedCount / metricCount).clamp(0.0, 1.0),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
