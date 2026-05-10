import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/financial_plan.dart';
import '../../services/financial_plan_service.dart';
import '../../state/financial_plan_state.dart';
import '../../state/providers.dart';
import 'widgets/calendar_grid.dart';
import 'widgets/donuts.dart';
import 'widgets/income_waterfall.dart';
import 'widgets/kpi_strip.dart';
import 'widgets/line_charts.dart';
import 'widgets/sankey_section.dart';
import 'widgets/scenario_widgets.dart';
import 'widgets/section_card.dart';

/// Main «Финансовый план» page — 18 sections rebuilt from a [FinancialPlanReport].
class FinancialPlanPage extends ConsumerWidget {
  const FinancialPlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(financialPlanConfigProvider);
    final plans = ref.watch(monthlyBudgetPlansProvider);
    final loans = ref.watch(loansProvider);
    final accounts = ref.watch(accountsProvider);

    final report = const FinancialPlanService().buildFinancialPlan(
      config: config,
      plans: plans,
      loans: loans,
      accounts: accounts,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Финансовый план'),
        actions: [
          IconButton(
            tooltip: 'Настройки сценариев',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/financial-plan/settings'),
          ),
        ],
      ),
      body: ListView(
        children: [
          _Cover(report: report),
          _IncomeWaterfallSection(report: report),
          _SankeySection(report: report),
          _ExpenseStructureSection(report: report),
          _NextMonthsSection(report: report),
          _DailyBalanceSection(report: report),
          _WeeklyFlowSection(report: report),
          _ScenarioCompareSection(report: report),
          _ScenarioTableSection(report: report),
          _CalendarSection(report: report),
          _HeatmapSection(report: report),
          _BasketSection(report: report),
          _TrajectorySection(report: report),
          _ProgressBarsSection(report: report),
          _PortfolioSection(report: report),
          _ActionPlanSection(report: report),
          _ScatterSection(report: report),
          _RulesSection(report: report),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Section widgets
// ---------------------------------------------------------------------------

class _Cover extends StatelessWidget {
  const _Cover({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    final c = report.config;
    return SectionCard(
      index: 0,
      title: 'Месяц ${_monthName(c.month.month)} · обложка',
      caption:
          'Цель: \$${(c.goalCurrency == 'USD' ? c.goalAmount : c.goalAmount / c.usdRate).round()}'
          ' (${c.goalAmount.round()} ${c.goalCurrency}).'
          ' Курс: ${c.usdRate.toStringAsFixed(2)} BYN/\$.',
      color: const Color(0xFF1E3A8A),
      child: KpiStrip(
        kpis: report.kpis,
        titles: const [
          'Придёт в день ЗП',
          'Придёт авансом',
          'Фикс. расходы',
          'В доллар на цель',
        ],
      ),
    );
  }
}

class _IncomeWaterfallSection extends StatelessWidget {
  const _IncomeWaterfallSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    final inc = report.income;
    return SectionCard(
      index: 1,
      title: 'Доходы — водопадная декомпозиция',
      caption:
          'Грязная ${inc.gross.round()} → чистая ${inc.net.round()} → на руки ${inc.netRemainder.round()}.',
      color: const Color(0xFF1E3A8A),
      footnote:
          '13% подоход + 1% ФСЗН (символически) + 1% профсоюз ≈ ${(inc.gross - inc.net).round()} BYN удержаний.',
      child: IncomeWaterfall(income: inc),
    );
  }
}

class _SankeySection extends StatelessWidget {
  const _SankeySection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 2,
      title: 'Sankey · доход → расходы',
      color: const Color(0xFF14B8A6),
      caption: 'Куда уходят деньги: каждая ленточка — реальная сумма.',
      child: SankeySection(data: report.sankey),
    );
  }
}

class _ExpenseStructureSection extends StatelessWidget {
  const _ExpenseStructureSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    final items = report.expenses.combined;
    final total = report.expenses.total;
    return SectionCard(
      index: 3,
      title: 'Структура расходов · ${total.round()} BYN',
      color: const Color(0xFFF97316),
      caption:
          'Регулярные ${report.expenses.totalRecurring.round()} BYN, разовые ${report.expenses.totalOneOff.round()} BYN.',
      child: DonutWithBars(
        items: items,
        donutLabel: '${total.round()} BYN',
      ),
    );
  }
}

class _NextMonthsSection extends StatelessWidget {
  const _NextMonthsSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 4,
      title: 'Этот месяц vs следующие',
      color: const Color(0xFFF59E0B),
      caption:
          'Сценарий: разовые расходы исчезают → бюджет перетекает в еду + USD.',
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final left = Column(
          children: [
            const Text('Этот месяц',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DonutChart(items: report.nextMonthsExpenses.thisMonth.combined),
          ],
        );
        final right = Column(
          children: [
            const Text('Следующие месяцы',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DonutChart(items: report.nextMonthsExpenses.nextMonth.combined),
          ],
        );
        if (!wide) {
          return Column(children: [left, const SizedBox(height: 16), right]);
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [Expanded(child: left), Expanded(child: right)],
        );
      }),
    );
  }
}

class _DailyBalanceSection extends StatelessWidget {
  const _DailyBalanceSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    final tracks = report.dailyBalance.scenarios
        .map((t) => MultiLineTrack(
              label: t.label,
              color: t.colorValue,
              points: t.points,
            ))
        .toList();
    final markers = report.dailyBalance.markers
        .map((m) => MultiLineMarker(
              x: m.dayOffset.toDouble(),
              label: m.label,
              color: m.colorValue,
            ))
        .toList();
    final xLabels = List.generate(report.dailyBalance.days, (i) {
      final date = report.dailyBalance.start.add(Duration(days: i));
      return '${date.day}.${date.month}';
    });
    return SectionCard(
      index: 5,
      title: '60 дней баланса · 3 сценария',
      color: const Color(0xFF22C55E),
      caption: 'Линия — баланс счёта по дням. Чем выше — тем больше остаётся.',
      child: MultiLineChart(
        tracks: tracks,
        xLabels: xLabels,
        markers: markers,
        height: 280,
      ),
    );
  }
}

class _WeeklyFlowSection extends StatelessWidget {
  const _WeeklyFlowSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    final w = report.weeklyFlow;
    return SectionCard(
      index: 6,
      title: 'Доход vs расход по неделям',
      color: const Color(0xFFEF4444),
      caption: 'Если зелёный бар выше красного — неделя в плюсе.',
      child: GroupedBars(
        labels: w.weekLabels,
        groups: [
          GroupedBarSet(label: 'Доход', color: const Color(0xFF22C55E), values: w.income),
          GroupedBarSet(label: 'Расход', color: const Color(0xFFEF4444), values: w.expense),
        ],
      ),
    );
  }
}

class _ScenarioCompareSection extends StatelessWidget {
  const _ScenarioCompareSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 7,
      title: 'Сравнение сценариев · копилка/еда/комфорт',
      color: const Color(0xFF14B8A6),
      child: ScenarioCompareTriple(items: report.scenarioCompare),
    );
  }
}

class _ScenarioTableSection extends StatelessWidget {
  const _ScenarioTableSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 8,
      title: 'Полная таблица сценариев',
      color: const Color(0xFF1E3A8A),
      child: ScenarioTable(items: report.scenarioCompare),
    );
  }
}

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 9,
      title:
          'Календарь ${_monthName(report.config.month.month)} ${report.config.month.year}',
      color: const Color(0xFF6366F1),
      caption: 'Зарплата/аренда — спецметки. Цвет ячейки = тип события.',
      child: CalendarGrid(calendar: report.calendar, heatmap: false),
    );
  }
}

class _HeatmapSection extends StatelessWidget {
  const _HeatmapSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 10,
      title: 'Тепловая карта трат',
      color: const Color(0xFFFB923C),
      caption: 'Чем темнее ячейка — тем больше потрачено в этот день.',
      child: CalendarGrid(calendar: report.heatmap, heatmap: true),
    );
  }
}

class _BasketSection extends StatelessWidget {
  const _BasketSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    final b = report.basket;
    return SectionCard(
      index: 11,
      title: 'Продуктовая корзина · ${b.totalByn.round()} BYN/нед',
      color: const Color(0xFF22C55E),
      caption: 'Шаблон от стоимости еды на день в выбранном сценарии.',
      child: Column(
        children: [
          DonutWithBars(
            items: b.groups
                .map((g) => ExpenseItem(
                      id: g.label,
                      label: g.label,
                      amount: g.amount,
                      color: g.color,
                      recurring: true,
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: b.items
                .map((it) => Chip(
                      backgroundColor: it.colorValue.withValues(alpha: 0.15),
                      side: BorderSide(color: it.colorValue),
                      label: Text(
                        '${it.label} · ${it.amount.round()} BYN',
                        style: TextStyle(color: it.colorValue, fontSize: 11),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TrajectorySection extends StatelessWidget {
  const _TrajectorySection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    final t = report.trajectory;
    final tracks = t.tracks
        .map((tr) => MultiLineTrack(
              label: '${tr.label} (${tr.monthsToGoal} мес)',
              color: tr.colorValue,
              points: tr.points,
            ))
        .toList();
    final xLabels =
        List.generate(t.months, (i) => 'M${(i + 1).toString().padLeft(2, '0')}');
    return SectionCard(
      index: 12,
      title: 'Долгосрочная траектория · цель \$${t.goalUsd.round()}',
      color: const Color(0xFFA855F7),
      caption: 'Точка пересечения линии с пунктиром = месяц достижения цели.',
      child: MultiLineChart(
        tracks: tracks,
        xLabels: xLabels,
        goalY: t.goalUsd,
        height: 300,
      ),
    );
  }
}

class _ProgressBarsSection extends StatelessWidget {
  const _ProgressBarsSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 13,
      title: 'Прогресс к цели · 6 vs 12 vs ∞',
      color: const Color(0xFF14B8A6),
      caption: 'Тёмный сегмент — за 6 мес, светлее — за 12 мес.',
      child: ProgressBarsToGoal(
        items: report.progress,
        boosters: const [
          'Кэшбэк (Halva, Whitebird) → +30–50 BYN/мес',
          'Подработка 5 ч/нед → +200–300 BYN/мес',
          'Сдвинуть зал на 1 мес → −100 BYN',
          'Открыть депозит на 6 мес: +5–10% к остатку',
        ],
      ),
    );
  }
}

class _PortfolioSection extends StatelessWidget {
  const _PortfolioSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    final p = report.portfolio;
    final donutItems = p.allocations
        .map((s) => ExpenseItem(
              id: s.instrumentId,
              label: '${s.label} · ${s.percent.round()}%',
              amount: s.amountUsd,
              color: s.color,
              recurring: true,
            ))
        .toList();
    return SectionCard(
      index: 14,
      title: 'Портфель · \$${p.totalUsd.round()}',
      color: const Color(0xFF1E3A8A),
      caption: 'Распределение по 12 инструментам Беларуси и квартальные взносы.',
      child: Column(
        children: [
          DonutWithBars(items: donutItems),
          const SizedBox(height: 16),
          QuarterlyBars(
            values: p.quarterly,
            goalY: p.totalUsd,
          ),
        ],
      ),
    );
  }
}

class _ActionPlanSection extends StatelessWidget {
  const _ActionPlanSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 15,
      title: 'Что делать прямо сейчас · 10 шагов',
      color: const Color(0xFF22C55E),
      caption:
          'Список генерируется правилами: кредит >18% → шаг рефинанса, овердрафт → закрыть и т.д.',
      child: ActionStepsList(steps: report.actionPlan),
    );
  }
}

class _ScatterSection extends StatelessWidget {
  const _ScatterSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 16,
      title: 'Карта риск/доходность БРБ',
      color: const Color(0xFF6366F1),
      caption: 'Sweet spot — депозиты и облигации Минфина: низкий риск + 9–12%.',
      child: RiskReturnScatterChart(scatter: report.scatter),
    );
  }
}

class _RulesSection extends StatelessWidget {
  const _RulesSection({required this.report});
  final FinancialPlanReport report;

  @override
  Widget build(BuildContext context) {
    final rules = const [
      '1. Авто-сохранение: \$ покупаются СРАЗУ в день ЗП.',
      '2. Любой кредит со ставкой выше 18% — рефинансировать.',
      '3. Не больше 30% от чистой ЗП на кредитные платежи.',
      '4. Резерв 1 месяц расходов — на отдельном счёте.',
      '5. Цель в твёрдой валюте, не в BYN.',
      '6. Регулярные ≥ 50% портфеля держим в депозитах/облигациях.',
      '7. Раз в квартал — пересмотр сценариев и портфеля.',
    ];
    return SectionCard(
      index: 17,
      title: 'Инструменты + 7 правил',
      color: const Color(0xFFEF4444),
      caption: 'Правила всегда применяются автоматически на следующих расчётах.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(r, style: const TextStyle(fontSize: 13)),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: brbInstruments
                .map((i) => Chip(
                      backgroundColor: Color(i.color).withValues(alpha: 0.15),
                      side: BorderSide(color: Color(i.color)),
                      label: Text(
                        '${i.shortName} · ${i.yieldFromPct.round()}–${i.yieldToPct.round()}%',
                        style: TextStyle(color: Color(i.color), fontSize: 11),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

String _monthName(int m) {
  const names = [
    '', 'январь', 'февраль', 'март', 'апрель', 'май', 'июнь',
    'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь',
  ];
  return m >= 1 && m <= 12 ? names[m] : '';
}
