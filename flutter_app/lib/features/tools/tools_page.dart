import 'package:flutter/material.dart';

import '../../widgets/coming_soon.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      title: 'Инструменты',
      summary:
          'Калькуляторы (зарплата, кредит, конвертер), Pomodoro, инбокс мыслей — порт идёт по чеклисту в MIGRATION_PLAN.md.',
      icon: Icons.handyman_outlined,
    );
  }
}
