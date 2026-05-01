import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat.currency(
  locale: 'ru_RU',
  symbol: '₽',
  decimalDigits: 0,
);

String formatMoney(num value) {
  return _money.format(value).replaceAll('\u00A0', ' ');
}

String formatMoneySigned(num value) {
  if (value > 0) return '+${formatMoney(value)}';
  return formatMoney(value);
}

String formatNumberCompact(num value) {
  if (value.abs() >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value.abs() >= 1000) {
    return '${(value / 1000).toStringAsFixed(value.abs() >= 10000 ? 0 : 1)}k';
  }
  return value.toStringAsFixed(0);
}

String formatDateRu(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  if (diff == -1) return 'Завтра';
  return DateFormat('d MMMM', 'ru').format(date);
}

String formatDateLong(DateTime date) =>
    DateFormat('d MMMM yyyy', 'ru').format(date);

String formatTime(DateTime date) =>
    DateFormat('HH:mm').format(date);
