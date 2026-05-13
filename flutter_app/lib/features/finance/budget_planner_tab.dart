import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/budget_planner.dart';
import '../../services/budget_planner_calc.dart';
import '../../state/budget_planner_state.dart';

const _uuid = Uuid();
final _fmt = NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);

const _typeLabels = <IncomeSourceType, String>{
  IncomeSourceType.salary: 'Зарплата',
  IncomeSourceType.advance: 'Аванс',
  IncomeSourceType.additional: 'Доп. доход',
};

enum _Section { income, expenses, fact }

class BudgetPlannerTab extends ConsumerStatefulWidget {
  const BudgetPlannerTab({super.key});

  @override
  ConsumerState<BudgetPlannerTab> createState() => _BudgetPlannerTabState();
}

class _BudgetPlannerTabState extends ConsumerState<BudgetPlannerTab> {
  _Section _section = _Section.fact;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(budgetPlannerProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Section tabs
        _SectionTabs(
          current: _section,
          onChanged: (s) => setState(() => _section = s),
        ),
        const SizedBox(height: 16),
        if (_section == _Section.income) _IncomeSection(config: config),
        if (_section == _Section.expenses) _ExpenseSection(config: config),
        if (_section == _Section.fact) _FactSection(config: config),
      ],
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
          _tab(Icons.wallet_outlined, 'Доходы', _Section.income, scheme),
          _tab(Icons.receipt_long_outlined, 'Расходы', _Section.expenses, scheme),
          _tab(Icons.bar_chart_outlined, 'Факт', _Section.fact, scheme),
        ],
      ),
    );
  }

  Widget _tab(IconData icon, String label, _Section section, ColorScheme scheme) {
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
              Icon(icon, size: 16, color: selected ? scheme.onPrimary : scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ПЛАН ДОХОДОВ
// ─────────────────────────────────────────────────────────────────────────────

class _IncomeSection extends ConsumerStatefulWidget {
  const _IncomeSection({required this.config});
  final BudgetPlanConfig config;

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
      ctrl.updateIncomeSource(_editingId!, (s) => s.copyWith(
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
    final total = sources.where((s) => s.isActive).fold<double>(0, (s, e) => s + e.amount);
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary card
        _SummaryCard(
          title: 'Общий доход',
          value: '${_fmt.format(total)} BYN',
          icon: Icons.trending_up,
          color: const Color(0xFF10B981),
        ),
        const SizedBox(height: 12),

        // List
        for (final s in sources) ...[
          _IncomeCard(
            source: s,
            payDate: s.dayOfMonth != null
                ? getPayDate(s, now.year, now.month)
                : null,
            onEdit: () => _editSource(s),
            onDelete: () => ref.read(budgetPlannerProvider.notifier).deleteIncomeSource(s.id),
          ),
          const SizedBox(height: 8),
        ],

        // Add button / form
        if (_showForm)
          _buildForm(scheme)
        else
          _AddButton(
            label: 'Добавить источник дохода',
            onTap: () => setState(() => _showForm = true),
          ),
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
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<IncomeSourceType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Тип', isDense: true),
              items: IncomeSourceType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabels[t]!)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(labelText: 'Название', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Сумма (BYN)', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dayCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'День месяца (1–31)',
                hintText: 'Напр. 15',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              title: const Text('Учитывать праздники/выходные', style: TextStyle(fontSize: 13)),
              value: _adjustHolidays,
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _adjustHolidays = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(_editingId != null ? 'Сохранить' : 'Добавить'),
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
    final dateStr = payDate != null
        ? DateFormat('d MMMM', 'ru').format(payDate!)
        : 'без даты';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF10B981).withAlpha(30),
          child: Icon(
            source.type == IncomeSourceType.salary
                ? Icons.account_balance
                : source.type == IncomeSourceType.advance
                    ? Icons.payments
                    : Icons.add_circle_outline,
            color: const Color(0xFF10B981),
            size: 20,
          ),
        ),
        title: Text(source.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${_typeLabels[source.type]} · $dateStr',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_fmt.format(source.amount)} BYN',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// ПЛАН РАСХОДОВ
// ─────────────────────────────────────────────────────────────────────────────

class _ExpenseSection extends ConsumerStatefulWidget {
  const _ExpenseSection({required this.config});
  final BudgetPlanConfig config;

  @override
  ConsumerState<_ExpenseSection> createState() => _ExpenseSectionState();
}

class _ExpenseSectionState extends ConsumerState<_ExpenseSection> {
  bool _showForm = false;
  String? _editingId;
  final _nameCtl = TextEditingController();
  final _amountCtl = TextEditingController();
  final _dayFromCtl = TextEditingController();
  final _dayToCtl = TextEditingController();

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

  void _submit() {
    final name = _nameCtl.text.trim();
    final amount = double.tryParse(_amountCtl.text) ?? 0;
    final dayFrom = int.tryParse(_dayFromCtl.text) ?? 1;
    final dayTo = int.tryParse(_dayToCtl.text) ?? 31;
    if (name.isEmpty || amount <= 0) return;
    final ctrl = ref.read(budgetPlannerProvider.notifier);

    if (_editingId != null) {
      ctrl.updatePlannedExpense(_editingId!, (e) => e.copyWith(
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

  @override
  void dispose() {
    _nameCtl.dispose();
    _amountCtl.dispose();
    _dayFromCtl.dispose();
    _dayToCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenses = widget.config.plannedExpenses;
    final total = expenses.where((e) => e.isActive).fold<double>(0, (s, e) => s + e.amount);
    final paidTotal = expenses.where((e) => e.isPaid).fold<double>(0, (s, e) => s + (e.paidAmount ?? e.amount));
    final paidCount = expenses.where((e) => e.isPaid).length;
    final scheme = Theme.of(context).colorScheme;
    final progress = expenses.isEmpty ? 0.0 : paidCount / expenses.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary
        _SummaryCard(
          title: 'Плановые расходы',
          value: '${_fmt.format(total)} BYN',
          icon: Icons.trending_down,
          color: const Color(0xFFEF4444),
        ),
        const SizedBox(height: 8),

        // Progress bar
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Оплачено: $paidCount из ${expenses.length}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${_fmt.format(paidTotal)} BYN',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% выполнено',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // List
        for (final e in expenses) ...[
          _ExpenseCard(
            expense: e,
            onEdit: () => _editExpense(e),
            onDelete: () => ref.read(budgetPlannerProvider.notifier).deletePlannedExpense(e.id),
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

        // Add form
        if (_showForm)
          _buildForm(scheme)
        else
          _AddButton(
            label: 'Добавить плановый расход',
            onTap: () => setState(() => _showForm = true),
          ),
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
              _editingId != null ? 'Редактировать расход' : 'Новый плановый расход',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(labelText: 'Название', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Сумма (BYN)', isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dayFromCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'С дня', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _dayToCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'По день', isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(_editingId != null ? 'Сохранить' : 'Добавить'),
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
              color: expense.isPaid ? const Color(0xFF10B981) : scheme.onSurfaceVariant,
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
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// ФАКТ
// ─────────────────────────────────────────────────────────────────────────────

class _FactSection extends ConsumerStatefulWidget {
  const _FactSection({required this.config});
  final BudgetPlanConfig config;

  @override
  ConsumerState<_FactSection> createState() => _FactSectionState();
}

class _FactSectionState extends ConsumerState<_FactSection> {
  bool _showActualForm = false;
  final _actNameCtl = TextEditingController();
  final _actAmountCtl = TextEditingController();

  @override
  void dispose() {
    _actNameCtl.dispose();
    _actAmountCtl.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    final config = widget.config;
    final cycles = computeBudgetCycles(
      incomeSources: config.incomeSources,
      plannedExpenses: config.plannedExpenses,
      actualExpenses: config.actualExpenses,
    );
    final scheme = Theme.of(context).colorScheme;

    final totalIncome =
        config.incomeSources.where((s) => s.isActive).fold<double>(0, (s, e) => s + e.amount);
    final totalPlanned =
        config.plannedExpenses.where((e) => e.isActive).fold<double>(0, (s, e) => s + e.amount);
    final totalActual =
        config.actualExpenses.fold<double>(0, (s, e) => s + e.amount);
    final remaining = totalIncome - totalPlanned - totalActual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary cards row
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                label: 'Доход',
                value: _fmt.format(totalIncome),
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniCard(
                label: 'План расходов',
                value: _fmt.format(totalPlanned),
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                label: 'Факт. расходы',
                value: _fmt.format(totalActual),
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniCard(
                label: 'Остаток',
                value: _fmt.format(remaining),
                color: remaining >= 0 ? const Color(0xFF6366F1) : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Donut chart
        if (totalIncome > 0) ...[
          _DonutChart(
            totalIncome: totalIncome,
            totalPlanned: totalPlanned,
            totalActual: totalActual,
            remaining: remaining,
          ),
          const SizedBox(height: 16),
        ],

        // Budget cycles
        if (cycles.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 32, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(
                    'Добавьте источники дохода для расчёта бюджета',
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

        // Actual expenses
        if (config.actualExpenses.isNotEmpty) ...[
          const Text('Фактические расходы',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          for (final e in config.actualExpenses) ...[
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                dense: true,
                title: Text(e.name, style: const TextStyle(fontSize: 13)),
                subtitle: Text(e.date, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('-${_fmt.format(e.amount)} BYN',
                        style: const TextStyle(
                            color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () =>
                          ref.read(budgetPlannerProvider.notifier).deleteActualExpense(e.id),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 12),
        ],

        // Add actual expense
        if (_showActualForm)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Новый фактический расход',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _actNameCtl,
                    decoration: const InputDecoration(labelText: 'Название', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _actAmountCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Сумма (BYN)', isDense: true),
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
                        onPressed: () => setState(() => _showActualForm = false),
                        child: const Text('Отмена'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          _AddButton(
            label: 'Добавить фактический расход',
            onTap: () => setState(() => _showActualForm = true),
          ),
      ],
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
        ? ((cycle.totalDays - cycle.daysLeft) / cycle.totalDays).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(cycle.label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${cycle.daysLeft} дн.',
                    style: TextStyle(
                        color: scheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat('d MMM', 'ru').format(cycle.startDate)} → ${DateFormat('d MMM', 'ru').format(cycle.endDate)}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Progress ring + stats
            Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(
                    painter: _ProgressRingPainter(
                      progress: daysProgress,
                      color: scheme.primary,
                      bgColor: scheme.surfaceContainerHighest,
                    ),
                    child: Center(
                      child: Text(
                        '${(daysProgress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatRow('Доход', '${_fmt.format(cycle.totalIncome)} BYN',
                          const Color(0xFF10B981)),
                      _StatRow('Расходы (план)', '${_fmt.format(cycle.totalPlannedExpenses)} BYN',
                          const Color(0xFFF59E0B)),
                      _StatRow('Остаток', '${_fmt.format(cycle.remainingBudget)} BYN',
                          const Color(0xFF6366F1)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Daily / Weekly
            Row(
              children: [
                Expanded(
                  child: _BudgetTile(
                    icon: Icons.today,
                    label: 'В день',
                    value: '${_fmt.format(cycle.dailyBudget)} BYN',
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BudgetTile(
                    icon: Icons.date_range,
                    label: 'В неделю',
                    value: '${_fmt.format(cycle.weeklyBudget)} BYN',
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${cycle.fullWeeks} полных нед. + ${cycle.extraDays} дн.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Donut chart
// ─────────────────────────────────────────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.totalIncome,
    required this.totalPlanned,
    required this.totalActual,
    required this.remaining,
  });
  final double totalIncome;
  final double totalPlanned;
  final double totalActual;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[
      PieChartSectionData(
        value: totalPlanned.clamp(0, totalIncome),
        color: const Color(0xFFF59E0B),
        title: '',
        radius: 22,
      ),
      PieChartSectionData(
        value: totalActual.clamp(0, totalIncome),
        color: const Color(0xFFEF4444),
        title: '',
        radius: 22,
      ),
      PieChartSectionData(
        value: remaining.clamp(0, totalIncome),
        color: const Color(0xFF10B981),
        title: '',
        radius: 22,
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Распределение бюджета',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Legend(color: const Color(0xFFF59E0B), label: 'План'),
                _Legend(color: const Color(0xFFEF4444), label: 'Факт'),
                _Legend(color: const Color(0xFF10B981), label: 'Остаток'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(25),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text('$value BYN',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
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
          border: Border.all(color: scheme.outline.withAlpha(60), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress ring painter
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  final double progress;
  final Color color;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const strokeWidth = 6.0;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = bgColor,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress || old.color != color;
}
