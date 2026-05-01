import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/budget_donut.dart';
import '../widgets/month_picker_button.dart';
import '../widgets/quick_action.dart';
import '../widgets/section_card.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'analytics_screen.dart';
import 'plan_editor_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppState state;
  final ValueChanged<int> onTabTap;

  const HomeScreen({super.key, required this.state, required this.onTabTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final month = state.selectedMonth;
        final income = state.totalIncomeIn(month);
        final expense = state.totalExpenseIn(month);
        final plan = state.planFor(month);
        final planTotal = plan.totalExpensePlan;
        final planIncome = plan.incomePlan;
        final left = (planIncome > 0 ? planIncome : income) - expense;
        final hasPlan = planTotal > 0 || planIncome > 0;
        final planPctOfIncomePlan = planIncome > 0
            ? ((income / planIncome) * 100).clamp(0.0, 999.0)
            : 0.0;

        final recent = state.txInMonth(month).take(3).toList();

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _HeaderGreeting(name: state.userName),
                const SizedBox(height: 16),
                SectionCard(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Мой бюджет',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          MonthPickerButton(
                            month: month,
                            onChanged: state.selectMonth,
                            textStyle: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _MoneyStat(
                                  label: 'Доходы',
                                  value: income,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 12),
                                _MoneyStat(
                                  label: 'Расходы',
                                  value: expense,
                                  color: AppColors.danger,
                                ),
                              ],
                            ),
                          ),
                          BudgetDonut(
                            income: planIncome > 0 ? planIncome : income,
                            expense: expense,
                            center: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatMoney(left),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: left < 0
                                          ? AppColors.danger
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'осталось',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (hasPlan)
                        Row(
                          children: [
                            Text(
                              planIncome > 0
                                  ? '${planPctOfIncomePlan.toStringAsFixed(0)}% от плана'
                                  : 'Без плана',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              planIncome > 0
                                  ? 'План: ${formatMoney(planIncome)}'
                                  : 'Расходы по плану: ${formatMoney(planTotal)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _editPlan(context, month),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.edit_rounded,
                                    size: 16, color: AppColors.primary),
                              ),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () => _editPlan(context, month),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Спланировать бюджет'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionHeader(title: 'Быстрые действия'),
                SectionCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      QuickAction(
                        icon: Icons.shopping_cart_rounded,
                        label: 'Добавить\nпокупку',
                        onTap: () => _addExpense(context),
                      ),
                      QuickAction(
                        icon: Icons.savings_rounded,
                        label: 'Записать\nдоход',
                        onTap: () => _addIncome(context),
                      ),
                      QuickAction(
                        icon: Icons.calendar_today_rounded,
                        label: 'Планировать\nбюджет',
                        onTap: () => _editPlan(context, month),
                      ),
                      QuickAction(
                        icon: Icons.bar_chart_rounded,
                        label: 'Аналитика',
                        onTap: () => _openAnalytics(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionHeader(
                  title: 'Недавние операции',
                  trailing: TextButton(
                    onPressed: () => onTabTap(1),
                    child: const Text('Смотреть все'),
                  ),
                ),
                if (recent.isEmpty)
                  SectionCard(
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Операций ещё нет.\nНачни с добавления покупки.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  )
                else
                  SectionCard(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Column(
                      children: [
                        for (var i = 0; i < recent.length; i++) ...[
                          if (i > 0)
                            const Divider(
                                height: 1, color: AppColors.divider),
                          TransactionTile(tx: recent[i], showDate: true),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const _LearnAndApplySection(),
                const SizedBox(height: 16),
                _MotivationBanner(),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addExpense(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AddTransactionScreen(state: state, presetExpense: true),
      ),
    );
  }

  void _addIncome(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AddTransactionScreen(state: state, presetExpense: false),
      ),
    );
  }

  void _editPlan(BuildContext context, DateTime month) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlanEditorScreen(state: state, month: month),
      ),
    );
  }

  void _openAnalytics(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnalyticsScreen(state: state)),
    );
  }
}

class _HeaderGreeting extends StatelessWidget {
  final String name;
  const _HeaderGreeting({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Привет, $name! 👋',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Давай разберёмся с финансами',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.notifications_none_rounded,
                color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _MoneyStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MoneyStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatMoney(value),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _LearnAndApplySection extends StatelessWidget {
  const _LearnAndApplySection();

  @override
  Widget build(BuildContext context) {
    final cards = <_LearnCardData>[
      _LearnCardData(
        title: 'Обучение',
        subtitle: 'Короткие уроки\nо финансах простым\nязыком',
        icon: Icons.menu_book_rounded,
        color: AppColors.primary,
      ),
      _LearnCardData(
        title: 'Цели',
        subtitle: 'Ставь цели и копи\nна важное',
        icon: Icons.flag_rounded,
        color: AppColors.accent,
      ),
      _LearnCardData(
        title: 'Привычки',
        subtitle: 'Формируй полезные\nфинансовые\nпривычки',
        icon: Icons.spa_rounded,
        color: AppColors.primaryLight,
      ),
      _LearnCardData(
        title: 'Безопасность',
        subtitle: 'Твои данные под\nнадёжной защитой',
        icon: Icons.shield_rounded,
        color: const Color(0xFF6B8E78),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Учись и применяй'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: [
            for (final c in cards)
              SectionCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(c.icon, size: 20, color: c.color),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      c.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        c.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 18, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LearnCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _LearnCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _MotivationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates_rounded,
              color: AppColors.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Маленькие шаги каждый день — большой результат в будущем',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.trending_up_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}
