// citation_list.dart
// 权威引用列表（模块 B 共用；模块 C 健康指导也可复用）
// 点击应跳转回 KJV / EGW / 教义原文，形成「产出 → 来源」闭环。

import 'package:flutter/material.dart';

import 'qa_models.dart';

class CitationList extends StatelessWidget {
  final List<QaCitation> citations;
  final ValueChanged<QaCitation>? onTap;

  const CitationList({super.key, required this.citations, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (citations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('（本条无引用）', style: TextStyle(fontSize: 12, color: Colors.black45)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Icon(Icons.verified_outlined, size: 14, color: Color(0xFF00695C)),
              const SizedBox(width: 4),
              Text(
                '权威依据 ${citations.length} 条',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00695C),
                ),
              ),
            ],
          ),
        ),
        ...citations.map((c) => _CitationTile(citation: c, onTap: onTap)),
      ],
    );
  }
}

class _CitationTile extends StatelessWidget {
  final QaCitation citation;
  final ValueChanged<QaCitation>? onTap;

  const _CitationTile({required this.citation, this.onTap});

  Color get _color {
    switch (citation.sourceType) {
      case QaSourceType.bible:
        return const Color(0xFF3F51B5);
      case QaSourceType.egw:
        return const Color(0xFF6A1B9A);
      case QaSourceType.doctrine:
        return const Color(0xFF00695C);
      case QaSourceType.unknown:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final illegal = citation.isCuv;
    final color = illegal ? const Color(0xFFC62828) : _color;
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(citation),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 3)),
          color: color.withOpacity(0.04),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(6),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    illegal ? '非法来源（和合本）' : citation.sourceType.label,
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    citation.ref,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.open_in_new, size: 14, color: Colors.grey.shade600),
              ],
            ),
            if (citation.snippet.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                citation.snippet,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.45, color: Colors.black87),
              ),
            ],
            const SizedBox(height: 3),
            Text(
              citation.sourceId,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
