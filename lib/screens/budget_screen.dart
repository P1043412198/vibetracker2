import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../utils/month_key.dart';
import '../widgets/budget_donut.dart';
import '../widgets/month_picker_button.dart';
import '../widgets/plan_progress_bar.dart';
import '../widgets/section_card.dart';
import 'plan_editor_screen.dart';

class BudgetScreen extends StatelessWidget {
  final AppState state;

  const BudgetScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final month = state.selectedMonth;
        final plan = state.planFor(month);
        final income = state.totalIncomeIn(month);
        final expense = state.totalExpenseIn(month);
        final byCat = state.expenseByCategoryIn(month);

        // "Свободно сегодня": days remaining * dailyBudget where
        // dailyBudget = (incomePlan or income) - planTotalExpense / daysInMonth
        final now = DateTime.now();
        final inCurrentMonth =
            month.year == now.year && month.month == now.month;
        final dim = daysInMonth(month);
        final dayIndex = inCurrentMonth ? now.day : dim;
        final daysLeft = (dim - dayIndex + 1).clamp(0, dim);

        final budgetTotal =
            plan.incomePlan > 0 ? plan.incomePlan : income;
        final dailyAllowance = dim == 0 ? 0.0 : budgetTotal / dim;

        // Свободно сегодня = бюджет - факт расходов до сегодня
        // если в текущем месяце; иначе budgetTotal - expense
        final freeToday = budgetTotal - expense;
        final pace = dayIndex == 0 ? 0.0 : (expense / dayIndex);
        final paceVsAllowance =
            dailyAllowance > 0 ? pace / dailyAllowance : 0.0;

        final categoryIds = <String>{...byCat.keys, ...plan.categoryPlans.keys};
        final categoryRows = categoryIds
            .map((id) {
              final cat = DefaultCategories.byId(id);
              return _CategoryRowData(
                id: id,
                name: cat?.name ?? 'Категория',
                icon: cat?.icon ?? Icons.label_rounded,
                color: cat?.color ?? AppColors.primary,
                actual: byCat[id] ?? 0,
                plan: plan.categoryPlans[id] ?? 0,
              );
            })
            .toList()
          ..sort((a, b) {
            // higher of actual/plan first
            final av = a.actual > a.plan ? a.actual : a.plan;
            final bv = b.actual > b.plan ? b.actual : b.plan;
            return bv.compareTo(av);
          });

        final freeColor =
            freeToday < 0 ? AppColors.danger : AppColors.primary;
        final hasAnyPlan =
            plan.incomePlan > 0 || plan.totalExpensePlan > 0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Бюджет'),
            actions: [
              MonthPickerButton(
                month: month,
                onChanged: state.selectMonth,
              ),
              IconButton(
                tooltip: 'Редактировать план',
                onPressed: () => _editPlan(context, month),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (!hasAnyPlan)
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'План ещё не создан',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Спланируй бюджет на этот месяц: укажи планируемый доход и расходы по категориям, чтобы видеть «свободно сегодня» и сравнение план/факт.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => _editPlan(context, month),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Создать план'),
                      ),
                    ],
                  ),
                ),
              if (hasAnyPlan) ...[
                _OverviewCard(
                  income: income,
                  expense: expense,
                  incomePlan: plan.incomePlan,
                  expensePlan: plan.totalExpensePlan,
                  freeToday: freeToday,
                  freeColor: freeColor,
                  daysLeft: daysLeft,
                  daysInMonth: dim,
                  dailyAllowance: dailyAllowance,
                  pace: pace,
                  paceRatio: paceVsAllowance,
                ),
                const SizedBox(height: 16),
              ],
              const SectionHeader(title: 'Доходы: план vs факт'),
              SectionCard(
                child: PlanProgressBar(
                  label: 'Доходы',
                  icon: Icons.savings_rounded,
                  color: AppColors.primary,
                  actual: income,
                  plan: plan.incomePlan,
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(
                title: 'Расходы по категориям',
                trailing: TextButton.icon(
                  onPressed: () => _editPlan(context, month),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Изменить план'),
                ),
              ),
              if (categoryRows.isEmpty)
                SectionCard(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Добавь покупки или планы по категориям',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                SectionCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < categoryRows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 14),
                        PlanProgressBar(
                          label: categoryRows[i].name,
                          icon: categoryRows[i].icon,
                          color: categoryRows[i].color,
                          actual: categoryRows[i].actual,
                          plan: categoryRows[i].plan,
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              if (hasAnyPlan)
                Center(
                  child: TextButton.icon(
                    onPressed: () => _confirmReset(context, month),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.danger),
                    label: const Text(
                      'Удалить план месяца',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editPlan(BuildContext context, DateTime month) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlanEditorScreen(state: state, month: month),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, DateTime month) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить план?'),
        content: const Text(
            'План на выбранный месяц будет удалён. Операции останутся.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) {
      await state.deletePlan(monthKeyFor(month));
    }
  }
}

class _CategoryRowData {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final double actual;
  final double plan;
  _CategoryRowData({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.actual,
    required this.plan,
  });
}

class _OverviewCard extends StatelessWidget {
  final double income;
  final double expense;
  final double incomePlan;
  final double expensePlan;
  final double freeToday;
  final Color freeColor;
  final int daysLeft;
  final int daysInMonth;
  final double dailyAllowance;
  final double pace;
  final double paceRatio;

  const _OverviewCard({
    required this.income,
    required this.expense,
    required this.incomePlan,
    required this.expensePlan,
    required this.freeToday,
    required this.freeColor,
    required this.daysLeft,
    required this.daysInMonth,
    required this.dailyAllowance,
    required this.pace,
    required this.paceRatio,
  });

  @override
  Widget build(BuildContext context) {
    final paceLabel = paceRatio == 0
        ? '—'
        : paceRatio < 0.95
            ? 'ниже плана'
            : paceRatio > 1.05
                ? 'выше плана'
                : 'в норме';
    final paceColor = paceRatio == 0
        ? AppColors.textSecondary
        : paceRatio > 1.05
            ? AppColors.danger
            : AppColors.primary;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Свободно сегодня',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatMoney(freeToday),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: freeColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      daysLeft > 0
                          ? 'Осталось $daysLeft из $daysInMonth дн.'
                          : 'Месяц закрыт',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              BudgetDonut(
                income: incomePlan > 0 ? incomePlan : income,
                expense: expense,
                diameter: 130,
                center: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatMoney(expense),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'потрачено',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: AppColors.divider),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'План в день',
                  value: formatMoney(dailyAllowance),
                  icon: Icons.calendar_today_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Темп',
                  value: '${formatMoney(pace)}/д',
                  hint: paceLabel,
                  hintColor: paceColor,
                  icon: Icons.speed_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? hint;
  final Color? hintColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
    this.hintColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: TextStyle(
                fontSize: 11,
                color: hintColor ?? AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
