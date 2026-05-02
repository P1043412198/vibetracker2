import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage.dart';

/// Persisted theme-mode toggle (system/light/dark).
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    final stored = AppStorage.readString(_key);
    if (stored != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.system,
      );
    }
  }

  static const _key = 'themeMode';

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await AppStorage.writeString(_key, mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});

/// Default currency used in finance screens (mirrors React `defaultCurrency`).
final defaultCurrencyProvider = StateProvider<String>((ref) {
  return AppStorage.readString('defaultCurrency') ?? 'BYN';
});
