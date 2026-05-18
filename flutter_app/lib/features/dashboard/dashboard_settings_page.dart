import '../../widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dashboard_config.dart';
import '../../state/settings_state.dart';

/// Editor for `DashboardConfig` — toggle visibility and reorder widgets via
/// drag handles. Mirrors the React `DashboardCustomizer.tsx` modal but lives
/// as a full page since the Flutter port doesn't have a parallel modal stack.
class DashboardSettingsPage extends ConsumerWidget {
  const DashboardSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(dashboardConfigProvider);
    final controller = ref.read(dashboardConfigProvider.notifier);

    final byId = {for (final w in kDashboardWidgets) w.id: w};
    final ordered = config.widgetsOrder
        .map((id) => byId[id])
        .whereType<DashboardWidgetMeta>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Настроить дашборд'),
        actions: [
          IconButton(
            tooltip: 'Сбросить',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              await controller.resetToDefault();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Дашборд сброшен к умолчанию')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Перетаскивай за иконку справа, чтобы изменить порядок. '
                'Переключатель скрывает виджет с главного экрана.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                itemCount: ordered.length,
                onReorder: (oldIndex, newIndex) async {
                  final ids = [...config.widgetsOrder];
                  final widgetIds = ordered.map((w) => w.id).toList();
                  if (newIndex > oldIndex) newIndex -= 1;
                  final moved = widgetIds.removeAt(oldIndex);
                  widgetIds.insert(newIndex, moved);
                  // Preserve any unknown ids (shouldn't happen given filter).
                  final unknown =
                      ids.where((id) => !widgetIds.contains(id)).toList();
                  await controller.reorder([...widgetIds, ...unknown]);
                },
                itemBuilder: (context, index) {
                  final w = ordered[index];
                  final visible = config.visibleWidgets.contains(w.id);
                  return Card(
                    key: ValueKey(w.id),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: Icon(_iconFor(w.icon)),
                      title: Text(w.title),
                      subtitle: Text(w.subtitle),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: visible,
                            onChanged: (v) => controller.setVisible(w.id, v),
                          ),
                          const SizedBox(width: 4),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String name) {
  switch (name) {
    case 'auto_awesome':
      return Icons.auto_awesome;
    case 'checklist':
      return Icons.checklist;
    case 'account_balance_wallet':
      return Icons.account_balance_wallet_outlined;
    case 'workspaces':
      return Icons.workspaces_outline;
    case 'flag':
      return Icons.flag_outlined;
    case 'shopping_cart':
      return Icons.shopping_cart_outlined;
    case 'timer':
      return Icons.timer_outlined;
    case 'water_drop':
      return Icons.water_drop_outlined;
    case 'bedtime':
      return Icons.bedtime_outlined;
    case 'show_chart':
      return Icons.show_chart;
    case 'grid_on':
      return Icons.grid_on;
    case 'bar_chart':
      return Icons.bar_chart;
    case 'inbox':
      return Icons.inbox_outlined;
    case 'donut_large':
      return Icons.donut_large_outlined;
    case 'pie_chart':
      return Icons.pie_chart_outline;
    case 'savings':
      return Icons.savings_outlined;
    case 'credit_score':
      return Icons.credit_score_outlined;
    case 'emoji_events':
      return Icons.emoji_events_outlined;
    default:
      return Icons.dashboard_outlined;
  }
}
