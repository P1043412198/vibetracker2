import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';
import 'dashboard_charts.dart';
import 'dashboard_widgets_v2.dart';

/// Dashboard / "Главная" — counterpart of `src/pages/Dashboard.tsx`.
///
/// The React version shows ~20 widgets driven by `dashboardConfig`. The
/// Flutter port surfaces the most important totals and shortcut cards. As of
/// Phase 10 the rendering order and visibility are user-configurable via
/// [DashboardSettingsPage] — same `dashboardConfig` storage key as the React
/// build so a future migration tool can preserve user choices.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tasks = ref.watch(tasksProvider);
    final habits = ref.watch(habitsProvider);
    final transactions = ref.watch(transactionsProvider);
    final goals = ref.watch(goalsProvider);
    final shopping = ref.watch(shoppingListProvider);
    final spheres = ref.watch(spheresProvider);
    final currency = ref.watch(defaultCurrencyProvider);

    final pomodoro = ref.watch(pomodoroProvider);
    final waterLogs = ref.watch(waterLogsProvider);
    final waterGoal = ref.watch(waterGoalProvider);
    final sleepLogs = ref.watch(sleepLogsProvider);
    final config = ref.watch(dashboardConfigProvider);

    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final monthKey = todayStr.substring(0, 7);

    final todayTasks = tasks
        .where((t) => t.date == todayStr && t.period == TaskPeriod.day)
        .toList(growable: false);
    final completedToday = todayTasks.where((t) => t.completed).length;

    final monthTransactions = transactions
        .where((t) => t.date.startsWith(monthKey))
        .toList(growable: false);
    final monthIncome = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold<num>(0, (sum, t) => sum + t.amount);
    final monthExpense = monthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold<num>(0, (sum, t) => sum + t.amount);

    final amountFormat =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);

    final visibleIds = config.widgetsOrder
        .where(config.visibleWidgets.contains)
        .toList();

    Widget? buildWidget(String id) {
      switch (id) {
        case 'greeting':
          return _GreetingCard(scheme: scheme);
        case 'tasks_habits':
          return _StatsRow(
            cards: [
              _StatData(
                label: 'Задачи сегодня',
                value: '$completedToday / ${todayTasks.length}',
                icon: Icons.checklist,
                color: scheme.primary,
                onTap: () => context.go('/tasks'),
              ),
              _StatData(
                label: 'Привычки',
                value: habits.length.toString(),
                icon: Icons.spa,
                color: const Color(0xFF22C55E),
                onTap: () => context.go('/habits'),
              ),
            ],
          );
        case 'finance_hub':
          return _StatsRow(
            cards: [
              _StatData(
                label: 'Доход за месяц',
                value: '+ ${amountFormat.format(monthIncome)} $currency',
                icon: Icons.trending_up,
                color: const Color(0xFF22C55E),
                onTap: () => context.go('/finance'),
              ),
              _StatData(
                label: 'Расход за месяц',
                value: '- ${amountFormat.format(monthExpense)} $currency',
                icon: Icons.trending_down,
                color: const Color(0xFFEF4444),
                onTap: () => context.go('/finance'),
              ),
            ],
          );
        case 'spheres':
          return _SectionCard(
            title: 'Сферы жизни',
            subtitle: spheres.isEmpty
                ? 'Создай первую сферу'
                : '${spheres.length} активных',
            icon: Icons.workspaces_outline,
            accent: scheme.primary,
            onTap: () => context.go('/spheres'),
          );
        case 'goals':
          return _SectionCard(
            title: 'Цели',
            subtitle:
                goals.isEmpty ? 'Поставь первую цель' : '${goals.length} в работе',
            icon: Icons.flag_outlined,
            accent: const Color(0xFFF59E0B),
            onTap: () => context.go('/goals'),
          );
        case 'shopping_list':
          return _SectionCard(
            title: 'Список покупок',
            subtitle: shopping.isEmpty
                ? 'Пусто'
                : '${shopping.where((s) => !s.completed).length} активных позиций',
            icon: Icons.shopping_cart_outlined,
            accent: const Color(0xFF3B82F6),
            onTap: () => context.go('/shopping-list'),
          );
        case 'pomodoro':
          return _StatsRow(
            cards: [
              _StatData(
                label: 'Pomodoro',
                value: pomodoro.isRunning
                    ? '${pomodoro.timeLeft ~/ 60}:${(pomodoro.timeLeft % 60).toString().padLeft(2, '0')}'
                    : '${pomodoro.sessionsCompleted} сессий',
                icon: Icons.timer,
                color: scheme.primary,
                onTap: () => context.go('/pomodoro'),
              ),
              _StatData(
                label: 'Вода сегодня',
                value: () {
                  final todayW = waterLogs
                      .where((l) => l.date == todayStr)
                      .fold<num>(0, (s, l) => s + l.amount);
                  return '${todayW.toInt()} / $waterGoal мл';
                }(),
                icon: Icons.water_drop,
                color: const Color(0xFF3B82F6),
                onTap: () => context.go('/water'),
              ),
            ],
          );
        case 'water':
          // Already shown alongside pomodoro card; render a dedicated row only
          // if 'pomodoro' is hidden, to avoid duplication.
          if (config.visibleWidgets.contains('pomodoro')) return null;
          return _SectionCard(
            title: 'Вода сегодня',
            subtitle: () {
              final todayW = waterLogs
                  .where((l) => l.date == todayStr)
                  .fold<num>(0, (s, l) => s + l.amount);
              return '${todayW.toInt()} / $waterGoal мл';
            }(),
            icon: Icons.water_drop_outlined,
            accent: const Color(0xFF3B82F6),
            onTap: () => context.go('/water'),
          );
        case 'sleep_recovery':
          return _SectionCard(
            title: 'Сон и Восстановление',
            subtitle: () {
              if (sleepLogs.isEmpty) return 'Нет записей';
              final avg = sleepLogs.fold<num>(0, (s, l) => s + l.hours) /
                  sleepLogs.length;
              return 'Среднее ${avg.toStringAsFixed(1)}ч';
            }(),
            icon: Icons.bedtime_outlined,
            accent: const Color(0xFF8B5CF6),
            onTap: () => context.go('/sleep'),
          );
        case 'expense_week_chart':
          return const ExpenseWeekChartWidget();
        case 'habit_heatmap':
          return const HabitHeatmapWidget();
        case 'task_progress_chart':
          return const TaskWeekProgressWidget();
        case 'inbox':
          return const InboxDashboardWidget();
        case 'habits_overview':
          return const HabitsOverviewWidget();
        case 'goals_overview':
          return const GoalsOverviewWidget();
        case 'finance_free_funds':
          return const FinanceFreeFundsWidget();
        case 'loans_overview':
          return const LoansOverviewWidget();
        case 'challenges_overview':
          return const ChallengesOverviewWidget();
      }
      return null;
    }

    final widgets = <Widget>[];
    for (final id in visibleIds) {
      final w = buildWidget(id);
      if (w == null) continue;
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
      widgets.add(w);
    }
    if (widgets.isEmpty) {
      widgets.add(_EmptyDashboardHint(
        onConfigure: () => context.go('/dashboard-settings'),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
            tooltip: 'Глобальный поиск',
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => context.go('/dashboard-settings'),
            tooltip: 'Настроить дашборд',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
            tooltip: 'Настройки',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: widgets,
        ),
      ),
    );
  }
}

class _EmptyDashboardHint extends StatelessWidget {
  const _EmptyDashboardHint({required this.onConfigure});
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.dashboard_customize_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('Все виджеты скрыты',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Включи нужные виджеты в настройках дашборда',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onConfigure,
            icon: const Icon(Icons.tune),
            label: const Text('Настроить дашборд'),
          ),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 6) {
      greeting = 'Доброй ночи';
    } else if (hour < 12) {
      greeting = 'Доброе утро';
    } else if (hour < 18) {
      greeting = 'Добрый день';
    } else {
      greeting = 'Добрый вечер';
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            scheme.primary.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Добро пожаловать в Vibesight',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat.yMMMMEEEEd('ru').format(DateTime.now()),
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.auto_awesome, color: scheme.onPrimary, size: 36),
        ],
      ),
    );
  }
}

class _StatData {
  _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.cards});
  final List<_StatData> cards;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _StatCard(data: cards[i])),
        ]
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                data.value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent),
        ),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
