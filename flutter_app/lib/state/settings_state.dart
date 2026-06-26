import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_config.dart';
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

/// Untouchable reserve kept aside in the safe-to-spend forecast (base
/// currency). User-configurable; default 0 (spend down to zero).
class SafeToSpendReserveController extends StateNotifier<double> {
  SafeToSpendReserveController() : super(0) {
    final stored = AppStorage.readString(_key);
    if (stored != null) {
      state = double.tryParse(stored) ?? 0;
    }
  }

  static const _key = 'safeToSpendReserve';

  Future<void> set(double amount) async {
    final value = amount < 0 ? 0.0 : amount;
    state = value;
    await AppStorage.writeString(_key, value.toString());
  }
}

final safeToSpendReserveProvider =
    StateNotifierProvider<SafeToSpendReserveController, double>((ref) {
  return SafeToSpendReserveController();
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

/// Persisted dashboard layout: visible widgets and their order.
class DashboardConfigController extends StateNotifier<DashboardConfig> {
  DashboardConfigController() : super(DashboardConfig.defaultConfig()) {
    final stored = AppStorage.readString(_key);
    if (stored != null && stored.isNotEmpty) {
      try {
        final decoded = json.decode(stored);
        if (decoded is Map<String, dynamic>) {
          state = DashboardConfig.fromJson(decoded);
        }
      } catch (_) {
        // Fall back to default if persisted JSON is corrupt.
      }
    }
  }

  static const _key = 'dashboardConfig';

  Future<void> _persist() async {
    await AppStorage.writeString(_key, json.encode(state.toJson()));
  }

  Future<void> reorder(List<String> ids) async {
    state = state.copyWith(widgetsOrder: ids);
    await _persist();
  }

  Future<void> setVisible(String id, bool visible) async {
    final next = <String>{
      if (visible) ...state.widgetsOrder.where(state.visibleWidgets.contains),
      if (visible) id,
      if (!visible) ...state.visibleWidgets.where((e) => e != id),
    }.toList();
    // Re-sort visible by current order.
    next.sort((a, b) =>
        state.widgetsOrder.indexOf(a).compareTo(state.widgetsOrder.indexOf(b)));
    state = state.copyWith(visibleWidgets: next);
    await _persist();
  }

  Future<void> resetToDefault() async {
    state = DashboardConfig.defaultConfig();
    await _persist();
  }
}

final dashboardConfigProvider =
    StateNotifierProvider<DashboardConfigController, DashboardConfig>((ref) {
  return DashboardConfigController();
});

/// Persisted UI locale override. `null` means "follow system".
class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null) {
    final stored = AppStorage.readString(_key);
    if (stored != null && stored.isNotEmpty) {
      state = Locale(stored);
    }
  }

  static const _key = 'appLocale';

  Future<void> set(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await AppStorage.writeString(_key, '');
    } else {
      await AppStorage.writeString(_key, locale.languageCode);
    }
  }
}

final localeProvider =
    StateNotifierProvider<LocaleController, Locale?>((ref) {
  return LocaleController();
});

/// AI features on/off toggle (default: on when key is present).
class AiEnabledController extends StateNotifier<bool> {
  AiEnabledController() : super(true) {
    final stored = AppStorage.readString(_key);
    if (stored != null) state = stored == 'true';
  }

  static const _key = 'aiEnabled';

  Future<void> set(bool enabled) async {
    state = enabled;
    await AppStorage.writeString(_key, enabled.toString());
  }
}

final aiEnabledProvider =
    StateNotifierProvider<AiEnabledController, bool>((ref) {
  return AiEnabledController();
});

/// Whether Claude can execute tools (write to user data: add/delete tasks,
/// transactions, habits, etc.). Default: enabled — the user explicitly
/// asked for full CRUD access via the chat.
class ClaudeToolsEnabledController extends StateNotifier<bool> {
  ClaudeToolsEnabledController() : super(true) {
    final stored = AppStorage.readString(_key);
    if (stored != null) state = stored == 'true';
  }

  static const _key = 'claudeToolsEnabled';

  Future<void> set(bool enabled) async {
    state = enabled;
    await AppStorage.writeString(_key, enabled.toString());
  }
}

final claudeToolsEnabledProvider =
    StateNotifierProvider<ClaudeToolsEnabledController, bool>((ref) {
  return ClaudeToolsEnabledController();
});

/// PIN-code lock. Stores a 4-digit code in plaintext (low-security: this is a
/// privacy gate against casual snooping, not a cryptographic vault).
class PinLockController extends StateNotifier<PinLockState> {
  PinLockController()
      : super(PinLockState(
          pin: AppStorage.readString(_pinKey),
          // Always start locked if a PIN is set.
          locked: AppStorage.readString(_pinKey)?.isNotEmpty ?? false,
        ));

  static const _pinKey = 'pinCode';

  Future<void> setPin(String? pin) async {
    if (pin == null || pin.isEmpty) {
      await AppStorage.box.delete(_pinKey);
      state = PinLockState(pin: null, locked: false);
    } else {
      await AppStorage.writeString(_pinKey, pin);
      state = PinLockState(pin: pin, locked: state.locked);
    }
  }

  void lock() {
    if (state.pin != null && state.pin!.isNotEmpty) {
      state = PinLockState(pin: state.pin, locked: true);
    }
  }

  bool tryUnlock(String input) {
    if (state.pin == null) {
      state = PinLockState(pin: null, locked: false);
      return true;
    }
    if (input == state.pin) {
      state = PinLockState(pin: state.pin, locked: false);
      return true;
    }
    return false;
  }

  /// Mark the app as unlocked after a successful biometric prompt without
  /// requiring the PIN to be re-entered. The PIN remains stored as a
  /// fallback for devices where biometric auth is unavailable.
  void tryUnlockBiometric() {
    state = PinLockState(pin: state.pin, locked: false);
  }
}

class PinLockState {
  PinLockState({required this.pin, required this.locked});
  final String? pin;
  final bool locked;

  bool get hasPin => pin != null && pin!.isNotEmpty;
}

final pinLockProvider =
    StateNotifierProvider<PinLockController, PinLockState>((ref) {
  return PinLockController();
});
