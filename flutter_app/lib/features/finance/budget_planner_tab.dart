import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/budget_planner.dart';
import '../../models/finance.dart';
import '../../services/budget_planner_calc.dart';
import '../../state/budget_planner_state.dart';
import '../../state/currency_state.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';

const _uuid = Uuid();
final _fmt =
    NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);
final _fmtShort =
    NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 0);

const _typeLabels = <IncomeSourceType, String>{
  IncomeSourceType.salary: 'Зарплата',
  IncomeSourceType.advance: 'Аванс',
  IncomeSourceType.additional: 'Доп. доход',
};

enum _Section { dashboard, income, expenses }

class BudgetPlannerTab extends ConsumerStatefulWidget {
  const BudgetPlannerTab({super.key});

  @override
  ConsumerState<BudgetPlannerTab> createState() => _BudgetPlannerTabState();
}

class _BudgetPlannerTabState extends ConsumerState<BudgetPlannerTab> {
  _Section _section = _Section.dashboard;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(budgetPlannerProvider);
    final config = store.currentMonth;
    final transactions = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final loans = ref.watch(loansProvider);
    final loanPayments = ref.watch(loanPaymentsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider);
    final reserve = ref.watch(safeToSpendReserveProvider);
    final rangeMode = ref.watch(safeToSpendRangeModeProvider);
    final customRange = ref.watch(safeToSpendCustomRangeProvider);
    final selectedAccountIds = ref.watch(safeToSpendAccountIdsProvider);

    DateTime? parseIso(String? iso) =>
        (iso == null || iso.isEmpty) ? null : DateTime.tryParse(iso);

    num convert(num amount, String from, String to) =>
        convertCurrency(amount: amount, from: from, to: to, rates: rates);

    final facts = computeBudgetFacts(
      monthKey: store.selectedMonthKey,
      transactions: transactions,
      accounts: accounts,
      convert: convert,
      baseCurrency: baseCurrency,
      linkedAccountIds: config.linkedAccountIds,
    );

    // Loans synthesised as planned expenses so the budget plan reflects them
    // automatically (unified ecosystem — see budget_planner_calc.dart). The
    // dashboard/forecast are global, so loans are anchored to the *real*
    // current month for the paid-this-month check.
    final nowKey = () {
      final n = DateTime.now();
      return '${n.year}-${n.month.toString().padLeft(2, '0')}';
    }();
    final loanExpenses = loansAsPlannedExpenses(
      loans: loans,
      convert: convert,
      baseCurrency: baseCurrency,
      monthKey: nowKey,
      loanPayments: loanPayments,
    );

    // Dashboard cycles + safe-to-spend forecast are *global*: they span every
    // month's plan, not the selected tab, so a future month's "once" expense
    // never falls into the current cycle. Each month uses its own plan, with
    // the current month as the recurring template for unconfigured months.
    final cycles = computeGlobalBudgetCycles(
      months: store.months,
      transactions: transactions,
      accounts: accounts,
      loans: loans,
      loanPayments: loanPayments,
      convert: convert,
      baseCurrency: baseCurrency,
      reserve: reserve.toDouble(),
      accountIds: selectedAccountIds,
    );

    final forecast = computeGlobalCashflowForecast(
      months: store.months,
      accounts: accounts,
      transactions: transactions,
      extraMonthlyExpenses: loanExpenses,
      convert: convert,
      baseCurrency: baseCurrency,
      reserve: reserve.toDouble(),
      rangeMode: rangeMode,
      customStart: parseIso(customRange.start),
      customEnd: parseIso(customRange.end),
      accountIds: selectedAccountIds,
    );

    // Historical spending averages feed the average-based forecast scenarios
    // (P3b) in the safe-to-spend card.
    final averages = computeSpendingAverages(
      accounts: accounts,
      transactions: transactions,
      convert: convert,
      baseCurrency: baseCurrency,
      accountIds: selectedAccountIds,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _MonthSelector(
          monthKey: store.selectedMonthKey,
          hasMonthData:
              store.months.any((m) => m.monthKey == store.selectedMonthKey),
          onPrev: () => _changeMonth(-1),
          onNext: () => _changeMonth(1),
          onRollover: _rollover,
          onCopyForward: () => _showCopyForwardDialog(context),
        ),
        const SizedBox(height: 12),
        _SectionTabs(
          current: _section,
          onChanged: (s) => setState(() => _section = s),
        ),
        const SizedBox(height: 16),
        if (_section == _Section.dashboard)
          _DashboardSection(
            config: config,
            facts: facts,
            cycles: cycles,
            accounts: accounts,
            baseCurrency: baseCurrency,
            loanExpenses: loanExpenses,
            forecast: forecast,
            reserve: reserve.toDouble(),
            averages: averages,
            transactions: transactions,
            convert: convert,
            comparisonAccountIds: selectedAccountIds,
          ),
        if (_section == _Section.income)
          _IncomeSection(config: config, facts: facts),
        if (_section == _Section.expenses)
          _ExpenseSection(
            config: config,
            facts: facts,
            transactions: transactions,
            accounts: accounts,
            baseCurrency: baseCurrency,
            convert: convert,
          ),
      ],
    );
  }

  void _changeMonth(int delta) {
    final parts = ref.read(budgetPlannerProvider).selectedMonthKey.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = DateTime(y, m + delta, 1);
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    ref.read(budgetPlannerProvider.notifier).selectMonth(key);
  }

  void _rollover() {
    final store = ref.read(budgetPlannerProvider);
    ref
        .read(budgetPlannerProvider.notifier)
        .rolloverToMonth(store.selectedMonthKey);
  }

  Future<void> _showCopyForwardDialog(BuildContext context) async {
    var months = 3;
    var overwrite = false;
    final result = await showDialog<({int months, bool overwrite})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Скопировать постоянные вперёд'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Скопировать доходы и плановые расходы текущего месяца '
                'на следующие месяцы.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('На сколько месяцев:'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: months,
                    items: const [1, 2, 3, 6, 12]
                        .map((n) =>
                            DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) => setLocal(() => months = v ?? 3),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: overwrite,
                onChanged: (v) => setLocal(() => overwrite = v ?? false),
                title: const Text(
                  'Перезаписать заполненные месяцы',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Факт. расходы этих месяцев сохранятся',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                (months: months, overwrite: overwrite),
              ),
              child: const Text('Скопировать'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final copied = await ref
        .read(budgetPlannerProvider.notifier)
        .copyToNextMonths(result.months, overwrite: result.overwrite);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copied > 0
            ? 'Скопировано на $copied ${_pluralizeMonths(copied)} вперёд'
            : 'Нет месяцев для копирования (уже заполнены)'),
      ),
    );
  }

  String _pluralizeMonths(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'месяц';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'месяца';
    }
    return 'месяцев';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month selector
// ─────────────────────────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.monthKey,
    required this.hasMonthData,
    required this.onPrev,
    required this.onNext,
    required this.onRollover,
    required this.onCopyForward,
  });
  final String monthKey;
  final bool hasMonthData;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onRollover;
  final VoidCallback onCopyForward;

  @override
  Widget build(BuildContext context) {
    final parts = monthKey.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final label = DateFormat.yMMMM('ru').format(DateTime(y, m, 1));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrev,
            ),
            Expanded(
              child: Text(
                label[0].toUpperCase() + label.substring(1),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            if (!hasMonthData)
              TextButton.icon(
                icon: const Icon(Icons.content_copy, size: 16),
                label: const Text('Перенести', style: TextStyle(fontSize: 12)),
                onPressed: onRollover,
              ),
            IconButton(
              icon: const Icon(Icons.copy_all_outlined),
              tooltip: 'Скопировать постоянные на след. месяцы',
              onPressed: onCopyForward,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section tabs
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.current, required this.onChanged});
  final _Section current;
  final ValueChanged<_Section> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tab(Icons.dashboard_outlined, 'Дашборд', _Section.dashboard, scheme),
          _tab(Icons.wallet_outlined, 'Доходы', _Section.income, scheme),
          _tab(Icons.receipt_long_outlined, 'Расходы', _Section.expenses, scheme),
        ],
      ),
    );
  }

  Widget _tab(
      IconData icon, String label, _Section section, ColorScheme scheme) {
    final selected = current == section;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color:
                      selected ? scheme.onPrimary : scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ██████  DASHBOARD  ██████
// ═════════════════════════════════════════════════════════════════════════════

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.config,
    required this.facts,
    required this.cycles,
    required this.accounts,
    required this.baseCurrency,
    required this.loanExpenses,
    required this.forecast,
    required this.reserve,
    required this.averages,
    required this.transactions,
    required this.convert,
    required this.comparisonAccountIds,
  });

  final BudgetPlanConfig config;
  final BudgetFacts facts;
  final List<BudgetCycle> cycles;
  final List<Account> accounts;
  final String baseCurrency;
  final List<PlannedExpense> loanExpenses;
  final CashflowForecast forecast;
  final double reserve;
  final SpendingAverages averages;
  final List<Transaction> transactions;
  final num Function(num amount, String from, String to) convert;
  final List<String> comparisonAccountIds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalPlannedIncome = config.incomeSources
        .where((s) => s.isActive)
        .fold<double>(0, (s, e) => s + e.amount);
    final manualPlannedExpense = config.plannedExpenses
        .where((e) => e.isActive)
        .fold<double>(0, (s, e) => s + e.amount);
    final loanPlannedExpense =
        loanExpenses.fold<double>(0, (s, e) => s + e.amount);
    final totalPlannedExpense = manualPlannedExpense + loanPlannedExpense;
    // Combined list so the planned-expenses panel reflects loans too.
    final combinedExpenses = [
      ...config.plannedExpenses,
      ...loanExpenses,
    ];
    final paidCount =
        combinedExpenses.where((e) => e.isPaid).length;
    final totalCount = combinedExpenses.length;
    final manualActual =
        config.actualExpenses.fold<double>(0, (s, e) => s + e.amount);
    final allActualExpense = facts.monthExpense + manualActual;
    final remaining = totalPlannedIncome - totalPlannedExpense - allActualExpense;
    final savingsRate = totalPlannedIncome > 0
        ? ((totalPlannedIncome - allActualExpense) / totalPlannedIncome * 100)
            .clamp(0, 100)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Account balance card ──
        _GradientCard(
          gradient: const LinearGradient(
            colors: [Color(0xFF6D5CFF), Color(0xFF3B82F6)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  const Text('Баланс счетов',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text(baseCurrency,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${_fmt.format(facts.accountBalance)} $baseCurrency',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Счетов: ${accounts.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Safe-to-spend forecast ──
        _SafeToSpendCard(
            forecast: forecast, reserve: reserve, averages: averages),
        const SizedBox(height: 12),

        // ── Summary row ──
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                label: 'Плановый доход',
                value: _fmtShort.format(totalPlannedIncome),
                color: const Color(0xFF10B981),
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniCard(
                label: 'Факт. доход',
                value: _fmtShort.format(facts.monthIncome),
                color: const Color(0xFF22C55E),
                icon: Icons.arrow_downward,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                label: 'Плановые расходы',
                value: _fmtShort.format(totalPlannedExpense),
                color: const Color(0xFFF59E0B),
                icon: Icons.event_note,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniCard(
                label: 'Факт. расходы',
                value: _fmtShort.format(allActualExpense),
                color: const Color(0xFFEF4444),
                icon: Icons.arrow_upward,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                label: 'Остаток',
                value: _fmtShort.format(remaining),
                color: remaining >= 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                icon: Icons.savings_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniCard(
                label: 'Норма сбережений',
                value: '${savingsRate.toStringAsFixed(1)}%',
                color: const Color(0xFF8B5CF6),
                icon: Icons.percent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Income vs Expense donut ──
        if (totalPlannedIncome > 0 || allActualExpense > 0) ...[
          const Text('Доходы vs Расходы',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          _IncomeExpenseDonut(
            plannedIncome: totalPlannedIncome,
            actualIncome: facts.monthIncome,
            plannedExpense: totalPlannedExpense,
            actualExpense: allActualExpense,
          ),
          const SizedBox(height: 16),
        ],

        // ── Monthly spending averages (P3) ──
        _MonthlyAveragesCard(averages: averages, baseCurrency: baseCurrency),
        const SizedBox(height: 16),

        // ── Month-vs-month comparison (P4) ──
        _MonthComparisonCard(
          availableMonths: [for (final m in averages.months) m.monthKey],
          accounts: accounts,
          transactions: transactions,
          convert: convert,
          baseCurrency: baseCurrency,
          accountIds: comparisonAccountIds,
        ),
        const SizedBox(height: 16),

        // ── Planned expenses progress ──
        if (combinedExpenses.isNotEmpty) ...[
          Row(
            children: [
              const Text('Плановые расходы',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$paidCount/$totalCount оплачено',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary),
                ),
              ),
            ],
          ),
          if (loanExpenses.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFF6D5CFF).withAlpha(30),
                  const Color(0xFFF59E0B).withAlpha(30),
                ]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance,
                      size: 16, color: Color(0xFF6D5CFF)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Кредиты в плане: ${loanExpenses.length} × → ${_fmt.format(loanPlannedExpense)} $baseCurrency',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          _ExpenseProgressBars(expenses: combinedExpenses),
          const SizedBox(height: 16),
        ],

        // ── Budget cycles ──
        const Text('Бюджетные циклы',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        if (cycles.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.info_outline,
                      size: 32, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(
                    'Добавьте источники дохода (зарплата, аванс)\nдля расчёта бюджетных циклов',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          for (final cycle in cycles) ...[
            _CycleCard(cycle: cycle),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 16),

        // ── Expense by category ──
        if (facts.expenseByCategory.isNotEmpty) ...[
          const Text('Расходы по категориям',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          _CategoryBreakdown(
            byCategory: facts.expenseByCategory,
            total: allActualExpense,
          ),
          const SizedBox(height: 16),
        ],

        // ── Daily spending chart ──
        if (facts.dailySpending.isNotEmpty) ...[
          const Text('Расходы по дням',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          _DailySpendingChart(
            dailySpending: facts.dailySpending,
            dailyBudget:
                cycles.isNotEmpty ? cycles.first.dailyBudget : 0,
          ),
          const SizedBox(height: 16),
        ],

        // ── Recent transactions ──
        if (facts.expenseTransactions.isNotEmpty) ...[
          const Text('Последние транзакции',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          ...facts.expenseTransactions.take(5).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          const Color(0xFFEF4444).withAlpha(30),
                      child: const Icon(Icons.arrow_upward,
                          size: 14, color: Color(0xFFEF4444)),
                    ),
                    title: Text(t.category,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(t.date,
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant)),
                    trailing: Text(
                      '-${_fmt.format(t.amount)}',
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ██████  INCOME SECTION  ██████
// ═════════════════════════════════════════════════════════════════════════════

class _IncomeSection extends ConsumerStatefulWidget {
  const _IncomeSection({required this.config, required this.facts});
  final BudgetPlanConfig config;
  final BudgetFacts facts;

  @override
  ConsumerState<_IncomeSection> createState() => _IncomeSectionState();
}

class _IncomeSectionState extends ConsumerState<_IncomeSection> {
  bool _showForm = false;
  String? _editingId;
  final _nameCtl = TextEditingController();
  final _amountCtl = TextEditingController();
  final _dayCtl = TextEditingController();
  IncomeSourceType _type = IncomeSourceType.salary;
  bool _adjustHolidays = true;

  void _resetForm() {
    _nameCtl.clear();
    _amountCtl.clear();
    _dayCtl.clear();
    _type = IncomeSourceType.salary;
    _adjustHolidays = true;
    _editingId = null;
    _showForm = false;
  }

  void _editSource(IncomeSource s) {
    _nameCtl.text = s.name;
    _amountCtl.text = s.amount.toStringAsFixed(0);
    _dayCtl.text = (s.dayOfMonth ?? '').toString();
    _type = s.type;
    _adjustHolidays = s.adjustForHolidays;
    _editingId = s.id;
    setState(() => _showForm = true);
  }

  void _submit() {
    final name = _nameCtl.text.trim();
    final amount = double.tryParse(_amountCtl.text) ?? 0;
    if (name.isEmpty || amount <= 0) return;
    final day = int.tryParse(_dayCtl.text);
    final ctrl = ref.read(budgetPlannerProvider.notifier);

    if (_editingId != null) {
      ctrl.updateIncomeSource(
          _editingId!,
          (s) => s.copyWith(
                name: name,
                type: _type,
                amount: amount,
                dayOfMonth: day,
                adjustForHolidays: _adjustHolidays,
              ));
    } else {
      ctrl.addIncomeSource(IncomeSource(
        id: _uuid.v4(),
        name: name,
        type: _type,
        amount: amount,
        dayOfMonth: day,
        adjustForHolidays: _adjustHolidays,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }
    setState(_resetForm);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _amountCtl.dispose();
    _dayCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources = widget.config.incomeSources;
    final total = sources
        .where((s) => s.isActive)
        .fold<double>(0, (s, e) => s + e.amount);
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Planned vs actual income comparison
        _ComparisonCard(
          title: 'Доходы за месяц',
          planned: total,
          actual: widget.facts.monthIncome,
          currency: 'BYN',
          plannedLabel: 'Запланировано',
          actualLabel: 'Факт (транзакции)',
        ),
        const SizedBox(height: 12),

        for (final s in sources) ...[
          _IncomeCard(
            source: s,
            payDate: s.dayOfMonth != null
                ? getPayDate(s, now.year, now.month)
                : null,
            onEdit: () => _editSource(s),
            onDelete: () => ref
                .read(budgetPlannerProvider.notifier)
                .deleteIncomeSource(s.id),
          ),
          const SizedBox(height: 8),
        ],

        if (_showForm)
          _buildForm(scheme)
        else
          _AddButton(
            label: 'Добавить источник дохода',
            onTap: () => setState(() => _showForm = true),
          ),

        // Actual income transactions
        if (widget.facts.incomeTransactions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Фактические поступления',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          ...widget.facts.incomeTransactions.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          const Color(0xFF10B981).withAlpha(30),
                      child: const Icon(Icons.arrow_downward,
                          size: 14, color: Color(0xFF10B981)),
                    ),
                    title: Text(t.category,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(t.date,
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant)),
                    trailing: Text(
                      '+${_fmt.format(t.amount)}',
                      style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                ),
              )),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildForm(ColorScheme scheme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editingId != null ? 'Редактировать' : 'Новый источник дохода',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<IncomeSourceType>(
              value: _type,
              decoration:
                  const InputDecoration(labelText: 'Тип', isDense: true),
              items: IncomeSourceType.values
                  .map((t) => DropdownMenuItem(
                      value: t, child: Text(_typeLabels[t]!)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(
                  labelText: 'Название', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Сумма (BYN)', isDense: true),
            ),
            const SizedBox(height: 8),
            if (_type != IncomeSourceType.additional) ...[
              TextField(
                controller: _dayCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _type == IncomeSourceType.advance
                      ? 'День месяца (пусто = последний)'
                      : 'День выплаты',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Учёт праздников РБ',
                    style: TextStyle(fontSize: 13)),
                value: _adjustHolidays,
                onChanged: (v) => setState(() => _adjustHolidays = v),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(
                        _editingId != null ? 'Сохранить' : 'Добавить'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(_resetForm),
                  child: const Text('Отмена'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  const _IncomeCard({
    required this.source,
    required this.payDate,
    required this.onEdit,
    required this.onDelete,
  });
  final IncomeSource source;
  final DateTime? payDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typeColor = switch (source.type) {
      IncomeSourceType.salary => const Color(0xFF10B981),
      IncomeSourceType.advance => const Color(0xFF3B82F6),
      IncomeSourceType.additional => const Color(0xFF8B5CF6),
    };

    return Dismissible(
      key: ValueKey('income-source-${source.id}'),
      direction: DismissDirection.endToStart,
      background: _deleteSwipeBackground(),
      confirmDismiss: (_) =>
          _confirmDelete(context, 'Удалить источник дохода «${source.name}»?'),
      onDismissed: (_) => onDelete(),
      child: Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withAlpha(30),
          child: Icon(_iconFor(source.type), color: typeColor, size: 20),
        ),
        title: Text(source.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          [
            _typeLabels[source.type],
            if (payDate != null)
              DateFormat('d MMMM', 'ru').format(payDate!),
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_fmt.format(source.amount)} BYN',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Изменить')),
                const PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              child: const Icon(Icons.more_vert, size: 18),
            ),
          ],
        ),
      ),
      ),
    );
  }

  IconData _iconFor(IncomeSourceType type) => switch (type) {
        IncomeSourceType.salary => Icons.work_outline,
        IncomeSourceType.advance => Icons.schedule,
        IncomeSourceType.additional => Icons.add_circle_outline,
      };
}

// ═════════════════════════════════════════════════════════════════════════════
// ██████  EXPENSE SECTION  ██████
// ═════════════════════════════════════════════════════════════════════════════

class _ExpenseSection extends ConsumerStatefulWidget {
  const _ExpenseSection({
    required this.config,
    required this.facts,
    required this.transactions,
    required this.accounts,
    required this.baseCurrency,
    required this.convert,
  });
  final BudgetPlanConfig config;
  final BudgetFacts facts;
  final List<Transaction> transactions;
  final List<Account> accounts;
  final String baseCurrency;
  final num Function(num, String, String) convert;

  @override
  ConsumerState<_ExpenseSection> createState() => _ExpenseSectionState();
}

class _ExpenseSectionState extends ConsumerState<_ExpenseSection> {
  bool _showForm = false;
  bool _showActualForm = false;
  String? _editingId;
  ExpenseRecurrence _recurrence = ExpenseRecurrence.monthly;
  String? _startMonth; // YYYY-MM
  final _nameCtl = TextEditingController();
  final _amountCtl = TextEditingController();
  final _dayFromCtl = TextEditingController();
  final _dayToCtl = TextEditingController();
  final _actNameCtl = TextEditingController();
  final _actAmountCtl = TextEditingController();

  String get _thisMonthKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  void _resetForm() {
    _nameCtl.clear();
    _amountCtl.clear();
    _dayFromCtl.clear();
    _dayToCtl.clear();
    _recurrence = ExpenseRecurrence.monthly;
    _startMonth = null;
    _editingId = null;
    _showForm = false;
  }

  void _editExpense(PlannedExpense e) {
    _nameCtl.text = e.name;
    _amountCtl.text = e.amount.toStringAsFixed(0);
    _dayFromCtl.text = e.dayFrom.toString();
    _dayToCtl.text = e.dayTo.toString();
    _recurrence = e.recurrence;
    _startMonth = e.startMonth;
    _editingId = e.id;
    setState(() => _showForm = true);
  }

  void _submitPlanned() {
    final name = _nameCtl.text.trim();
    final amount = double.tryParse(_amountCtl.text) ?? 0;
    if (name.isEmpty || amount <= 0) return;
    final dayFrom = int.tryParse(_dayFromCtl.text) ?? 1;
    final dayTo = int.tryParse(_dayToCtl.text) ?? 31;
    // 'once' must be anchored to a month; default to the current one.
    final startMonth = _recurrence == ExpenseRecurrence.once
        ? (_startMonth ?? _thisMonthKey)
        : _startMonth;
    final ctrl = ref.read(budgetPlannerProvider.notifier);

    if (_editingId != null) {
      ctrl.updatePlannedExpense(
          _editingId!,
          (e) => e.copyWith(
                name: name,
                amount: amount,
                dayFrom: dayFrom,
                dayTo: dayTo,
                recurrence: _recurrence,
                startMonth: startMonth,
                clearStartMonth: startMonth == null,
              ));
    } else {
      ctrl.addPlannedExpense(PlannedExpense(
        id: _uuid.v4(),
        name: name,
        amount: amount,
        dayFrom: dayFrom,
        dayTo: dayTo,
        recurrence: _recurrence,
        startMonth: startMonth,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }
    setState(_resetForm);
  }

  void _submitActual() {
    final name = _actNameCtl.text.trim();
    final amount = double.tryParse(_actAmountCtl.text) ?? 0;
    if (name.isEmpty || amount <= 0) return;
    ref.read(budgetPlannerProvider.notifier).addActualExpense(
          ActualExpense(
            id: _uuid.v4(),
            name: name,
            amount: amount,
            date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          ),
        );
    _actNameCtl.clear();
    _actAmountCtl.clear();
    setState(() => _showActualForm = false);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _amountCtl.dispose();
    _dayFromCtl.dispose();
    _dayToCtl.dispose();
    _actNameCtl.dispose();
    _actAmountCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenses = widget.config.plannedExpenses;
    final total = expenses
        .where((e) => e.isActive)
        .fold<double>(0, (s, e) => s + e.amount);
    final scheme = Theme.of(context).colorScheme;
    final manualActual =
        widget.config.actualExpenses.fold<double>(0, (s, e) => s + e.amount);
    final allActual = widget.facts.monthExpense + manualActual;

    // Auto-detect which planned expenses are already settled by a real
    // transaction this month, so they show as paid without a manual tick.
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final accountCurrency = {for (final a in widget.accounts) a.id: a.currency};
    final autoPaidIds = <String>{
      for (final e in expenses)
        if (!e.isPaid &&
            plannedExpensePaidByTransaction(
              exp: e,
              transactions: widget.transactions,
              monthKey: currentMonthKey,
              accountCurrency: accountCurrency,
              convert: widget.convert,
              baseCurrency: widget.baseCurrency,
            ))
          e.id,
    };
    final paidTotal = expenses
        .where((e) => e.isPaid || autoPaidIds.contains(e.id))
        .fold<double>(0, (s, e) => s + (e.paidAmount ?? e.amount));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Comparison card
        _ComparisonCard(
          title: 'Расходы за месяц',
          planned: total,
          actual: allActual,
          currency: 'BYN',
          plannedLabel: 'Запланировано',
          actualLabel: 'Факт (транзакции + ручные)',
          isExpense: true,
        ),
        const SizedBox(height: 12),

        // Planned expense progress
        if (expenses.isNotEmpty) ...[
          Row(
            children: [
              const Text('Оплачено',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Text('${_fmt.format(paidTotal)} / ${_fmt.format(total)} BYN',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: total > 0 ? (paidTotal / total).clamp(0, 1) : 0,
            borderRadius: BorderRadius.circular(6),
            minHeight: 8,
          ),
          const SizedBox(height: 12),
        ],

        // Planned expenses list
        for (final e in expenses) ...[
          _ExpenseCard(
            expense: e,
            autoPaid: autoPaidIds.contains(e.id),
            onEdit: () => _editExpense(e),
            onDelete: () => ref
                .read(budgetPlannerProvider.notifier)
                .deletePlannedExpense(e.id),
            onTogglePaid: () {
              final ctrl = ref.read(budgetPlannerProvider.notifier);
              if (e.isPaid) {
                ctrl.markExpenseUnpaid(e.id);
              } else {
                ctrl.markExpensePaid(e.id);
              }
            },
          ),
          const SizedBox(height: 8),
        ],

        if (_showForm)
          _buildPlannedForm(scheme)
        else
          _AddButton(
            label: 'Добавить плановый расход',
            onTap: () => setState(() => _showForm = true),
          ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // Manual actual expenses
        Row(
          children: [
            const Text('Ручные расходы',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            Text('${_fmt.format(manualActual)} BYN',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        for (final e in widget.config.actualExpenses) ...[
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              title: Text(e.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text(e.date,
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('-${_fmt.format(e.amount)} BYN',
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => ref
                        .read(budgetPlannerProvider.notifier)
                        .deleteActualExpense(e.id),
                    child: const Icon(Icons.close,
                        size: 16, color: Color(0xFFEF4444)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],

        if (_showActualForm)
          _buildActualForm()
        else
          _AddButton(
            label: 'Добавить ручной расход',
            onTap: () => setState(() => _showActualForm = true),
          ),

        // Transaction expenses from accounts
        if (widget.facts.expenseTransactions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Расходы из транзакций',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              Text('${_fmt.format(widget.facts.monthExpense)} BYN',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.facts.expenseTransactions.take(10).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          const Color(0xFFEF4444).withAlpha(30),
                      child: const Icon(Icons.receipt,
                          size: 14, color: Color(0xFFEF4444)),
                    ),
                    title: Text(t.category,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                        '${t.date}${t.notes != null ? " · ${t.notes}" : ""}',
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant)),
                    trailing: Text(
                      '-${_fmt.format(t.amount)}',
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                ),
              )),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPlannedForm(ColorScheme scheme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editingId != null ? 'Редактировать' : 'Новый плановый расход',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(
                  labelText: 'Название', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Сумма (BYN)', isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dayFromCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'С числа', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _dayToCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'По число', isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Повторение',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            SegmentedButton<ExpenseRecurrence>(
              segments: const [
                ButtonSegment(
                    value: ExpenseRecurrence.monthly,
                    label: Text('Каждый месяц')),
                ButtonSegment(
                    value: ExpenseRecurrence.once, label: Text('Разовый')),
              ],
              selected: {_recurrence},
              onSelectionChanged: (s) => setState(() {
                _recurrence = s.first;
                if (_recurrence == ExpenseRecurrence.once) {
                  _startMonth ??= _thisMonthKey;
                }
              }),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickStartMonth,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: _recurrence == ExpenseRecurrence.once
                      ? 'Месяц платежа'
                      : 'С какого месяца (необязательно)',
                  isDense: true,
                  suffixIcon: _startMonth != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _recurrence == ExpenseRecurrence.once
                              ? null
                              : () => setState(() => _startMonth = null),
                        )
                      : const Icon(Icons.calendar_month, size: 18),
                ),
                child: Text(
                  _startMonth != null
                      ? _monthKeyLabel(_startMonth!)
                      : (_recurrence == ExpenseRecurrence.monthly
                          ? 'С текущего месяца'
                          : 'Выбрать'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _submitPlanned,
                    child: Text(
                        _editingId != null ? 'Сохранить' : 'Добавить'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(_resetForm),
                  child: const Text('Отмена'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _monthNames = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];

  String _monthKeyLabel(String key) {
    final parts = key.split('-');
    if (parts.length < 2) return key;
    final m = int.tryParse(parts[1]) ?? 1;
    return '${_monthNames[(m - 1).clamp(0, 11)]} ${parts[0].substring(2)}';
  }

  Future<void> _pickStartMonth() async {
    final now = DateTime.now();
    final initial = _startMonth != null
        ? DateTime(
            int.parse(_startMonth!.split('-')[0]),
            int.parse(_startMonth!.split('-')[1]),
          )
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5, 12),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Выберите месяц (день не важен)',
    );
    if (picked != null) {
      setState(() =>
          _startMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}');
    }
  }

  Widget _buildActualForm() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Новый расход',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            TextField(
              controller: _actNameCtl,
              decoration: const InputDecoration(
                  labelText: 'Название', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _actAmountCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Сумма (BYN)', isDense: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _submitActual,
                    child: const Text('Добавить'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () =>
                      setState(() => _showActualForm = false),
                  child: const Text('Отмена'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePaid,
    this.autoPaid = false,
  });
  final PlannedExpense expense;
  final bool autoPaid;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePaid;

  static const _monthNames = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];

  String _monthKeyLabel(String key) {
    final parts = key.split('-');
    if (parts.length < 2) return key;
    final m = int.tryParse(parts[1]) ?? 1;
    return '${_monthNames[(m - 1).clamp(0, 11)]} ${parts[0].substring(2)}';
  }

  String? _recurrenceSuffix() {
    if (expense.recurrence == ExpenseRecurrence.once) {
      return expense.startMonth != null
          ? 'разовый · ${_monthKeyLabel(expense.startMonth!)}'
          : 'разовый';
    }
    if (expense.startMonth != null) {
      return 'с ${_monthKeyLabel(expense.startMonth!)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paid = expense.isPaid || autoPaid;
    final recurrenceSuffix = _recurrenceSuffix();
    return Dismissible(
      key: ValueKey('planned-expense-${expense.id}'),
      direction: DismissDirection.endToStart,
      background: _deleteSwipeBackground(),
      confirmDismiss: (_) => _confirmDelete(
          context, 'Удалить плановый расход «${expense.name}»?'),
      onDismissed: (_) => onDelete(),
      child: Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: GestureDetector(
          onTap: onTogglePaid,
          child: CircleAvatar(
            backgroundColor: paid
                ? const Color(0xFF10B981).withAlpha(30)
                : scheme.surfaceContainerHighest,
            child: Icon(
              paid ? Icons.check_circle : Icons.circle_outlined,
              color: paid
                  ? const Color(0xFF10B981)
                  : scheme.onSurfaceVariant,
              size: 24,
            ),
          ),
        ),
        title: Text(
          expense.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            decoration: paid ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          autoPaid && !expense.isPaid
              ? '${expense.dayFrom}–${expense.dayTo} числа · оплачено по транзакции'
              : '${expense.dayFrom}–${expense.dayTo} числа'
                  '${recurrenceSuffix != null ? ' · $recurrenceSuffix' : ''}',
          style: TextStyle(
              fontSize: 12,
              color: autoPaid && !expense.isPaid
                  ? const Color(0xFF10B981)
                  : scheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_fmt.format(expense.amount)} BYN',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit', child: Text('Изменить')),
                const PopupMenuItem(
                    value: 'delete', child: Text('Удалить')),
              ],
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              child: const Icon(Icons.more_vert, size: 18),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Red "delete" panel revealed when swiping a budget card from right to left.
Widget _deleteSwipeBackground() => Container(
      margin: EdgeInsets.zero,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );

Future<bool> _confirmDelete(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Удалить?'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// ═════════════════════════════════════════════════════════════════════════════
// ██████  SHARED WIDGETS  ██████
// ═════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// Safe-to-spend forecast card ("Сколько можно тратить")
// ─────────────────────────────────────────────────────────────────────────────

String _pluralizeDays(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'день';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'дня';
  return 'дней';
}

String _pluralizeMonths(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'месяц';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'месяца';
  return 'месяцев';
}

const _monthLabelsShort = [
  'янв', 'фев', 'мар', 'апр', 'май', 'июн',
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
];

String _monthLabel(MonthlySpending m) =>
    '${_monthLabelsShort[(m.month - 1).clamp(0, 11)]} ${m.year % 100}';

// Label for a 'yyyy-MM' month key, e.g. '2026-06' → 'июн 26'.
String _monthKeyLabel(String key) {
  final parts = key.split('-');
  if (parts.length < 2) return key;
  final year = int.tryParse(parts[0]) ?? 0;
  final month = int.tryParse(parts[1]) ?? 0;
  return '${_monthLabelsShort[(month - 1).clamp(0, 11)]} ${year % 100}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly spending averages (P3): avg daily/monthly expense & income per month
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlyAveragesCard extends StatelessWidget {
  const _MonthlyAveragesCard({
    required this.averages,
    required this.baseCurrency,
  });

  final SpendingAverages averages;
  final String baseCurrency;

  @override
  Widget build(BuildContext context) {
    const expenseColor = Color(0xFFF43F5E);
    const incomeColor = Color(0xFF10B981);

    if (averages.monthsCounted == 0) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  Icon(Icons.bar_chart, size: 16, color: Colors.grey),
                  SizedBox(width: 6),
                  Text('Средние траты по месяцам',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Недостаточно истории. Добавьте фактические доходы/расходы '
                'за прошлые месяцы.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final maxDaily = averages.months.fold<double>(
      0,
      (m, e) => math.max(m, math.max(e.avgDailyExpense, e.avgDailyIncome)),
    );
    final cap = maxDaily * 1.2;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, size: 16, color: Color(0xFF6D5CFF)),
                SizedBox(width: 6),
                Text('Средние траты по месяцам',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _avgTile(
                    'Расход / день',
                    averages.avgDailyExpense,
                    averages.avgMonthlyExpense,
                    expenseColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _avgTile(
                    'Доход / день',
                    averages.avgDailyIncome,
                    averages.avgMonthlyIncome,
                    incomeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'По ${averages.monthsCounted} '
              '${_pluralizeMonths(averages.monthsCounted)}; '
              'текущий месяц — по прошедшим дням.',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (averages.months.length > 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: BarChart(BarChartData(
                  maxY: cap > 0 ? cap : 100,
                  barGroups: [
                    for (var i = 0; i < averages.months.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: averages.months[i].avgDailyIncome,
                          width: 7,
                          color: incomeColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        BarChartRodData(
                          toY: averages.months[i].avgDailyExpense,
                          width: 7,
                          color: expenseColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ]),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= averages.months.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_monthLabel(averages.months[i]),
                                style: const TextStyle(fontSize: 9)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                )),
              ),
            ],
            const SizedBox(height: 8),
            for (final m in averages.months.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_monthLabel(m),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Text('−${_fmt.format(m.avgDailyExpense)}/дн',
                        style: const TextStyle(
                            fontSize: 11,
                            color: expenseColor,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    Text('+${_fmt.format(m.avgDailyIncome)}/дн',
                        style: const TextStyle(
                            fontSize: 11,
                            color: incomeColor,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    Text(
                      '${m.net >= 0 ? '+' : ''}${_fmt.format(m.net)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: m.net >= 0 ? incomeColor : expenseColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _avgTile(String label, double daily, double monthly, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(height: 2),
          Text('${_fmt.format(daily)} $baseCurrency',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          Text('≈ ${_fmt.format(monthly)} $baseCurrency/мес',
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month-vs-month comparison (P4): pick any two months, see income/expense deltas
// and per-category changes (b − a).
// ─────────────────────────────────────────────────────────────────────────────

class _MonthComparisonCard extends StatefulWidget {
  const _MonthComparisonCard({
    required this.availableMonths,
    required this.accounts,
    required this.transactions,
    required this.convert,
    required this.baseCurrency,
    required this.accountIds,
  });

  final List<String> availableMonths;
  final List<Account> accounts;
  final List<Transaction> transactions;
  final num Function(num amount, String from, String to) convert;
  final String baseCurrency;
  final List<String> accountIds;

  @override
  State<_MonthComparisonCard> createState() => _MonthComparisonCardState();
}

class _MonthComparisonCardState extends State<_MonthComparisonCard> {
  String? _monthKeyA;
  String? _monthKeyB;

  List<String> get _months {
    final set = {...widget.availableMonths};
    final sorted = set.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    const expenseColor = Color(0xFFF43F5E);
    const incomeColor = Color(0xFF10B981);
    final months = _months;

    if (months.length < 2) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  Icon(Icons.compare_arrows, size: 16, color: Colors.grey),
                  SizedBox(width: 6),
                  Text('Сравнение месяцев',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Нужно минимум два месяца с фактическими данными, '
                'чтобы сравнить.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Defaults: latest month (b) vs previous (a).
    final keyB = (_monthKeyB != null && months.contains(_monthKeyB))
        ? _monthKeyB!
        : months.last;
    final keyA = (_monthKeyA != null && months.contains(_monthKeyA))
        ? _monthKeyA!
        : months[months.length - 2];

    final cmp = computeMonthlyComparison(
      accounts: widget.accounts,
      transactions: widget.transactions,
      convert: widget.convert,
      baseCurrency: widget.baseCurrency,
      monthKeyA: keyA,
      monthKeyB: keyB,
      accountIds: widget.accountIds,
    );

    final topCategories = cmp.categories.take(8).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.compare_arrows, size: 16, color: Color(0xFF6D5CFF)),
                SizedBox(width: 6),
                Text('Сравнение месяцев',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _monthDropdown(
                    label: 'Месяц A',
                    value: keyA,
                    months: months,
                    onChanged: (v) => setState(() => _monthKeyA = v),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                ),
                Expanded(
                  child: _monthDropdown(
                    label: 'Месяц B',
                    value: keyB,
                    months: months,
                    onChanged: (v) => setState(() => _monthKeyB = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _totalsTile(
                    'Расходы',
                    cmp.a.totalExpense,
                    cmp.b.totalExpense,
                    cmp.expenseDelta,
                    expenseColor,
                    higherIsBad: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _totalsTile(
                    'Доходы',
                    cmp.a.totalIncome,
                    cmp.b.totalIncome,
                    cmp.incomeDelta,
                    incomeColor,
                    higherIsBad: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _totalsTile(
              'Сальдо (доход − расход)',
              cmp.a.net,
              cmp.b.net,
              cmp.netDelta,
              const Color(0xFF8B5CF6),
              higherIsBad: false,
              wide: true,
            ),
            if (topCategories.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Изменения по категориям',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final c in topCategories)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.category,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_fmtShort.format(c.a)} → ${_fmtShort.format(c.b)}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(width: 10),
                      _DeltaChip(
                        value: c.delta,
                        baseCurrency: widget.baseCurrency,
                        higherIsBad: true,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _monthDropdown({
    required String label,
    required String value,
    required List<String> months,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: [
            for (final m in months.reversed)
              DropdownMenuItem(value: m, child: Text(_monthKeyLabel(m))),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _totalsTile(
    String label,
    double a,
    double b,
    double delta,
    Color color, {
    required bool higherIsBad,
    bool wide = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '${_fmtShort.format(a)} → ${_fmtShort.format(b)}',
                  style: TextStyle(
                      fontSize: wide ? 15 : 13,
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
              ),
              _DeltaChip(
                value: delta,
                baseCurrency: widget.baseCurrency,
                higherIsBad: higherIsBad,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.value,
    required this.baseCurrency,
    required this.higherIsBad,
  });

  final double value;
  final String baseCurrency;
  final bool higherIsBad;

  @override
  Widget build(BuildContext context) {
    const good = Color(0xFF10B981);
    const bad = Color(0xFFF43F5E);
    final neutral = Colors.grey.shade500;
    Color color;
    if (value.abs() < 0.005) {
      color = neutral;
    } else {
      final isPositive = value > 0;
      final isGood = higherIsBad ? !isPositive : isPositive;
      color = isGood ? good : bad;
    }
    final sign = value > 0 ? '+' : (value < 0 ? '−' : '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$sign${_fmtShort.format(value.abs())}',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _SafeToSpendCard extends ConsumerStatefulWidget {
  const _SafeToSpendCard({
    required this.forecast,
    required this.reserve,
    required this.averages,
  });

  final CashflowForecast forecast;
  final double reserve;
  final SpendingAverages averages;

  @override
  ConsumerState<_SafeToSpendCard> createState() => _SafeToSpendCardState();
}

class _SafeToSpendCardState extends ConsumerState<_SafeToSpendCard> {
  late final TextEditingController _reserveCtrl;
  final _reserveFocus = FocusNode();
  final _customDailyCtrl = TextEditingController();
  bool _showSegments = false;
  SafeToSpendScenario _scenario = SafeToSpendScenario.planToZero;

  @override
  void initState() {
    super.initState();
    _reserveCtrl = TextEditingController(text: _formatReserve(widget.reserve));
    _reserveFocus.addListener(() {
      if (!_reserveFocus.hasFocus) _commitReserve();
    });
    _customDailyCtrl.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(_SafeToSpendCard old) {
    super.didUpdateWidget(old);
    // Keep the field in sync when the reserve changes elsewhere, unless the
    // user is actively editing it.
    if (!_reserveFocus.hasFocus && widget.reserve != old.reserve) {
      _reserveCtrl.text = _formatReserve(widget.reserve);
    }
  }

  @override
  void dispose() {
    _reserveCtrl.dispose();
    _reserveFocus.dispose();
    _customDailyCtrl.dispose();
    super.dispose();
  }

  static String _formatReserve(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  void _commitReserve() {
    final raw = _reserveCtrl.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(raw) ?? 0;
    final value = parsed < 0 ? 0.0 : parsed;
    ref.read(safeToSpendReserveProvider.notifier).set(value);
    _reserveCtrl.text = _formatReserve(value);
  }

  Future<void> _pickCustomDate(BuildContext context, {required bool isStart}) async {
    final custom = ref.read(safeToSpendCustomRangeProvider);
    final current = isStart ? custom.start : custom.end;
    final initial = (current != null && current.isNotEmpty
            ? DateTime.tryParse(current)
            : null) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (picked == null) return;
    final iso = DateFormat('yyyy-MM-dd').format(picked);
    final notifier = ref.read(safeToSpendCustomRangeProvider.notifier);
    if (isStart) {
      await notifier.setStart(iso);
    } else {
      await notifier.setEnd(iso);
    }
  }

  Widget _pillButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? Colors.white : Colors.white.withAlpha(38),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? const Color(0xFF4338CA) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRangeSelector(BuildContext context) {
    final mode = ref.watch(safeToSpendRangeModeProvider);
    final custom = ref.watch(safeToSpendCustomRangeProvider);
    const white70 = Color(0xB3FFFFFF);

    String dateLabel(String? iso, {String empty = 'выбрать'}) {
      if (iso == null || iso.isEmpty) return empty;
      final d = DateTime.tryParse(iso);
      return d != null ? DateFormat('d MMM yyyy', 'ru').format(d) : empty;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in CashflowRangeMode.values)
              _pillButton(
                label: cashflowRangeLabels[m]!,
                selected: mode == m,
                onTap: () =>
                    ref.read(safeToSpendRangeModeProvider.notifier).set(m),
              ),
          ],
        ),
        if (mode == CashflowRangeMode.custom) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CustomDateButton(
                  label: 'С',
                  value: dateLabel(custom.start, empty: 'сегодня'),
                  onTap: () => _pickCustomDate(context, isStart: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CustomDateButton(
                  label: 'По',
                  value: dateLabel(custom.end),
                  onTap: () => _pickCustomDate(context, isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            (custom.start == null || custom.start!.isEmpty)
                ? 'Считаем с сегодняшнего дня до выбранной даты.'
                : 'Выберите начало и конец периода для расчёта.',
            style: const TextStyle(color: white70, fontSize: 10),
          ),
        ],
      ],
    );
  }

  Widget _buildAccountSelector(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    if (accounts.isEmpty) return const SizedBox.shrink();
    final selected = ref.watch(safeToSpendAccountIdsProvider);
    const white70 = Color(0xB3FFFFFF);

    Widget chip({
      required String label,
      required bool active,
      required VoidCallback onTap,
    }) {
      return _pillButton(label: label, selected: active, onTap: onTap);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'СЧЕТА ДЛЯ РАСЧЁТА',
          style: TextStyle(
            color: white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            chip(
              label: 'Все счета',
              active: selected.isEmpty,
              onTap: () =>
                  ref.read(safeToSpendAccountIdsProvider.notifier).set(const []),
            ),
            for (final a in accounts)
              chip(
                label: a.name,
                active: selected.contains(a.id),
                onTap: () => ref
                    .read(safeToSpendAccountIdsProvider.notifier)
                    .toggle(a.id),
              ),
          ],
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text(
            'Баланс считается только по выбранным счетам.',
            style: TextStyle(color: white70, fontSize: 10),
          ),
        ],
      ],
    );
  }

  Widget _buildScenarioSelector(BuildContext context) {
    final f = widget.forecast;
    final ccy = f.baseCurrency;
    const white70 = Color(0xB3FFFFFF);
    const white54 = Color(0x8AFFFFFF);
    const rose = Color(0xFFFECDD3);

    final customDaily =
        double.tryParse(_customDailyCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final projection = computeScenarioProjection(
      scenario: _scenario,
      forecast: f,
      reserve: widget.reserve,
      averages: widget.averages,
      customDaily: customDaily,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'СЦЕНАРИЙ ПЛАНА',
          style: TextStyle(
            color: white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in SafeToSpendScenario.values)
              _pillButton(
                label: scenarioLabels[s]!,
                selected: _scenario == s,
                onTap: () => setState(() => _scenario = s),
              ),
          ],
        ),
        if (_scenario == SafeToSpendScenario.customDaily) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customDailyCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              color: Color(0xFF18181B),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white.withAlpha(230),
              hintText: 'Мой расход в день ($ccy), напр. 30',
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
        if (projection != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(38),
              borderRadius: BorderRadius.circular(12),
            ),
            child: projection.insufficientHistory
                ? const Text(
                    'Недостаточно истории трат, чтобы посчитать средние. '
                    'Добавьте фактические расходы за прошлые месяцы.',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'ТРАТА В ДЕНЬ',
                              style: TextStyle(
                                color: white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Text(
                            '${_fmt.format(projection.dailySpend)} $ccy',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'ОСТАТОК К КОНЦУ',
                              style: TextStyle(
                                color: white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Text(
                            '${_fmt.format(projection.endBalance)} $ccy',
                            style: TextStyle(
                              color:
                                  projection.shortfall ? rose : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        projection.surplusOverReserve >= 0
                            ? 'профицит над резервом: '
                                '+${_fmt.format(projection.surplusOverReserve)} $ccy'
                            : 'не хватает до резерва: '
                                '${_fmt.format(projection.surplusOverReserve)} $ccy',
                        style: TextStyle(
                          color: projection.surplusOverReserve >= 0
                              ? white70
                              : rose,
                          fontSize: 11,
                        ),
                      ),
                      if (_scenario == SafeToSpendScenario.avgExpense ||
                          _scenario ==
                              SafeToSpendScenario.avgExpenseIncome) ...[
                        const SizedBox(height: 4),
                        Text(
                          'По средним за ${widget.averages.monthsCounted} '
                          '${_pluralizeMonths(widget.averages.monthsCounted)}; '
                          'платежи уже внутри средних трат.',
                          style: const TextStyle(
                              color: white54, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.forecast;
    final ccy = f.baseCurrency;
    const white70 = Color(0xB3FFFFFF);
    const white54 = Color(0x8AFFFFFF);

    return _GradientCard(
      gradient: const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF7C3AED)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.savings_outlined, color: white70, size: 18),
              SizedBox(width: 6),
              Text(
                'СКОЛЬКО МОЖНО ТРАТИТЬ',
                style: TextStyle(
                  color: white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRangeSelector(context),
          const SizedBox(height: 12),
          _buildAccountSelector(context),
          const SizedBox(height: 12),
          if (!f.ok)
            const Text(
              'Добавьте источники дохода с датами выплат, чтобы рассчитать дневной лимит.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            )
          else ...[
            if (f.range != null) ...[
              Text(
                'Период: ${f.range!.label} · '
                '${DateFormat('d MMM', 'ru').format(f.range!.startDate)} → '
                '${DateFormat('d MMM', 'ru').format(f.range!.endDate)} '
                '(${f.range!.daysLeft} ${_pluralizeDays(f.range!.daysLeft)})',
                style: const TextStyle(color: white70, fontSize: 11),
              ),
              const SizedBox(height: 8),
            ],
            // Headline: daily until next income.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _fmt.format(f.dailyUntilNextIncome),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$ccy/день',
                  style: const TextStyle(
                      color: white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              f.nextIncome != null
                  ? 'до «${f.nextIncome!.name}» — через ${f.nextIncome!.daysUntil} '
                      '${_pluralizeDays(f.nextIncome!.daysUntil)} '
                      '(${DateFormat('d MMM', 'ru').format(f.nextIncome!.date)}, '
                      '+${_fmt.format(f.nextIncome!.amount)} $ccy)'
                  : 'ближайших поступлений в горизонте нет',
              style: const TextStyle(color: white70, fontSize: 12),
            ),
            const SizedBox(height: 12),

            _buildScenarioSelector(context),
            const SizedBox(height: 12),

            // Balance + smoothed.
            Row(
              children: [
                Expanded(
                  child: _SafeStat(
                    label: 'СЕЙЧАС НА СЧЕТАХ',
                    value: '${_fmt.format(f.currentBalance)} $ccy',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SafeStat(
                    label: 'РОВНО В ДЕНЬ (ДО ЗАРПЛАТЫ)',
                    value: '${_fmt.format(f.smoothedDaily)} $ccy',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Cash-gap warning.
            if (f.hasCashGap) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E).withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: white54),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Кассовый разрыв: остатка и резерва не хватает на '
                        'обязательные платежи до следующего дохода.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Reserve input.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'НЕСГОРАЕМЫЙ РЕЗЕРВ',
                    style: TextStyle(
                      color: white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reserveCtrl,
                          focusNode: _reserveFocus,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _commitReserve(),
                          style: const TextStyle(
                            color: Color(0xFF18181B),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white.withAlpha(230),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ccy,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Эта сумма не входит в дневной лимит — её приложение бережёт.',
                    style: TextStyle(color: white54, fontSize: 10),
                  ),
                ],
              ),
            ),

            // Segments toggle.
            if (f.segments.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _showSegments = !_showSegments),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showSegments
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: white70,
                      size: 18,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'По периодам (${f.segments.length})',
                      style: const TextStyle(
                          color: white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (_showSegments)
                for (final seg in f.segments) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                seg.label,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              '${_fmt.format(seg.dailyLimit)} $ccy/день',
                              style: TextStyle(
                                color: seg.shortfall
                                    ? const Color(0xFFFECDD3)
                                    : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${DateFormat('d MMM', 'ru').format(seg.startDate)} → '
                                '${DateFormat('d MMM', 'ru').format(seg.endDate)} '
                                '(${seg.days} ${_pluralizeDays(seg.days)})',
                                style:
                                    const TextStyle(color: white54, fontSize: 10),
                              ),
                            ),
                            if (seg.obligations > 0)
                              Text(
                                'платежи: −${_fmt.format(seg.obligations)}',
                                style: const TextStyle(
                                    color: white54, fontSize: 10),
                              ),
                          ],
                        ),
                        if (seg.shortfall) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'не хватает на платежи + резерв в этом окне',
                            style:
                                TextStyle(color: Color(0xFFFECDD3), fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
            ],
          ],
        ],
      ),
    );
  }
}

class _SafeStat extends StatelessWidget {
  const _SafeStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CustomDateButton extends StatelessWidget {
  const _CustomDateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(38),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
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

class _GradientCard extends StatelessWidget {
  const _GradientCard({required this.gradient, required this.child});
  final Gradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.title,
    required this.planned,
    required this.actual,
    required this.currency,
    required this.plannedLabel,
    required this.actualLabel,
    this.isExpense = false,
  });
  final String title;
  final double planned;
  final double actual;
  final String currency;
  final String plannedLabel;
  final String actualLabel;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = planned > 0 ? (actual / planned).clamp(0.0, 2.0) : 0.0;
    final pct = (progress * 100).toStringAsFixed(0);
    final overBudget = isExpense && actual > planned;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plannedLabel,
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant)),
                      Text('${_fmt.format(planned)} $currency',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: scheme.outlineVariant,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(actualLabel,
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant)),
                        Text(
                          '${_fmt.format(actual)} $currency',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: overBudget
                                ? const Color(0xFFEF4444)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 8,
                      color: overBudget
                          ? const Color(0xFFEF4444)
                          : scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$pct%',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: overBudget
                          ? const Color(0xFFEF4444)
                          : scheme.primary,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
              color: scheme.primary.withAlpha(80), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline,
                size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ██████  CHARTS & INFOGRAPHICS  ██████
// ═════════════════════════════════════════════════════════════════════════════

class _IncomeExpenseDonut extends StatelessWidget {
  const _IncomeExpenseDonut({
    required this.plannedIncome,
    required this.actualIncome,
    required this.plannedExpense,
    required this.actualExpense,
  });
  final double plannedIncome;
  final double actualIncome;
  final double plannedExpense;
  final double actualExpense;

  @override
  Widget build(BuildContext context) {
    final remaining =
        (plannedIncome - plannedExpense - actualExpense).clamp(0.0, double.infinity);
    final sections = <PieChartSectionData>[
      PieChartSectionData(
        value: plannedExpense > 0 ? plannedExpense : 0.01,
        color: const Color(0xFFF59E0B),
        radius: 28,
        title: '',
      ),
      PieChartSectionData(
        value: actualExpense > 0 ? actualExpense : 0.01,
        color: const Color(0xFFEF4444),
        radius: 28,
        title: '',
      ),
      PieChartSectionData(
        value: remaining > 0 ? remaining : 0.01,
        color: const Color(0xFF10B981),
        radius: 28,
        title: '',
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: PieChart(PieChartData(
                sections: sections,
                centerSpaceRadius: 26,
                sectionsSpace: 2,
              )),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendItem(
                      color: const Color(0xFFF59E0B),
                      label: 'План',
                      value: _fmtShort.format(plannedExpense)),
                  const SizedBox(height: 6),
                  _LegendItem(
                      color: const Color(0xFFEF4444),
                      label: 'Факт',
                      value: _fmtShort.format(actualExpense)),
                  const SizedBox(height: 6),
                  _LegendItem(
                      color: const Color(0xFF10B981),
                      label: 'Свободно',
                      value: _fmtShort.format(remaining)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(
      {required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ExpenseProgressBars extends StatelessWidget {
  const _ExpenseProgressBars({required this.expenses});
  final List<PlannedExpense> expenses;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = expenses
        .where((e) => e.isActive)
        .fold<double>(0, (s, e) => s + e.amount);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < expenses.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _singleBar(expenses[i], total, scheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _singleBar(PlannedExpense e, double total, ColorScheme scheme) {
    final pct = total > 0 ? e.amount / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              e.isPaid ? Icons.check_circle : Icons.pending,
              size: 14,
              color: e.isPaid
                  ? const Color(0xFF10B981)
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(e.name,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            Text('${_fmt.format(e.amount)} (${(pct * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0, 1),
            minHeight: 6,
            color: e.isPaid
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown(
      {required this.byCategory, required this.total});
  final Map<String, double> byCategory;
  final double total;

  static const _palette = <Color>[
    Color(0xFF6D5CFF),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFF8B5CF6),
    Color(0xFFF97316),
    Color(0xFF06B6D4),
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: PieChart(PieChartData(
                sections: [
                  for (var i = 0; i < sorted.length; i++)
                    PieChartSectionData(
                      value: sorted[i].value,
                      color: _palette[i % _palette.length],
                      radius: 24,
                      title: '',
                    ),
                ],
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              )),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < sorted.length && i < 8; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: _palette[i % _palette.length],
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(sorted[i].key,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    '${_fmt.format(sorted[i].value)} (${total > 0 ? (sorted[i].value / total * 100).toStringAsFixed(0) : 0}%)',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DailySpendingChart extends StatelessWidget {
  const _DailySpendingChart({
    required this.dailySpending,
    required this.dailyBudget,
  });
  final Map<int, double> dailySpending;
  final double dailyBudget;

  @override
  Widget build(BuildContext context) {
    final maxDay =
        dailySpending.keys.fold<int>(0, (m, d) => d > m ? d : m);
    final maxVal =
        dailySpending.values.fold<double>(0, (m, v) => v > m ? v : m);
    final cap = math.max(maxVal, dailyBudget) * 1.2;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 160,
          child: BarChart(BarChartData(
            maxY: cap > 0 ? cap : 100,
            barGroups: [
              for (var d = 1; d <= maxDay; d++)
                BarChartGroupData(x: d, barRods: [
                  BarChartRodData(
                    toY: dailySpending[d] ?? 0,
                    width: 8,
                    color: (dailySpending[d] ?? 0) > dailyBudget &&
                            dailyBudget > 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ]),
            ],
            extraLinesData: dailyBudget > 0
                ? ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: dailyBudget,
                      color: const Color(0xFF10B981),
                      strokeWidth: 2,
                      dashArray: [5, 3],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        labelResolver: (_) =>
                            'бюджет ${_fmtShort.format(dailyBudget)}/день',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF10B981)),
                      ),
                    ),
                  ])
                : null,
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, _) {
                    if (v.toInt() % 5 == 0 || v.toInt() == 1) {
                      return Text('${v.toInt()}',
                          style: const TextStyle(fontSize: 10));
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
          )),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cycle card with progress ring
// ─────────────────────────────────────────────────────────────────────────────

class _CycleCard extends StatelessWidget {
  const _CycleCard({required this.cycle});
  final BudgetCycle cycle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daysProgress = cycle.totalDays > 0
        ? ((cycle.totalDays - cycle.daysLeft) / cycle.totalDays)
            .clamp(0.0, 1.0)
        : 0.0;
    final spentProgress = cycle.remainingAfterExpenses > 0
        ? (cycle.actualSpent / cycle.remainingAfterExpenses).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(cycle.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${cycle.daysLeft} дн. осталось',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Two progress rings
            Row(
              children: [
                _ProgressRing(
                  progress: daysProgress,
                  color: scheme.primary,
                  label: 'Время',
                  value:
                      '${((daysProgress * 100).toStringAsFixed(0))}%',
                  size: 56,
                ),
                const SizedBox(width: 12),
                _ProgressRing(
                  progress: spentProgress,
                  color: spentProgress > 0.8
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFF59E0B),
                  label: 'Расход',
                  value:
                      '${((spentProgress * 100).toStringAsFixed(0))}%',
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BudgetTile(
                          label: 'В день',
                          value:
                              '${_fmt.format(cycle.dailyBudget)} BYN',
                          color: const Color(0xFF10B981)),
                      const SizedBox(height: 4),
                      _BudgetTile(
                          label: 'В неделю',
                          value:
                              '${_fmt.format(cycle.weeklyBudget)} BYN',
                          color: const Color(0xFF3B82F6)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Details grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withAlpha(60),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  if (cycle.useAccountBase)
                    _detailRow('Баланс счёта',
                        _fmt.format(cycle.accountBalance),
                        const Color(0xFF6D5CFF)),
                  if (cycle.useAccountBase && cycle.receivedIncome > 0)
                    _detailRow(
                        'Получено (в балансе)',
                        _fmt.format(cycle.receivedIncome),
                        const Color(0xFF22C55E)),
                  if (cycle.useAccountBase && cycle.pendingIncome > 0)
                    _detailRow(
                        'Ожидаемый доход',
                        '+ ${_fmt.format(cycle.pendingIncome)}',
                        const Color(0xFF10B981)),
                  if (!cycle.useAccountBase)
                    _detailRow('Доход', _fmt.format(cycle.totalIncome),
                        const Color(0xFF10B981)),
                  _detailRow(
                      'Неоплач. расходы',
                      '- ${_fmt.format(cycle.totalPlannedExpenses)}',
                      const Color(0xFFF59E0B)),
                  const Divider(height: 8),
                  _detailRow('Свободно', _fmt.format(cycle.remainingBudget),
                      cycle.remainingBudget >= 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444)),
                  if (cycle.fullWeeks > 0)
                    _detailRow(
                        'Период',
                        '${cycle.fullWeeks} нед.${cycle.extraDays > 0 ? " + ${cycle.extraDays} дн." : ""}',
                        scheme.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.progress,
    required this.color,
    required this.label,
    required this.value,
    required this.size,
  });
  final double progress;
  final Color color;
  final String label;
  final String value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ProgressRingPainter(
              progress: progress,
              color: color,
              trackColor: color.withAlpha(30),
            ),
            child: Center(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });
  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress || old.color != color;
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 3, height: 20, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ],
        ),
      ],
    );
  }
}
