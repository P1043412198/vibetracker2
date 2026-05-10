import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/finance.dart';
import '../../models/financial_plan_month.dart';
import '../../state/providers.dart';
import 'financial_plan_helpers.dart';

/// Detail page for a single [FinancialPlanMonth]. Shows the scenario picker,
/// the roadmap progress strip, and the editable list of sections.
class FinancialPlanMonthPage extends ConsumerWidget {
  const FinancialPlanMonthPage({super.key, required this.id});

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
        appBar: AppBar(title: const Text('План месяца')),
        body: const Center(child: Text('План не найден')),
      );
    }
    final transactions = ref.watch(transactionsProvider);
    final activeScenario = plan.scenarios.firstWhere(
      (s) => s.id == plan.activeScenarioId,
      orElse: () => plan.scenarios.first,
    );
    final summary =
        computeSummary(activeScenario, transactions, plan.monthKey);
    final fact = factForMonth(transactions, plan.monthKey);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          plan.title.isEmpty ? humanMonth(plan.monthKey) : plan.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Сравнить сценарии',
            icon: const Icon(Icons.compare_arrows),
            onPressed: plan.scenarios.length < 2
                ? null
                : () => context.push('/financial-plan/compare/${plan.id}'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _onAction(context, ref, plan, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Переименовать')),
              PopupMenuItem(value: 'change-month', child: Text('Сменить месяц')),
              PopupMenuItem(value: 'delete', child: Text('Удалить план')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          _RoadmapCard(plan: plan, summary: summary, fact: fact),
          const SizedBox(height: 12),
          _ScenarioStrip(plan: plan),
          const SizedBox(height: 12),
          if (activeScenario.sections.isEmpty)
            _EmptySectionsCard(
              onAddSection: () => _addSection(
                context,
                ref,
                plan,
                activeScenario,
              ),
            )
          else
            for (final section in activeScenario.sections)
              _SectionCard(
                plan: plan,
                scenario: activeScenario,
                section: section,
                transactions: transactions,
              ),
          const SizedBox(height: 12),
          _AddSectionButton(
            onPressed: () => _addSection(context, ref, plan, activeScenario),
          ),
        ],
      ),
    );
  }

  void _onAction(
    BuildContext context,
    WidgetRef ref,
    FinancialPlanMonth plan,
    String action,
  ) async {
    switch (action) {
      case 'rename':
        final controller = TextEditingController(text: plan.title);
        final newTitle = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Название плана'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Например: «Май — отпуск»',
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        );
        if (newTitle == null) return;
        await ref.read(financialPlanMonthsProvider.notifier).update(
              plan.id,
              (p) => p.copyWith(
                title: newTitle,
                updatedAt: DateTime.now().toIso8601String(),
              ),
            );
        break;
      case 'change-month':
        final picked = await showDatePicker(
          context: context,
          initialDate: parseMonthKey(plan.monthKey) ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(DateTime.now().year + 5, 12, 31),
          helpText: 'Выбери новый месяц',
        );
        if (picked == null) return;
        await ref.read(financialPlanMonthsProvider.notifier).update(
              plan.id,
              (p) => p.copyWith(
                monthKey: monthKeyForDate(picked),
                updatedAt: DateTime.now().toIso8601String(),
              ),
            );
        break;
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить план?'),
            content: Text('План «${humanMonth(plan.monthKey)}» будет удалён.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await ref
              .read(financialPlanMonthsProvider.notifier)
              .remove(plan.id);
          if (context.mounted) Navigator.of(context).pop();
        }
        break;
    }
  }

  Future<void> _addSection(
    BuildContext context,
    WidgetRef ref,
    FinancialPlanMonth plan,
    FinPlanScenario scenario,
  ) async {
    final result = await _showSectionEditor(context);
    if (result == null) return;
    final next = FinPlanSection(
      id: const Uuid().v4(),
      title: result.title,
      kind: result.kind,
      icon: result.icon,
      color: result.color,
      items: const [],
    );
    await _replaceScenario(
      ref,
      plan,
      scenario.copyWith(sections: [...scenario.sections, next]),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({
    required this.plan,
    required this.summary,
    required this.fact,
  });

  final FinancialPlanMonth plan;
  final FinPlanSummary summary;
  final MonthFact fact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = monthProgress(DateTime.now(), plan.monthKey);
    final start = parseMonthKey(plan.monthKey);
    final daysInMonth = start == null
        ? 30
        : DateTime(start.year, start.month + 1, 0).day;
    final dayOfMonth = (progress * daysInMonth).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Roadmap · ${humanMonth(plan.monthKey)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  'день $dayOfMonth/$daysInMonth',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(
                  label: 'План доход',
                  value: summary.income,
                  color: const Color(0xFF22C55E),
                ),
                _Pill(
                  label: 'План расход',
                  value: summary.expense + summary.savings + summary.debt,
                  color: const Color(0xFFEF4444),
                ),
                _Pill(
                  label: 'Факт доход',
                  value: fact.income,
                  color: const Color(0xFF16A34A),
                  outlined: true,
                ),
                _Pill(
                  label: 'Факт расход',
                  value: fact.expense,
                  color: const Color(0xFFDC2626),
                  outlined: true,
                ),
                _Pill(
                  label: 'Остаток (план)',
                  value: summary.balance,
                  color: summary.balance >= 0
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFEF4444),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.value,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final double value;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: outlined ? null : color.withValues(alpha: 0.10),
        border: outlined ? Border.all(color: color.withValues(alpha: 0.6)) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label · ',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            NumberFormat.currency(locale: 'ru', symbol: '', decimalDigits: 0)
                .format(value),
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioStrip extends ConsumerWidget {
  const _ScenarioStrip({required this.plan});

  final FinancialPlanMonth plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in plan.scenarios)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: GestureDetector(
                          onLongPress: () =>
                              _onScenarioMenu(context, ref, s),
                          child: ChoiceChip(
                            selected: s.id == plan.activeScenarioId,
                            selectedColor:
                                Color(s.color).withValues(alpha: 0.2),
                            label: Text(s.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(s.color))),
                            onSelected: (_) => ref
                                .read(financialPlanMonthsProvider.notifier)
                                .update(
                                  plan.id,
                                  (p) => p.copyWith(
                                    activeScenarioId: s.id,
                                    updatedAt:
                                        DateTime.now().toIso8601String(),
                                  ),
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Сценарий: добавить',
              icon: const Icon(Icons.add),
              onPressed: () => _addScenario(context, ref),
            ),
            IconButton(
              tooltip: 'Сценарии: действия',
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                final active = plan.scenarios.firstWhere(
                  (s) => s.id == plan.activeScenarioId,
                  orElse: () => plan.scenarios.first,
                );
                _onScenarioMenu(context, ref, active);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addScenario(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый сценарий'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Например: «Эконом», «Идеал»'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final palette = [
      0xFF6D5CFF,
      0xFF22C55E,
      0xFFF59E0B,
      0xFFEC4899,
      0xFF14B8A6,
      0xFFEF4444,
    ];
    final color =
        palette[plan.scenarios.length % palette.length];
    final scenario = FinPlanScenario(
      id: const Uuid().v4(),
      name: name,
      color: color,
      sections: const [],
    );
    await ref.read(financialPlanMonthsProvider.notifier).update(
          plan.id,
          (p) => p.copyWith(
            scenarios: [...p.scenarios, scenario],
            activeScenarioId: scenario.id,
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
  }

  Future<void> _onScenarioMenu(
    BuildContext context,
    WidgetRef ref,
    FinPlanScenario scenario,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Переименовать'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Дублировать'),
              onTap: () => Navigator.pop(ctx, 'duplicate'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Удалить',
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    final notifier = ref.read(financialPlanMonthsProvider.notifier);
    if (action == 'rename') {
      if (!context.mounted) return;
      final controller = TextEditingController(text: scenario.name);
      final next = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Переименовать сценарий'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена')),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
      if (next == null || next.isEmpty) return;
      await notifier.update(
        plan.id,
        (p) => p.copyWith(
          scenarios: p.scenarios
              .map((s) => s.id == scenario.id
                  ? s.copyWith(name: next)
                  : s)
              .toList(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
    } else if (action == 'duplicate') {
      final clone = FinPlanScenario(
        id: const Uuid().v4(),
        name: '${scenario.name} (копия)',
        color: scenario.color,
        notes: scenario.notes,
        sections: scenario.sections
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
      );
      await notifier.update(
        plan.id,
        (p) => p.copyWith(
          scenarios: [...p.scenarios, clone],
          activeScenarioId: clone.id,
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
    } else if (action == 'delete') {
      if (plan.scenarios.length <= 1) return;
      final remaining =
          plan.scenarios.where((s) => s.id != scenario.id).toList();
      await notifier.update(
        plan.id,
        (p) => p.copyWith(
          scenarios: remaining,
          activeScenarioId: plan.activeScenarioId == scenario.id
              ? remaining.first.id
              : plan.activeScenarioId,
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
    }
  }
}

class _EmptySectionsCard extends StatelessWidget {
  const _EmptySectionsCard({required this.onAddSection});
  final VoidCallback onAddSection;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Создай свои секции',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Например: «Доход», «Жильё», «Еда», «Сбережения». '
              'Внутри секций добавляй конкретные статьи с суммами.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAddSection,
              icon: const Icon(Icons.add),
              label: const Text('Добавить секцию'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSectionButton extends StatelessWidget {
  const _AddSectionButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: const Text('Добавить секцию'),
      ),
    );
  }
}

class _SectionCard extends ConsumerWidget {
  const _SectionCard({
    required this.plan,
    required this.scenario,
    required this.section,
    required this.transactions,
  });

  final FinancialPlanMonth plan;
  final FinPlanScenario scenario;
  final FinPlanSection section;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(section.color ?? defaultColorForKind(section.kind));
    final total =
        section.items.fold<double>(0, (sum, it) => sum + it.amount);
    final fact = section.items.fold<double>(
      0,
      (sum, it) => sum + factForItem(it, transactions, plan.monthKey),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.18),
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                if (section.icon != null) ...[
                  Text(section.icon!, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        labelForSectionKind(section.kind),
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _SectionTotal(
                  total: total,
                  fact: fact,
                  color: color,
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => _onAction(context, ref, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Изменить')),
                    PopupMenuItem(value: 'delete', child: Text('Удалить')),
                  ],
                ),
              ],
            ),
          ),
          if (section.items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Text(
                'Пока пусто. Добавь первую статью →',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (final item in section.items)
              _ItemTile(
                plan: plan,
                scenario: scenario,
                section: section,
                item: item,
                transactions: transactions,
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _addItem(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Статья'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
    final res = await _showItemEditor(context);
    if (res == null) return;
    final item = FinPlanItem(
      id: const Uuid().v4(),
      label: res.label,
      amount: res.amount,
      currency: res.currency,
      day: res.day,
      recurring: res.recurring,
      linkedCategory: res.linkedCategory,
      notes: res.notes,
    );
    final updated = section.copyWith(items: [...section.items, item]);
    await _replaceSection(ref, plan, scenario, updated);
  }

  Future<void> _onAction(
      BuildContext context, WidgetRef ref, String action) async {
    if (action == 'edit') {
      final res = await _showSectionEditor(
        context,
        initialTitle: section.title,
        initialKind: section.kind,
        initialIcon: section.icon,
        initialColor: section.color,
      );
      if (res == null) return;
      final updated = section.copyWith(
        title: res.title,
        kind: res.kind,
        icon: res.icon,
        color: res.color,
        clearIcon: res.icon == null,
        clearColor: res.color == null,
      );
      await _replaceSection(ref, plan, scenario, updated);
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Удалить секцию?'),
          content: Text('«${section.title}» и все её статьи будут удалены.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить'),
            ),
          ],
        ),
      );
      if (ok == true) {
        final next = scenario.sections
            .where((s) => s.id != section.id)
            .toList();
        await _replaceScenario(
          ref,
          plan,
          scenario.copyWith(sections: next),
        );
      }
    }
  }
}

class _SectionTotal extends StatelessWidget {
  const _SectionTotal({
    required this.total,
    required this.fact,
    required this.color,
  });

  final double total;
  final double fact;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: 'ru',
      symbol: '',
      decimalDigits: 0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          fmt.format(total),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        if (fact > 0)
          Text(
            'факт ${fmt.format(fact)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({
    required this.plan,
    required this.scenario,
    required this.section,
    required this.item,
    required this.transactions,
  });

  final FinancialPlanMonth plan;
  final FinPlanScenario scenario;
  final FinPlanSection section;
  final FinPlanItem item;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fact = factForItem(item, transactions, plan.monthKey);
    final fmt =
        NumberFormat.currency(locale: 'ru', symbol: '', decimalDigits: 0);
    return InkWell(
      onTap: () => _edit(context, ref),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: [
            if (item.day != null) ...[
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.day}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.linkedCategory != null ||
                      item.recurring ||
                      (item.notes?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (item.linkedCategory != null)
                          '#${item.linkedCategory}',
                        if (item.recurring) 'каждый месяц',
                        if (item.notes?.isNotEmpty ?? false) item.notes!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${fmt.format(item.amount)} ${item.currency}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (fact > 0)
                  Text(
                    'факт ${fmt.format(fact)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final next = section.items
                    .where((i) => i.id != item.id)
                    .toList();
                await _replaceSection(
                  ref,
                  plan,
                  scenario,
                  section.copyWith(items: next),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final res = await _showItemEditor(
      context,
      initial: item,
    );
    if (res == null) return;
    final next = section.items
        .map((i) => i.id == item.id
            ? i.copyWith(
                label: res.label,
                amount: res.amount,
                currency: res.currency,
                day: res.day,
                clearDay: res.day == null,
                recurring: res.recurring,
                linkedCategory: res.linkedCategory,
                clearLinkedCategory: res.linkedCategory == null,
                notes: res.notes,
                clearNotes: res.notes == null,
              )
            : i)
        .toList();
    await _replaceSection(ref, plan, scenario, section.copyWith(items: next));
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Future<void> _replaceSection(
  WidgetRef ref,
  FinancialPlanMonth plan,
  FinPlanScenario scenario,
  FinPlanSection updated,
) async {
  final next = scenario.sections
      .map((s) => s.id == updated.id ? updated : s)
      .toList();
  await _replaceScenario(ref, plan, scenario.copyWith(sections: next));
}

Future<void> _replaceScenario(
  WidgetRef ref,
  FinancialPlanMonth plan,
  FinPlanScenario updated,
) async {
  await ref.read(financialPlanMonthsProvider.notifier).update(
        plan.id,
        (p) => p.copyWith(
          scenarios: p.scenarios
              .map((s) => s.id == updated.id ? updated : s)
              .toList(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
}

class _SectionEditorResult {
  _SectionEditorResult({
    required this.title,
    required this.kind,
    required this.icon,
    required this.color,
  });
  final String title;
  final FinPlanSectionKind kind;
  final String? icon;
  final int? color;
}

const _sectionIcons = [
  '💼', '🏠', '🍔', '💰', '✈️', '📚', '🎁',
  '🚗', '💡', '🛍️', '⚽', '🎮', '🩺', '🐶',
];

Future<_SectionEditorResult?> _showSectionEditor(
  BuildContext context, {
  String? initialTitle,
  FinPlanSectionKind? initialKind,
  String? initialIcon,
  int? initialColor,
}) {
  final controller = TextEditingController(text: initialTitle ?? '');
  FinPlanSectionKind kind = initialKind ?? FinPlanSectionKind.expense;
  String? icon = initialIcon;
  int? color = initialColor;
  return showModalBottomSheet<_SectionEditorResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(initialTitle == null ? 'Новая секция' : 'Изменить секцию',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Название',
                  ),
                ),
                const SizedBox(height: 12),
                Text('Тип', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final k in FinPlanSectionKind.values)
                      ChoiceChip(
                        selected: k == kind,
                        label: Text(labelForSectionKind(k)),
                        onSelected: (_) => setState(() {
                          kind = k;
                          color ??= defaultColorForKind(k);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Иконка', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final ic in _sectionIcons)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() {
                          icon = icon == ic ? null : ic;
                        }),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: icon == ic
                                ? Theme.of(ctx)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.18)
                                : Theme.of(ctx)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(ic,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final t = controller.text.trim();
                    if (t.isEmpty) return;
                    Navigator.of(ctx).pop(_SectionEditorResult(
                      title: t,
                      kind: kind,
                      icon: icon,
                      color: color ?? defaultColorForKind(kind),
                    ));
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _ItemEditorResult {
  _ItemEditorResult({
    required this.label,
    required this.amount,
    required this.currency,
    this.day,
    this.recurring = false,
    this.linkedCategory,
    this.notes,
  });
  final String label;
  final double amount;
  final String currency;
  final int? day;
  final bool recurring;
  final String? linkedCategory;
  final String? notes;
}

Future<_ItemEditorResult?> _showItemEditor(
  BuildContext context, {
  FinPlanItem? initial,
}) {
  final label = TextEditingController(text: initial?.label ?? '');
  final amount = TextEditingController(
      text: initial == null ? '' : initial.amount.toStringAsFixed(2));
  final notes = TextEditingController(text: initial?.notes ?? '');
  final cat = TextEditingController(text: initial?.linkedCategory ?? '');
  String currency = initial?.currency ?? 'BYN';
  int? day = initial?.day;
  bool recurring = initial?.recurring ?? false;
  return showModalBottomSheet<_ItemEditorResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(initial == null ? 'Новая статья' : 'Изменить статью',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: label,
                    autofocus: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Название',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Сумма',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: currency,
                        items: const [
                          DropdownMenuItem(value: 'BYN', child: Text('BYN')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                          DropdownMenuItem(value: 'RUB', child: Text('RUB')),
                        ],
                        onChanged: (v) =>
                            setState(() => currency = v ?? currency),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showModalBottomSheet<int?>(
                              context: ctx,
                              builder: (sheetCtx) => SafeArea(
                                child: GridView.count(
                                  shrinkWrap: true,
                                  crossAxisCount: 7,
                                  padding: const EdgeInsets.all(12),
                                  children: [
                                    for (var d = 1; d <= 31; d++)
                                      InkWell(
                                        onTap: () =>
                                            Navigator.pop(sheetCtx, d),
                                        child: Container(
                                          margin: const EdgeInsets.all(4),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: day == d
                                                ? Theme.of(ctx)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.18)
                                                : Theme.of(ctx)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text('$d'),
                                        ),
                                      ),
                                    InkWell(
                                      onTap: () =>
                                          Navigator.pop(sheetCtx, -1),
                                      child: Container(
                                        margin: const EdgeInsets.all(4),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.close, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (picked == null) return;
                            setState(
                                () => day = picked == -1 ? null : picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'День месяца',
                            ),
                            child: Text(day == null ? '—' : 'каждый $day-го'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Повторять каждый месяц'),
                    value: recurring,
                    onChanged: (v) => setState(() => recurring = v),
                  ),
                  TextField(
                    controller: cat,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Категория транзакции (для факта)',
                      hintText: 'Например: Еда',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notes,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Заметка (необязательно)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      final t = label.text.trim();
                      final raw = amount.text.replaceAll(',', '.');
                      final v = double.tryParse(raw) ?? 0;
                      if (t.isEmpty) return;
                      Navigator.of(ctx).pop(_ItemEditorResult(
                        label: t,
                        amount: v,
                        currency: currency,
                        day: day,
                        recurring: recurring,
                        linkedCategory: cat.text.trim().isEmpty
                            ? null
                            : cat.text.trim(),
                        notes: notes.text.trim().isEmpty
                            ? null
                            : notes.text.trim(),
                      ));
                    },
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
