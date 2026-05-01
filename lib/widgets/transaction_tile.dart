import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../theme.dart';
import '../utils/formatters.dart';

class TransactionTile extends StatelessWidget {
  final TxRecord tx;
  final VoidCallback? onTap;
  final bool showDate;

  const TransactionTile({
    super.key,
    required this.tx,
    this.onTap,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final cat = DefaultCategories.byId(tx.categoryId);
    final isExpense = tx.type == TxType.expense;
    final amountText =
        '${isExpense ? '−' : '+'}${formatMoney(tx.amount)}';
    final amountColor = isExpense ? AppColors.textPrimary : AppColors.primary;

    final title = (tx.store?.trim().isNotEmpty ?? false)
        ? tx.store!.trim()
        : (cat?.name ?? 'Операция');
    final subtitle = (tx.store?.trim().isNotEmpty ?? false)
        ? (cat?.name ?? '')
        : (tx.comment?.trim().isNotEmpty ?? false)
            ? tx.comment!.trim()
            : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (cat?.color ?? AppColors.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                cat?.icon ?? Icons.swap_horiz_rounded,
                size: 20,
                color: cat?.color ?? AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  showDate ? formatDateRu(tx.date) : formatTime(tx.date),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
