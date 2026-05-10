import 'package:flutter/material.dart';

import '../../../models/financial_plan.dart';

/// Horizontal row of 4 colored KPI cards used on the cover page of the report.
class KpiStrip extends StatelessWidget {
  const KpiStrip({super.key, required this.kpis, required this.titles});

  final List<KpiCard> kpis;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final crossAxisCount = isNarrow ? 2 : 4;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(kpis.length, (i) {
            final k = kpis[i];
            final title = i < titles.length ? titles[i] : '';
            return _KpiTile(value: k.value, label: k.label, title: title, color: k.colorValue);
          }),
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.value,
    required this.label,
    required this.title,
    required this.color,
  });

  final double value;
  final String label;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    final fg = brightness == Brightness.dark ? Colors.white : Colors.black;
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: fg.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value.round().toString(),
            style: TextStyle(
              color: fg,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: fg.withValues(alpha: 0.85),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
