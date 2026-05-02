import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../services/finance_calc.dart';
import '../../state/currency_state.dart';
import '../../state/providers.dart';
import 'finance_shared.dart';

/// "Счета" tab — list of accounts with derived running balance.
class AccountsTab extends ConsumerWidget {
  const AccountsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final transactions = ref.watch(transactionsProvider);
    final rates = ref.watch(currencyRatesProvider);

    num convert(num amount, String from, String to) {
      return convertCurrency(
          amount: amount, from: from, to: to, rates: rates);
    }

    return Stack(
      children: [
        accounts.isEmpty
            ? const _Empty()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: accounts.length,
                itemBuilder: (context, i) {
                  final a = accounts[i];
                  final balance = accountBalance(
                    account: a,
                    transactions: transactions,
                    accounts: accounts,
                    convert: convert,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AccountCard(
                      account: a,
                      balance: balance,
                    ),
                  );
                },
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _openAddSheet(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Счёт'),
          ),
        ),
      ],
    );
  }

  static Future<void> _openAddSheet(
      BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => const _AccountFormSheet(),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account, required this.balance});
  final Account account;
  final num balance;

  String _typeLabel(AccountType t) {
    switch (t) {
      case AccountType.card:
        return 'Карта';
      case AccountType.cash:
        return 'Наличные';
      case AccountType.deposit:
        return 'Депозит';
      case AccountType.crypto:
        return 'Крипта';
      case AccountType.installment:
        return 'Рассрочка';
      case AccountType.other:
        return 'Прочее';
    }
  }

  IconData _icon(AccountType t) {
    switch (t) {
      case AccountType.card:
        return Icons.credit_card;
      case AccountType.cash:
        return Icons.payments_outlined;
      case AccountType.deposit:
        return Icons.savings_outlined;
      case AccountType.crypto:
        return Icons.currency_bitcoin;
      case AccountType.installment:
        return Icons.calendar_today_outlined;
      case AccountType.other:
        return Icons.account_balance_wallet_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);
    final color = parseHexColor(account.color);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon(account.type), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(
                        '${_typeLabel(account.type)} · ${account.currency}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      ref.read(accountsProvider.notifier).remove(account.id),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Баланс',
                style: Theme.of(context).textTheme.bodySmall),
            Text(
              '${fmt.format(balance)} ${account.currency}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: balance >= 0 ? color : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏦', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Создай первый счёт',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Карты, кошельки и депозиты — добавь их, чтобы транзакции считали баланс автоматически.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountFormSheet extends ConsumerStatefulWidget {
  const _AccountFormSheet();
  @override
  ConsumerState<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<_AccountFormSheet> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  AccountType _type = AccountType.card;
  String _currency = 'BYN';
  String _color = kAccountColors.first;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Новый счёт',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AccountType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Тип'),
              items: const [
                DropdownMenuItem(
                    value: AccountType.card, child: Text('Карта')),
                DropdownMenuItem(
                    value: AccountType.cash, child: Text('Наличные')),
                DropdownMenuItem(
                    value: AccountType.deposit, child: Text('Депозит')),
                DropdownMenuItem(
                    value: AccountType.crypto, child: Text('Крипта')),
                DropdownMenuItem(
                    value: AccountType.installment,
                    child: Text('Рассрочка')),
                DropdownMenuItem(
                    value: AccountType.other, child: Text('Прочее')),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(labelText: 'Валюта'),
              items: [
                for (final c in kCurrencies)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _currency = v ?? _currency),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _balanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Начальный баланс'),
            ),
            const SizedBox(height: 16),
            Text('Цвет',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in kAccountColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: parseHexColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == hex
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final balance = double.tryParse(_balanceController.text.trim()) ?? 0;
    final account = Account(
      id: const Uuid().v4(),
      name: name,
      type: _type,
      currency: _currency,
      initialBalance: balance,
      color: _color,
      createdAt: DateTime.now().toIso8601String(),
    );
    await ref.read(accountsProvider.notifier).add(account);
    if (mounted) Navigator.of(context).pop();
  }
}
