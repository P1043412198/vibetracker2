import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/month_key.dart';

class MonthPickerButton extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final TextStyle? textStyle;

  const MonthPickerButton({
    super.key,
    required this.month,
    required this.onChanged,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMonthLong(month),
              style: textStyle ??
                  const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5, 1);
    final lastDate = DateTime(now.year + 5, 12);
    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _MonthPickerDialog(
        initial: month,
        firstDate: firstDate,
        lastDate: lastDate,
      ),
    );
    if (result != null) {
      onChanged(DateTime(result.year, result.month));
    }
  }
}

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;

  const _MonthPickerDialog({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _year > widget.firstDate.year
                      ? () => setState(() => _year--)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '$_year',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: _year < widget.lastDate.year
                      ? () => setState(() => _year++)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.4,
              children: List.generate(12, (i) {
                final m = i + 1;
                final candidate = DateTime(_year, m);
                final selected =
                    widget.initial.year == _year && widget.initial.month == m;
                return _MonthCell(
                  label: formatMonthShort(candidate),
                  selected: selected,
                  onTap: () => Navigator.pop(context, candidate),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MonthCell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : const Color(0xFFF1F4F2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
