// consult_hub_page.dart
// v55：专业咨询整合模块——原「专业咨询·医药布道」与「AI 医生·多轮问诊」
// 两个平铺入口合并为一个模块，进入后再分两个子功能：
//   ① 材料核验（上传诊断材料 → 核验级别 → 疾病解读 + 医药布道建议）
//   ② AI 多轮问诊（像真人医生一样逐步询问 → 结合上传报告综合分析）
// 两个子功能均可独立使用，也可配合：先问诊定位方向，再核验材料佐证。
// 合规底线不变：只呈现信息与建议，不替代医生，涉及用药/症状必引导就医。

import 'package:flutter/material.dart';

import 'health_consult_page.dart';
import 'consult_chat_page.dart';

class ConsultHubPage extends StatelessWidget {
  const ConsultHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('专业咨询'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // 模块说明 + 合规底线
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.volunteer_activism,
                    size: 18, color: Color(0xFF6A1B9A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '这里把专业咨询的两项能力放在同一个模块：可以先做材料核验，'
                    '也可以直接开始多轮问诊，随时互相切换。'
                    '所有内容仅供健康参考，不替代医生诊断与治疗。',
                    style: TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ConsultFunctionCard(
            color: const Color(0xFFF3E5F5),
            borderColor: const Color(0xFF6A1B9A),
            icon: Icons.medical_services,
            iconColor: const Color(0xFF6A1B9A),
            title: '材料核验 · 医药布道',
            subtitle: '上传诊断材料 → 核验级别 → 疾病解读 + 医药布道建议（不替代医生）',
            scenario: '适用场景：已持有病历 / 报告 / 检验单等诊断材料',
            steps: const ['上传病历 / 报告', '提取诊断与医院信息', '分级与多家一致性核验', '解读 + 布道建议'],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HealthConsultPage()),
            ),
          ),
          const SizedBox(height: 10),
          _ConsultFunctionCard(
            color: const Color(0xFFE3F2FD),
            borderColor: const Color(0xFF1565C0),
            icon: Icons.forum,
            iconColor: const Color(0xFF1565C0),
            title: 'AI 医生 · 多轮问诊',
            subtitle: '像真人医生一样逐步询问症状病史 → 结合上传报告综合分析 → '
                '可能性判断 + 依据 + 检查建议（不替代医生）',
            scenario: '适用场景：还没有明确诊断，说不清是什么问题时',
            steps: const ['描述主要不适', '逐题回答追问', '上传报告辅助分析', '可能性 + 依据 + 检查建议'],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConsultChatPage()),
            ),
          ),
          const SizedBox(height: 12),
          // 配合使用提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '小贴士：没有诊断材料时，先用「多轮问诊」梳理症状；'
                    '已有报告时，可先在「材料核验」中上传，再进入问诊时'
                    '助手会结合报告一起分析。',
                    style: TextStyle(
                        fontSize: 12, height: 1.5, color: Colors.black54),
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

/// 模块内的单个功能卡：图标 + 标题 + 副标题 + 流程步骤 + 进入箭头。
class _ConsultFunctionCard extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String scenario;
  final List<String> steps;
  final VoidCallback onTap;

  const _ConsultFunctionCard({
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.scenario,
    required this.steps,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: borderColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      scenario,
                      style: TextStyle(
                          fontSize: 11.5, height: 1.4, color: borderColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in steps)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: borderColor.withOpacity(0.25)),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                            fontSize: 11, color: borderColor),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
