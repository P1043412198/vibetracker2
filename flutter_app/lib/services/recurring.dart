import '../models/finance.dart';

/// Pure helpers mirroring the React `lib/finance/recurring.ts` logic so both
/// apps surface the same recurring occurrences. All date math is done on plain
/// YYYY-MM-DD strings in UTC to avoid timezone drift.

String _pad(int n) => n.toString().padLeft(2, '0');

String _toIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_pad(d.month)}-${_pad(d.day)}';

DateTime _parseIso(String iso) {
  final parts = iso.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts.length > 1 ? parts[1] : 1,
      parts.length > 2 ? parts[2] : 1);
}

int _daysInMonth(int year, int month1) => DateTime.utc(year, month1 + 1, 0).day;

class RecurringOccurrence {
  RecurringOccurrence(this.dateISO, this.periodKey);
  final String dateISO;
  final String periodKey;
}

/// Most recent occurrence on or before [todayISO] for a rule, or null when the
/// rule has no occurrence at/before today (e.g. a biweekly anchor in future).
RecurringOccurrence? lastDueOccurrence(RegularPayment rule, String todayISO) {
  final today = _parseIso(todayISO);

  switch (rule.frequency) {
    case RecurringFrequency.monthly:
      final y = today.year;
      final m = today.month;
      final day = rule.dueDate.clamp(1, _daysInMonth(y, m));
      var occ = DateTime.utc(y, m, day);
      if (occ.isAfter(today)) {
        final py = m == 1 ? y - 1 : y;
        final pm = m == 1 ? 12 : m - 1;
        final pday = rule.dueDate.clamp(1, _daysInMonth(py, pm));
        occ = DateTime.utc(py, pm, pday);
      }
      return RecurringOccurrence(
          _toIso(occ), '${occ.year.toString().padLeft(4, '0')}-${_pad(occ.month)}');

    case RecurringFrequency.yearly:
      final month1 = (rule.month ?? 1).clamp(1, 12);
      final y = today.year;
      final day = rule.dueDate.clamp(1, _daysInMonth(y, month1));
      var occ = DateTime.utc(y, month1, day);
      if (occ.isAfter(today)) {
        final py = y - 1;
        final pday = rule.dueDate.clamp(1, _daysInMonth(py, month1));
        occ = DateTime.utc(py, month1, pday);
      }
      return RecurringOccurrence(
          _toIso(occ), occ.year.toString().padLeft(4, '0'));

    case RecurringFrequency.weekly:
      // Dart: Mon=1..Sun=7. Convert to JS-style Sun=0..Sat=6.
      final todayDow = today.weekday % 7;
      final target = ((rule.weekday ?? todayDow) % 7 + 7) % 7;
      final diff = (todayDow - target + 7) % 7;
      final occ = today.subtract(Duration(days: diff));
      return RecurringOccurrence(_toIso(occ), _toIso(occ));

    case RecurringFrequency.biweekly:
      final anchorISO = rule.anchorDate;
      if (anchorISO == null) return null;
      final anchor = _parseIso(anchorISO);
      if (anchor.isAfter(today)) return null;
      final periods = today.difference(anchor).inDays ~/ 14;
      final occ = anchor.add(Duration(days: periods * 14));
      return RecurringOccurrence(_toIso(occ), _toIso(occ));
  }
}

String refFor(String ruleId, String periodKey) => '$ruleId:$periodKey';

bool isOccurrencePosted(
    List<Transaction> transactions, String ruleId, String periodKey) {
  final ref = refFor(ruleId, periodKey);
  return transactions.any((t) => t.recurringRef == ref);
}

class DueRecurring {
  DueRecurring(this.rule, this.periodKey, this.dateISO, this.ref);
  final RegularPayment rule;
  final String periodKey;
  final String dateISO;
  final String ref;
}

/// Active rules whose latest occurrence is due, not yet posted, and not skipped.
List<DueRecurring> getDueRecurring(
  List<RegularPayment> rules,
  List<Transaction> transactions,
  List<RecurringSkip> skips,
  String todayISO,
) {
  final skipSet = skips.map((s) => refFor(s.ruleId, s.periodKey)).toSet();
  final out = <DueRecurring>[];
  for (final rule in rules) {
    if (!rule.isActive) continue;
    final occ = lastDueOccurrence(rule, todayISO);
    if (occ == null) continue;
    final ref = refFor(rule.id, occ.periodKey);
    if (skipSet.contains(ref)) continue;
    if (isOccurrencePosted(transactions, rule.id, occ.periodKey)) continue;
    out.add(DueRecurring(rule, occ.periodKey, occ.dateISO, ref));
  }
  out.sort((a, b) => a.dateISO.compareTo(b.dateISO));
  return out;
}
