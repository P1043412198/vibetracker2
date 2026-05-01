import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/month_picker_button.dart';
import '../widgets/period_chip.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class OperationsScreen extends StatefulWidget {
  final AppState state;

  const OperationsScreen({super.key, required this.state});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  /// 0 = all, 1 = expense, 2 = income
  int _filter = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final month = widget.state.selectedMonth;
        var txs = widget.state.txInMonth(month);
        if (_filter == 1) {
          txs = txs.where((t) => t.type == TxType.expense).toList();
        } else if (_filter == 2) {
          txs = txs.where((t) => t.type == TxType.income).toList();
        }
        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          txs = txs.where((t) {
            final hay = '${t.store ?? ''} ${t.comment ?? ''} ${t.account ?? ''}'
                .toLowerCase();
            return hay.contains(q);
          }).toList();
        }

        final grouped = <String, List<TxRecord>>{};
        for (final t in txs) {
          final key = formatDateRu(t.date);
          grouped.putIfAbsent(key, () => []).add(t);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Операции'),
            actions: [
              IconButton(
                onPressed: _onSearch,
                icon: const Icon(Icons.search_rounded),
              ),
              MonthPickerButton(
                month: month,
                onChanged: widget.state.selectMonth,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: PeriodChips(
                  labels: const ['Все', 'Расходы', 'Доходы'],
                  selected: _filter,
                  onSelected: (i) => setState(() => _filter = i),
                ),
              ),
              if (_query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Поиск: $_query',
                          style: const TextStyle(
                              color: AppColors.textSecondary),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _query = ''),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: txs.isEmpty
                    ? const _EmptyState()
                    : ListView(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        children: [
                          for (final entry in grouped.entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.divider),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              child: Column(
                                children: [
                                  for (var i = 0; i < entry.value.length; i++) ...[
                                    if (i > 0)
                                      const Divider(
                                          height: 1,
                                          color: AppColors.divider),
                                    Dismissible(
                                      key: ValueKey(entry.value[i].id),
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        color: AppColors.danger,
                                        child: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.white),
                                      ),
                                      direction:
                                          DismissDirection.endToStart,
                                      onDismissed: (_) async {
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        await widget.state.deleteTransaction(
                                            entry.value[i].id);
                                        messenger.showSnackBar(
                                          const SnackBar(
                                              content: Text('Удалено')),
                                        );
                                      },
                                      child: TransactionTile(
                                        tx: entry.value[i],
                                        onTap: () =>
                                            _editTx(entry.value[i]),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _MonthSummaryCard(state: widget.state),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onSearch() async {
    final controller = TextEditingController(text: _query);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Поиск операций'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Магазин, комментарий, счёт',
            filled: false,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Очистить')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Искать')),
        ],
      ),
    );
    if (result != null) setState(() => _query = result.trim());
  }

  void _editTx(TxRecord tx) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(state: widget.state, edit: tx),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Операций ещё нет',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Нажми «+», чтобы добавить первую',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  final AppState state;
  const _MonthSummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final month = state.selectedMonth;
    final income = state.totalIncomeIn(month);
    final expense = state.totalExpenseIn(month);
    final balance = income - expense;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Итого за ${DateFormat.yMMMM('ru').format(month)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _row('Доходы', income, AppColors.primary),
          const SizedBox(height: 6),
          _row('Расходы', -expense, AppColors.danger),
          const Divider(height: 18, color: AppColors.divider),
          _row(
            'Баланс',
            balance,
            balance >= 0 ? AppColors.primary : AppColors.danger,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value, Color color, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimary,
              fontSize: bold ? 15 : 14,
            ),
          ),
        ),
        Text(
          formatMoneySigned(value),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
