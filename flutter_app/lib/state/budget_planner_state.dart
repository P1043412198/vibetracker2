import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget_planner.dart';
import '../services/storage.dart';

const _storageKey = 'budget_plan_store';
const _legacyKey = 'budget_plan_config';

class BudgetPlannerController extends StateNotifier<BudgetPlanStore> {
  BudgetPlannerController() : super(BudgetPlanStore.empty()) {
    _load();
  }

  void _load() {
    final raw = AppStorage.readMap(_storageKey);
    if (raw != null) {
      state = BudgetPlanStore.fromJson(raw);
      return;
    }
    // Migrate from legacy single-config format.
    final legacy = AppStorage.readMap(_legacyKey);
    if (legacy != null) {
      state = BudgetPlanStore.migrateFromLegacy(legacy);
      _persist();
    }
  }

  Future<void> _persist() async {
    await AppStorage.writeMap(_storageKey, state.toJson());
  }

  BudgetPlanConfig get _current => state.currentMonth;

  BudgetPlanStore _withUpdatedMonth(BudgetPlanConfig updated) {
    final exists = state.months.any((m) => m.monthKey == updated.monthKey);
    final months = exists
        ? state.months
            .map((m) => m.monthKey == updated.monthKey ? updated : m)
            .toList()
        : [...state.months, updated];
    return BudgetPlanStore(
      months: months,
      selectedMonthKey: state.selectedMonthKey,
    );
  }

  // ── Month navigation ──

  void selectMonth(String monthKey) {
    state = BudgetPlanStore(
      months: state.months,
      selectedMonthKey: monthKey,
    );
  }

  /// Rollover current month's plan into [targetMonthKey].
  Future<void> rolloverToMonth(String targetMonthKey) async {
    final existing = state.months.any((m) => m.monthKey == targetMonthKey);
    if (existing) return;
    final rolled = _current.rolloverToMonth(targetMonthKey);
    state = BudgetPlanStore(
      months: [...state.months, rolled],
      selectedMonthKey: targetMonthKey,
    );
    await _persist();
  }

  // ── Income Sources ──

  Future<void> addIncomeSource(IncomeSource source) async {
    final updated = _current.copyWith(
      incomeSources: [..._current.incomeSources, source],
    );
    state = _withUpdatedMonth(updated);
    await _persist();
  }

  Future<void> updateIncomeSource(
      String id, IncomeSource Function(IncomeSource) transform) async {
    final updated = _current.copyWith(
      incomeSources:
          _current.incomeSources.map((s) => s.id == id ? transform(s) : s).toList(),
    );
    state = _withUpdatedMonth(updated);
    await _persist();
  }

  Future<void> deleteIncomeSource(String id) async {
    final updated = _current.copyWith(
      incomeSources: _current.incomeSources.where((s) => s.id != id).toList(),
    );
    state = _withUpdatedMonth(updated);
    await _persist();
  }

  // ── Planned Expenses ──

  Future<void> addPlannedExpense(PlannedExpense expense) async {
    final updated = _current.copyWith(
      plannedExpenses: [..._current.plannedExpenses, expense],
    );
    state = _withUpdatedMonth(updated);
    await _persist();
  }

  Future<void> updatePlannedExpense(
      String id, PlannedExpense Function(PlannedExpense) transform) async {
    final updated = _current.copyWith(
      plannedExpenses: _current.plannedExpenses
          .map((e) => e.id == id ? transform(e) : e)
          .toList(),
    );
    state = _withUpdatedMonth(updated);
    await _persist();
  }

  Future<void> deletePlannedExpense(String id) async {
    final updated = _current.copyWith(
      plannedExpenses:
          _current.plannedExpenses.where((e) => e.id != id).toList(),
    );
    state = _withUpdatedMonth(updated);
    await _persist();
  }

  Future<void> markExpensePaid(String id, {double? paidAmount}) async {
    await updatePlannedExpense(
      id,
      (e) => e.copyWith(
        isPaid: true,
        paidDate: DateTime.now().toIso8601String().substring(0, 10),
        paidAmount: paidAmount ?? e.amount,
      ),
    );
  }

  Future<void> markExpenseUnpaid(String id) async {
    await updatePlannedExpense(id, (e) => e.copyWith(clearPaid: true));
  }

  // ── Actual Expenses (manual entries) ──

  Future<void> addActualExpense(ActualExpense expense) async {
    final updated = _current.copyWith(
      actualExpenses: [..._current.actualExpenses, expense],
    );
    state = _withUpdatedMonth(updated);
    await _persist();
  }

  Future<void> deleteActualExpense(String id) async {
    final updated = _current.copyWith(
      actualExpenses:
          _current.actualExpenses.where((e) => e.id != id).toList(),
    );
    state = _withUpdatedMonth(updated);
    await _persist();
  }

  // ── Linked accounts ──

  Future<void> setLinkedAccounts(List<String> ids) async {
    final updated = _current.copyWith(linkedAccountIds: ids);
    state = _withUpdatedMonth(updated);
    await _persist();
  }

  /// Reset paid status for all planned expenses in current month.
  Future<void> resetMonthlyExpenseStatus() async {
    final updated = _current.copyWith(
      plannedExpenses: _current.plannedExpenses
          .map((e) => e.copyWith(clearPaid: true))
          .toList(),
    );
    state = _withUpdatedMonth(updated);
    await _persist();
  }
}

final budgetPlannerProvider =
    StateNotifierProvider<BudgetPlannerController, BudgetPlanStore>((ref) {
  return BudgetPlannerController();
});
