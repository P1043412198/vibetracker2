import 'package:flutter/material.dart';

import '../../widgets/coming_soon.dart';

class WorkSchedulePage extends StatelessWidget {
  const WorkSchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      title: 'График работы',
      summary:
          'Сменный график, отпуска и календарь смен — порт WorkSchedule.tsx запланирован.',
      icon: Icons.calendar_today_outlined,
    );
  }
}
