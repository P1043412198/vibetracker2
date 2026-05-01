import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'add_transaction_screen.dart';
import 'budget_screen.dart';
import 'education_screen.dart';
import 'home_screen.dart';
import 'operations_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  final AppState state;

  const MainShell({super.key, required this.state});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _switchTo(int i) => setState(() => _index = i);

  Future<void> _addTransaction() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(state: widget.state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(state: widget.state, onTabTap: _switchTo),
      OperationsScreen(state: widget.state),
      BudgetScreen(state: widget.state),
      const EducationScreen(),
      ProfileScreen(state: widget.state),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: pages[_index],
        ),
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton(
              onPressed: _addTransaction,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 8,
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Главная',
                  selected: _index == 0,
                  onTap: () => _switchTo(0),
                ),
                _NavItem(
                  icon: Icons.list_alt_rounded,
                  label: 'Операции',
                  selected: _index == 1,
                  onTap: () => _switchTo(1),
                ),
                _NavItem(
                  icon: Icons.pie_chart_rounded,
                  label: 'Бюджет',
                  selected: _index == 2,
                  onTap: () => _switchTo(2),
                ),
                _NavItem(
                  icon: Icons.menu_book_rounded,
                  label: 'Обучение',
                  selected: _index == 3,
                  onTap: () => _switchTo(3),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Профиль',
                  selected: _index == 4,
                  onTap: () => _switchTo(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
