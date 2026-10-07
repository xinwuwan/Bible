// onboarding_page.dart
// 首次启动引导页：在用户第一次打开应用时展示，说明应用的权威来源、三大模块与合规边界。
// 展示一次后由 main.dart 的 AppRoot 写入 shared_preferences 标记，之后不再出现。
//
// 合规要点（与全应用一致）：
//   · 唯一权威 = KJV 英文圣经 + 怀爱伦（EGW）原版英文著作 + 复临安息日教会（SDA）教义
//   · 中文内容为独立「产出物」，和合本仅作参照，绝不作为权威来源
//   · 健康内容不替代专业医疗诊断；未过医学审核的条目不会出现在正式发布包中

import 'package:flutter/material.dart';

class OnboardingPage extends StatelessWidget {
  final VoidCallback onFinish;

  const OnboardingPage({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final headline = Theme.of(context).textTheme.headlineMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('欢迎使用')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          const SizedBox(height: 8),
          Text(
            '真理对照',
            style: headline?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '以 KJV 英文圣经、怀爱伦（Ellen G. White）原版英文著作、'
            '复临安息日教会（SDA）教义为唯一权威依据。',
            style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
          ),
          const SizedBox(height: 22),
          const Text(
            '三大模块',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          _ModuleTile(
            icon: Icons.auto_stories_outlined,
            color: Colors.indigo,
            title: '对照（模块 A）',
            body: 'KJV 英文原文与中文产出物并列阅读；中文和合本仅作参照，不作权威底本。',
          ),
          _ModuleTile(
            icon: Icons.chat_outlined,
            color: Colors.teal,
            title: '问答（模块 B）',
            body: '基于权威来源的牧师问答，正文引用可一键跳回原文对照。',
          ),
          _ModuleTile(
            icon: Icons.favorite_border,
            color: Colors.green,
            title: '健康（模块 C · NEWSTART）',
            body: '营养 / 运动 / 水 / 阳光 / 节制 / 空气 / 休息 / 信靠 八支柱，'
                '医学审核后才予以展示。',
          ),
          const SizedBox(height: 22),
          _NoticeCard(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('合规边界', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                SizedBox(height: 6),
                Text('· 本应用所有中文内容均为独立「产出物」，一切以英文权威原文为准。',
                    style: _noticeStyle),
                Text('· 健康内容不替代专业医疗诊断，如有健康问题请咨询医生。',
                    style: _noticeStyle),
                Text('· 未通过医学审核的健康条目不会出现在正式发布包中。', style: _noticeStyle),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onFinish,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('开始使用'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

const TextStyle _noticeStyle = TextStyle(fontSize: 13, height: 1.5, color: Colors.black87);

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _ModuleTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
        contentPadding: EdgeInsets.zero,
      );
}

class _NoticeCard extends StatelessWidget {
  final Widget child;

  const _NoticeCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EAF6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
}
