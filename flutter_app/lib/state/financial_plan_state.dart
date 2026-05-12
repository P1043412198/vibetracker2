import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/financial_plan.dart';
import '../services/storage.dart';

const String _kFinancialPlanConfigKey = 'financial_plan_config_v1';

/// Persistent Riverpod controller for [FinancialPlanConfig].
///
/// Mirrors the React app's Zustand+persist pattern: load on construction
/// from [AppStorage], write back through [box] on every state change.
class FinancialPlanConfigController extends StateNotifier<FinancialPlanConfig> {
  FinancialPlanConfigController() : super(_load()) {
    // No-op — _load already populated state.
  }

  static FinancialPlanConfig _load() {
    final raw = AppStorage.box.get(_kFinancialPlanConfigKey);
    if (raw == null || raw.isEmpty) return FinancialPlanConfig.defaults();
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return FinancialPlanConfig.fromJson(decoded);
      }
    } catch (_) {
      // Fall through to defaults.
    }
    return FinancialPlanConfig.defaults();
  }

  Future<void> _save() async {
    await AppStorage.box.put(
      _kFinancialPlanConfigKey,
      json.encode(state.toJson()),
    );
  }

  Future<void> update(FinancialPlanConfig next) async {
    state = next;
    await _save();
  }

  Future<void> resetToDefaults() async {
    state = FinancialPlanConfig.defaults();
    await _save();
  }

  Future<void> updateScenario(String id, SavingsScenario next) async {
    final scenarios = state.scenarios
        .map((s) => s.id == id ? next : s)
        .toList(growable: false);
    state = state.copyWith(scenarios: scenarios);
    await _save();
  }

  Future<void> updatePortfolio(List<PortfolioAllocation> next) async {
    state = state.copyWith(portfolio: next);
    await _save();
  }
}

final financialPlanConfigProvider = StateNotifierProvider<
    FinancialPlanConfigController, FinancialPlanConfig>((ref) {
  return FinancialPlanConfigController();
});
