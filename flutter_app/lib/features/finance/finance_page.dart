import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/finance_calc.dart';
import '../../state/currency_state.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';
import '../financial_plan/services/finplan_export.dart';
import 'accounts_tab.dart';
import 'budget_planner_tab.dart';
import 'charts_tab.dart';
import 'transactions_tab.dart';

/// Tabbed finance page — port of `src/pages/Finance.tsx` (2700+ lines).
///
/// Phase 1 ports the four most-used tabs from the React version:
/// Транзакции / Счета / План месяца / Графики. The remaining 16 tabs
/// (subscriptions, FIRE, AI, debt strategy, …) are tracked in
/// MIGRATION_PLAN.md and will land in later phases.
class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key});

  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  static const _tabs = ['Бюджет', 'Транзакции', 'Счета', 'Аналитика'];

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: _tabs.length, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider);

    num convert(num amount, String from, String to) {
      return convertCurrency(
          amount: amount, from: from, to: to, rates: rates);
    }

    final facts = computeMonthFacts(
      month: DateTime.now(),
      transactions: transactions,
      accounts: accounts,
      baseCurrency: baseCurrency,
      convert: convert,
    );
    final balance = accounts.fold<num>(
      0,
      (sum, a) =>
          sum +
          convert(
              accountBalance(
                account: a,
                transactions: transactions,
                accounts: accounts,
                convert: convert,
              ),
              a.currency,
              baseCurrency),
    );

    final fmt =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Финансы'),
        actions: [
          IconButton(
            tooltip: 'Обновить курсы НБРБ',
            icon: const Icon(Icons.currency_exchange_outlined),
            onPressed: () => _refreshNbrbRates(context, ref),
          ),
          IconButton(
            tooltip: 'Чеки',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push('/receipts'),
          ),
          IconButton(
            tooltip: 'Сканер QR чеков',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/qr-receipt'),
          ),
          IconButton(
            tooltip: 'Финансовая грамотность',
            icon: const Icon(Icons.school_outlined),
            onPressed: () => context.push('/tools'),
          ),
          IconButton(
            tooltip: 'Финансовый план',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => context.push('/financial-plan'),
          ),
          IconButton(
            tooltip: 'Экспорт транзакций в CSV',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => exportTransactionsAsCsv(transactions),
          ),
        ],
        bottom: TabBar(
          controller: _controller,
          isScrollable: true,
          tabs: [for (final t in _tabs) Tab(text: t)],
        ),
      ),
      body: Column(
        children: [
          _NetWorthBar(
            balance: balance,
            income: facts.income,
            expense: facts.expense,
            currency: baseCurrency,
            fmt: fmt,
          ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: const [
                BudgetPlannerTab(),
                TransactionsTab(),
                AccountsTab(),
                ChartsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetWorthBar extends StatelessWidget {
  const _NetWorthBar({
    required this.balance,
    required this.income,
    required this.expense,
    required this.currency,
    required this.fmt,
  });

  final num balance;
  final num income;
  final num expense;
  final String currency;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            scheme.primary.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Баланс на счетах',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${fmt.format(balance)} $currency',
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Доход за месяц',
                  value: '+ ${fmt.format(income)} $currency',
                  color: const Color(0xFFA7F3D0),
                  scheme: scheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Расход за месяц',
                  value: '- ${fmt.format(expense)} $currency',
                  color: const Color(0xFFFCA5A5),
                  scheme: scheme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.scheme,
  });

  final String label;
  final String value;
  final Color color;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: scheme.onPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

Future<void> _refreshNbrbRates(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(
      duration: Duration(seconds: 1),
      content: Row(children: [
        SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 12),
        Text('Загружаю курсы НБРБ…'),
      ]),
    ),
  );
  try {
    final n =
        await ref.read(currencyRatesProvider.notifier).refreshFromNbrb();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
          content: Text('Курсы НБРБ обновлены ($n валют)'),
          duration: const Duration(seconds: 2)),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Не удалось обновить НБРБ: $e')),
    );
  }
}
