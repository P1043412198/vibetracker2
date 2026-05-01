import 'package:flutter/material.dart';

class TxCategory {
  final String id;
  final String name;
  final IconData icon;
  final int colorValue;
  final bool isExpense;

  const TxCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    required this.isExpense,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon.codePoint,
        'iconFamily': icon.fontFamily,
        'iconPackage': icon.fontPackage,
        'color': colorValue,
        'isExpense': isExpense,
      };

  factory TxCategory.fromJson(Map<String, dynamic> json) {
    return TxCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: IconData(
        json['icon'] as int,
        fontFamily: json['iconFamily'] as String?,
        fontPackage: json['iconPackage'] as String?,
      ),
      colorValue: json['color'] as int,
      isExpense: json['isExpense'] as bool,
    );
  }
}

class DefaultCategories {
  static const expenses = <TxCategory>[
    TxCategory(
      id: 'food',
      name: 'Продукты',
      icon: Icons.shopping_basket_rounded,
      colorValue: 0xFF2E7D52,
      isExpense: true,
    ),
    TxCategory(
      id: 'cafes',
      name: 'Еда и напитки',
      icon: Icons.local_cafe_rounded,
      colorValue: 0xFFE07A5F,
      isExpense: true,
    ),
    TxCategory(
      id: 'transport',
      name: 'Транспорт',
      icon: Icons.directions_car_rounded,
      colorValue: 0xFF6BB7C9,
      isExpense: true,
    ),
    TxCategory(
      id: 'shopping',
      name: 'Покупки',
      icon: Icons.shopping_bag_rounded,
      colorValue: 0xFF9C7BD2,
      isExpense: true,
    ),
    TxCategory(
      id: 'health',
      name: 'Здоровье',
      icon: Icons.medical_services_rounded,
      colorValue: 0xFFD27B9C,
      isExpense: true,
    ),
    TxCategory(
      id: 'entertainment',
      name: 'Развлечения',
      icon: Icons.movie_rounded,
      colorValue: 0xFFFFC542,
      isExpense: true,
    ),
    TxCategory(
      id: 'home',
      name: 'Дом и быт',
      icon: Icons.home_rounded,
      colorValue: 0xFF8AAE7A,
      isExpense: true,
    ),
    TxCategory(
      id: 'transfer',
      name: 'Переводы',
      icon: Icons.swap_horiz_rounded,
      colorValue: 0xFF4CAF7C,
      isExpense: true,
    ),
    TxCategory(
      id: 'other_expense',
      name: 'Другое',
      icon: Icons.more_horiz_rounded,
      colorValue: 0xFF9AA8A0,
      isExpense: true,
    ),
  ];

  static const incomes = <TxCategory>[
    TxCategory(
      id: 'salary',
      name: 'Зарплата',
      icon: Icons.payments_rounded,
      colorValue: 0xFF2E7D52,
      isExpense: false,
    ),
    TxCategory(
      id: 'bonus',
      name: 'Премия',
      icon: Icons.star_rounded,
      colorValue: 0xFFFFC542,
      isExpense: false,
    ),
    TxCategory(
      id: 'gift',
      name: 'Подарок',
      icon: Icons.card_giftcard_rounded,
      colorValue: 0xFFD27B9C,
      isExpense: false,
    ),
    TxCategory(
      id: 'other_income',
      name: 'Другое',
      icon: Icons.more_horiz_rounded,
      colorValue: 0xFF9AA8A0,
      isExpense: false,
    ),
  ];

  static List<TxCategory> all() => [...expenses, ...incomes];

  static TxCategory? byId(String id) {
    for (final c in all()) {
      if (c.id == id) return c;
    }
    return null;
  }
}
