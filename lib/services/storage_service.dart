import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget_plan.dart';
import '../models/transaction.dart';

class StorageService {
  static const _kTx = 'finflow.transactions';
  static const _kPlans = 'finflow.plans';
  static const _kUserName = 'finflow.userName';
  static const _kOnboarded = 'finflow.onboarded';

  Future<List<TxRecord>> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTx);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => TxRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTransactions(List<TxRecord> txs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(txs.map((t) => t.toJson()).toList());
    await prefs.setString(_kTx, encoded);
  }

  Future<Map<String, BudgetPlan>> loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlans);
    if (raw == null || raw.isEmpty) return {};
    final list = jsonDecode(raw) as List;
    final plans = <String, BudgetPlan>{};
    for (final entry in list) {
      final plan = BudgetPlan.fromJson(entry as Map<String, dynamic>);
      plans[plan.monthKey] = plan;
    }
    return plans;
  }

  Future<void> savePlans(Map<String, BudgetPlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(plans.values.map((p) => p.toJson()).toList());
    await prefs.setString(_kPlans, encoded);
  }

  Future<String?> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserName);
  }

  Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserName, name);
  }

  Future<bool> loadOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboarded) ?? false;
  }

  Future<void> saveOnboarded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarded, value);
  }

  Future<void> wipeAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTx);
    await prefs.remove(_kPlans);
    await prefs.remove(_kUserName);
    await prefs.remove(_kOnboarded);
  }
}
