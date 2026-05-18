import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/finance.dart';
import '../models/goal.dart';
import '../models/habit.dart';
import '../models/misc.dart';
import '../models/sphere.dart';
import '../models/task.dart';
import '../state/providers.dart';

const _uuid = Uuid();

/// A single tool that Claude can call.
class ClaudeTool {
  const ClaudeTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final Future<String> Function(Ref ref, Map<String, dynamic> args) handler;

  Map<String, dynamic> toApiJson() => {
        'name': name,
        'description': description,
        'input_schema': inputSchema,
      };
}

String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());
String _now() => DateTime.now().toIso8601String();

/// All registered tools available to Claude.
final List<ClaudeTool> claudeToolRegistry = [
  // ─────────────────────── TASKS ───────────────────────
  ClaudeTool(
    name: 'list_tasks',
    description: 'Получить список задач. Можно отфильтровать по дате, статусу, периоду.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'date': {'type': 'string', 'description': 'ISO date (yyyy-MM-dd). Если не указано — все.'},
        'completed': {'type': 'boolean', 'description': 'Фильтр: только выполненные / невыполненные.'},
        'period': {'type': 'string', 'enum': ['day', 'week', 'month', 'year', 'history']},
      },
    },
    handler: (ref, args) async {
      var tasks = ref.read(tasksProvider);
      final date = args['date'] as String?;
      final completed = args['completed'] as bool?;
      final period = args['period'] as String?;
      if (date != null) tasks = tasks.where((t) => t.date == date).toList();
      if (completed != null) tasks = tasks.where((t) => t.completed == completed).toList();
      if (period != null) tasks = tasks.where((t) => t.period.name == period).toList();
      final list = tasks.map((t) => {
        'id': t.id,
        'title': t.title,
        'date': t.date,
        'completed': t.completed,
        'period': t.period.name,
        if (t.priority != null) 'priority': t.priority!.name,
        if (t.sphereId != null) 'sphereId': t.sphereId,
      }).toList();
      return jsonEncode({'count': list.length, 'tasks': list});
    },
  ),
  ClaudeTool(
    name: 'add_task',
    description: 'Создать новую задачу.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string', 'description': 'Название задачи'},
        'date': {'type': 'string', 'description': 'ISO date (yyyy-MM-dd). По умолчанию сегодня.'},
        'period': {'type': 'string', 'enum': ['day', 'week', 'month', 'year', 'history'], 'description': 'По умолчанию day.'},
        'priority': {'type': 'string', 'enum': ['urgent_important', 'important', 'urgent', 'later']},
        'sphereId': {'type': 'string', 'description': 'ID сферы-контекста'},
      },
      'required': ['title'],
    },
    handler: (ref, args) async {
      final task = TaskItem(
        id: _uuid.v4(),
        title: args['title'] as String,
        date: (args['date'] as String?) ?? _today(),
        period: enumFromName(TaskPeriod.values, args['period'] as String?, TaskPeriod.day),
        completed: false,
        failed: false,
        createdAt: _now(),
        priority: args['priority'] != null
            ? enumFromName(TaskPriority.values, args['priority'] as String?, TaskPriority.later)
            : null,
        sphereId: args['sphereId'] as String?,
      );
      await ref.read(tasksProvider.notifier).add(task);
      return jsonEncode({'ok': true, 'id': task.id, 'title': task.title});
    },
  ),
  ClaudeTool(
    name: 'complete_task',
    description: 'Отметить задачу как выполненную (или снять отметку).',
    inputSchema: {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'ID задачи'},
      },
      'required': ['id'],
    },
    handler: (ref, args) async {
      final id = args['id'] as String;
      await ref.read(tasksProvider.notifier).toggleCompleted(id);
      final t = ref.read(tasksProvider).where((t) => t.id == id).firstOrNull;
      return jsonEncode({'ok': true, 'id': id, 'completed': t?.completed ?? true});
    },
  ),
  ClaudeTool(
    name: 'delete_task',
    description: 'Удалить задачу по ID.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'id': {'type': 'string'},
      },
      'required': ['id'],
    },
    handler: (ref, args) async {
      await ref.read(tasksProvider.notifier).remove(args['id'] as String);
      return jsonEncode({'ok': true, 'deleted': args['id']});
    },
  ),

  // ─────────────────────── HABITS ───────────────────────
  ClaudeTool(
    name: 'list_habits',
    description: 'Получить список всех привычек.',
    inputSchema: {'type': 'object', 'properties': {}},
    handler: (ref, args) async {
      final habits = ref.read(habitsProvider);
      final list = habits.map((h) => {
        'id': h.id,
        'title': h.title,
        'type': h.type.name,
        if (h.targetValue != null) 'targetValue': h.targetValue,
        if (h.unit != null) 'unit': h.unit,
        if (h.frequency != null) 'frequency': h.frequency!.type.name,
      }).toList();
      return jsonEncode({'count': list.length, 'habits': list});
    },
  ),
  ClaudeTool(
    name: 'add_habit',
    description: 'Создать новую привычку.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'type': {'type': 'string', 'enum': ['good', 'bad'], 'description': 'По умолчанию good.'},
        'targetValue': {'type': 'number', 'description': 'Цель для измеримой привычки (опционально)'},
        'unit': {'type': 'string', 'description': 'Единица (л, км, мин, раз)'},
        'frequency': {'type': 'string', 'enum': ['daily', 'specific_days', 'times_per_week']},
      },
      'required': ['title'],
    },
    handler: (ref, args) async {
      final h = Habit(
        id: _uuid.v4(),
        title: args['title'] as String,
        type: enumFromName(HabitTypeKind.values, args['type'] as String?, HabitTypeKind.good),
        createdAt: _now(),
        targetValue: args['targetValue'] as num?,
        unit: args['unit'] as String?,
        frequency: args['frequency'] != null
            ? HabitFrequency(type: enumFromName(HabitFrequencyType.values, args['frequency'] as String?, HabitFrequencyType.daily))
            : null,
      );
      await ref.read(habitsProvider.notifier).add(h);
      return jsonEncode({'ok': true, 'id': h.id, 'title': h.title});
    },
  ),
  ClaudeTool(
    name: 'mark_habit',
    description: 'Отметить выполнение привычки за дату (done/failed/skipped).',
    inputSchema: {
      'type': 'object',
      'properties': {
        'habitId': {'type': 'string'},
        'date': {'type': 'string', 'description': 'ISO date. По умолчанию сегодня.'},
        'status': {'type': 'string', 'enum': ['done', 'failed', 'skipped']},
        'value': {'type': 'number', 'description': 'Значение для измеримой привычки'},
      },
      'required': ['habitId'],
    },
    handler: (ref, args) async {
      final log = HabitLog(
        id: _uuid.v4(),
        habitId: args['habitId'] as String,
        date: (args['date'] as String?) ?? _today(),
        status: enumFromName(HabitLogStatus.values, args['status'] as String?, HabitLogStatus.done),
        notes: '',
        feelings: '',
        value: args['value'] as num?,
      );
      await ref.read(habitLogsProvider.notifier).add(log);
      return jsonEncode({'ok': true, 'logId': log.id, 'habitId': log.habitId, 'status': log.status.name});
    },
  ),
  ClaudeTool(
    name: 'delete_habit',
    description: 'Удалить привычку по ID.',
    inputSchema: {
      'type': 'object',
      'properties': {'id': {'type': 'string'}},
      'required': ['id'],
    },
    handler: (ref, args) async {
      await ref.read(habitsProvider.notifier).remove(args['id'] as String);
      return jsonEncode({'ok': true, 'deleted': args['id']});
    },
  ),
  ClaudeTool(
    name: 'get_habit_stats',
    description: 'Получить статистику привычки: стрик, всего отметок, процент выполнения.',
    inputSchema: {
      'type': 'object',
      'properties': {'habitId': {'type': 'string'}},
      'required': ['habitId'],
    },
    handler: (ref, args) async {
      final habitId = args['habitId'] as String;
      final logs = ref.read(habitLogsProvider).where((l) => l.habitId == habitId).toList();
      logs.sort((a, b) => b.date.compareTo(a.date));
      int streak = 0;
      final today = _today();
      var checkDate = DateTime.parse(today);
      for (final log in logs) {
        final logDate = DateFormat('yyyy-MM-dd').format(checkDate);
        if (log.date == logDate && log.status == HabitLogStatus.done) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
      final done = logs.where((l) => l.status == HabitLogStatus.done).length;
      return jsonEncode({
        'habitId': habitId,
        'totalLogs': logs.length,
        'doneCount': done,
        'currentStreak': streak,
        'completionRate': logs.isEmpty ? 0 : (done / logs.length * 100).round(),
      });
    },
  ),

  // ─────────────────────── TRANSACTIONS / FINANCE ───────────────────────
  ClaudeTool(
    name: 'list_transactions',
    description: 'Получить транзакции. Опционально за период или по категории.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'from': {'type': 'string', 'description': 'ISO date начала периода'},
        'to': {'type': 'string', 'description': 'ISO date конца периода'},
        'type': {'type': 'string', 'enum': ['income', 'expense', 'transfer']},
        'category': {'type': 'string'},
        'limit': {'type': 'integer', 'description': 'Макс кол-во (по умолчанию 50)'},
      },
    },
    handler: (ref, args) async {
      var txns = ref.read(transactionsProvider);
      final from = args['from'] as String?;
      final to = args['to'] as String?;
      final type = args['type'] as String?;
      final category = args['category'] as String?;
      final limit = (args['limit'] as num?)?.toInt() ?? 50;
      if (from != null) txns = txns.where((t) => t.date.compareTo(from) >= 0).toList();
      if (to != null) txns = txns.where((t) => t.date.compareTo(to) <= 0).toList();
      if (type != null) txns = txns.where((t) => t.type.name == type).toList();
      if (category != null) txns = txns.where((t) => t.category == category).toList();
      txns.sort((a, b) => b.date.compareTo(a.date));
      final limited = txns.take(limit).toList();
      final list = limited.map((t) => {
        'id': t.id,
        'type': t.type.name,
        'amount': t.amount,
        'category': t.category,
        'date': t.date,
        if (t.notes != null) 'notes': t.notes,
        if (t.accountId != null) 'accountId': t.accountId,
      }).toList();
      return jsonEncode({'count': list.length, 'total': txns.length, 'transactions': list});
    },
  ),
  ClaudeTool(
    name: 'add_transaction',
    description: 'Добавить транзакцию (расход, доход или перевод).',
    inputSchema: {
      'type': 'object',
      'properties': {
        'type': {'type': 'string', 'enum': ['income', 'expense', 'transfer']},
        'amount': {'type': 'number'},
        'category': {'type': 'string'},
        'date': {'type': 'string', 'description': 'ISO date. По умолчанию сегодня.'},
        'notes': {'type': 'string'},
        'accountId': {'type': 'string'},
      },
      'required': ['type', 'amount', 'category'],
    },
    handler: (ref, args) async {
      final txn = Transaction(
        id: _uuid.v4(),
        type: enumFromName(TransactionType.values, args['type'] as String?, TransactionType.expense),
        amount: args['amount'] as num,
        category: args['category'] as String,
        date: (args['date'] as String?) ?? _today(),
        notes: args['notes'] as String?,
        accountId: args['accountId'] as String?,
      );
      await ref.read(transactionsProvider.notifier).add(txn);
      return jsonEncode({'ok': true, 'id': txn.id, 'amount': txn.amount, 'category': txn.category});
    },
  ),
  ClaudeTool(
    name: 'delete_transaction',
    description: 'Удалить транзакцию по ID.',
    inputSchema: {
      'type': 'object',
      'properties': {'id': {'type': 'string'}},
      'required': ['id'],
    },
    handler: (ref, args) async {
      await ref.read(transactionsProvider.notifier).remove(args['id'] as String);
      return jsonEncode({'ok': true, 'deleted': args['id']});
    },
  ),
  ClaudeTool(
    name: 'get_budget_summary',
    description: 'Получить сводку бюджета за текущий месяц: доходы, расходы, баланс, по категориям.',
    inputSchema: {'type': 'object', 'properties': {}},
    handler: (ref, args) async {
      final now = DateTime.now();
      final monthKey = DateFormat('yyyy-MM').format(now);
      final txns = ref.read(transactionsProvider)
          .where((t) => t.date.startsWith(monthKey))
          .toList();
      num totalIncome = 0, totalExpense = 0;
      final byCategory = <String, num>{};
      for (final t in txns) {
        if (t.type == TransactionType.income) {
          totalIncome += t.amount;
        } else if (t.type == TransactionType.expense) {
          totalExpense += t.amount;
          byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
        }
      }
      return jsonEncode({
        'month': monthKey,
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'balance': totalIncome - totalExpense,
        'expenseByCategory': byCategory,
        'transactionCount': txns.length,
      });
    },
  ),
  ClaudeTool(
    name: 'list_accounts',
    description: 'Получить список финансовых счетов.',
    inputSchema: {'type': 'object', 'properties': {}},
    handler: (ref, args) async {
      final accs = ref.read(accountsProvider);
      final list = accs.map((a) => {
        'id': a.id,
        'name': a.name,
        'type': a.type.name,
        'currency': a.currency,
        'initialBalance': a.initialBalance,
      }).toList();
      return jsonEncode({'count': list.length, 'accounts': list});
    },
  ),
  ClaudeTool(
    name: 'add_account',
    description: 'Создать новый финансовый счёт (карта, наличные, депозит и т.д.).',
    inputSchema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'type': {'type': 'string', 'enum': ['card', 'cash', 'deposit', 'crypto', 'installment', 'other']},
        'currency': {'type': 'string', 'description': 'По умолчанию BYN'},
        'initialBalance': {'type': 'number', 'description': 'Начальный баланс. По умолчанию 0.'},
      },
      'required': ['name'],
    },
    handler: (ref, args) async {
      final acc = Account(
        id: _uuid.v4(),
        name: args['name'] as String,
        type: enumFromName(AccountType.values, args['type'] as String?, AccountType.card),
        currency: (args['currency'] as String?) ?? 'BYN',
        initialBalance: (args['initialBalance'] as num?) ?? 0,
        color: '#6D5CFF',
        createdAt: _now(),
      );
      await ref.read(accountsProvider.notifier).add(acc);
      return jsonEncode({'ok': true, 'id': acc.id, 'name': acc.name});
    },
  ),
  ClaudeTool(
    name: 'delete_account',
    description: 'Удалить финансовый счёт по ID.',
    inputSchema: {
      'type': 'object',
      'properties': {'id': {'type': 'string'}},
      'required': ['id'],
    },
    handler: (ref, args) async {
      await ref.read(accountsProvider.notifier).remove(args['id'] as String);
      return jsonEncode({'ok': true, 'deleted': args['id']});
    },
  ),

  // ─────────────────────── LOANS ───────────────────────
  ClaudeTool(
    name: 'list_loans',
    description: 'Получить список кредитов.',
    inputSchema: {'type': 'object', 'properties': {}},
    handler: (ref, args) async {
      final loans = ref.read(loansProvider);
      final list = loans.map((l) => {
        'id': l.id,
        'title': l.title,
        'principal': l.principal,
        'balance': l.balance,
        'annualRate': l.annualRate,
        'monthlyPayment': l.monthlyPayment,
        'currency': l.currency,
        if (l.kind != null) 'kind': l.kind,
      }).toList();
      return jsonEncode({'count': list.length, 'loans': list});
    },
  ),
  ClaudeTool(
    name: 'add_loan',
    description: 'Добавить новый кредит.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'principal': {'type': 'number', 'description': 'Сумма кредита'},
        'balance': {'type': 'number', 'description': 'Текущий остаток (если не указан = principal)'},
        'annualRate': {'type': 'number', 'description': 'Годовая ставка в %'},
        'monthlyPayment': {'type': 'number', 'description': 'Ежемесячный платёж'},
        'currency': {'type': 'string'},
        'kind': {'type': 'string', 'enum': ['consumer', 'mortgage', 'card', 'auto', 'personal', 'other']},
        'paymentDay': {'type': 'integer', 'description': 'День месяца платежа (1-31)'},
      },
      'required': ['title', 'principal', 'annualRate', 'monthlyPayment'],
    },
    handler: (ref, args) async {
      final loan = Loan(
        id: _uuid.v4(),
        title: args['title'] as String,
        principal: args['principal'] as num,
        balance: (args['balance'] as num?) ?? (args['principal'] as num),
        annualRate: args['annualRate'] as num,
        monthlyPayment: args['monthlyPayment'] as num,
        startDate: _today(),
        currency: (args['currency'] as String?) ?? 'BYN',
        kind: args['kind'] as String?,
        paymentDay: (args['paymentDay'] as num?)?.toInt(),
      );
      await ref.read(loansProvider.notifier).add(loan);
      return jsonEncode({'ok': true, 'id': loan.id, 'title': loan.title});
    },
  ),
  ClaudeTool(
    name: 'add_loan_payment',
    description: 'Записать платёж по кредиту.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'loanId': {'type': 'string'},
        'amount': {'type': 'number'},
        'date': {'type': 'string', 'description': 'ISO date. По умолчанию сегодня.'},
        'principalPart': {'type': 'number'},
        'interestPart': {'type': 'number'},
      },
      'required': ['loanId', 'amount'],
    },
    handler: (ref, args) async {
      final payment = LoanPayment(
        id: _uuid.v4(),
        loanId: args['loanId'] as String,
        date: (args['date'] as String?) ?? _today(),
        amount: args['amount'] as num,
        principalPart: args['principalPart'] as num?,
        interestPart: args['interestPart'] as num?,
      );
      await ref.read(loanPaymentsProvider.notifier).add(payment);
      return jsonEncode({'ok': true, 'id': payment.id, 'loanId': payment.loanId, 'amount': payment.amount});
    },
  ),

  // ─────────────────────── GOALS ───────────────────────
  ClaudeTool(
    name: 'list_goals',
    description: 'Получить список целей.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'status': {'type': 'string', 'enum': ['not_started', 'in_progress', 'completed']},
      },
    },
    handler: (ref, args) async {
      var goals = ref.read(goalsProvider);
      final status = args['status'] as String?;
      if (status != null) goals = goals.where((g) => g.status.name == status).toList();
      final list = goals.map((g) => {
        'id': g.id,
        'title': g.title,
        'status': g.status.name,
        'type': g.type.name,
        if (g.deadline != null) 'deadline': g.deadline,
        if (g.progress != null) 'progress': g.progress,
        if (g.targetValue != null) 'targetValue': g.targetValue,
        if (g.currentValue != null) 'currentValue': g.currentValue,
        'stepsTotal': g.steps.length,
        'stepsCompleted': g.steps.where((s) => s.completed).length,
      }).toList();
      return jsonEncode({'count': list.length, 'goals': list});
    },
  ),
  ClaudeTool(
    name: 'add_goal',
    description: 'Создать новую цель.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'description': {'type': 'string'},
        'type': {'type': 'string', 'enum': ['goal', 'skill', 'book', 'learning']},
        'deadline': {'type': 'string', 'description': 'ISO date дедлайна'},
        'targetValue': {'type': 'number', 'description': 'Целевое значение (для измеримых целей)'},
      },
      'required': ['title'],
    },
    handler: (ref, args) async {
      final goal = Goal(
        id: _uuid.v4(),
        title: args['title'] as String,
        description: args['description'] as String?,
        type: enumFromName(GoalType.values, args['type'] as String?, GoalType.goal),
        status: GoalStatus.not_started,
        steps: const [],
        createdAt: _now(),
        deadline: args['deadline'] as String?,
        targetValue: args['targetValue'] as num?,
        currentValue: 0,
      );
      await ref.read(goalsProvider.notifier).add(goal);
      return jsonEncode({'ok': true, 'id': goal.id, 'title': goal.title});
    },
  ),
  ClaudeTool(
    name: 'update_goal_progress',
    description: 'Обновить прогресс цели: числовое значение или статус.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'id': {'type': 'string'},
        'currentValue': {'type': 'number'},
        'status': {'type': 'string', 'enum': ['not_started', 'in_progress', 'completed']},
      },
      'required': ['id'],
    },
    handler: (ref, args) async {
      final id = args['id'] as String;
      final currentValue = args['currentValue'] as num?;
      final status = args['status'] as String?;
      await ref.read(goalsProvider.notifier).update(id, (g) {
        num? progress;
        final cv = currentValue ?? g.currentValue;
        if (cv != null && g.targetValue != null && g.targetValue! > 0) {
          progress = (cv / g.targetValue! * 100).clamp(0, 100);
        }
        return g.copyWith(
          currentValue: currentValue,
          status: status != null ? enumFromName(GoalStatus.values, status, g.status) : null,
          progress: progress,
        );
      });
      return jsonEncode({'ok': true, 'id': id});
    },
  ),
  ClaudeTool(
    name: 'add_milestone',
    description: 'Добавить веху (milestone) к цели.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'goalId': {'type': 'string'},
        'title': {'type': 'string'},
        'date': {'type': 'string', 'description': 'ISO date (опционально)'},
      },
      'required': ['goalId', 'title'],
    },
    handler: (ref, args) async {
      final goalId = args['goalId'] as String;
      final milestone = Milestone(
        id: _uuid.v4(),
        title: args['title'] as String,
        date: args['date'] as String?,
      );
      await ref.read(goalsProvider.notifier).update(goalId, (g) {
        return g.copyWith(milestones: [...(g.milestones ?? []), milestone]);
      });
      return jsonEncode({'ok': true, 'milestoneId': milestone.id, 'goalId': goalId});
    },
  ),

  // ─────────────────────── SLEEP ───────────────────────
  ClaudeTool(
    name: 'list_sleep',
    description: 'Получить записи сна. Опционально за период.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'from': {'type': 'string'},
        'to': {'type': 'string'},
        'limit': {'type': 'integer'},
      },
    },
    handler: (ref, args) async {
      var logs = ref.read(sleepLogsProvider);
      final from = args['from'] as String?;
      final to = args['to'] as String?;
      final limit = (args['limit'] as num?)?.toInt() ?? 30;
      if (from != null) logs = logs.where((l) => l.date.compareTo(from) >= 0).toList();
      if (to != null) logs = logs.where((l) => l.date.compareTo(to) <= 0).toList();
      logs.sort((a, b) => b.date.compareTo(a.date));
      final limited = logs.take(limit).toList();
      final list = limited.map((s) => {
        'id': s.id,
        'date': s.date,
        'hours': s.hours,
        'quality': s.quality,
        if (s.notes != null) 'notes': s.notes,
      }).toList();
      return jsonEncode({'count': list.length, 'sleepLogs': list});
    },
  ),
  ClaudeTool(
    name: 'add_sleep',
    description: 'Добавить запись сна.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'date': {'type': 'string', 'description': 'ISO date. По умолчанию сегодня.'},
        'hours': {'type': 'number', 'description': 'Сколько часов спал'},
        'quality': {'type': 'integer', 'description': '1-5'},
        'notes': {'type': 'string'},
      },
      'required': ['hours'],
    },
    handler: (ref, args) async {
      final log = SleepLog(
        id: _uuid.v4(),
        date: (args['date'] as String?) ?? _today(),
        hours: args['hours'] as num,
        quality: (args['quality'] as num?)?.toInt() ?? 3,
        notes: args['notes'] as String?,
      );
      await ref.read(sleepLogsProvider.notifier).add(log);
      return jsonEncode({'ok': true, 'id': log.id, 'date': log.date, 'hours': log.hours});
    },
  ),

  // ─────────────────────── WATER ───────────────────────
  ClaudeTool(
    name: 'get_water_today',
    description: 'Получить сколько воды выпито сегодня (мл).',
    inputSchema: {'type': 'object', 'properties': {}},
    handler: (ref, args) async {
      final today = _today();
      final logs = ref.read(waterLogsProvider).where((w) => w.date == today);
      final total = logs.fold<num>(0, (s, w) => s + w.amount);
      return jsonEncode({'date': today, 'totalMl': total, 'entries': logs.length});
    },
  ),
  ClaudeTool(
    name: 'add_water',
    description: 'Добавить запись о выпитой воде (мл).',
    inputSchema: {
      'type': 'object',
      'properties': {
        'amount': {'type': 'number', 'description': 'Количество в мл'},
        'date': {'type': 'string'},
      },
      'required': ['amount'],
    },
    handler: (ref, args) async {
      final log = WaterLog(
        id: _uuid.v4(),
        date: (args['date'] as String?) ?? _today(),
        timestamp: _now(),
        amount: args['amount'] as num,
      );
      await ref.read(waterLogsProvider.notifier).add(log);
      return jsonEncode({'ok': true, 'id': log.id, 'amount': log.amount});
    },
  ),

  // ─────────────────────── WORKOUTS ───────────────────────
  ClaudeTool(
    name: 'list_workouts',
    description: 'Получить журнал тренировок (exercise logs).',
    inputSchema: {
      'type': 'object',
      'properties': {
        'from': {'type': 'string'},
        'to': {'type': 'string'},
        'limit': {'type': 'integer'},
      },
    },
    handler: (ref, args) async {
      var logs = ref.read(exerciseLogsProvider);
      final from = args['from'] as String?;
      final to = args['to'] as String?;
      final limit = (args['limit'] as num?)?.toInt() ?? 30;
      if (from != null) logs = logs.where((l) => l.date.compareTo(from) >= 0).toList();
      if (to != null) logs = logs.where((l) => l.date.compareTo(to) <= 0).toList();
      logs.sort((a, b) => b.date.compareTo(a.date));
      final limited = logs.take(limit).toList();
      final list = limited.map((l) => {
        'id': l.id,
        'exerciseId': l.exerciseId,
        'date': l.date,
        'metrics': {for (final e in l.metrics.entries) e.key.name: e.value},
        if (l.notes != null) 'notes': l.notes,
      }).toList();
      return jsonEncode({'count': list.length, 'logs': list});
    },
  ),
  ClaudeTool(
    name: 'add_workout_log',
    description: 'Добавить запись тренировки (метрики упражнения: weight, reps, distance, time, speed, calories).',
    inputSchema: {
      'type': 'object',
      'properties': {
        'exerciseId': {'type': 'string', 'description': 'ID упражнения из дерева'},
        'date': {'type': 'string'},
        'metrics': {
          'type': 'object',
          'description': 'Метрики: {"weight": 80, "reps": 10, "distance": 5, "time": 30, "speed": 10, "calories": 300}',
          'additionalProperties': {'type': 'number'},
        },
        'notes': {'type': 'string'},
      },
      'required': ['exerciseId', 'metrics'],
    },
    handler: (ref, args) async {
      final raw = (args['metrics'] as Map?) ?? const {};
      final metrics = <WorkoutMetric, num>{};
      raw.forEach((k, v) {
        if (k is String && v is num) {
          metrics[enumFromName(WorkoutMetric.values, k, WorkoutMetric.weight)] = v;
        }
      });
      final log = ExerciseLog(
        id: _uuid.v4(),
        exerciseId: args['exerciseId'] as String,
        date: (args['date'] as String?) ?? _today(),
        metrics: metrics,
        notes: args['notes'] as String?,
      );
      await ref.read(exerciseLogsProvider.notifier).add(log);
      return jsonEncode({'ok': true, 'id': log.id, 'exerciseId': log.exerciseId, 'metricsCount': metrics.length});
    },
  ),

  // ─────────────────────── SPHERES ───────────────────────
  ClaudeTool(
    name: 'list_spheres',
    description: 'Получить список всех сфер жизни с категориями.',
    inputSchema: {'type': 'object', 'properties': {}},
    handler: (ref, args) async {
      final spheres = ref.read(spheresProvider);
      final list = spheres.map((s) => {
        'id': s.id,
        'title': s.title,
        if (s.description != null) 'description': s.description,
        'notesCount': s.notesList?.length ?? 0,
        'categories': (s.categories ?? []).map((c) => {'id': c.id, 'title': c.title}).toList(),
      }).toList();
      return jsonEncode({'count': list.length, 'spheres': list});
    },
  ),
  ClaudeTool(
    name: 'add_sphere',
    description: 'Создать новую сферу жизни.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'description': {'type': 'string'},
        'icon': {'type': 'string', 'description': 'Эмодзи или код иконки'},
        'color': {'type': 'string', 'description': 'HEX цвет (#RRGGBB)'},
      },
      'required': ['title'],
    },
    handler: (ref, args) async {
      final sphere = Sphere(
        id: _uuid.v4(),
        title: args['title'] as String,
        description: args['description'] as String?,
        notes: '',
        createdAt: _now(),
        icon: args['icon'] as String?,
        color: args['color'] as String?,
      );
      await ref.read(spheresProvider.notifier).add(sphere);
      return jsonEncode({'ok': true, 'id': sphere.id, 'title': sphere.title});
    },
  ),
  ClaudeTool(
    name: 'delete_sphere',
    description: 'Удалить сферу жизни по ID.',
    inputSchema: {
      'type': 'object',
      'properties': {'id': {'type': 'string'}},
      'required': ['id'],
    },
    handler: (ref, args) async {
      await ref.read(spheresProvider.notifier).remove(args['id'] as String);
      return jsonEncode({'ok': true, 'deleted': args['id']});
    },
  ),
  ClaudeTool(
    name: 'add_sphere_category',
    description: 'Добавить категорию (папку) внутри сферы.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'sphereId': {'type': 'string'},
        'title': {'type': 'string'},
        'icon': {'type': 'string'},
        'color': {'type': 'string'},
      },
      'required': ['sphereId', 'title'],
    },
    handler: (ref, args) async {
      final sphereId = args['sphereId'] as String;
      final cat = SphereCategory(
        id: _uuid.v4(),
        title: args['title'] as String,
        createdAt: _now(),
        icon: args['icon'] as String?,
        color: args['color'] as String?,
      );
      await ref.read(spheresProvider.notifier).update(sphereId, (s) {
        return s.copyWith(categories: [...(s.categories ?? []), cat]);
      });
      return jsonEncode({'ok': true, 'categoryId': cat.id, 'sphereId': sphereId, 'title': cat.title});
    },
  ),
  ClaudeTool(
    name: 'add_sphere_note',
    description: 'Добавить заметку в сферу (опционально в категорию внутри сферы).',
    inputSchema: {
      'type': 'object',
      'properties': {
        'sphereId': {'type': 'string'},
        'content': {'type': 'string', 'description': 'Текст заметки (поддерживает длинные тексты)'},
        'categoryId': {'type': 'string', 'description': 'ID категории внутри сферы (опционально)'},
        'youtubeUrl': {'type': 'string'},
        'isCheckbox': {'type': 'boolean'},
      },
      'required': ['sphereId', 'content'],
    },
    handler: (ref, args) async {
      final sphereId = args['sphereId'] as String;
      final note = SphereNote(
        id: _uuid.v4(),
        content: args['content'] as String,
        createdAt: _now(),
        categoryId: args['categoryId'] as String?,
        youtubeUrl: args['youtubeUrl'] as String?,
        isCheckbox: args['isCheckbox'] as bool?,
      );
      await ref.read(spheresProvider.notifier).update(sphereId, (s) {
        return s.copyWith(notesList: [...(s.notesList ?? []), note]);
      });
      return jsonEncode({'ok': true, 'noteId': note.id, 'sphereId': sphereId});
    },
  ),

  // ─────────────────────── SUMMARY / META ───────────────────────
  ClaudeTool(
    name: 'get_today_summary',
    description: 'Общая сводка за сегодня: задачи, привычки, бюджет, вода, сон.',
    inputSchema: {'type': 'object', 'properties': {}},
    handler: (ref, args) async {
      final today = _today();

      final tasks = ref.read(tasksProvider).where((t) => t.date == today).toList();
      final tasksCompleted = tasks.where((t) => t.completed).length;

      final habits = ref.read(habitsProvider);
      final todayLogs = ref.read(habitLogsProvider).where((l) => l.date == today).toList();
      final habitsDone = todayLogs.where((l) => l.status == HabitLogStatus.done).length;

      final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
      final txns = ref.read(transactionsProvider).where((t) => t.date == today);
      num todaySpent = 0;
      for (final t in txns) {
        if (t.type == TransactionType.expense) todaySpent += t.amount;
      }

      final water = ref.read(waterLogsProvider).where((w) => w.date == today);
      final waterTotal = water.fold<num>(0, (s, w) => s + w.amount);

      final sleepLogs = ref.read(sleepLogsProvider);
      final lastSleep = sleepLogs.isNotEmpty ? sleepLogs.last : null;

      return jsonEncode({
        'date': today,
        'tasks': {'total': tasks.length, 'completed': tasksCompleted},
        'habits': {'total': habits.length, 'doneToday': habitsDone},
        'finance': {'spentToday': todaySpent, 'month': monthKey},
        'water': {'totalMl': waterTotal},
        if (lastSleep != null) 'lastSleep': {'date': lastSleep.date, 'quality': lastSleep.quality},
      });
    },
  ),
];
