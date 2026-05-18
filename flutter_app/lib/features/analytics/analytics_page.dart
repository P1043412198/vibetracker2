import '../../widgets/app_back_button.dart';
import 'package:flutter/material.dart';

import 'fire_tab.dart';
import 'habits_tab.dart';
import 'predictive_tab.dart';
import 'sankey_tab.dart';
import 'treemap_tab.dart';

/// "Аналитика" page. Phase 5 ships four tabs that mirror the React app:
///
/// * Sankey   — income → expense flow (`charts/SankeyFlow.tsx`)
/// * Treemap  — expenses by category coloured by plan vs. actual
///   (`charts/TreemapExpenses.tsx`)
/// * Прогноз  — predictive month-end spend with optional Gemini insight
///   (`PredictiveBudgetTab.tsx`)
/// * FIRE     — Financial Independence calculator (`FIRECalculatorTab.tsx`)
/// * Привычки — pie/donut/bar charts across all habits.
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Аналитика'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Sankey'),
            Tab(text: 'Treemap'),
            Tab(text: 'Прогноз'),
            Tab(text: 'FIRE'),
            Tab(text: 'Привычки'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          SankeyTab(),
          TreemapTab(),
          PredictiveTab(),
          FireTab(),
          HabitsAnalyticsTab(),
        ],
      ),
    );
  }
}
