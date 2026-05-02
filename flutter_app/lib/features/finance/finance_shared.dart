import 'package:flutter/material.dart';

/// Shared helpers used across the finance tabs.
const List<String> kCurrencies = [
  'BYN',
  'USD',
  'EUR',
  'RUB',
  'PLN',
  'USDT',
];

const List<String> kAccountColors = [
  '#6D5CFF',
  '#22C55E',
  '#F59E0B',
  '#EF4444',
  '#3B82F6',
  '#EC4899',
  '#14B8A6',
  '#8B5CF6',
];

Color parseHexColor(String hex, {Color fallback = const Color(0xFF6D5CFF)}) {
  final cleaned = hex.replaceAll('#', '');
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse('FF$cleaned', radix: 16);
  if (value == null) return fallback;
  return Color(value);
}

/// Common categories used in the Russian-speaking React build. Used as
/// suggestions in the transaction form and for default monthly plans.
const List<String> kExpenseCategories = [
  'Еда',
  'Транспорт',
  'Кафе и рестораны',
  'Дом и быт',
  'Связь и интернет',
  'Развлечения',
  'Здоровье',
  'Одежда',
  'Образование',
  'Подписки',
  'Подарки',
  'Спорт',
  'Путешествия',
  'Прочее',
];

const List<String> kIncomeCategories = [
  'Зарплата',
  'Подработка',
  'Подарки',
  'Возврат',
  'Инвестиции',
  'Прочее',
];
