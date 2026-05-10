import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/finance.dart';
import '../../services/finance_calc.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';
import 'loan_calculator_page.dart';

/// Phase 13: Кредиты — отслеживание остатка, графика погашения и эффекта
/// от досрочных платежей с учётом расходов.
class LoansPage extends ConsumerWidget {
  const LoansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loans = ref.watch(loansProvider);
    final accounts = ref.watch(accountsProvider);
    final defCur = ref.watch(defaultCurrencyProvider);
    final monthly = loans.fold<num>(
        0, (a, l) => a + (l.balance > 0 ? l.monthlyPayment : 0));
    final balanceTotal =
        loans.fold<num>(0, (a, l) => a + (l.balance > 0 ? l.balance : 0));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кредиты'),
        actions: [
          IconButton(
            tooltip: 'Калькулятор',
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LoanCalculatorPage(currency: defCur)));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _editLoan(context, ref, defaultCurrency: defCur),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (loans.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Нет активных кредитов',
                        style:
                            Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                        'Добавь свой кредит — приложение посчитает остаток, переплату и подскажет, насколько быстрее ты погасишь его, если докладывать сверху.'),
                  ],
                ),
              ),
            )
          else
            _SummaryCard(
              total: balanceTotal,
              monthly: monthly,
              currency: defCur,
              count: loans.length,
            ),
          const SizedBox(height: 12),
          for (final l in loans)
            _LoanCard(
              loan: l,
              accountName: l.accountId == null
                  ? null
                  : accounts
                      .cast<Account?>()
                      .firstWhere((a) => a?.id == l.accountId,
                          orElse: () => null)
                      ?.name,
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.monthly,
    required this.currency,
    required this.count,
  });
  final num total;
  final num monthly;
  final String currency;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.credit_score, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count активных',
                      style: Theme.of(context).textTheme.labelMedium),
                  Text('${_fmt(total)} $currency остатка',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                  Text('${_fmt(monthly)} $currency / мес.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanCard extends ConsumerWidget {
  const _LoanCard({required this.loan, this.accountName});
  final Loan loan;
  final String? accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = loan.principal == 0
        ? 0.0
        : (1.0 - (loan.balance / loan.principal)).clamp(0.0, 1.0);
    final months = _projectMonths(loan, extra: 0);
    final projection = projectLoan(loan);
    final fullProjection = projectLoanFromOrigination(loan);
    final payments = ref.watch(loanPaymentsProvider)
      .where((p) => p.loanId == loan.id)
      .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(loan.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Text('${(progress * 100).round()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editLoan(context, ref,
                      existing: loan, defaultCurrency: loan.currency),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Pill('Остаток',
                    '${_fmt(loan.balance)} ${loan.currency}'),
                _Pill('Платёж',
                    '${_fmt(loan.monthlyPayment)} ${loan.currency} / мес.'),
                _Pill('Ставка',
                    '${loan.annualRate.toStringAsFixed(1)} %'),
                _Pill('Осталось',
                    months == null ? '—' : '$months мес.'),
                if (loan.paymentDay != null)
                  _Pill('Дата платежа', '${loan.paymentDay} число'),
                if (accountName != null)
                  _Pill('Счёт', accountName!),
              ],
            ),
            const SizedBox(height: 12),
            if (fullProjection.totalPaid > 0)
              _PayoffSummary(loan: loan, full: fullProjection),
            if (projection.schedule.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: _AmortizationChart(
                  schedule: projection.schedule,
                  scheme: Theme.of(context).colorScheme,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showStrategy(context, ref, loan),
                    icon: const Icon(Icons.psychology_alt_outlined),
                    label: const Text('Совет'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        _addPayment(context, ref, loan),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Платёж'),
                  ),
                ),
              ],
            ),
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Последние платежи',
                  style: Theme.of(context).textTheme.labelMedium),
              for (final p in payments.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(_humanDate(p.date),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall)),
                      Text('${_fmt(p.amount)} ${loan.currency}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addPayment(
      BuildContext context, WidgetRef ref, Loan loan) async {
    final amountCtl =
        TextEditingController(text: loan.monthlyPayment.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Платёж по кредиту'),
        content: TextField(
          controller: amountCtl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: 'Сумма, ${loan.currency}',
              border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Записать')),
        ],
      ),
    );
    if (ok != true) return;
    final amt = num.tryParse(amountCtl.text.replaceAll(',', '.')) ?? 0;
    if (amt <= 0) return;
    final monthlyRate = loan.annualRate / 12 / 100;
    final interest = loan.balance * monthlyRate;
    final principal = (amt - interest).clamp(0, double.infinity);
    final newBalance = (loan.balance - principal).clamp(0, double.infinity);
    await ref.read(loanPaymentsProvider.notifier).add(LoanPayment(
          id: const Uuid().v4(),
          loanId: loan.id,
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          amount: amt,
          principalPart: principal,
          interestPart: interest,
        ));
    await ref
        .read(loansProvider.notifier)
        .upsert(loan.copyWith(balance: newBalance));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Зачислено ${amt.toStringAsFixed(2)} ${loan.currency} (${principal.toStringAsFixed(2)} в тело, ${interest.toStringAsFixed(2)} в проценты)')),
      );
    }
  }

  Future<void> _showStrategy(
      BuildContext context, WidgetRef ref, Loan loan) async {
    final txns = ref.read(transactionsProvider);
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));
    final spent30 = txns
        .where((t) =>
            t.type.name == 'expense' &&
            DateTime.tryParse(t.date)?.isAfter(monthAgo) == true)
        .fold<num>(0, (a, t) => a + t.amount);
    final monthsBase = _projectMonths(loan, extra: 0);
    final extras = const [50, 100, 200];
    final scenarios = <_PayoffScenario>[
      for (final e in extras)
        _PayoffScenario(
          extra: e,
          months: _projectMonths(loan, extra: e.toDouble()),
          base: monthsBase,
        ),
    ];
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Стратегия по «${loan.title}»',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'За 30 дней ты потратил ${spent30.toStringAsFixed(0)} ${loan.currency}. Платёж по кредиту — ${loan.monthlyPayment.toStringAsFixed(0)} ${loan.currency}.',
            ),
            const SizedBox(height: 12),
            Text('Что будет, если докладывать сверху:',
                style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final s in scenarios)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.trending_down),
                title: Text(
                    '+${s.extra} ${loan.currency} к платежу — закроется ${s.months ?? '—'} мес.'),
                subtitle: Text(s.months == null || s.base == null
                    ? '—'
                    : 'на ${s.base! - s.months!} мес. быстрее, переплата меньше'),
              ),
            const SizedBox(height: 12),
            Text('Совет под твои расходы',
                style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(_advice(loan, spent30)),
          ],
        ),
      ),
    );
  }

  String _advice(Loan loan, num spent30) {
    final share = spent30 == 0 ? 0 : loan.monthlyPayment / spent30;
    if (share >= 0.4) {
      return 'Платёж занимает >40% твоих расходов — это нагрузка. Сокращай категории «развлечения», «еда вне дома», «подписки» и направляй сэкономленное на досрочное гашение. Цель — снизить долю до 20–30%.';
    }
    if (share >= 0.2) {
      return 'Нагрузка средняя. Если есть свободные деньги в конце месяца — клади их в досрочное гашение, пока ставка ${loan.annualRate.toStringAsFixed(1)}% выше доходности депозита (обычно 10–13%).';
    }
    if (loan.annualRate >= 15) {
      return 'Ставка высокая (${loan.annualRate.toStringAsFixed(1)}%). Если у тебя есть подушка > 3 месячных расходов — гасить досрочно выгоднее, чем держать деньги на депозите.';
    }
    return 'Кредит под низкий процент — не торопись с досрочным гашением. Лучше копи финансовую подушку: 3–6 месячных расходов на отдельном счёте.';
  }

  String _humanDate(String iso) {
    final dt = DateTime.tryParse(iso);
    return dt == null ? iso : DateFormat.yMMMd('ru').format(dt);
  }
}

class _PayoffScenario {
  _PayoffScenario({required this.extra, required this.months, required this.base});
  final int extra;
  final int? months;
  final int? base;
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Returns null if the schedule never converges (rate too high vs payment).
int? _projectMonths(Loan loan, {required double extra}) {
  if (loan.balance <= 0) return 0;
  final rate = loan.annualRate / 12 / 100;
  final pay = loan.monthlyPayment + extra;
  if (rate <= 0) {
    if (pay <= 0) return null;
    return (loan.balance / pay).ceil();
  }
  // Annuity formula solved for n: n = -ln(1 - r*P/A) / ln(1+r)
  final ratio = rate * loan.balance / pay;
  if (ratio >= 1) return null; // payment doesn't even cover interest
  final n = -math.log(1 - ratio) / math.log(1 + rate);
  if (!n.isFinite) return null;
  return n.ceil();
}

String _fmt(num v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 2);

Future<void> _editLoan(
  BuildContext context,
  WidgetRef ref, {
  Loan? existing,
  required String defaultCurrency,
}) async {
  final titleCtl = TextEditingController(text: existing?.title ?? '');
  final principalCtl = TextEditingController(
      text: existing?.principal.toStringAsFixed(2) ?? '');
  final balanceCtl = TextEditingController(
      text: existing?.balance.toStringAsFixed(2) ?? '');
  final rateCtl = TextEditingController(
      text: existing?.annualRate.toStringAsFixed(2) ?? '');
  final paymentCtl = TextEditingController(
      text: existing?.monthlyPayment.toStringAsFixed(2) ?? '');
  final paymentDayCtl = TextEditingController(
      text: existing?.paymentDay == null
          ? ''
          : existing!.paymentDay.toString());
  final termMonthsCtl = TextEditingController(
      text: existing?.termMonths == null
          ? ''
          : existing!.termMonths.toString());
  final notesCtl = TextEditingController(text: existing?.notes ?? '');
  String currency = existing?.currency ?? defaultCurrency;
  String? accountId = existing?.accountId;
  String startDate =
      existing?.startDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx2, setState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 4,
            bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? 'Новый кредит' : 'Редактирование',
                    style: Theme.of(ctx2).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                    controller: titleCtl,
                    autofocus: existing == null,
                    decoration: const InputDecoration(
                        labelText: 'Название (например, Беларусбанк-потреб)')),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: principalCtl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Сумма кредита'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: balanceCtl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Текущий остаток'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: rateCtl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Ставка, % годовых'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: paymentCtl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Платёж/мес.'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: paymentDayCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'День платежа (1–31)',
                        helperText: 'для cashflow и графика месяца',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: termMonthsCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Срок, мес. (опц.)',
                        helperText: 'для прогноза итоговой суммы',
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: currency,
                  decoration: const InputDecoration(labelText: 'Валюта'),
                  items: const [
                    DropdownMenuItem(value: 'BYN', child: Text('BYN')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    DropdownMenuItem(value: 'RUB', child: Text('RUB')),
                  ],
                  onChanged: (v) =>
                      setState(() => currency = v ?? currency),
                ),
                const SizedBox(height: 8),
                Consumer(builder: (_, ref2, __) {
                  final accs = ref2.watch(accountsProvider);
                  return DropdownButtonFormField<String?>(
                    value: accountId,
                    decoration: const InputDecoration(
                        labelText: 'С какого счёта платишь'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Не указан')),
                      for (final a in accs)
                        DropdownMenuItem<String?>(
                            value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (v) => setState(() => accountId = v),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                    controller: notesCtl,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Заметки')),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final title = titleCtl.text.trim();
                        if (title.isEmpty) return;
                        final principal =
                            num.tryParse(principalCtl.text.replaceAll(',', '.')) ??
                                0;
                        final balance =
                            num.tryParse(balanceCtl.text.replaceAll(',', '.')) ??
                                principal;
                        final rate =
                            num.tryParse(rateCtl.text.replaceAll(',', '.')) ?? 0;
                        final payment =
                            num.tryParse(paymentCtl.text.replaceAll(',', '.')) ??
                                0;
                        final pd = int.tryParse(paymentDayCtl.text.trim());
                        final paymentDay =
                            (pd != null && pd >= 1 && pd <= 31) ? pd : null;
                        final tm = int.tryParse(termMonthsCtl.text.trim());
                        final termMonths =
                            (tm != null && tm > 0 && tm <= 600) ? tm : null;
                        if (existing == null) {
                          await ref.read(loansProvider.notifier).add(Loan(
                                id: const Uuid().v4(),
                                title: title,
                                principal: principal,
                                balance: balance,
                                annualRate: rate,
                                monthlyPayment: payment,
                                startDate: startDate,
                                currency: currency,
                                accountId: accountId,
                                notes: notesCtl.text.trim().isEmpty
                                    ? null
                                    : notesCtl.text.trim(),
                                paymentDay: paymentDay,
                                termMonths: termMonths,
                              ));
                        } else {
                          await ref
                              .read(loansProvider.notifier)
                              .upsert(existing.copyWith(
                                title: title,
                                principal: principal,
                                balance: balance,
                                annualRate: rate,
                                monthlyPayment: payment,
                                currency: currency,
                                accountId: accountId,
                                notes: notesCtl.text.trim().isEmpty
                                    ? null
                                    : notesCtl.text.trim(),
                                paymentDay: paymentDay,
                                termMonths: termMonths,
                              ));
                        }
                        if (ctx2.mounted) Navigator.of(ctx2).pop();
                      },
                      child: Text(
                          existing == null ? 'Создать' : 'Сохранить'),
                    ),
                  ),
                  if (existing != null) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref
                            .read(loansProvider.notifier)
                            .remove(existing.id);
                        if (ctx2.mounted) Navigator.of(ctx2).pop();
                      },
                    ),
                  ]
                ]),
              ],
            ),
          ),
        );
      });
    },
  );
}

class _PayoffSummary extends StatelessWidget {
  const _PayoffSummary({required this.loan, required this.full});
  final Loan loan;
  final LoanProjection full;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final principal = (full.totalPaid - full.totalInterest)
        .clamp(0.0, double.infinity);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 18,
                sections: [
                  PieChartSectionData(
                    value: principal.toDouble(),
                    color: const Color(0xFF22C55E),
                    title: 'Тело',
                    radius: 26,
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10),
                  ),
                  PieChartSectionData(
                    value:
                        math.max(full.totalInterest, 1).toDouble(),
                    color: const Color(0xFFEF4444),
                    title: '%',
                    radius: 26,
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Итог по кредиту',
                    style: Theme.of(context).textTheme.labelSmall),
                Text(
                  '${_fmt(full.totalPaid)} ${loan.currency}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Переплата: ${_fmt(full.totalInterest)} ${loan.currency} '
                  '(${full.totalPaid == 0 ? 0 : ((full.totalInterest / full.totalPaid) * 100).round()}%)',
                  style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600),
                ),
                Text('Срок: ${full.months} мес.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmortizationChart extends StatelessWidget {
  const _AmortizationChart({required this.schedule, required this.scheme});
  final List<AmortizationRow> schedule;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (schedule.isEmpty) return const SizedBox.shrink();
    final maxPay = schedule
        .map((r) => r.payment.toDouble())
        .reduce((a, b) => a > b ? a : b);
    // Sample at most 24 bars to keep it readable.
    final step = math.max(1, (schedule.length / 24).ceil());
    final sampled = <AmortizationRow>[];
    for (var i = 0; i < schedule.length; i += step) {
      sampled.add(schedule[i]);
    }
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              interval: math.max(1, (sampled.length / 5).ceil()).toDouble(),
              getTitlesWidget: (v, _) => Text('${v.toInt() * step}',
                  style: const TextStyle(fontSize: 9)),
            ),
          ),
        ),
        maxY: maxPay,
        barGroups: [
          for (var i = 0; i < sampled.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: sampled[i].payment.toDouble(),
                  width: 6,
                  rodStackItems: [
                    BarChartRodStackItem(
                      0,
                      sampled[i].principal.toDouble(),
                      const Color(0xFF22C55E),
                    ),
                    BarChartRodStackItem(
                      sampled[i].principal.toDouble(),
                      sampled[i].payment.toDouble(),
                      const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
