/// Riverpod state for the budget planner (План Доходов / Расходов / Факт).
///
/// Persists a single [BudgetPlanConfig] as a JSON map in Hive under the
/// `budget_plan_config` key. CRUD operations expose granular methods so the
/// UI never has to deal with the raw map.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget_planner.dart';
import '../services/storage.dart';

const _storageKey = 'budget_plan_config';

class BudgetPlannerController extends StateNotifier<BudgetPlanConfig> {
  BudgetPlannerController() : super(BudgetPlanConfig.empty()) {
    _load();
  }

  void _load() {
    final raw = AppStorage.readMap(_storageKey);
    if (raw != null) {
      state = BudgetPlanConfig.fromJson(raw);
    }
  }

  Future<void> _persist() async {
    await AppStorage.writeMap(_storageKey, state.toJson());
  }

  // ── Income Sources ──

  Future<void> addIncomeSource(IncomeSource source) async {
    state = BudgetPlanConfig(
      incomeSources: [...state.incomeSources, source],
      plannedExpenses: state.plannedExpenses,
      actualExpenses: state.actualExpenses,
    );
    await _persist();
  }

  Future<void> updateIncomeSource(String id, IncomeSource Function(IncomeSource) transform) async {
    state = BudgetPlanConfig(
      incomeSources: state.incomeSources.map((s) => s.id == id ? transform(s) : s).toList(),
      plannedExpenses: state.plannedExpenses,
      actualExpenses: state.actualExpenses,
    );
    await _persist();
  }

  Future<void> deleteIncomeSource(String id) async {
    state = BudgetPlanConfig(
      incomeSources: state.incomeSources.where((s) => s.id != id).toList(),
      plannedExpenses: state.plannedExpenses,
      actualExpenses: state.actualExpenses,
    );
    await _persist();
  }

  // ── Planned Expenses ──

  Future<void> addPlannedExpense(PlannedExpense expense) async {
    state = BudgetPlanConfig(
      incomeSources: state.incomeSources,
      plannedExpenses: [...state.plannedExpenses, expense],
      actualExpenses: state.actualExpenses,
    );
    await _persist();
  }

  Future<void> updatePlannedExpense(String id, PlannedExpense Function(PlannedExpense) transform) async {
    state = BudgetPlanConfig(
      incomeSources: state.incomeSources,
      plannedExpenses: state.plannedExpenses.map((e) => e.id == id ? transform(e) : e).toList(),
      actualExpenses: state.actualExpenses,
    );
    await _persist();
  }

  Future<void> deletePlannedExpense(String id) async {
    state = BudgetPlanConfig(
      incomeSources: state.incomeSources,
      plannedExpenses: state.plannedExpenses.where((e) => e.id != id).toList(),
      actualExpenses: state.actualExpenses,
    );
    await _persist();
  }

  Future<void> markExpensePaid(String id, {double? paidAmount}) async {
    await updatePlannedExpense(id, (e) => e.copyWith(
      isPaid: true,
      paidDate: DateTime.now().toIso8601String().substring(0, 10),
      paidAmount: paidAmount ?? e.amount,
    ));
  }

  Future<void> markExpenseUnpaid(String id) async {
    await updatePlannedExpense(id, (e) => e.copyWith(clearPaid: true));
  }

  // ── Actual Expenses ──

  Future<void> addActualExpense(ActualExpense expense) async {
    state = BudgetPlanConfig(
      incomeSources: state.incomeSources,
      plannedExpenses: state.plannedExpenses,
      actualExpenses: [...state.actualExpenses, expense],
    );
    await _persist();
  }

  Future<void> deleteActualExpense(String id) async {
    state = BudgetPlanConfig(
      incomeSources: state.incomeSources,
      plannedExpenses: state.plannedExpenses,
      actualExpenses: state.actualExpenses.where((e) => e.id != id).toList(),
    );
    await _persist();
  }

  /// Reset all expenses' paid status (for new month cycle).
  Future<void> resetMonthlyExpenseStatus() async {
    state = BudgetPlanConfig(
      incomeSources: state.incomeSources,
      plannedExpenses: state.plannedExpenses.map((e) => e.copyWith(clearPaid: true)).toList(),
      actualExpenses: state.actualExpenses,
    );
    await _persist();
  }
}

final budgetPlannerProvider =
    StateNotifierProvider<BudgetPlannerController, BudgetPlanConfig>((ref) {
  return BudgetPlannerController();
});
