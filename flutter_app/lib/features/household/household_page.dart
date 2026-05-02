import 'package:flutter/material.dart';

import '../../widgets/coming_soon.dart';

class HouseholdPage extends StatelessWidget {
  const HouseholdPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      title: 'Хозяйство',
      summary:
          'Учёт техники, мебели, гарантий и сервисов — будет в следующей фазе порта.',
      icon: Icons.home_outlined,
    );
  }
}
