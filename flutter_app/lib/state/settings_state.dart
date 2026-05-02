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

/// Water goal in ml (default 2000).
class WaterGoalController extends StateNotifier<int> {
  WaterGoalController() : super(2000) {
    final stored = AppStorage.readString(_key);
    if (stored != null) {
      state = int.tryParse(stored) ?? 2000;
    }
  }

  static const _key = 'waterGoal';

  Future<void> set(int goal) async {
    state = goal;
    await AppStorage.writeString(_key, goal.toString());
  }
}

final waterGoalProvider =
    StateNotifierProvider<WaterGoalController, int>((ref) {
  return WaterGoalController();
});

/// Water increment in ml (default 250).
class WaterIncrementController extends StateNotifier<int> {
  WaterIncrementController() : super(250) {
    final stored = AppStorage.readString(_key);
    if (stored != null) {
      state = int.tryParse(stored) ?? 250;
    }
  }

  static const _key = 'waterIncrement';

  Future<void> set(int increment) async {
    state = increment;
    await AppStorage.writeString(_key, increment.toString());
  }
}

final waterIncrementProvider =
    StateNotifierProvider<WaterIncrementController, int>((ref) {
  return WaterIncrementController();
});

/// Water visualization mode: 'glass' or 'bottle'.
class WaterVisualizationController extends StateNotifier<String> {
  WaterVisualizationController() : super('glass') {
    final stored = AppStorage.readString(_key);
    if (stored != null) state = stored;
  }

  static const _key = 'waterVisualization';

  Future<void> set(String mode) async {
    state = mode;
    await AppStorage.writeString(_key, mode);
  }
}

final waterVisualizationProvider =
    StateNotifierProvider<WaterVisualizationController, String>((ref) {
  return WaterVisualizationController();
});
