import 'package:flutter/material.dart';

import '../../widgets/coming_soon.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      title: 'Аналитика',
      summary:
          'Sankey, treemap, тепловые карты и сводные графики — переходим на fl_chart, поэтому делаем после порта Finance.',
      icon: Icons.analytics_outlined,
    );
  }
}
