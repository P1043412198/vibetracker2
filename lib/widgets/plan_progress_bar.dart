import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/formatters.dart';

/// Horizontal stacked progress bar comparing actual vs planned amount.
class PlanProgressBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double actual;
  final double plan;

  const PlanProgressBar({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.actual,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    final hasPlan = plan > 0;
    final ratio = hasPlan ? (actual / plan).clamp(0.0, 1.5) : 0.0;
    final isOver = hasPlan && actual > plan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              hasPlan
                  ? '${formatMoney(actual)} / ${formatMoney(plan)}'
                  : formatMoney(actual),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isOver ? AppColors.danger : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 8,
                color: const Color(0xFFEFF3F0),
              ),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  color: isOver ? AppColors.danger : color,
                ),
              ),
              if (ratio > 1.0)
                Positioned(
                  left: 0,
                  right: 0,
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    child: Container(
                      height: 8,
                      color: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
