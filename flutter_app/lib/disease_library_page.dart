// disease_library_page.dart
// v63：把「疾病知识库」从医药布道页（health_consult_page）拆为独立导航页，
// 与「医药布道」「AI 医生」并列，缩减医药布道页篇幅。
import 'package:flutter/material.dart';

import 'consult_models.dart';
import 'health_consult_page.dart'; // consultProfileSections（疾病解读详情板块，公开顶层）

class DiseaseLibraryPage extends StatelessWidget {
  const DiseaseLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('疾病知识库')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF2E7D32).withOpacity(0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.local_library, size: 18, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '收录常见疾病的形成机制、对健康的影响、临床表现、诊断标准、'
                    '鉴别要点与就医信号。所有解读均在本页内联展开，无外部链接。',
                    style: TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            icon: Icons.local_library,
            title: '疾病知识库（可检索，全部内容本页查看）',
            children: const [
              SizedBox(height: 10),
              _DiseaseBrowser(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(14)),
        border: Border.fromBorderSide(BorderSide(color: Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// 疾病知识库浏览器：按名称/别名/分类检索，完整解读在本页内联展开。
/// 数据来自 ConsultData.diseases（离线 JSON），无任何外部链接。
class _DiseaseBrowser extends StatefulWidget {
  const _DiseaseBrowser();

  @override
  State<_DiseaseBrowser> createState() => _DiseaseBrowserState();
}

class _DiseaseBrowserState extends State<_DiseaseBrowser> {
  String _query = '';
  String _category = 'all';
  String? _expandedId;

  static const _categoryLabels = {
    'cardio': '心血管', 'neuro': '神经', 'resp': '呼吸', 'gi': '消化',
    'renal': '泌尿', 'blood': '血液', 'immune': '风湿免疫', 'endo': '内分泌',
    'metabolic': '代谢', 'tumor': '肿瘤', 'mental': '精神心理', 'derm': '皮肤',
    'eye': '眼科', 'ent': '耳鼻喉', 'ortho': '骨科', 'gyne': '妇科',
    'peds': '儿科', 'infect': '感染', 'other': '其他',
  };

  static const _severityLabels = {
    'major': ('重大', Color(0xFFB71C1C)),
    'severe': ('严重', Color(0xFFEF6C00)),
    'common': ('常见', Color(0xFF1565C0)),
  };

  List<DiseaseProfile> get _filtered {
    final q = _query.trim();
    return ConsultData.diseases.where((d) {
      if (_category != 'all' && d.category != _category) return false;
      if (q.isEmpty) return true;
      if (d.name.contains(q)) return true;
      for (final a in d.aliases) {
        if (a.contains(q)) return true;
      }
      final label = _categoryLabels[d.category] ?? '';
      return label.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (ConsultData.diseases.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('知识库加载中…', style: TextStyle(fontSize: 12.5)),
      );
    }
    // 分类计数（按出现顺序）
    final counts = <String, int>{};
    for (final d in ConsultData.diseases) {
      counts[d.category] = (counts[d.category] ?? 0) + 1;
    }
    final results = _filtered;
    final shown = results.take(30).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: '检索疾病名称 / 别名 / 分类，如「糖尿病」「肿瘤」「甲亢」',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _query = ''),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _catChip('全部', ConsultData.diseases.length, 'all'),
              for (final e in counts.entries)
                _catChip(_categoryLabels[e.key] ?? e.key, e.value, e.key),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _query.isEmpty && _category == 'all'
              ? '共收录 ${ConsultData.diseases.length} 种疾病'
              : '找到 ${results.length} 种疾病',
          style: const TextStyle(fontSize: 11.5, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('未找到匹配疾病，请换个关键词或分类试试。',
                style: TextStyle(fontSize: 12.5)),
          ),
        for (final d in shown) _diseaseCard(d),
        if (results.length > shown.length)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('结果较多，仅显示前 30 种，请细化检索条件。',
                style: TextStyle(fontSize: 11.5, color: Colors.black54)),
          ),
      ],
    );
  }

  Widget _catChip(String label, int count, String key) {
    final selected = _category == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text('$label $count', style: const TextStyle(fontSize: 11.5)),
        selected: selected,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(() => _category = key),
      ),
    );
  }

  Widget _diseaseCard(DiseaseProfile d) {
    final expanded = _expandedId == d.id;
    final sev = _severityLabels[d.severityHint] ??
        const ('', Color(0xFF1565C0));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: expanded ? const Color(0xFFF3E5F5).withOpacity(0.4) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: expanded
                ? const Color(0xFF6A1B9A).withOpacity(0.4)
                : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(d.name,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
              _tag('${_categoryLabels[d.category] ?? d.category}', Colors.blueGrey),
              const SizedBox(width: 4),
              _tag(sev.$1, sev.$2),
            ],
          ),
          const SizedBox(height: 4),
          Text(d.overview,
              maxLines: expanded ? null : 2,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.5)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  setState(() => _expandedId = expanded ? null : d.id),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(
                expanded ? '收起 ▲' : '展开完整解读 ▼',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 12),
            // _profileSections 已含「权威来源」小节，这里不重复渲染
            ...consultProfileSections(d),
            if (d.aliases.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('别称：${d.aliases.join('、')}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ),
            const SizedBox(height: 6),
            Text(
              '以上为医学科普通识，不构成诊疗建议；诊断与治疗请以正规医院和医生意见为准。',
              style: TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
