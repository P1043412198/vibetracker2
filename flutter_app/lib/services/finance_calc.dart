import 'dart:math' as math;

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

/// Free funds = (planned income reference) - committed expense.
///
/// * The income reference is the **largest** of [plannedIncome],
///   [scheduledIncomeTotal] (sum of `plan.incomes[].amount`) and, as a final
///   fallback when both are zero, [actualIncome]. This ensures dated incomes
///   ("получка 5го + премия 25го") behave the same as a single
///   `plannedIncome` field, fixing a bug where free funds ignored
///   schedule-only income plans.
/// * The committed expense is `max(actualExpense, plannedExpense)` so that
///   not-yet-realised but planned outflows (categoryPlans + scheduledExpenses)
///   already eat into free funds — and once the user has overspent, actual
///   takes over.
FreeFunds computeFreeFunds({
  required num plannedIncome,
  required num actualIncome,
  required num actualExpense,
  num scheduledIncomeTotal = 0,
  num plannedExpense = 0,
}) {
  final plannedTotal = plannedIncome > scheduledIncomeTotal
      ? plannedIncome
      : scheduledIncomeTotal;
  final ref = plannedTotal > 0 ? plannedTotal : actualIncome;
  final committed =
      actualExpense > plannedExpense ? actualExpense : plannedExpense;
  return FreeFunds(incomeRef: ref, free: ref - committed);
}

num dailyAllowance(num freeFunds, int daysLeft) {
  if (daysLeft <= 0) return 0;
  return freeFunds > 0 ? freeFunds / daysLeft : 0;
}

/// Approximate "сколько остаётся в неделю". A simple `daily * 7` so the
/// figure stays consistent with the per-day allowance no matter how many
/// days are left in the month.
num weeklyAllowance(num freeFunds, int daysLeft) {
  return dailyAllowance(freeFunds, daysLeft) * 7;
}

/// Breakdown of how much money is **really committed** for the month. This
/// is what should reduce free funds — not just `actualExpense` and not just
/// `plannedExpense`, but a mix:
///
/// * **categoryCommitted**: per-category `max(planned, actualForCategory)` so
///   under-spend stays bounded by the plan and over-spend is fully felt.
/// * **uncategorisedActual**: real transactions in categories that have no
///   `CategoryPlan` (or no category at all) — they always reduce free funds.
/// * **scheduledExpensesTotal**: fixed bills (`scheduledExpenses[]`).
/// * **loansTotal**: monthly loan payments (already converted to plan
///   currency by the caller).
class CommittedExpense {
  CommittedExpense({
    required this.categoryCommitted,
    required this.uncategorisedActual,
    required this.scheduledExpensesTotal,
    required this.loansTotal,
  });

  final num categoryCommitted;
  final num uncategorisedActual;
  final num scheduledExpensesTotal;
  final num loansTotal;

  num get total =>
      categoryCommitted +
      uncategorisedActual +
      scheduledExpensesTotal +
      loansTotal;
}

CommittedExpense computeCommittedExpense({
  required Iterable<CategoryPlan> categoryPlans,
  required Map<String, num> actualByCategory,
  required num totalActualExpense,
  required Iterable<ScheduledExpense> scheduledExpenses,
  required num loansMonthlyPayments,
}) {
  num categoryCommitted = 0;
  num actualInPlannedCategories = 0;
  for (final c in categoryPlans) {
    final actual = actualByCategory[c.category] ?? 0;
    categoryCommitted += c.planned > actual ? c.planned : actual;
    actualInPlannedCategories += actual;
  }
  var uncategorisedActual = totalActualExpense - actualInPlannedCategories;
  if (uncategorisedActual < 0) uncategorisedActual = 0;
  final scheduledTotal =
      scheduledExpenses.fold<num>(0, (s, e) => s + e.amount);
  return CommittedExpense(
    categoryCommitted: categoryCommitted,
    uncategorisedActual: uncategorisedActual,
    scheduledExpensesTotal: scheduledTotal,
    loansTotal: loansMonthlyPayments,
  );
}

/// =============================================================
/// Phase 14: schedule / period-aware daily allowance + loan math
/// =============================================================

/// One day inside the cashflow timeline.
class CashflowDay {
  CashflowDay({
    required this.date,
    required this.dayOfMonth,
    required this.income,
    required this.expense,
    required this.balance,
  });
  final DateTime date;
  final int dayOfMonth;
  final num income;
  final num expense;
  /// Accumulated free funds remaining at the END of this day, after applying
  /// the day's income & scheduled expenses.
  final num balance;
}

/// One spending period — between two scheduled cashflow events. The daily
/// allowance is constant within each period.
class CashflowPeriod {
  CashflowPeriod({
    required this.startDay,
    required this.endDay,
    required this.startBalance,
    required this.endBalance,
    required this.daysInclusive,
    required this.dailyAllowance,
    required this.label,
  });
  final int startDay;
  final int endDay;
  final num startBalance;
  final num endBalance;
  final int daysInclusive;
  final num dailyAllowance;
  final String label;
}

class CashflowResult {
  CashflowResult({
    required this.timeline,
    required this.periods,
    required this.totalIncome,
    required this.totalScheduled,
    required this.endOfMonthBalance,
  });
  final List<CashflowDay> timeline;
  final List<CashflowPeriod> periods;
  final num totalIncome;
  final num totalScheduled;
  final num endOfMonthBalance;
}

/// Builds a day-by-day cashflow for a given month, taking scheduled income
/// (from `plan.incomes`), scheduled category expenses (from
/// `plan.categoryPlans` with `dueDay`), and loan monthly payments
/// (`Loan.paymentDay`, in plan currency via [convert]) into account.
///
/// Categories without a `dueDay` are treated as evenly spread daily expenses.
CashflowResult buildCashflow({
  required DateTime month,
  required MonthlyBudgetPlan plan,
  List<Loan> loans = const [],
  required String planCurrency,
  required num Function(num amount, String from, String to) convert,
}) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final incomes = (plan.incomes ?? const <IncomeEntry>[]);
  final scheduledByDay = List<num>.filled(daysInMonth + 1, 0);
  final incomesByDay = List<num>.filled(daysInMonth + 1, 0);

  num totalIncome = 0;
  for (final inc in incomes) {
    final day = inc.day.clamp(1, daysInMonth);
    incomesByDay[day] += inc.amount;
    totalIncome += inc.amount;
  }
  // Fallback to plannedIncome on day 1 if no granular incomes are set.
  if (incomes.isEmpty && plan.plannedIncome > 0) {
    incomesByDay[1] += plan.plannedIncome;
    totalIncome += plan.plannedIncome;
  }

  num scheduled = 0;
  num undated = 0; // categories without a dueDay → spread evenly.
  for (final cp in plan.categoryPlans) {
    if (cp.planned <= 0) continue;
    if (cp.dueDay != null) {
      final d = cp.dueDay!.clamp(1, daysInMonth);
      scheduledByDay[d] += cp.planned;
      scheduled += cp.planned;
    } else {
      undated += cp.planned;
    }
  }
  // One-off planned expenses with explicit dates (e.g. internet on the 25th).
  for (final se in plan.scheduledExpenses ?? const <ScheduledExpense>[]) {
    if (se.amount <= 0) continue;
    final d = se.day.clamp(1, daysInMonth);
    scheduledByDay[d] += se.amount;
    scheduled += se.amount;
  }
  // Loan monthly payments — converted into the plan currency.
  for (final l in loans) {
    if (l.balance <= 0 || l.monthlyPayment <= 0) continue;
    final d = (l.paymentDay ?? 1).clamp(1, daysInMonth);
    final amount = convert(l.monthlyPayment, l.currency, planCurrency);
    scheduledByDay[d] += amount;
    scheduled += amount;
  }

  final dailyUndated = daysInMonth > 0 ? undated / daysInMonth : 0;
  final timeline = <CashflowDay>[];
  num running = 0;
  for (var d = 1; d <= daysInMonth; d++) {
    final dayDate = DateTime(month.year, month.month, d);
    final inc = incomesByDay[d];
    final exp = scheduledByDay[d] + dailyUndated;
    running += inc - exp;
    timeline.add(CashflowDay(
      date: dayDate,
      dayOfMonth: d,
      income: inc,
      expense: exp,
      balance: running,
    ));
  }

  // Build period list: split the month at every income or scheduled-expense
  // event. Within each period, "free per day" stays constant.
  final eventDays = <int>{1, daysInMonth};
  for (var d = 1; d <= daysInMonth; d++) {
    if (incomesByDay[d] != 0 || scheduledByDay[d] != 0) {
      eventDays.add(d);
      if (d > 1) eventDays.add(d); // start of new period at d
    }
  }
  final sortedEvents = eventDays.toList()..sort();
  final periods = <CashflowPeriod>[];
  for (var i = 0; i < sortedEvents.length - 1; i++) {
    final start = sortedEvents[i];
    final end = sortedEvents[i + 1] - 1;
    if (end < start) continue;
    final startBal = start == 1 ? 0 : timeline[start - 2].balance;
    final endBal = timeline[end - 1].balance;
    final days = end - start + 1;
    final spendable = endBal - startBal +
        (days * dailyUndated); // we add back evenly-spread money allotted
    final daily = days > 0 ? spendable / days : 0;
    periods.add(CashflowPeriod(
      startDay: start,
      endDay: end,
      startBalance: startBal,
      endBalance: endBal,
      daysInclusive: days,
      dailyAllowance: daily,
      label: start == end ? 'День $start' : 'Дни $start–$end',
    ));
  }

  return CashflowResult(
    timeline: timeline,
    periods: periods,
    totalIncome: totalIncome,
    totalScheduled: scheduled + undated,
    endOfMonthBalance: timeline.isEmpty ? 0 : timeline.last.balance,
  );
}

/// =============================================================
/// Loan amortization
/// =============================================================

class AmortizationRow {
  AmortizationRow({
    required this.month,
    required this.payment,
    required this.principal,
    required this.interest,
    required this.balance,
  });
  final int month;
  final num payment;
  final num principal;
  final num interest;
  final num balance;
}

class LoanProjection {
  LoanProjection({
    required this.schedule,
    required this.totalPaid,
    required this.totalInterest,
    required this.months,
  });
  final List<AmortizationRow> schedule;
  final num totalPaid;
  final num totalInterest;
  final int months;
}

/// Build a remaining-life amortization schedule for the loan (annuity).
/// Stops when the balance reaches zero; safe-guards against rates so high
/// the payment can't cover interest by capping at 600 months.
LoanProjection projectLoan(Loan loan, {num extraPerMonth = 0}) {
  final schedule = <AmortizationRow>[];
  if (loan.balance <= 0 || loan.monthlyPayment <= 0) {
    return LoanProjection(
      schedule: schedule,
      totalPaid: 0,
      totalInterest: 0,
      months: 0,
    );
  }
  final monthlyRate = loan.annualRate / 12 / 100;
  num balance = loan.balance.toDouble();
  num totalInterest = 0;
  num totalPaid = 0;
  var month = 0;
  while (balance > 0.005 && month < 600) {
    month++;
    final interest = balance * monthlyRate;
    var pay = (loan.monthlyPayment + extraPerMonth).toDouble();
    if (pay <= interest && extraPerMonth == 0) {
      // Payment can't even cover interest → schedule diverges; bail out.
      break;
    }
    var principal = pay - interest;
    if (principal > balance) {
      principal = balance.toDouble();
      pay = principal + interest;
    }
    balance -= principal;
    totalInterest += interest;
    totalPaid += pay;
    schedule.add(AmortizationRow(
      month: month,
      payment: pay,
      principal: principal,
      interest: interest,
      balance: balance < 0 ? 0 : balance,
    ));
  }
  return LoanProjection(
    schedule: schedule,
    totalPaid: totalPaid,
    totalInterest: totalInterest,
    months: schedule.length,
  );
}

/// Total nominal payoff (principal + interest) over the full life of the
/// loan from inception (using `principal`, not `balance`). Useful for the
/// "итоговая сумма по кредиту" figure.
LoanProjection projectLoanFromOrigination(Loan loan) {
  if (loan.principal <= 0 || loan.monthlyPayment <= 0) {
    return LoanProjection(schedule: const [], totalPaid: 0, totalInterest: 0, months: 0);
  }
  final tmp = Loan(
    id: loan.id,
    title: loan.title,
    principal: loan.principal,
    balance: loan.principal,
    annualRate: loan.annualRate,
    monthlyPayment: loan.monthlyPayment,
    startDate: loan.startDate,
    currency: loan.currency,
  );
  return projectLoan(tmp);
}

/// Suggested annuity payment for a hypothetical loan — useful in the loan
/// editor to back-fill the "monthlyPayment" field.
num suggestAnnuityPayment({
  required num principal,
  required num annualRatePct,
  required int months,
}) {
  if (months <= 0 || principal <= 0) return 0;
  final r = annualRatePct / 12 / 100;
  if (r <= 0) return principal / months;
  final pow = math.pow(1 + r, months);
  return principal * (r * pow) / (pow - 1);
}

/// Months required to pay off [principal] given a fixed [monthlyPayment]
/// and annual rate (%). Returns null if payment never covers interest.
int? termMonthsForPayment({
  required num principal,
  required num annualRatePct,
  required num monthlyPayment,
}) {
  if (principal <= 0 || monthlyPayment <= 0) return null;
  final r = annualRatePct / 12 / 100;
  if (r <= 0) return (principal / monthlyPayment).ceil();
  // Annuity: M = P * (r * (1+r)^n) / ((1+r)^n - 1)
  // → n = log(M / (M - P*r)) / log(1+r)
  final denom = monthlyPayment - principal * r;
  if (denom <= 0) return null; // payment doesn't cover interest
  final n = math.log(monthlyPayment / denom) / math.log(1 + r);
  return n.ceil();
}

/// Maximum principal you can borrow at [annualRatePct] over [months]
/// while keeping the monthly annuity payment at [monthlyPayment].
num maxPrincipalForPayment({
  required num monthlyPayment,
  required num annualRatePct,
  required int months,
}) {
  if (monthlyPayment <= 0 || months <= 0) return 0;
  final r = annualRatePct / 12 / 100;
  if (r <= 0) return monthlyPayment * months;
  final pow = math.pow(1 + r, months);
  return monthlyPayment * (pow - 1) / (r * pow);
}

/// Totals of monthly loan burden in the given currency (converted via
/// [convert]). Active loans only (balance > 0).
num monthlyLoanBurden({
  required List<Loan> loans,
  required String currency,
  required num Function(num amount, String from, String to) convert,
}) {
  num total = 0;
  for (final l in loans) {
    if (l.balance <= 0 || l.monthlyPayment <= 0) continue;
    total += convert(l.monthlyPayment, l.currency, currency);
  }
  return total;
}
