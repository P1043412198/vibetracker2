import '../models/enums.dart';
import '../models/finance.dart';
import 'recurring.dart';

/// Mirrors React `lib/finance/reminders.ts`: surfaces upcoming bill/loan
/// payments so the UI can nudge the user before money is due.

enum ReminderKind { recurring, loan }

class PaymentReminder {
  PaymentReminder({
    required this.id,
    required this.kind,
    required this.sourceId,
    required this.periodKey,
    required this.name,
    required this.amount,
    required this.currency,
    required this.type,
    required this.dueISO,
    required this.daysUntil,
  });

  /// Stable key `kind:sourceId:periodKey` — used for acknowledge tracking.
  final String id;
  final ReminderKind kind;
  final String sourceId;
  final String periodKey;
  final String name;
  final num amount;
  final Currency currency;
  final TransactionType type;
  final String dueISO;
  final int daysUntil;
}

int _daysBetween(String fromISO, String toISO) {
  final a = DateTime.parse(fromISO);
  final b = DateTime.parse(toISO);
  return b.difference(a).inDays;
}

String _loanNextDue(Loan loan, String todayISO) {
  final today = DateTime.parse(todayISO);
  final day = (loan.paymentDay ?? 5).clamp(1, 28);
  var occ = DateTime.utc(today.year, today.month, day);
  if (occ.isBefore(DateTime.utc(today.year, today.month, today.day))) {
    final ny = today.month == 12 ? today.year + 1 : today.year;
    final nm = today.month == 12 ? 1 : today.month + 1;
    occ = DateTime.utc(ny, nm, day);
  }
  return '${occ.year.toString().padLeft(4, '0')}-'
      '${occ.month.toString().padLeft(2, '0')}-'
      '${occ.day.toString().padLeft(2, '0')}';
}

/// Upcoming reminders within [windowDays], from active non-auto recurring
/// rules and loans with an outstanding balance. Sorted soonest-first.
List<PaymentReminder> getUpcomingReminders(
  List<RegularPayment> rules,
  List<Loan> loans,
  String todayISO, {
  int windowDays = 7,
}) {
  final out = <PaymentReminder>[];

  for (final rule in rules) {
    if (!rule.isActive || rule.autoConfirm) continue;
    final occ = nextDueOccurrence(rule, todayISO);
    if (occ == null) continue;
    final daysUntil = _daysBetween(todayISO, occ.dateISO);
    if (daysUntil < 0 || daysUntil > windowDays) continue;
    out.add(PaymentReminder(
      id: 'recurring:${rule.id}:${occ.periodKey}',
      kind: ReminderKind.recurring,
      sourceId: rule.id,
      periodKey: occ.periodKey,
      name: rule.name,
      amount: rule.amount,
      currency: rule.currency ?? 'BYN',
      type:
          rule.type == TransactionType.income ? TransactionType.income : TransactionType.expense,
      dueISO: occ.dateISO,
      daysUntil: daysUntil,
    ));
  }

  for (final loan in loans) {
    if (loan.balance <= 0) continue;
    if (!(loan.monthlyPayment > 0)) continue;
    final dueISO = _loanNextDue(loan, todayISO);
    final daysUntil = _daysBetween(todayISO, dueISO);
    if (daysUntil < 0 || daysUntil > windowDays) continue;
    final periodKey = dueISO.substring(0, 7);
    out.add(PaymentReminder(
      id: 'loan:${loan.id}:$periodKey',
      kind: ReminderKind.loan,
      sourceId: loan.id,
      periodKey: periodKey,
      name: loan.title,
      amount: loan.monthlyPayment,
      currency: loan.currency,
      type: TransactionType.expense,
      dueISO: dueISO,
      daysUntil: daysUntil,
    ));
  }

  out.sort((a, b) {
    final c = a.dueISO.compareTo(b.dueISO);
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return out;
}
