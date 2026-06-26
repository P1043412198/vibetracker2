import '../../widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/financial_plan_month.dart';
import '../../state/providers.dart';
import 'financial_plan_helpers.dart';
import 'widgets/finplan_charts.dart';

/// Brand-new flexible Financial Plan home page.
///
/// Replaces the old 18-section template. The page now lists every monthly
/// plan the user has created (newest first), highlights the current
/// real-world month and lets the user create a new month from scratch
/// (optionally cloning a previous month).
class FinancialPlanPage extends ConsumerStatefulWidget {
  const FinancialPlanPage({super.key});

  @override
  ConsumerState<FinancialPlanPage> createState() => _FinancialPlanPageState();
}

class _FinancialPlanPageState extends ConsumerState<FinancialPlanPage> {
  late int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final months = [...ref.watch(financialPlanMonthsProvider)]
      ..sort((a, b) => b.monthKey.compareTo(a.monthKey));
    final transactions = ref.watch(transactionsProvider);
    final nowKey = monthKeyForDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Финансовый план'),
      ),
      body: months.isEmpty
          ? _EmptyState(
              onCreate: () => _createMonth(context, ref, copyFromId: null))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                YearOverviewCard(
                  transactions: transactions,
                  plans: months,
                  year: _year,
                  onYearChanged: (y) => setState(() => _year = y),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < months.length; i++) ...[
                  _MonthTile(
                    month: months[i],
                    isCurrent: months[i].monthKey == nowKey,
                    onCopy: () => _createMonth(
                      context,
                      ref,
                      copyFromId: months[i].id,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 280.ms, delay: (60 * i).ms)
                      .slideY(begin: 0.08, end: 0),
                  if (i != months.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createMonth(context, ref, copyFromId: null),
        icon: const Icon(Icons.add),
        label: const Text('Новый месяц'),
      ),
    );
  }

  Future<void> _createMonth(
    BuildContext context,
    WidgetRef ref, {
    required String? copyFromId,
  }) async {
    final result = await showModalBottomSheet<_NewMonthResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => _NewMonthSheet(
        existing: ref.read(financialPlanMonthsProvider),
        suggestion: nextEmptyMonthKey(ref.read(financialPlanMonthsProvider)),
      ),
    );
    if (result == null) return;

    final source = copyFromId != null
        ? ref
            .read(financialPlanMonthsProvider)
            .firstWhere((m) => m.id == copyFromId)
        : null;

    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final scenarios = source != null
        ? source.scenarios
            .map((s) => FinPlanScenario(
                  id: const Uuid().v4(),
                  name: s.name,
                  color: s.color,
                  notes: s.notes,
                  sections: s.sections
                      .map((sec) => FinPlanSection(
                            id: const Uuid().v4(),
                            title: sec.title,
                            kind: sec.kind,
                            icon: sec.icon,
                            color: sec.color,
                            notes: sec.notes,
                            items: sec.items
                                .map((it) => FinPlanItem(
                                      id: const Uuid().v4(),
                                      label: it.label,
                                      amount: it.amount,
                                      currency: it.currency,
                                      day: it.day,
                                      recurring: it.recurring,
                                      linkedCategory: it.linkedCategory,
                                      linkedSphereId: it.linkedSphereId,
                                      linkedSphereCategoryId:
                                          it.linkedSphereCategoryId,
                                      notes: it.notes,
                                      done: false,
                                    ))
                                .toList(),
                          ))
                      .toList(),
                ))
            .toList()
        : [
            FinPlanScenario(
              id: const Uuid().v4(),
              name: 'Базовый',
              color: 0xFF6D5CFF,
              sections: const [],
            ),
          ];

    final plan = FinancialPlanMonth(
      id: id,
      monthKey: result.monthKey,
      title: result.title,
      scenarios: scenarios,
      activeScenarioId: scenarios.first.id,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(financialPlanMonthsProvider.notifier).add(plan);
    if (!context.mounted) return;
    context.push('/financial-plan/month/${plan.id}');
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('📊', style: TextStyle(fontSize: 44)),
            ),
            const SizedBox(height: 18),
            Text('Создай первый план',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Никаких готовых шаблонов. Создавай план на любой месяц '
              '— добавляй свои секции, свои статьи и сценарии «А/В/С». '
              'Сравнивай, копируй из прошлого, видь факт по транзакциям.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Создать план месяца'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthTile extends ConsumerWidget {
  const _MonthTile({
    required this.month,
    required this.isCurrent,
    required this.onCopy,
  });

  final FinancialPlanMonth month;
  final bool isCurrent;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final activeScenario = month.scenarios.firstWhere(
      (s) => s.id == month.activeScenarioId,
      orElse: () => month.scenarios.first,
    );
    final transactions = ref.watch(transactionsProvider);
    final summary = computeSummary(activeScenario, transactions, month.monthKey);
    final fact = factForMonth(transactions, month.monthKey);
    final color = Color(activeScenario.color);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/financial-plan/month/${month.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _shortMonth(month.monthKey),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                month.title.isEmpty
                                    ? humanMonth(month.monthKey)
                                    : month.title,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.primary
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'сейчас',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.primary),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${month.scenarios.length} сценари${_plural(month.scenarios.length)} · '
                          'активный: ${activeScenario.name}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'copy') {
                        onCopy();
                      } else if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Удалить план?'),
                            content: Text(
                                'План «${humanMonth(month.monthKey)}» будет удалён.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Отмена'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref
                              .read(financialPlanMonthsProvider.notifier)
                              .remove(month.id);
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'copy',
                          child: Text('Скопировать в новый месяц')),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricChip(
                      label: 'Доход',
                      value: summary.income,
                      fact: fact.income,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricChip(
                      label: 'Расход',
                      value: summary.expense,
                      fact: fact.expense,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricChip(
                      label: 'Сбережения',
                      value: summary.savings,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortMonth(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final monthNum = int.tryParse(parts[1]);
    if (monthNum == null) return monthKey;
    final names = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return names[(monthNum - 1).clamp(0, 11)];
  }

  String _plural(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'ев';
    if (mod10 == 1) return 'й';
    if (mod10 >= 2 && mod10 <= 4) return 'я';
    return 'ев';
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
    this.fact,
  });

  final String label;
  final double value;
  final Color color;

  /// Optional actual amount from real transactions for this month. When set a
  /// «факт N» subline is shown so the plan can be read against reality.
  final double? fact;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: 'ru',
      symbol: '',
      decimalDigits: 0,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              fmt.format(value),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          if (fact != null && fact! > 0) ...[
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'факт ${fmt.format(fact)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NewMonthResult {
  _NewMonthResult({required this.monthKey, required this.title});
  final String monthKey;
  final String title;
}

class _NewMonthSheet extends StatefulWidget {
  const _NewMonthSheet({required this.existing, required this.suggestion});

  final List<FinancialPlanMonth> existing;
  final String suggestion;

  @override
  State<_NewMonthSheet> createState() => _NewMonthSheetState();
}

class _NewMonthSheetState extends State<_NewMonthSheet> {
  late String _monthKey = widget.suggestion;
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taken = {for (final p in widget.existing) p.monthKey};
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Новый план месяца',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text('Месяц', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickMonth,
            child: InputDecorator(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, size: 18),
                  const SizedBox(width: 8),
                  Text(humanMonth(_monthKey)),
                  const Spacer(),
                  if (taken.contains(_monthKey))
                    const Text('уже создан',
                        style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Название (необязательно)',
              hintText: 'Например: «Май — отпуск»',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: taken.contains(_monthKey)
                ? null
                : () => Navigator.of(context).pop(_NewMonthResult(
                      monthKey: _monthKey,
                      title: _titleController.text.trim(),
                    )),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth() async {
    final initial = parseMonthKey(_monthKey) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 5),
      helpText: 'Выбери месяц плана',
      initialEntryMode: DatePickerEntryMode.calendar,
    );
    if (picked == null) return;
    setState(() => _monthKey = monthKeyForDate(picked));
  }
}
