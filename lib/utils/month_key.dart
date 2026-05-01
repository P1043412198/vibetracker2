import 'package:intl/intl.dart';

String monthKeyFor(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

DateTime monthFromKey(String key) {
  final parts = key.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]));
}

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month);

DateTime endOfMonth(DateTime date) =>
    DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);

int daysInMonth(DateTime date) =>
    DateTime(date.year, date.month + 1, 0).day;

String formatMonthLong(DateTime date) =>
    toBeginningOfSentenceCase(DateFormat.yMMMM('ru').format(date)) ?? '';

String formatMonthShort(DateTime date) =>
    DateFormat.MMMM('ru').format(date);
