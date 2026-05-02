import 'package:flutter/material.dart';

import '../../widgets/coming_soon.dart';

class WorkoutsPage extends StatelessWidget {
  const WorkoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      title: 'Тренировки',
      summary:
          'Дерево упражнений, журнал тренировок, замеры тела и план на неделю — Workouts.tsx (2367 строк) переписывается следующим этапом.',
      icon: Icons.fitness_center_outlined,
    );
  }
}
