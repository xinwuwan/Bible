// onboarding_page.dart
// 首次启动引导页：在用户第一次打开应用时展示，说明应用的权威来源、三大模块与合规边界。
// 展示一次后由 main.dart 的 AppRoot 写入 shared_preferences 标记，之后不再出现。
//
// 视觉：渐变靛蓝英雄区 + 金色金句（JHN 8:32）+ 白卡模块 + 柔和合规提示。
//
// 合规要点（与全应用一致）：
//   · 唯一权威 = KJV 英文圣经 + 怀爱伦（EGW）原版英文著作 + 复临安息日教会（SDA）教义
//   · 中文内容为独立「产出物」，和合本仅作参照，绝不作为权威来源
//   · 健康内容不替代专业医疗诊断；未过医学审核的条目不会出现在正式发布包中

import 'package:flutter/material.dart';

import 'app_theme.dart';

class OnboardingPage extends StatelessWidget {
  final VoidCallback onFinish;

  const OnboardingPage({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ---- 英雄区：渐变 + 金句 ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary, AppTheme.primaryDeep],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_stories,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '真理对照',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '“你们必晓得真理，\n真理必叫你们得以自由。”',
                    style: AppTheme.scripture(
                      size: 19,
                      color: Colors.white,
                      weight: FontWeight.w600,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '—— 约翰福音 8:32（和合本参照 · 权威底本为 KJV）',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withOpacity(0.75),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---- 三大模块 ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '三大模块',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ModuleCard(
                    icon: Icons.auto_stories_outlined,
                    color: AppTheme.primary,
                    title: '对照',
                    tag: '模块 A',
                    body: 'KJV 英文原文与中文产出物并列阅读；中文和合本仅作参照，不作权威底本。',
                  ),
                  _ModuleCard(
                    icon: Icons.forum_outlined,
                    color: AppTheme.zhTeal,
                    title: '问答',
                    tag: '模块 B',
                    body: '基于权威来源的牧师问答，正文引用可一键跳回原文对照。',
                  ),
                  _ModuleCard(
                    icon: Icons.favorite_outline,
                    color: AppTheme.gold,
                    title: '健康',
                    tag: '模块 C · NEWSTART',
                    body: '营养 / 运动 / 水 / 阳光 / 节制 / 空气 / 休息 / 信靠 八支柱，医学审核后才予以展示。',
                  ),
                  const SizedBox(height: 20),

                  // ---- 合规边界（柔和提示卡）----
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF6E9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEBDCC0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.gavel_outlined,
                                size: 15, color: AppTheme.gold),
                            SizedBox(width: 6),
                            Text(
                              '合规边界',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.ink,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('· 本应用所有中文内容均为独立「产出物」，一切以英文权威原文为准。',
                            style: _noticeStyle),
                        SizedBox(height: 4),
                        Text('· 健康内容不替代专业医疗诊断，如有健康问题请咨询医生。',
                            style: _noticeStyle),
                        SizedBox(height: 4),
                        Text('· 未通过医学审核的健康条目不会出现在正式发布包中。',
                            style: _noticeStyle),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onFinish,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('开始使用'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const TextStyle _noticeStyle = TextStyle(
  fontSize: 12.5,
  height: 1.5,
  color: AppTheme.inkSoft,
);

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String tag;
  final String body;

  const _ModuleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.tag,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppTheme.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
