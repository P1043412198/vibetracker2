import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/budget_plan.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/storage_service.dart';
import '../utils/month_key.dart';

class AppState extends ChangeNotifier {
  AppState({StorageService? storage}) : _storage = storage ?? StorageService();

  final StorageService _storage;
  final _uuid = const Uuid();

  bool _loaded = false;
  bool get loaded => _loaded;

  bool _onboarded = false;
  bool get onboarded => _onboarded;

  String _userName = 'Друг';
  String get userName => _userName;

  final List<TxRecord> _transactions = [];
  List<TxRecord> get transactions => List.unmodifiable(_transactions);

  final Map<String, BudgetPlan> _plans = {};
  Map<String, BudgetPlan> get plans => Map.unmodifiable(_plans);

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime get selectedMonth => _selectedMonth;

  Future<void> load() async {
    final txs = await _storage.loadTransactions();
    final plans = await _storage.loadPlans();
    final name = await _storage.loadUserName();
    final onboarded = await _storage.loadOnboarded();

    _transactions
      ..clear()
      ..addAll(txs);
    _plans
      ..clear()
      ..addAll(plans);
    if (name != null && name.trim().isNotEmpty) _userName = name;
    _onboarded = onboarded;
    _loaded = true;
    _sortTransactions();
    notifyListeners();
  }

  Future<void> setOnboarded(bool value, {String? name}) async {
    _onboarded = value;
    if (name != null && name.trim().isNotEmpty) _userName = name.trim();
    await _storage.saveOnboarded(value);
    if (name != null && name.trim().isNotEmpty) {
      await _storage.saveUserName(name.trim());
    }
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name.trim().isEmpty ? 'Друг' : name.trim();
    await _storage.saveUserName(_userName);
    notifyListeners();
  }

  void selectMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  // --- Transactions ---
  Future<TxRecord> addTransaction({
    required TxType type,
    required double amount,
    required String categoryId,
    required DateTime date,
    String? account,
    String? store,
    String? comment,
  }) async {
    final tx = TxRecord(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      categoryId: categoryId,
      date: date,
      account: account,
      store: store,
      comment: comment,
    );
    _transactions.add(tx);
    _sortTransactions();
    await _storage.saveTransactions(_transactions);
    notifyListeners();
    return tx;
  }

  Future<void> updateTransaction(TxRecord tx) async {
    final i = _transactions.indexWhere((t) => t.id == tx.id);
    if (i == -1) return;
    _transactions[i] = tx;
    _sortTransactions();
    await _storage.saveTransactions(_transactions);
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await _storage.saveTransactions(_transactions);
    notifyListeners();
  }

  void _sortTransactions() {
    _transactions.sort((a, b) => b.date.compareTo(a.date));
  }

  // --- Plans ---
  BudgetPlan planFor(DateTime month) =>
      _plans[monthKeyFor(month)] ?? BudgetPlan.empty(monthKeyFor(month));

  Future<void> savePlan(BudgetPlan plan) async {
    _plans[plan.monthKey] = plan;
    await _storage.savePlans(_plans);
    notifyListeners();
  }

  Future<void> deletePlan(String monthKey) async {
    _plans.remove(monthKey);
    await _storage.savePlans(_plans);
    notifyListeners();
  }

  // --- Aggregations ---
  List<TxRecord> txInMonth(DateTime month) {
    return _transactions
        .where((t) =>
            t.date.year == month.year && t.date.month == month.month)
        .toList();
  }

  double totalIncomeIn(DateTime month) => txInMonth(month)
      .where((t) => t.type == TxType.income)
      .fold(0.0, (a, b) => a + b.amount);

  double totalExpenseIn(DateTime month) => txInMonth(month)
      .where((t) => t.type == TxType.expense)
      .fold(0.0, (a, b) => a + b.amount);

  Map<String, double> expenseByCategoryIn(DateTime month) {
    final map = <String, double>{};
    for (final t in txInMonth(month)) {
      if (t.type != TxType.expense) continue;
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amount;
    }
    return map;
  }

  /// daily expense totals for a given month [date.day -> amount]
  Map<int, double> dailyExpenseIn(DateTime month) {
    final map = <int, double>{};
    for (final t in txInMonth(month)) {
      if (t.type != TxType.expense) continue;
      map[t.date.day] = (map[t.date.day] ?? 0) + t.amount;
    }
    return map;
  }

  Future<void> wipeAll() async {
    _transactions.clear();
    _plans.clear();
    _userName = 'Друг';
    _onboarded = false;
    await _storage.wipeAll();
    notifyListeners();
  }

  /// Seed a small demo set so first launch isn't empty (only when no data exists).
  Future<void> seedDemoIfEmpty() async {
    if (_transactions.isNotEmpty || _plans.isNotEmpty) return;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final mk = monthKeyFor(now);

    final demoPlan = BudgetPlan(
      monthKey: mk,
      incomePlan: 65000,
      categoryPlans: {
        'food': 12000,
        'cafes': 4500,
        'transport': 3500,
        'shopping': 5000,
        'health': 2500,
        'entertainment': 2500,
        'home': 3000,
      },
    );
    _plans[mk] = demoPlan;

    DateTime mkDate(int day, [int hour = 12]) =>
        DateTime(monthStart.year, monthStart.month, day, hour);

    final demoDay = (now.day < 5) ? 1 : (now.day - 1);

    final demoTx = <TxRecord>[
      TxRecord(
        id: _uuid.v4(),
        type: TxType.income,
        amount: 45000,
        categoryId: 'salary',
        date: mkDate(1, 10),
        comment: 'Аванс',
      ),
      TxRecord(
        id: _uuid.v4(),
        type: TxType.expense,
        amount: 1245,
        categoryId: 'food',
        date: mkDate(demoDay, 14),
        store: 'Пятёрочка',
      ),
      TxRecord(
        id: _uuid.v4(),
        type: TxType.expense,
        amount: 320,
        categoryId: 'cafes',
        date: mkDate(demoDay, 9),
        store: 'Кофе с собой',
      ),
      TxRecord(
        id: _uuid.v4(),
        type: TxType.expense,
        amount: 2450,
        categoryId: 'shopping',
        date: mkDate((demoDay - 1).clamp(1, 28), 18),
        store: 'OZON',
      ),
      TxRecord(
        id: _uuid.v4(),
        type: TxType.expense,
        amount: 560,
        categoryId: 'transport',
        date: mkDate((demoDay - 1).clamp(1, 28), 8),
        store: 'Яндекс.Такси',
      ),
      TxRecord(
        id: _uuid.v4(),
        type: TxType.expense,
        amount: 890,
        categoryId: 'health',
        date: mkDate((demoDay - 2).clamp(1, 28), 17),
        store: 'Аптека',
      ),
    ];

    _transactions.addAll(demoTx);
    _sortTransactions();

    await _storage.saveTransactions(_transactions);
    await _storage.savePlans(_plans);
    notifyListeners();
  }

  /// All known category IDs across known categories + ones used in transactions/plans.
  List<String> knownExpenseCategoryIds() {
    final set = <String>{};
    for (final c in DefaultCategories.expenses) {
      set.add(c.id);
    }
    for (final t in _transactions) {
      if (t.type == TxType.expense) set.add(t.categoryId);
    }
    for (final p in _plans.values) {
      set.addAll(p.categoryPlans.keys);
    }
    return set.toList();
  }
}
