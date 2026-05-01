import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../utils/month_key.dart';
import '../widgets/section_card.dart';
import 'analytics_screen.dart';

class ProfileScreen extends StatelessWidget {
  final AppState state;
  const ProfileScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final monthsTracked = <String>{};
        for (final t in state.transactions) {
          monthsTracked.add(monthKeyFor(t.date));
        }
        final totalIncome = state.transactions
            .where((t) => t.type.name == 'income')
            .fold(0.0, (a, b) => a + b.amount);
        final totalExpense = state.transactions
            .where((t) => t.type.name == 'expense')
            .fold(0.0, (a, b) => a + b.amount);
        return Scaffold(
          appBar: AppBar(title: const Text('Профиль')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              SectionCard(
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.userName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Локальный профиль',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editName(context),
                      icon: const Icon(Icons.edit_rounded,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Месяцев',
                        value: '${monthsTracked.length}',
                        icon: Icons.calendar_month_rounded,
                      ),
                    ),
                    Expanded(
                      child: _StatTile(
                        label: 'Доходы',
                        value: formatMoney(totalIncome),
                        icon: Icons.savings_rounded,
                      ),
                    ),
                    Expanded(
                      child: _StatTile(
                        label: 'Расходы',
                        value: formatMoney(totalExpense),
                        icon: Icons.receipt_long_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Действия'),
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.bar_chart_rounded,
                      label: 'Аналитика',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AnalyticsScreen(state: state),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _MenuTile(
                      icon: Icons.delete_outline_rounded,
                      label: 'Очистить все данные',
                      color: AppColors.danger,
                      onTap: () => _confirmWipe(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'FinFlow • Локально и приватно',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: state.userName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Имя'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Как тебя зовут?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Сохранить')),
        ],
      ),
    );
    if (result != null) {
      await state.setUserName(result);
    }
  }

  Future<void> _confirmWipe(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить все данные?'),
        content: const Text(
            'Все операции и планы будут удалены без возможности восстановления.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) {
      await state.wipeAll();
    }
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
