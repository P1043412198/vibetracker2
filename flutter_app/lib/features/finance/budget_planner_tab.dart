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
    // automatically (unified ecosystem — see budget_planner_calc.dart).
    final loanExpenses = loansAsPlannedExpenses(
      loans: loans,
      convert: convert,
      baseCurrency: baseCurrency,
      monthKey: store.selectedMonthKey,
      loanPayments: loanPayments,
    );

    final cycles = computeBudgetCycles(
      incomeSources: config.incomeSources,
      plannedExpenses: config.plannedExpenses,
      actualExpenses: config.actualExpenses,
      transactions: transactions,
      accounts: accounts,
      loans: loans,
      loanPayments: loanPayments,
      convert: convert,
      baseCurrency: baseCurrency,
      accountBalance: facts.accountBalance,
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
          ),
        if (_section == _Section.income)
          _IncomeSection(config: config, facts: facts),
        if (_section == _Section.expenses)
          _ExpenseSection(
            config: config,
            facts: facts,
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
  });
  final String monthKey;
  final bool hasMonthData;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onRollover;

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
  });

  final BudgetPlanConfig config;
  final BudgetFacts facts;
  final List<BudgetCycle> cycles;
  final List<Account> accounts;
  final String baseCurrency;
  final List<PlannedExpense> loanExpenses;

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

    return Card(
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
  const _ExpenseSection({required this.config, required this.facts});
  final BudgetPlanConfig config;
  final BudgetFacts facts;

  @override
  ConsumerState<_ExpenseSection> createState() => _ExpenseSectionState();
}

class _ExpenseSectionState extends ConsumerState<_ExpenseSection> {
  bool _showForm = false;
  bool _showActualForm = false;
  String? _editingId;
  final _nameCtl = TextEditingController();
  final _amountCtl = TextEditingController();
  final _dayFromCtl = TextEditingController();
  final _dayToCtl = TextEditingController();
  final _actNameCtl = TextEditingController();
  final _actAmountCtl = TextEditingController();

  void _resetForm() {
    _nameCtl.clear();
    _amountCtl.clear();
    _dayFromCtl.clear();
    _dayToCtl.clear();
    _editingId = null;
    _showForm = false;
  }

  void _editExpense(PlannedExpense e) {
    _nameCtl.text = e.name;
    _amountCtl.text = e.amount.toStringAsFixed(0);
    _dayFromCtl.text = e.dayFrom.toString();
    _dayToCtl.text = e.dayTo.toString();
    _editingId = e.id;
    setState(() => _showForm = true);
  }

  void _submitPlanned() {
    final name = _nameCtl.text.trim();
    final amount = double.tryParse(_amountCtl.text) ?? 0;
    if (name.isEmpty || amount <= 0) return;
    final dayFrom = int.tryParse(_dayFromCtl.text) ?? 1;
    final dayTo = int.tryParse(_dayToCtl.text) ?? 31;
    final ctrl = ref.read(budgetPlannerProvider.notifier);

    if (_editingId != null) {
      ctrl.updatePlannedExpense(
          _editingId!,
          (e) => e.copyWith(
                name: name,
                amount: amount,
                dayFrom: dayFrom,
                dayTo: dayTo,
              ));
    } else {
      ctrl.addPlannedExpense(PlannedExpense(
        id: _uuid.v4(),
        name: name,
        amount: amount,
        dayFrom: dayFrom,
        dayTo: dayTo,
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
    final paidTotal = expenses
        .where((e) => e.isPaid)
        .fold<double>(0, (s, e) => s + (e.paidAmount ?? e.amount));
    final scheme = Theme.of(context).colorScheme;
    final manualActual =
        widget.config.actualExpenses.fold<double>(0, (s, e) => s + e.amount);
    final allActual = widget.facts.monthExpense + manualActual;

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
  });
  final PlannedExpense expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePaid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: GestureDetector(
          onTap: onTogglePaid,
          child: CircleAvatar(
            backgroundColor: expense.isPaid
                ? const Color(0xFF10B981).withAlpha(30)
                : scheme.surfaceContainerHighest,
            child: Icon(
              expense.isPaid ? Icons.check_circle : Icons.circle_outlined,
              color: expense.isPaid
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
            decoration: expense.isPaid ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${expense.dayFrom}–${expense.dayTo} числа',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ██████  SHARED WIDGETS  ██████
// ═════════════════════════════════════════════════════════════════════════════

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
