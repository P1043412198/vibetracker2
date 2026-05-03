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
  num carryIn = 0,
}) {
  final plannedTotal = plannedIncome > scheduledIncomeTotal
      ? plannedIncome
      : scheduledIncomeTotal;
  final ref = (plannedTotal > 0 ? plannedTotal : actualIncome) + carryIn;
  final committed =
      actualExpense > plannedExpense ? actualExpense : plannedExpense;
  return FreeFunds(incomeRef: ref, free: ref - committed);
}

/// Computes how many free funds were left over from a given month plan +
/// facts, in the plan currency. Used to feed [computeFreeFunds.carryIn] for
/// the next month when [MonthlyBudgetPlan.freeFundsCarryover] is enabled.
///
/// Mirrors `computeFreeFunds` but always clamped at zero (only positive
/// leftovers carry forward; negative "overspend" does not bleed into next
/// month's plan).
num computeMonthLeftoverFree({
  required MonthlyBudgetPlan? plan,
  required MonthFacts facts,
  required num loansMonthlyPayments,
}) {
  if (plan == null) return 0;
  final scheduledIncomeTotal =
      (plan.incomes ?? const <IncomeEntry>[]).fold<num>(0, (s, e) => s + e.amount);
  final committed = computeCommittedExpense(
    categoryPlans: plan.categoryPlans,
    actualByCategory: facts.expenseByCategory,
    totalActualExpense: facts.expense,
    scheduledExpenses:
        plan.scheduledExpenses ?? const <ScheduledExpense>[],
    loansMonthlyPayments: loansMonthlyPayments,
  );
  final res = computeFreeFunds(
    plannedIncome: plan.plannedIncome,
    scheduledIncomeTotal: scheduledIncomeTotal,
    plannedExpense: committed.total,
    actualIncome: facts.income,
    actualExpense: facts.expense,
  );
  return res.free > 0 ? res.free : 0;
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

/// =============================================================
/// Phase 18: per-day-of-week + per-week breakdowns of free funds
/// =============================================================

/// Per-day-of-week aggregate of free-funds allowance for the **current**
/// (or selected) week, derived from the cashflow timeline. Each entry
/// captures a calendar day inside the week with its income/expense and the
/// running free-funds balance at end-of-day, plus the suggested allowance
/// for that day.
class FreeFundsDay {
  FreeFundsDay({
    required this.date,
    required this.weekday,
    required this.income,
    required this.expense,
    required this.endBalance,
    required this.allowance,
    required this.daysToNextEvent,
    required this.upcomingCommits,
  });
  final DateTime date;
  final int weekday; // DateTime.monday..sunday
  final num income;
  final num expense;

  /// Running balance at the END of this day (after applying its income and
  /// scheduled expenses). Includes [carryIn] from the previous month when
  /// passed to [buildCashflow].
  final num endBalance;

  /// Suggested per-day free-funds allowance for this day:
  /// `max(0, endBalance - upcomingCommits) / daysToNextEvent`. Reflects
  /// "how much can I safely spend each day until the next salary or end
  /// of month".
  final num allowance;

  /// Days remaining (inclusive) from the day after [date] until the next
  /// scheduled income event (or end-of-month if no more income).
  final int daysToNextEvent;

  /// Sum of scheduled expenses that still must be paid between the day
  /// after [date] and the next income event / end-of-month.
  final num upcomingCommits;
}

/// One ISO-week segment inside the month: the seven (or fewer at month
/// boundaries) days that fall into the same Mon-Sun stretch.
class FreeFundsWeek {
  FreeFundsWeek({
    required this.index,
    required this.startDay,
    required this.endDay,
    required this.startDate,
    required this.endDate,
    required this.income,
    required this.expense,
    required this.startBalance,
    required this.endBalance,
    required this.daysInclusive,
    required this.dailyAllowance,
    required this.weeklyFree,
  });
  final int index; // 1-based week-of-month
  final int startDay;
  final int endDay;
  final DateTime startDate;
  final DateTime endDate;

  /// Total scheduled income earned during this Mon-Sun stretch.
  final num income;

  /// Total scheduled expense (one-off bills + dated category limits + loan
  /// payments + evenly-spread undated category share) charged during this
  /// stretch.
  final num expense;

  /// Running balance at the end of the day BEFORE the first day of this
  /// week (so [startBalance] of week 1 is just [carryIn]).
  final num startBalance;

  /// Running balance at the end of the LAST day of this week.
  final num endBalance;

  final int daysInclusive;

  /// `weeklyFree / daysInclusive` — справедливый по-день бюджет внутри
  /// фактически отображенной недели.
  final num dailyAllowance;

  /// "Свободных средств в эту неделю" — `max(0, endBalance − commits)`,
  /// где commits — запланированные расходы от конца недели до
  /// ближайшего дохода / конца месяца. Реальный пул денег,
  /// который остаётся после этой недели для свободного распоряжения.
  final num weeklyFree;
}

class FreeFundsBreakdown {
  FreeFundsBreakdown({required this.days, required this.weeks});
  final List<FreeFundsDay> days;
  final List<FreeFundsWeek> weeks;
}

/// Slice [cashflow] into Mon-Sun weeks (clipped to the month) and a list of
/// [FreeFundsDay] entries for the **current** week. Caller must pass the
/// resolved [today] so the "current week" anchor is deterministic in tests.
FreeFundsBreakdown buildFreeFundsBreakdown({
  required CashflowResult cashflow,
  required DateTime month,
  DateTime? today,
}) {
  final timeline = cashflow.timeline;
  if (timeline.isEmpty) {
    return FreeFundsBreakdown(days: const [], weeks: const []);
  }
  final daysInMonth = timeline.length;

  // Helper: for a day [d] (1..daysInMonth), find the next day in the
  // month with positive income (or daysInMonth+1 if no more income).
  int nextIncomeDay(int d) {
    for (var x = d + 1; x <= daysInMonth; x++) {
      if (timeline[x - 1].income > 0) return x;
    }
    return daysInMonth + 1;
  }

  // Helper: per-day suggested allowance, taking the running balance at the
  // end of [d] and spreading it (after subtracting upcoming committed
  // expenses before the next income event) over the days remaining until
  // that event.
  ({num allowance, int daysAhead, num upcomingCommits}) computeAllowance(
      int d) {
    final endBal = timeline[d - 1].balance;
    final nextInc = nextIncomeDay(d);
    final upper = nextInc <= daysInMonth ? nextInc - 1 : daysInMonth;
    var commits = 0.0;
    for (var x = d + 1; x <= upper; x++) {
      commits += timeline[x - 1].expense.toDouble();
    }
    final daysAhead = math.max(1, upper - d + 1);
    final available = endBal.toDouble() - commits;
    final allowance = available > 0 ? available / daysAhead : 0.0;
    return (
      allowance: allowance,
      daysAhead: daysAhead,
      upcomingCommits: commits,
    );
  }

  // ---------- per-day-of-week list (anchor = current week) ----------
  DateTime anchor;
  final isCurrentMonth = today != null &&
      today.year == month.year &&
      today.month == month.month;
  if (isCurrentMonth) {
    anchor = DateTime(today.year, today.month, today.day);
  } else {
    anchor = DateTime(month.year, month.month, 1);
  }
  final monday = anchor.subtract(
      Duration(days: (anchor.weekday - DateTime.monday) % 7));
  final days = <FreeFundsDay>[];
  for (var i = 0; i < 7; i++) {
    final date = monday.add(Duration(days: i));
    if (date.year != month.year || date.month != month.month) {
      days.add(FreeFundsDay(
        date: date,
        weekday: date.weekday,
        income: 0,
        expense: 0,
        endBalance: 0,
        allowance: 0,
        daysToNextEvent: 0,
        upcomingCommits: 0,
      ));
      continue;
    }
    final tlIdx = date.day - 1;
    final cd = timeline[tlIdx];
    final a = computeAllowance(date.day);
    days.add(FreeFundsDay(
      date: date,
      weekday: date.weekday,
      income: cd.income,
      expense: cd.expense,
      endBalance: cd.balance,
      allowance: a.allowance,
      daysToNextEvent: a.daysAhead,
      upcomingCommits: a.upcomingCommits,
    ));
  }

  // ---------- per-week aggregates inside the month ----------
  final weeks = <FreeFundsWeek>[];
  var weekIdx = 0;
  var d = 1;
  // startBal of week 1 is the carry-in / starting balance, which is
  // timeline[0].balance - timeline[0].(income-expense).
  final firstDayBalanceBefore =
      timeline[0].balance - timeline[0].income + timeline[0].expense;
  while (d <= daysInMonth) {
    final dStart = DateTime(month.year, month.month, d);
    final daysToSunday = (DateTime.sunday - dStart.weekday + 7) % 7;
    var endDay = d + daysToSunday;
    if (endDay > daysInMonth) endDay = daysInMonth;
    final dEnd = DateTime(month.year, month.month, endDay);
    final startBal =
        d == 1 ? firstDayBalanceBefore : timeline[d - 2].balance;
    final endBal = timeline[endDay - 1].balance;
    num inc = 0;
    num exp = 0;
    for (var x = d; x <= endDay; x++) {
      inc += timeline[x - 1].income;
      exp += timeline[x - 1].expense;
    }
    final daysInWeek = endDay - d + 1;
    final allowanceAtEnd = computeAllowance(endDay);
    // Total free pool at end-of-week: balance left after future committed
    // expenses up to the next income event or month-end. This is the
    // реальный остаток свободных средств user can spend across the
    // remaining stretch — NOT `dailyAllowance × daysInWeek` (the latter
    // multiplies the spike on the very last day where daysAhead=1).
    final pool = allowanceAtEnd.allowance > 0
        ? allowanceAtEnd.allowance * allowanceAtEnd.daysAhead
        : 0.0;
    final daily = daysInWeek > 0 ? pool / daysInWeek : 0.0;
    weekIdx++;
    weeks.add(FreeFundsWeek(
      index: weekIdx,
      startDay: d,
      endDay: endDay,
      startDate: dStart,
      endDate: dEnd,
      income: inc,
      expense: exp,
      startBalance: startBal,
      endBalance: endBal,
      daysInclusive: daysInWeek,
      dailyAllowance: daily,
      weeklyFree: pool,
    ));
    d = endDay + 1;
  }

  return FreeFundsBreakdown(days: days, weeks: weeks);
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
  num carryIn = 0,
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
  num running = carryIn;
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
    final startBal =
        start == 1 ? carryIn : timeline[start - 2].balance;
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
/// Income periods — "what can I spend per day until the next paycheck"
/// =============================================================

/// One income-aligned period: a stretch from one income event (or month
/// start) through the day before the next income event (or month end).
///
/// Within an income period the user has a fixed amount of free money —
/// `inflow - committed`. The daily budget is that money divided by the
/// number of days, which answers the "how much can I spend per day until
/// my next paycheck without going broke?" question that Wave 1 cards
/// (Cashflow / per-day / per-week) tried to answer indirectly.
class IncomePeriod {
  IncomePeriod({
    required this.startDay,
    required this.endDay,
    required this.daysInclusive,
    required this.income,
    required this.committed,
    required this.startBalance,
    required this.endBalance,
    required this.dailyBudget,
    required this.label,
  });

  final int startDay;
  final int endDay;
  final int daysInclusive;
  /// Income arriving on `startDay` (or carried into the first period).
  final num income;
  /// Committed/scheduled expenses falling inside this period.
  final num committed;
  /// Running balance at the start of the period (before income).
  final num startBalance;
  /// Running balance at the end of the period.
  final num endBalance;
  /// `(income − committed) / days`, clamped to 0 when negative — the safe
  /// per-day spending number until the next paycheck.
  final num dailyBudget;
  final String label;

  /// Free money available across the whole period (= `dailyBudget × days`,
  /// pre-clamp). Useful for callers that want to render a "X BYN free in
  /// this period" line.
  num get free {
    final raw = income - committed;
    return raw > 0 ? raw : 0;
  }
}

/// Aligns [cashflow] to income events: each period starts on an income day
/// (or day 1) and runs through the day before the next income event (or to
/// month end).
///
/// Example (income on the 16th and 30th, rent on the 1st, JKH on the 16th):
/// → 3 periods: 1–15 (no income, only rent), 16–29 (1500 income, JKH),
///   30–31 (800 advance).
List<IncomePeriod> computeIncomePeriods(CashflowResult cashflow) {
  final timeline = cashflow.timeline;
  if (timeline.isEmpty) return const [];
  final daysInMonth = timeline.length;

  final boundarySet = <int>{1};
  for (var i = 0; i < daysInMonth; i++) {
    if (timeline[i].income > 0 && (i + 1) != 1) boundarySet.add(i + 1);
  }
  final boundaries = boundarySet.toList()..sort();
  boundaries.add(daysInMonth + 1);

  final periods = <IncomePeriod>[];
  for (var i = 0; i < boundaries.length - 1; i++) {
    final start = boundaries[i];
    final end = boundaries[i + 1] - 1;
    if (end < start) continue;
    num inc = 0;
    num exp = 0;
    for (var d = start; d <= end; d++) {
      inc += timeline[d - 1].income;
      exp += timeline[d - 1].expense;
    }
    final startBal =
        start == 1 ? (timeline[0].balance - timeline[0].income + timeline[0].expense) : timeline[start - 2].balance;
    final endBal = timeline[end - 1].balance;
    final days = end - start + 1;
    final freeRaw = inc - exp;
    final dailyBudget = days > 0 && freeRaw > 0 ? freeRaw / days : 0;
    periods.add(IncomePeriod(
      startDay: start,
      endDay: end,
      daysInclusive: days,
      income: inc,
      committed: exp,
      startBalance: startBal,
      endBalance: endBal,
      dailyBudget: dailyBudget,
      label: start == end ? 'День $start' : 'Дни $start–$end',
    ));
  }
  return periods;
}

/// Pick the income period that contains [todayDay] (1..daysInMonth). Returns
/// the first period if [todayDay] is before the month and the last period if
/// it's after. Returns null when [periods] is empty.
IncomePeriod? currentIncomePeriod(
    List<IncomePeriod> periods, int todayDay) {
  if (periods.isEmpty) return null;
  for (final p in periods) {
    if (todayDay >= p.startDay && todayDay <= p.endDay) return p;
  }
  return todayDay < periods.first.startDay ? periods.first : periods.last;
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

/// =============================================================
/// Phase 19: emergency fund / health-check / forecast / history
/// =============================================================

/// Income / expense for a single historical month — used for the 6-/12-month
/// trend chart on the planning tab.
class HistoricalMonth {
  HistoricalMonth({
    required this.month,
    required this.monthKey,
    required this.income,
    required this.expense,
  });
  final DateTime month;
  final String monthKey;
  final num income;
  final num expense;

  num get net => income - expense;
}

/// Compute [count] months of history (oldest first), ending with [endMonth].
/// Always includes [endMonth] itself.
List<HistoricalMonth> computeHistoricalMonths({
  required DateTime endMonth,
  required int count,
  required Iterable<Transaction> transactions,
  required Iterable<Account> accounts,
  required String baseCurrency,
  required CurrencyConvert convert,
  Set<String>? excludedAccountIds,
}) {
  final out = <HistoricalMonth>[];
  for (var i = count - 1; i >= 0; i--) {
    final m = DateTime(endMonth.year, endMonth.month - i, 1);
    final f = computeMonthFacts(
      month: m,
      transactions: transactions,
      accounts: accounts,
      baseCurrency: baseCurrency,
      convert: convert,
      excludedAccountIds: excludedAccountIds,
    );
    out.add(HistoricalMonth(
      month: m,
      monthKey: monthKeyOf(m),
      income: f.income,
      expense: f.expense,
    ));
  }
  return out;
}

/// =============================================================
/// Wave 2: month compare + savings forecast
/// =============================================================

/// Side-by-side numbers for "this month vs previous month" — used by the
/// `_MonthCompareCard` to teach the user to spot trends.
class MonthCompare {
  MonthCompare({
    required this.thisIncome,
    required this.thisExpense,
    required this.prevIncome,
    required this.prevExpense,
  });

  final num thisIncome;
  final num thisExpense;
  final num prevIncome;
  final num prevExpense;

  num get thisNet => thisIncome - thisExpense;
  num get prevNet => prevIncome - prevExpense;

  num get incomeDelta => thisIncome - prevIncome;
  num get expenseDelta => thisExpense - prevExpense;
  num get netDelta => thisNet - prevNet;

  /// True when both months had non-zero data — caller can hide the card
  /// otherwise (no point comparing against an empty month).
  bool get hasBothMonths =>
      (prevIncome > 0 || prevExpense > 0) &&
      (thisIncome > 0 || thisExpense > 0);
}

/// Build a [MonthCompare] from a [history] list (oldest first). When the
/// list has < 2 entries, returns null.
MonthCompare? buildMonthCompare(List<HistoricalMonth> history) {
  if (history.length < 2) return null;
  final prev = history[history.length - 2];
  final cur = history.last;
  return MonthCompare(
    thisIncome: cur.income,
    thisExpense: cur.expense,
    prevIncome: prev.income,
    prevExpense: prev.expense,
  );
}

/// Future projection of liquid balance under "continue at the current
/// average" assumption — used for the 6-month forecast card.
class SavingsForecast {
  SavingsForecast({
    required this.startBalance,
    required this.monthlyNet,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.months,
    required this.endBalance,
  });

  final num startBalance;
  /// Average net (income − expense) per month over the history window.
  final num monthlyNet;
  final num monthlyIncome;
  final num monthlyExpense;
  /// Forecast horizon in months (e.g. 6).
  final int months;
  /// Predicted balance after [months] months.
  final num endBalance;

  /// Per-month projected balance points (length = months + 1, including
  /// the start point).
  List<num> get points {
    final out = <num>[startBalance];
    var bal = startBalance;
    for (var i = 0; i < months; i++) {
      bal = bal + monthlyNet;
      out.add(bal);
    }
    return out;
  }

  /// "Coverage" metric: how many months of average expenses [endBalance]
  /// represents (useful for the «подушка через X мес» line).
  num get endMonthsCoverage =>
      monthlyExpense > 0 ? endBalance / monthlyExpense : 0;
}

/// Build a forecast that simply extrapolates the average net inflow from
/// [history] forward [months] months. Useful for "what happens if I keep
/// the same habits" reasoning, not a compound-interest model.
SavingsForecast buildSavingsForecast({
  required num currentLiquid,
  required List<HistoricalMonth> history,
  int months = 6,
}) {
  if (history.isEmpty) {
    return SavingsForecast(
      startBalance: currentLiquid,
      monthlyNet: 0,
      monthlyIncome: 0,
      monthlyExpense: 0,
      months: months,
      endBalance: currentLiquid,
    );
  }
  num inc = 0;
  num exp = 0;
  for (final m in history) {
    inc += m.income;
    exp += m.expense;
  }
  final avgIncome = inc / history.length;
  final avgExpense = exp / history.length;
  final avgNet = avgIncome - avgExpense;
  return SavingsForecast(
    startBalance: currentLiquid,
    monthlyNet: avgNet,
    monthlyIncome: avgIncome,
    monthlyExpense: avgExpense,
    months: months,
    endBalance: currentLiquid + avgNet * months,
  );
}

/// "What-if" projection: tweak income / expense by a percentage and see
/// how the forecast changes. `incomeDelta` and `expenseDelta` are signed
/// percentages (0.0 = no change, 0.1 = +10 %, -0.2 = −20 %).
SavingsForecast applyWhatIf(
  SavingsForecast base, {
  double incomeDelta = 0,
  double expenseDelta = 0,
}) {
  final newIncome = base.monthlyIncome * (1 + incomeDelta);
  final newExpense = base.monthlyExpense * (1 + expenseDelta);
  final newNet = newIncome - newExpense;
  return SavingsForecast(
    startBalance: base.startBalance,
    monthlyNet: newNet,
    monthlyIncome: newIncome,
    monthlyExpense: newExpense,
    months: base.months,
    endBalance: base.startBalance + newNet * base.months,
  );
}

/// Emergency-fund metric. `months` = total non-excluded liquid assets divided
/// by the average monthly expense over [history]. `severity` is a 0..3
/// indicator (0=red <1mo, 1=orange 1..3, 2=blue 3..6, 3=green ≥6).
class EmergencyFund {
  EmergencyFund({
    required this.totalLiquid,
    required this.avgMonthlyExpense,
    required this.months,
    required this.severity,
  });
  final num totalLiquid;
  final num avgMonthlyExpense;
  final num months;
  final int severity;
}

EmergencyFund computeEmergencyFund({
  required num totalLiquid,
  required List<HistoricalMonth> history,
}) {
  // Use only months with non-zero expense, otherwise average is meaningless.
  final used = history.where((m) => m.expense > 0).toList();
  if (used.isEmpty) {
    return EmergencyFund(
        totalLiquid: totalLiquid,
        avgMonthlyExpense: 0,
        months: 0,
        severity: 0);
  }
  final avg =
      used.fold<num>(0, (s, m) => s + m.expense) / used.length;
  if (avg <= 0) {
    return EmergencyFund(
        totalLiquid: totalLiquid,
        avgMonthlyExpense: 0,
        months: 0,
        severity: 0);
  }
  final months = totalLiquid / avg;
  final severity = months < 1
      ? 0
      : months < 3
          ? 1
          : months < 6
              ? 2
              : 3;
  return EmergencyFund(
    totalLiquid: totalLiquid,
    avgMonthlyExpense: avg,
    months: months,
    severity: severity,
  );
}

/// 50/30/20-style health-check of the plan. We classify category plans into:
/// * **needs**: rent, JKH, food, transport, health, family, education, kids
/// * **wants**: cafe, entertainment, clothes, beauty, travel, hobbies, gifts
/// * **savings**: explicit "savings" category names; if absent, free funds
///   are treated as savings.
class HealthCheck {
  HealthCheck({
    required this.needsShare,
    required this.wantsShare,
    required this.savingsShare,
    required this.expenseToIncome,
    required this.savingsRate,
    required this.severity,
    required this.message,
  });
  final double needsShare;
  final double wantsShare;
  final double savingsShare;
  /// expense ÷ income, e.g. 0.92 means расходы 92% дохода.
  final double expenseToIncome;
  /// Free funds ÷ income (≈ savings rate), 0..1.
  final double savingsRate;
  /// 0=red, 1=orange, 2=green.
  final int severity;
  final String message;
}

const Set<String> _needsCategories = {
  'Аренда',
  'Жильё',
  'ЖКХ',
  'Коммуналка',
  'Еда',
  'Продукты',
  'Транспорт',
  'Здоровье',
  'Лекарства',
  'Семья',
  'Дети',
  'Образование',
  'Дом и быт',
  'Связь и интернет',
};

const Set<String> _wantsCategories = {
  'Кафе и рестораны',
  'Развлечения',
  'Одежда',
  'Красота',
  'Путешествия',
  'Хобби',
  'Подарки',
  'Подарки и праздники',
  'Электроника',
};

const Set<String> _savingsCategories = {
  'Накопления',
  'Инвестиции',
  'Подушка',
  'Подушка безопасности',
  'Сбережения',
};

bool isNeed(String category) => _needsCategories.contains(category);
bool isWant(String category) => _wantsCategories.contains(category);
bool isSavings(String category) => _savingsCategories.contains(category);

HealthCheck computeHealthCheck({
  required num plannedIncomeRef,
  required List<CategoryPlan> categoryPlans,
  required List<ScheduledExpense> scheduledExpenses,
  required num loansMonthlyPayments,
  required num committedTotal,
  required num freeFunds,
}) {
  num needs = 0;
  num wants = 0;
  num savings = 0;
  for (final cp in categoryPlans) {
    if (isNeed(cp.category)) {
      needs += cp.planned;
    } else if (isWant(cp.category)) {
      wants += cp.planned;
    } else if (isSavings(cp.category)) {
      savings += cp.planned;
    } else {
      // Unknown → treat as wants for the 50/30/20 lens.
      wants += cp.planned;
    }
  }
  // Loan payments and dated bills are needs by default; a subscription or
  // entertainment scheduled-expense can opt into wants by setting category.
  needs += loansMonthlyPayments;
  for (final s in scheduledExpenses) {
    if (s.category != null && isWant(s.category!)) {
      wants += s.amount;
    } else if (s.category != null && isSavings(s.category!)) {
      savings += s.amount;
    } else {
      needs += s.amount;
    }
  }
  // Free funds also count as "savings potential" if no explicit savings
  // category is configured.
  if (savings <= 0 && freeFunds > 0) savings = freeFunds;

  final ref = plannedIncomeRef > 0 ? plannedIncomeRef.toDouble() : 0;
  double share(num x) => ref <= 0 ? 0 : (x / ref).clamp(0, 1).toDouble();
  final exprat = ref <= 0
      ? 0.0
      : (committedTotal / ref).toDouble();
  final saveRate = ref <= 0
      ? 0.0
      : (freeFunds > 0 ? freeFunds / ref : 0).toDouble();

  int severity;
  String message;
  if (ref <= 0) {
    severity = 1;
    message = 'Добавь плановый доход или планы по дням, чтобы посчитать.';
  } else if (exprat >= 1.0) {
    severity = 0;
    message = 'Расходы покрывают весь доход — нет запаса. Подрежь хотелки.';
  } else if (exprat >= 0.85) {
    severity = 0;
    message =
        'Расходы ${(exprat * 100).round()}% от дохода — слишком впритык.';
  } else if (exprat >= 0.7) {
    severity = 1;
    message =
        'Расходы ${(exprat * 100).round()}% от дохода — есть запас, но небольшой.';
  } else {
    severity = 2;
    message =
        'Расходы ${(exprat * 100).round()}% от дохода — здоровый запас.';
  }
  return HealthCheck(
    needsShare: share(needs),
    wantsShare: share(wants),
    savingsShare: share(savings),
    expenseToIncome: exprat,
    savingsRate: saveRate,
    severity: severity,
    message: message,
  );
}

/// Linear forecast of the running balance N months ahead, given the average
/// monthly net (`avgIncome - avgExpense`) over [history]. Returns the
/// projected total balance after [monthsAhead] full months.
class BalanceForecast {
  BalanceForecast({
    required this.startBalance,
    required this.avgMonthlyNet,
    required this.monthsAhead,
    required this.projected,
    required this.bestCase,
    required this.worstCase,
  });
  final num startBalance;
  final num avgMonthlyNet;
  final int monthsAhead;
  final num projected;
  final num bestCase;
  final num worstCase;
}

BalanceForecast forecastBalance({
  required num startBalance,
  required List<HistoricalMonth> history,
  required int monthsAhead,
}) {
  if (history.isEmpty) {
    return BalanceForecast(
        startBalance: startBalance,
        avgMonthlyNet: 0,
        monthsAhead: monthsAhead,
        projected: startBalance,
        bestCase: startBalance,
        worstCase: startBalance);
  }
  final nets =
      history.map((m) => m.net).toList()..sort();
  final avg = nets.fold<num>(0, (s, x) => s + x) / nets.length;
  final best = nets.last;
  final worst = nets.first;
  return BalanceForecast(
    startBalance: startBalance,
    avgMonthlyNet: avg,
    monthsAhead: monthsAhead,
    projected: startBalance + avg * monthsAhead,
    bestCase: startBalance + best * monthsAhead,
    worstCase: startBalance + worst * monthsAhead,
  );
}

/// Returns the per-day "сколько можно безопасно тратить" allowance for
/// every day in the month. The value at index `i` is the **period-constant**
/// daily allowance for the cashflow period that contains day `i+1`. This
/// keeps the per-day infographic 1:1 with the per-period table immediately
/// below it: every day inside the same period gets the same number, and the
/// number you read off a bar matches exactly the row beneath. Negative
/// period values (the user is in deficit until the next income) are clamped
/// to 0.
List<num> perDayAllowance(CashflowResult cashflow) {
  final timeline = cashflow.timeline;
  if (timeline.isEmpty) return const [];
  final daysInMonth = timeline.length;
  final out = List<num>.filled(daysInMonth, 0);
  for (final p in cashflow.periods) {
    final daily = p.dailyAllowance < 0 ? 0 : p.dailyAllowance;
    for (var d = p.startDay; d <= p.endDay && d <= daysInMonth; d++) {
      out[d - 1] = daily;
    }
  }
  return out;
}

/// Subscription detection: items flagged as `isSubscription==true`, or items
/// with `recurEvery != null && recurEvery > 0` whose name matches a known
/// service (Netflix, Spotify, …). Returns the filtered list **plus** total
/// monthly cost (annualised: cost ÷ recurEvery × 1).
class SubscriptionsSummary {
  SubscriptionsSummary({
    required this.items,
    required this.monthlyTotal,
    required this.annualTotal,
  });
  final List<ScheduledExpense> items;
  final num monthlyTotal;
  final num annualTotal;
}

const List<String> _kSubscriptionKeywords = [
  'netflix',
  'spotify',
  'youtube',
  'apple',
  'icloud',
  'google one',
  'one drive',
  'onedrive',
  'megogo',
  'kinopoisk',
  'okko',
  'wink',
  'ivi',
  'amazon prime',
  'office 365',
  'microsoft 365',
  'adobe',
  'dropbox',
  'patreon',
  'duolingo',
  'tinder',
  'chatgpt',
  'github',
  'figma',
  'notion',
  'slack',
  'zoom',
  'kaspersky',
  'nordvpn',
  'expressvpn',
  'подписка',
  'subscription',
  'тариф',
];

bool looksLikeSubscription(ScheduledExpense e) {
  if (e.isSubscription == true) return true;
  if (e.isSubscription == false) return false;
  if ((e.recurEvery ?? 0) <= 0) return false;
  final name = e.name.toLowerCase();
  for (final kw in _kSubscriptionKeywords) {
    if (name.contains(kw)) return true;
  }
  return false;
}

SubscriptionsSummary computeSubscriptions(
    Iterable<ScheduledExpense> scheduledExpenses) {
  final items = scheduledExpenses.where(looksLikeSubscription).toList();
  num monthly = 0;
  for (final s in items) {
    final every = s.recurEvery ?? 1;
    monthly += s.amount / (every <= 0 ? 1 : every);
  }
  return SubscriptionsSummary(
      items: items, monthlyTotal: monthly, annualTotal: monthly * 12);
}
