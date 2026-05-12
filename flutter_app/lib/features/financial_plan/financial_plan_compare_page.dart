import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/financial_plan_month.dart';
import '../../state/providers.dart';
import 'financial_plan_helpers.dart';

/// Side-by-side compare of every scenario inside a [FinancialPlanMonth].
class FinancialPlanComparePage extends ConsumerWidget {
  const FinancialPlanComparePage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(financialPlanMonthsProvider);
    final plan = months.cast<FinancialPlanMonth?>().firstWhere(
          (p) => p?.id == id,
          orElse: () => null,
        );
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Сравнение')),
        body: const Center(child: Text('План не найден')),
      );
    }
    final transactions = ref.watch(transactionsProvider);
    final summaries = {
      for (final s in plan.scenarios)
        s.id: computeSummary(s, transactions, plan.monthKey),
    };
    final fmt = NumberFormat.currency(
        locale: 'ru', symbol: '', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Сравнение · ${humanMonth(plan.monthKey)}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                columns: [
                  const DataColumn(label: Text('Метрика')),
                  for (final s in plan.scenarios)
                    DataColumn(
                      label: Text(
                        s.name,
                        style: TextStyle(
                            color: Color(s.color),
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
                rows: [
                  _row('Доход', plan, summaries, fmt, (sum) => sum.income),
                  _row('Расход', plan, summaries, fmt, (sum) => sum.expense),
                  _row('Сбережения', plan, summaries, fmt,
                      (sum) => sum.savings),
                  _row('Долги', plan, summaries, fmt, (sum) => sum.debt),
                  _row('Другое', plan, summaries, fmt, (sum) => sum.custom),
                  _row('Остаток', plan, summaries, fmt,
                      (sum) => sum.balance),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Сценарии подробно',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final s in plan.scenarios) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(s.color))),
                      const SizedBox(height: 4),
                      Text('секций: ${s.sections.length}'),
                      for (final sec in s.sections)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              if (sec.icon != null) ...[
                                Text(sec.icon!),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  '${sec.title} (${labelForSectionKind(sec.kind)})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                fmt.format(sec.items.fold<double>(
                                    0, (sum, it) => sum + it.amount)),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  DataRow _row(
    String label,
    FinancialPlanMonth plan,
    Map<String, FinPlanSummary> summaries,
    NumberFormat fmt,
    double Function(FinPlanSummary) selector,
  ) {
    return DataRow(cells: [
      DataCell(Text(label,
          style: const TextStyle(fontWeight: FontWeight.w700))),
      for (final s in plan.scenarios)
        DataCell(Text(fmt.format(selector(summaries[s.id]!)))),
    ]);
  }
}
