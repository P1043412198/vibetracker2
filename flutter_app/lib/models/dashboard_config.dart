/// Configuration of the home dashboard — which widgets are visible and the
/// order in which they appear. Mirrors the React `DashboardConfig` type from
/// `src/types.ts` but only ports widgets that have a Flutter counterpart in
/// the current build.
library;

class DashboardWidgetMeta {
  const DashboardWidgetMeta({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String id;
  final String title;
  final String subtitle;
  final String icon; // Material icon code-point name (resolved at render time)
  final String? route; // Optional navigation target.
}

/// Catalogue of widgets the Flutter port currently knows how to render on
/// the dashboard. Adding a new entry here makes it appear in the
/// "Настроить дашборд" page so the user can show/hide and reorder it.
const List<DashboardWidgetMeta> kDashboardWidgets = [
  DashboardWidgetMeta(
    id: 'greeting',
    title: 'Приветствие',
    subtitle: 'Дата + текущее время суток',
    icon: 'auto_awesome',
    route: null,
  ),
  DashboardWidgetMeta(
    id: 'tasks_habits',
    title: 'Задачи и Привычки',
    subtitle: 'Прогресс на сегодня',
    icon: 'checklist',
    route: '/tasks',
  ),
  DashboardWidgetMeta(
    id: 'finance_hub',
    title: 'Финансы',
    subtitle: 'Доход и расход за месяц',
    icon: 'account_balance_wallet',
    route: '/finance',
  ),
  DashboardWidgetMeta(
    id: 'spheres',
    title: 'Сферы жизни',
    subtitle: 'Быстрый переход',
    icon: 'workspaces',
    route: '/spheres',
  ),
  DashboardWidgetMeta(
    id: 'goals',
    title: 'Цели',
    subtitle: 'Активные цели',
    icon: 'flag',
    route: '/goals',
  ),
  DashboardWidgetMeta(
    id: 'shopping_list',
    title: 'Список покупок',
    subtitle: 'Несделанные позиции',
    icon: 'shopping_cart',
    route: '/shopping-list',
  ),
  DashboardWidgetMeta(
    id: 'pomodoro',
    title: 'Pomodoro',
    subtitle: 'Текущая сессия',
    icon: 'timer',
    route: '/pomodoro',
  ),
  DashboardWidgetMeta(
    id: 'water',
    title: 'Вода',
    subtitle: 'Прогресс по дневной норме',
    icon: 'water_drop',
    route: '/water',
  ),
  DashboardWidgetMeta(
    id: 'sleep_recovery',
    title: 'Сон и Восстановление',
    subtitle: 'Среднее за неделю',
    icon: 'bedtime',
    route: '/sleep',
  ),
  DashboardWidgetMeta(
    id: 'expense_week_chart',
    title: 'Расход за 7 дней',
    subtitle: 'Мини-график',
    icon: 'show_chart',
    route: '/finance',
  ),
  DashboardWidgetMeta(
    id: 'habit_heatmap',
    title: 'Привычки за 4 недели',
    subtitle: 'Heatmap прогресса',
    icon: 'grid_on',
    route: '/habits',
  ),
  DashboardWidgetMeta(
    id: 'task_progress_chart',
    title: 'Задачи за неделю',
    subtitle: 'Сделано / запланировано',
    icon: 'bar_chart',
    route: '/tasks',
  ),
  // Phase 14: more analytics widgets — habits/goals/finance.
  DashboardWidgetMeta(
    id: 'inbox',
    title: 'Входящие',
    subtitle: 'Захват мыслей и идей',
    icon: 'inbox',
    route: '/inbox',
  ),
  DashboardWidgetMeta(
    id: 'habits_overview',
    title: 'Привычки: обзор',
    subtitle: 'Хорошие vs вредные, пробег по неделе',
    icon: 'donut_large',
    route: '/habits',
  ),
  DashboardWidgetMeta(
    id: 'goals_overview',
    title: 'Цели: статусы',
    subtitle: 'Pie + средний прогресс',
    icon: 'pie_chart',
    route: '/goals',
  ),
  DashboardWidgetMeta(
    id: 'finance_free_funds',
    title: 'Свободно в день',
    subtitle: 'С учётом кредитов и графика',
    icon: 'savings',
    route: '/finance',
  ),
  DashboardWidgetMeta(
    id: 'loans_overview',
    title: 'Кредиты',
    subtitle: 'Остаток, переплата, прогресс',
    icon: 'credit_score',
    route: '/loans',
  ),
  // Phase 15: challenges & body progress.
  DashboardWidgetMeta(
    id: 'challenges_overview',
    title: 'Челленджи',
    subtitle: 'Активные с прогрессом',
    icon: 'emoji_events',
    route: '/challenges',
  ),
];

class DashboardConfig {
  DashboardConfig({
    required this.widgetsOrder,
    required this.visibleWidgets,
  });

  /// Ordered list of widget ids — defines the rendering order.
  final List<String> widgetsOrder;

  /// Subset of [widgetsOrder] that should currently be rendered.
  final List<String> visibleWidgets;

  static DashboardConfig defaultConfig() => DashboardConfig(
        widgetsOrder: kDashboardWidgets.map((w) => w.id).toList(),
        visibleWidgets: kDashboardWidgets.map((w) => w.id).toList(),
      );

  DashboardConfig copyWith({
    List<String>? widgetsOrder,
    List<String>? visibleWidgets,
  }) =>
      DashboardConfig(
        widgetsOrder: widgetsOrder ?? this.widgetsOrder,
        visibleWidgets: visibleWidgets ?? this.visibleWidgets,
      );

  Map<String, dynamic> toJson() => {
        'widgetsOrder': widgetsOrder,
        'visibleWidgets': visibleWidgets,
      };

  factory DashboardConfig.fromJson(Map<String, dynamic> json) {
    final order = (json['widgetsOrder'] as List?)
            ?.whereType<String>()
            .toList() ??
        const [];
    final visible = (json['visibleWidgets'] as List?)
            ?.whereType<String>()
            .toList() ??
        order;

    // Auto-heal: append any newly added catalogue entries that the persisted
    // config doesn't know about yet (so a new release immediately shows new
    // widgets without forcing the user to "reset").
    final knownIds = kDashboardWidgets.map((w) => w.id).toSet();
    final mergedOrder = <String>[
      ...order.where(knownIds.contains),
      ...knownIds.where((id) => !order.contains(id)),
    ];
    final mergedVisible = <String>[
      ...visible.where(mergedOrder.contains),
      ...mergedOrder.where((id) => !order.contains(id)),
    ];
    return DashboardConfig(
      widgetsOrder: mergedOrder,
      visibleWidgets: mergedVisible,
    );
  }
}
