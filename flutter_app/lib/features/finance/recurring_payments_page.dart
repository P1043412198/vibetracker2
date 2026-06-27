import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../state/providers.dart';
import 'recurring_review_card.dart';

const _freqLabel = {
  RecurringFrequency.weekly: 'Еженедельно',
  RecurringFrequency.biweekly: 'Раз в 2 недели',
  RecurringFrequency.monthly: 'Ежемесячно',
  RecurringFrequency.yearly: 'Ежегодно',
};

const _weekdays = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
const _months = [
  'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
  'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'
];

/// Manage recurring income/expense rules and review their due occurrences.
class RecurringPaymentsPage extends ConsumerWidget {
  const RecurringPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(regularPaymentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Регулярные операции')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Правило'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const RecurringReviewCard(),
          if (rules.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Нет правил. Добавьте повторяющийся доход или расход — '
                  'он будет появляться на подтверждение в нужную дату.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          for (final r in rules) _RuleTile(rule: r),
        ],
      ),
    );
  }

  static Future<void> _openForm(BuildContext context, WidgetRef ref,
      {RegularPayment? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _RuleFormSheet(existing: existing),
    );
  }
}

class _RuleTile extends ConsumerWidget {
  const _RuleTile({required this.rule});
  final RegularPayment rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final isIncome = rule.type == TransactionType.income;
    final account = accounts.where((a) => a.id == rule.accountId).firstOrNull;
    final cur = rule.currency ?? account?.currency ?? 'BYN';

    String schedule;
    switch (rule.frequency) {
      case RecurringFrequency.weekly:
        schedule = 'кажд. ${_weekdays[(rule.weekday ?? 1) % 7]}';
        break;
      case RecurringFrequency.biweekly:
        schedule = 'раз в 2 недели';
        break;
      case RecurringFrequency.monthly:
        schedule = '${rule.dueDate} числа';
        break;
      case RecurringFrequency.yearly:
        schedule = '${rule.dueDate} ${_months[((rule.month ?? 1) - 1) % 12]}';
        break;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: ListTile(
        leading: Icon(
          isIncome ? Icons.south_west : Icons.north_east,
          color: isIncome ? Colors.green : Colors.redAccent,
        ),
        title: Row(
          children: [
            Expanded(child: Text(rule.name)),
            if (rule.autoConfirm)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.bolt, size: 16, color: Colors.amber),
              ),
            if (!rule.isActive)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('выкл', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        subtitle: Text(
          '${_freqLabel[rule.frequency]} · $schedule · ${rule.category}'
          '${account != null ? ' · ${account.name}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${isIncome ? '+' : '−'}${rule.amount.toStringAsFixed(2)} $cur',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  RecurringPaymentsPage._openForm(context, ref, existing: rule);
                } else if (v == 'toggle') {
                  ref.read(regularPaymentsProvider.notifier).update(
                      rule.id, (r) => r.copyWith(isActive: !r.isActive));
                } else if (v == 'delete') {
                  ref.read(regularPaymentsProvider.notifier).remove(rule.id);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Изменить')),
                PopupMenuItem(
                    value: 'toggle',
                    child: Text(rule.isActive ? 'Выключить' : 'Включить')),
                const PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleFormSheet extends ConsumerStatefulWidget {
  const _RuleFormSheet({this.existing});
  final RegularPayment? existing;

  @override
  ConsumerState<_RuleFormSheet> createState() => _RuleFormSheetState();
}

class _RuleFormSheetState extends ConsumerState<_RuleFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late TransactionType _type;
  late RecurringFrequency _freq;
  late int _day;
  late int _weekday;
  late int _month;
  late String _anchor;
  String? _accountId;
  late bool _autoConfirm;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _amount = TextEditingController(text: e?.amount.toString() ?? '');
    _type = e?.type ?? TransactionType.expense;
    _freq = e?.frequency ?? RecurringFrequency.monthly;
    _day = e?.dueDate ?? 1;
    _weekday = e?.weekday ?? 1;
    _month = e?.month ?? 1;
    _anchor = e?.anchorDate ??
        DateTime.now().toIso8601String().split('T').first;
    _accountId = e?.accountId;
    _autoConfirm = e?.autoConfirm ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final amount = num.tryParse(_amount.text.replaceAll(',', '.'));
    if (name.isEmpty || amount == null) return;

    final accounts = ref.read(accountsProvider);
    final accountId = _accountId ?? (accounts.isNotEmpty ? accounts.first.id : null);
    final notifier = ref.read(regularPaymentsProvider.notifier);

    if (widget.existing != null) {
      notifier.update(
        widget.existing!.id,
        (r) => r.copyWith(
          name: name,
          type: _type,
          amount: amount,
          dueDate: _day,
          frequency: _freq,
          weekday: _weekday,
          month: _month,
          anchorDate: _anchor,
          accountId: accountId,
          autoConfirm: _autoConfirm,
        ),
      );
    } else {
      notifier.add(RegularPayment(
        id: const Uuid().v4(),
        name: name,
        type: _type,
        amount: amount,
        dueDate: _day,
        frequency: _freq,
        weekday: _weekday,
        month: _month,
        anchorDate: _anchor,
        accountId: accountId,
        autoConfirm: _autoConfirm,
        category: _type == TransactionType.income ? 'Доход' : 'Подписки',
        isActive: true,
      ));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Новое правило' : 'Изменить правило',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                    value: TransactionType.expense, label: Text('Расход')),
                ButtonSegment(
                    value: TransactionType.income, label: Text('Доход')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Название', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Сумма', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurringFrequency>(
              value: _freq,
              decoration: const InputDecoration(
                  labelText: 'Периодичность', border: OutlineInputBorder()),
              items: [
                for (final f in RecurringFrequency.values)
                  DropdownMenuItem(value: f, child: Text(_freqLabel[f]!)),
              ],
              onChanged: (v) => setState(() => _freq = v ?? _freq),
            ),
            const SizedBox(height: 12),
            if (_freq == RecurringFrequency.monthly ||
                _freq == RecurringFrequency.yearly)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _day,
                      decoration: const InputDecoration(
                          labelText: 'День', border: OutlineInputBorder()),
                      items: [
                        for (var d = 1; d <= 31; d++)
                          DropdownMenuItem(value: d, child: Text('$d')),
                      ],
                      onChanged: (v) => setState(() => _day = v ?? _day),
                    ),
                  ),
                  if (_freq == RecurringFrequency.yearly) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _month,
                        decoration: const InputDecoration(
                            labelText: 'Месяц', border: OutlineInputBorder()),
                        items: [
                          for (var m = 1; m <= 12; m++)
                            DropdownMenuItem(
                                value: m, child: Text(_months[m - 1])),
                        ],
                        onChanged: (v) => setState(() => _month = v ?? _month),
                      ),
                    ),
                  ],
                ],
              ),
            if (_freq == RecurringFrequency.weekly)
              DropdownButtonFormField<int>(
                value: _weekday,
                decoration: const InputDecoration(
                    labelText: 'День недели', border: OutlineInputBorder()),
                items: [
                  for (var w = 0; w < 7; w++)
                    DropdownMenuItem(value: w, child: Text(_weekdays[w])),
                ],
                onChanged: (v) => setState(() => _weekday = v ?? _weekday),
              ),
            if (_freq == RecurringFrequency.biweekly)
              InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Первая дата', border: OutlineInputBorder()),
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(_anchor) ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _anchor =
                          picked.toIso8601String().split('T').first);
                    }
                  },
                  child: Text(_anchor),
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _accountId ??
                  (accounts.isNotEmpty ? accounts.first.id : null),
              decoration: const InputDecoration(
                  labelText: 'Счёт', border: OutlineInputBorder()),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoConfirm,
              onChanged: (v) => setState(() => _autoConfirm = v),
              title: const Text('Создавать автоматически'),
              subtitle: const Text('Без подтверждения в очереди'),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: const Text('Сохранить')),
          ],
        ),
      ),
    );
  }
}
