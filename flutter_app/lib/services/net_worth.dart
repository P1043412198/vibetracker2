import '../models/enums.dart';
import '../models/finance.dart';
import 'finance_calc.dart';

/// Net-worth-over-time analytics, mirroring the React `FinanceVisualsTab`
/// reconstruction + `lib/finance/netWorth.ts` trend helper.

class NetWorthPoint {
  NetWorthPoint({
    required this.monthKey,
    required this.assets,
    required this.debts,
  });

  final String monthKey; // YYYY-MM
  final num assets;
  final num debts;
  num get netWorth => assets - debts;
}

String _monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Last calendar day of [month] at 23:59:59 (local) — the cutoff for that
/// month's snapshot.
DateTime _monthEnd(DateTime month) =>
    DateTime(month.year, month.month + 1, 0, 23, 59, 59);

/// Reconstructs net worth at the end of each of the last [months] months,
/// oldest first. Assets = account balances at month-end (+ orphan
/// income/expense without a real account). Debts = remaining loan principal
/// at month-end. Accounts/loans created after a snapshot are excluded from it.
List<NetWorthPoint> computeNetWorthHistory({
  required List<Account> accounts,
  required List<Transaction> transactions,
  required List<Loan> loans,
  required List<LoanPayment> loanPayments,
  required String baseCurrency,
  required CurrencyConvert convert,
  DateTime? now,
  int months = 12,
}) {
  final ref = now ?? DateTime.now();
  final accountIds = accounts.map((a) => a.id).toSet();
  final out = <NetWorthPoint>[];

  for (var i = months - 1; i >= 0; i--) {
    final month = DateTime(ref.year, ref.month - i, 1);
    final end = _monthEnd(month);
    bool throughEnd(String iso) {
      final d = DateTime.tryParse(iso);
      return d != null && !d.isAfter(end);
    }

    final txThroughEnd =
        transactions.where((t) => throughEnd(t.date)).toList(growable: false);

    num assets = 0;
    for (final acc in accounts) {
      final bal = accountBalance(
        account: acc,
        transactions: txThroughEnd,
        accounts: accounts,
        convert: convert,
      );
      assets += convert(bal, acc.currency, baseCurrency);
    }

    // Orphan transactions without a real account (legacy paymentMethod data).
    num orphan = 0;
    for (final t in txThroughEnd) {
      if (t.accountId != null && accountIds.contains(t.accountId)) continue;
      if (t.type == TransactionType.income) {
        orphan += t.amount;
      } else if (t.type == TransactionType.expense) {
        orphan -= t.amount;
      }
    }
    assets += orphan;

    num debts = 0;
    for (final loan in loans) {
      final paid = loanPayments
          .where((p) => p.loanId == loan.id && throughEnd(p.date))
          .fold<num>(0, (s, p) => s + p.amount);
      final remaining = (loan.principal - paid);
      debts += convert(remaining > 0 ? remaining : 0, loan.currency, baseCurrency);
    }

    out.add(NetWorthPoint(monthKey: _monthKey(month), assets: assets, debts: debts));
  }

  return out;
}

enum TrendDirection { up, down, flat }

class NetWorthTrend {
  NetWorthTrend({
    required this.current,
    required this.change,
    required this.monthlyRate,
    required this.direction,
  });

  final num current;
  final num change;
  final num monthlyRate;
  final TrendDirection direction;
}

const double _flatEpsilon = 0.5;

/// Trend over a net-worth series (oldest first). Null when empty.
NetWorthTrend? computeNetWorthTrend(List<num> values) {
  if (values.isEmpty) return null;
  final current = values.last;
  final change = current - values.first;
  final spans = values.length - 1;
  final monthlyRate = spans > 0 ? change / spans : 0;
  final direction = monthlyRate > _flatEpsilon
      ? TrendDirection.up
      : monthlyRate < -_flatEpsilon
          ? TrendDirection.down
          : TrendDirection.flat;
  return NetWorthTrend(
    current: current,
    change: change,
    monthlyRate: monthlyRate,
    direction: direction,
  );
}
