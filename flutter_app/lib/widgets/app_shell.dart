import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom navigation shell — mirrors the React Layout component (`Layout.tsx`).
/// The React app shows the most-used 5 tabs at the bottom and the rest in the
/// "More" sheet; we replicate that here.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_NavTab>[
    _NavTab(path: '/', label: 'Главная', icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard),
    _NavTab(path: '/finance', label: 'Финансы', icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet),
    _NavTab(path: '/tasks', label: 'Задачи', icon: Icons.checklist_rounded,
        selectedIcon: Icons.checklist),
    _NavTab(path: '/habits', label: 'Привычки', icon: Icons.spa_outlined,
        selectedIcon: Icons.spa),
    _NavTab(path: '/_more', label: 'Ещё', icon: Icons.menu,
        selectedIcon: Icons.menu),
  ];

  static const _moreItems = <_MoreItem>[
    _MoreItem('/inbox', 'Инбокс', Icons.inbox_outlined),
    _MoreItem('/spheres', 'Сферы', Icons.workspaces_outline),
    _MoreItem('/goals', 'Цели', Icons.flag_outlined),
    _MoreItem('/workouts', 'Тренировки', Icons.fitness_center_outlined),
    _MoreItem('/household', 'Хозяйство', Icons.home_outlined),
    _MoreItem('/shopping-list', 'Список покупок', Icons.shopping_cart_outlined),
    _MoreItem('/work-schedule', 'График работы', Icons.calendar_today_outlined),
    _MoreItem('/analytics', 'Аналитика', Icons.analytics_outlined),
    _MoreItem('/passwords', 'Пароли', Icons.lock_outline),
    _MoreItem('/tools', 'Инструменты', Icons.handyman_outlined),
    _MoreItem('/settings', 'Настройки', Icons.settings_outlined),
  ];

  int _selectedIndex(String location) {
    for (var i = 0; i < _tabs.length - 1; i++) {
      if (location == _tabs[i].path) return i;
      if (_tabs[i].path != '/' && location.startsWith(_tabs[i].path)) return i;
    }
    final inMore =
        _moreItems.any((m) => location == m.path || location.startsWith('${m.path}/'));
    return inMore ? _tabs.length - 1 : 0;
  }

  void _onTabTap(BuildContext context, int index) {
    final tab = _tabs[index];
    if (tab.path == '/_more') {
      _openMoreSheet(context);
    } else {
      context.go(tab.path);
    }
  }

  void _openMoreSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Ещё',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                ..._moreItems.map(
                  (m) => ListTile(
                    leading: Icon(m.icon),
                    title: Text(m.label),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.go(m.path);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _selectedIndex(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => _onTabTap(context, i),
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.selectedIcon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _MoreItem {
  const _MoreItem(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}
