import 'package:intl/intl.dart';

import '../models/enums.dart';
import '../models/finance.dart';

/// Pure helpers for finance calculations.
///
/// Port of `src/lib/monthlyBudget.ts` plus the inline helpers from
/// `src/pages/Finance.tsx` that compute account balances and month-aggregated
/// facts. Currency conversion is delegated through a callback so the caller
/// owns the FX-rate source.
typedef CurrencyConvert = num Function(num amount, String from, String to);

String monthKeyOf(DateTime date) {
  return DateFormat('yyyy-MM').format(date);
}

String previousMonthKey(String monthKey) {
  final parts = monthKey.split('-');
  final y = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final prev = DateTime(y, m - 1, 1);
  return monthKeyOf(prev);
}

/// Compute the running balance for a single account, taking initial balance
/// and applying every relevant transaction. Cross-currency transfers are
/// converted via [convert].
num accountBalance({
  required Account account,
  required Iterable<Transaction> transactions,
  required Iterable<Account> accounts,
  required CurrencyConvert convert,
}) {
  num balance = account.initialBalance;
  for (final t in transactions) {
    if (t.type == TransactionType.income && t.accountId == account.id) {
      balance += t.amount;
    } else if (t.type == TransactionType.expense &&
        t.accountId == account.id) {
      balance -= t.amount;
    } else if (t.type == TransactionType.transfer) {
      if (t.accountId == account.id) {
        balance -= t.amount;
      } else if (t.toAccountId == account.id) {
        final from =
            accounts.cast<Account?>().firstWhere(
                  (a) => a?.id == t.accountId,
                  orElse: () => null,
                );
        if (from == null || from.currency == account.currency) {
          balance += t.amount;
        } else {
          balance += convert(t.amount, from.currency, account.currency);
        }
      }
    }
  }
  return balance;
}

class MonthFacts {
  MonthFacts({
    required this.income,
    required this.expense,
    required this.expenseByCategory,
    required this.monthTransactions,
  });

  final num income;
  final num expense;
  final Map<String, num> expenseByCategory;
  final List<Transaction> monthTransactions;
}

/// Compute month income/expense in a target currency. The transaction's
/// currency is inferred from its account; if the account is missing we fall
/// back to [baseCurrency].
MonthFacts computeMonthFacts({
  required DateTime month,
  required Iterable<Transaction> transactions,
  required Iterable<Account> accounts,
  required String baseCurrency,
  required CurrencyConvert convert,
  Set<String>? excludedAccountIds,
}) {
  final monthKey = monthKeyOf(month);
  final excluded = excludedAccountIds ?? const <String>{};
  final monthTx = transactions
      .where((t) => t.date.startsWith(monthKey))
      .where((t) =>
          !excluded.contains(t.accountId) && !excluded.contains(t.toAccountId))
      .toList(growable: false);
  num income = 0;
  num expense = 0;
  final byCategory = <String, num>{};
  for (final t in monthTx) {
    final account =
        accounts.cast<Account?>().firstWhere(
              (a) => a?.id == t.accountId,
              orElse: () => null,
            );
    final currency = account?.currency ?? baseCurrency;
    final converted = convert(t.amount, currency, baseCurrency);
    if (t.type == TransactionType.income) {
      income += converted;
    } else if (t.type == TransactionType.expense) {
      expense += converted;
      byCategory[t.category] = (byCategory[t.category] ?? 0) + converted;
    }
  }
  return MonthFacts(
    income: income,
    expense: expense,
    expenseByCategory: byCategory,
    monthTransactions: monthTx,
  );
}

int daysLeftInMonth(DateTime month, [DateTime? today]) {
  final now = today ?? DateTime.now();
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final sameMonth = month.year == now.year && month.month == now.month;
  if (sameMonth) {
    final left = daysInMonth - now.day + 1;
    return left < 1 ? 1 : left;
  }
  final isFuture = DateTime(month.year, month.month, 1)
      .isAfter(DateTime(now.year, now.month, 1));
  return isFuture ? daysInMonth : 1;
}

/// Effective category limit, accounting for an optional rollover carry-in
/// from the previous month.
num effectiveLimit({
  required String category,
  MonthlyBudgetPlan? monthPlan,
  MonthlyBudgetPlan? previousPlan,
  Map<String, num>? previousActuals,
}) {
  final base = monthPlan?.categoryPlans
          .cast<CategoryPlan?>()
          .firstWhere((c) => c?.category == category, orElse: () => null)
          ?.planned ??
      0;
  if (monthPlan?.rollover != true) return base;
  final prevLimit = previousPlan?.categoryPlans
          .cast<CategoryPlan?>()
          .firstWhere((c) => c?.category == category, orElse: () => null)
          ?.planned ??
      0;
  final prevActual = previousActuals?[category] ?? 0;
  final carry = (prevLimit - prevActual);
  return base + (carry > 0 ? carry : 0);
}

class FreeFunds {
  FreeFunds({required this.incomeRef, required this.free});
  final num incomeRef;
  final num free;
}

FreeFunds computeFreeFunds({
  required num plannedIncome,
  required num actualIncome,
  required num actualExpense,
}) {
  final ref = plannedIncome > 0 ? plannedIncome : actualIncome;
  return FreeFunds(incomeRef: ref, free: ref - actualExpense);
}

num dailyAllowance(num freeFunds, int daysLeft) {
  if (daysLeft <= 0) return 0;
  return freeFunds > 0 ? freeFunds / daysLeft : 0;
}
