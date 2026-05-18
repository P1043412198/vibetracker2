import '../finance/by_tax.dart';
import '../models/enums.dart';
import '../models/finance.dart';
import '../models/financial_plan.dart';

/// Service responsible for turning raw user data + a [FinancialPlanConfig]
/// into a fully populated [FinancialPlanReport]. Pure functions so the result
/// is trivially testable.
class FinancialPlanService {
  const FinancialPlanService();

  /// One-shot builder. Tries to fill every section of the report; sections
  /// fall back to safe placeholder values when input data is missing.
  FinancialPlanReport buildFinancialPlan({
    required FinancialPlanConfig config,
    required List<MonthlyBudgetPlan> plans,
    required List<Loan> loans,
    required List<Account> accounts,
  }) {
    final income = computeIncomeBreakdown(config);
    final expenses = computeExpenseStructure(
      config: config,
      plans: plans,
      loans: loans,
    );
    final sankey = buildSankeyFromStructure(income.net, expenses);
    final nextMonths =
        structureForNextMonths(config: config, current: expenses);
    final daily = computeDailyBalanceSeries(
      config: config,
      income: income,
      expenses: expenses,
      days: 60,
    );
    final weekly = computeWeeklyIncomeVsExpense(
      config: config,
      income: income,
      expenses: expenses,
    );
    final compare = compareScenarios(config);
    final calendar = computeMonthCalendar(
      config: config,
      income: income,
      expenses: expenses,
      heatmap: false,
    );
    final heatmap = computeMonthCalendar(
      config: config,
      income: income,
      expenses: expenses,
      heatmap: true,
    );
    final basket = buildWeeklyBasket(
      foodPerDay: config.scenarios.isNotEmpty
          ? config.scenarios.first.foodPerDay
          : 14.3,
    );
    final trajectory = computeLongTermTrajectory(
      config: config,
      months: 24,
    );
    final progress = computeScenarioProgress(config: config);
    final portfolio = computePortfolio(config: config);
    final actions = generateActionPlan(
      config: config,
      expenses: expenses,
      loans: loans,
      accounts: accounts,
    );
    final scatter = buildRiskReturnScatter();
    return FinancialPlanReport(
      config: config,
      income: income,
      expenses: expenses,
      sankey: sankey,
      nextMonthsExpenses: nextMonths,
      dailyBalance: daily,
      weeklyFlow: weekly,
      scenarioCompare: compare,
      calendar: calendar,
      heatmap: heatmap,
      basket: basket,
      trajectory: trajectory,
      progress: progress,
      portfolio: portfolio,
      actionPlan: actions,
      scatter: scatter,
    );
  }

  // --------------------------------------------------------------------------
  //  1. Income waterfall.
  // --------------------------------------------------------------------------

  IncomeBreakdown computeIncomeBreakdown(FinancialPlanConfig config) {
    final extras = <SalaryDeduction>[];
    if (config.applyTradeUnion) {
      extras.add(const SalaryDeduction(
        id: 'trade_union',
        label: '1% профсоюз',
        kind: 'percent',
        value: 1,
        taxable: false,
      ));
    }
    final result = calcNetSalary(
      gross: config.salaryGross,
      children: config.children,
      dependents: config.dependents,
      applyStandardDeduction: config.applyStandardDeduction,
      extraDeductions: extras,
    );
    final advance = config.advanceAmount;
    final remainder = (result.net - advance).clamp(0.0, double.infinity);

    final steps = <WaterfallStep>[
      WaterfallStep(
        label: 'Грязная ЗП',
        value: result.gross,
        delta: result.gross,
        kind: WaterfallKind.gross,
        color: 0xFF1E3A8A,
      ),
      WaterfallStep(
        label: '−13% подоход.',
        value: result.gross - result.incomeTax,
        delta: -result.incomeTax,
        kind: WaterfallKind.deduction,
        color: 0xFFEF4444,
      ),
      WaterfallStep(
        label: '−1% пенс.',
        value: result.gross - result.incomeTax - result.fszn,
        delta: -result.fszn,
        kind: WaterfallKind.deduction,
        color: 0xFFF59E0B,
      ),
      WaterfallStep(
        label: '−1% профс.',
        value: result.gross -
            result.incomeTax -
            result.fszn -
            (config.applyTradeUnion ? result.postTaxDeductions : 0),
        delta: config.applyTradeUnion ? -result.postTaxDeductions : 0,
        kind: WaterfallKind.deduction,
        color: 0xFFF97316,
      ),
      WaterfallStep(
        label: 'Чистая ЗП',
        value: result.net,
        delta: 0,
        kind: WaterfallKind.net,
        color: 0xFF22C55E,
      ),
      WaterfallStep(
        label: '−Аванс',
        value: remainder,
        delta: -advance,
        kind: WaterfallKind.advance,
        color: 0xFFEF4444,
      ),
      WaterfallStep(
        label: 'На руки',
        value: remainder,
        delta: 0,
        kind: WaterfallKind.remainder,
        color: 0xFF14B8A6,
      ),
    ];

    return IncomeBreakdown(
      gross: result.gross,
      incomeTax: result.incomeTax,
      fszn: result.fszn,
      tradeUnion: config.applyTradeUnion ? result.postTaxDeductions : 0,
      net: result.net,
      advance: advance,
      netRemainder: remainder,
      steps: steps,
    );
  }

  // --------------------------------------------------------------------------
  //  2. Expense structure (recurring + one-off).
  // --------------------------------------------------------------------------

  ExpenseStructure computeExpenseStructure({
    required FinancialPlanConfig config,
    required List<MonthlyBudgetPlan> plans,
    required List<Loan> loans,
  }) {
    final monthKey =
        '${config.month.year}-${config.month.month.toString().padLeft(2, '0')}';
    final plan = plans.firstWhere(
      (p) => p.monthKey == monthKey,
      orElse: () => plans.isNotEmpty
          ? plans.first
          : MonthlyBudgetPlan(
              id: '_synthetic',
              monthKey: monthKey,
              plannedIncome: 0,
              categoryPlans: const [],
              createdAt: DateTime.now().toIso8601String(),
              updatedAt: DateTime.now().toIso8601String(),
            ),
    );

    final recurring = <ExpenseItem>[];
    final oneOff = <ExpenseItem>[];

    // Always include rent as the headline recurring expense.
    recurring.add(ExpenseItem(
      id: 'rent',
      label: 'Аренда',
      amount: config.rentAmount,
      color: 0xFF1E3A8A,
      recurring: true,
    ));

    final palette = <int>[
      0xFF14B8A6,
      0xFFEF4444,
      0xFFF59E0B,
      0xFFEC4899,
      0xFF8B5CF6,
      0xFF06B6D4,
      0xFF65A30D,
      0xFFF97316,
      0xFF22C55E,
      0xFFDB2777,
    ];
    var palIdx = 0;

    for (final loan in loans) {
      if (loan.balance <= 0) continue;
      recurring.add(ExpenseItem(
        id: 'loan_${loan.id}',
        label: 'Кредит ${loan.title}',
        amount: loan.monthlyPayment.toDouble(),
        color: palette[palIdx++ % palette.length],
        recurring: true,
      ));
    }

    final scheduled = plan.scheduledExpenses ?? const [];
    for (final s in scheduled) {
      final isRecurring =
          (s.recurEvery != null && s.recurEvery! > 0) || s.isSubscription == true;
      final color = palette[palIdx++ % palette.length];
      final item = ExpenseItem(
        id: 'sched_${s.id}',
        label: s.name,
        amount: s.amount.toDouble(),
        color: color,
        recurring: isRecurring,
      );
      if (isRecurring) {
        recurring.add(item);
      } else {
        oneOff.add(item);
      }
    }

    if (recurring.length == 1 && oneOff.isEmpty) {
      // No transactions yet — fall back to the PDF defaults so the page is
      // still meaningful on a brand-new install.
      recurring.addAll(const [
        ExpenseItem(
          id: 'utilities',
          label: 'Коммуналка',
          amount: 200,
          color: 0xFF14B8A6,
          recurring: true,
        ),
        ExpenseItem(
          id: 'food',
          label: 'Еда / быт',
          amount: 620,
          color: 0xFFEC4899,
          recurring: true,
        ),
        ExpenseItem(
          id: 'transit',
          label: 'Проездной',
          amount: 50,
          color: 0xFF65A30D,
          recurring: true,
        ),
        ExpenseItem(
          id: 'gym',
          label: 'Зал',
          amount: 100,
          color: 0xFF22C55E,
          recurring: true,
        ),
        ExpenseItem(
          id: 'lenses',
          label: 'Линзы',
          amount: 50,
          color: 0xFFF97316,
          recurring: true,
        ),
      ]);
      oneOff.add(const ExpenseItem(
        id: 'speaker',
        label: 'Колонка (разово)',
        amount: 300,
        color: 0xFFF59E0B,
        recurring: false,
      ));
    }

    final totalRecurring = recurring.fold<double>(0, (s, e) => s + e.amount);
    final totalOneOff = oneOff.fold<double>(0, (s, e) => s + e.amount);
    return ExpenseStructure(
      recurring: recurring,
      oneOff: oneOff,
      totalRecurring: totalRecurring,
      totalOneOff: totalOneOff,
    );
  }

  // --------------------------------------------------------------------------
  //  3. Sankey income → outflows.
  // --------------------------------------------------------------------------

  SankeyData buildSankeyFromStructure(
    double income,
    ExpenseStructure structure,
  ) {
    final outflows = [...structure.combined];
    final remainingForUsd =
        (income - structure.total).clamp(0.0, double.infinity);
    if (remainingForUsd > 1) {
      outflows.add(ExpenseItem(
        id: 'savings_usd',
        label: '\$ в USD',
        amount: remainingForUsd,
        color: 0xFF8B5CF6,
        recurring: false,
      ));
    }
    return SankeyData(income: income, outflows: outflows);
  }

  // --------------------------------------------------------------------------
  //  4. This month vs the next: one-offs disappear, freed cash → food + USD.
  // --------------------------------------------------------------------------

  NextMonthsExpenses structureForNextMonths({
    required FinancialPlanConfig config,
    required ExpenseStructure current,
  }) {
    if (current.oneOff.isEmpty) {
      // Synthesize a small uplift to food/USD for the second month so the
      // donut still tells a story.
      final next = ExpenseStructure(
        recurring: current.recurring,
        oneOff: const [],
        totalRecurring: current.totalRecurring,
        totalOneOff: 0,
      );
      return NextMonthsExpenses(thisMonth: current, nextMonth: next);
    }
    final freed = current.totalOneOff;
    final scen =
        config.scenarios.isNotEmpty ? config.scenarios.first : null;
    final nextRecurring = <ExpenseItem>[...current.recurring];
    final foodIdx =
        nextRecurring.indexWhere((e) => e.label.toLowerCase().contains('еда'));
    final extraFood = freed * 0.4;
    final extraUsd = freed - extraFood;
    if (foodIdx >= 0) {
      final f = nextRecurring[foodIdx];
      nextRecurring[foodIdx] = ExpenseItem(
        id: f.id,
        label: f.label,
        amount: f.amount + extraFood,
        color: f.color,
        recurring: true,
      );
    } else {
      nextRecurring.add(ExpenseItem(
        id: 'extra_food',
        label: 'Еда / быт +${extraFood.round()}',
        amount: extraFood,
        color: 0xFFEC4899,
        recurring: true,
      ));
    }
    nextRecurring.add(ExpenseItem(
      id: 'extra_usd',
      label: scen != null ? '+${extraUsd.round()} BYN в USD' : '+USD',
      amount: extraUsd,
      color: 0xFF8B5CF6,
      recurring: false,
    ));
    final next = ExpenseStructure(
      recurring: nextRecurring,
      oneOff: const [],
      totalRecurring: nextRecurring.fold<double>(0, (s, e) => s + e.amount),
      totalOneOff: 0,
    );
    return NextMonthsExpenses(thisMonth: current, nextMonth: next);
  }

  // --------------------------------------------------------------------------
  //  5. Daily balance for 60 days × 3 scenarios.
  // --------------------------------------------------------------------------

  DailyBalanceSeries computeDailyBalanceSeries({
    required FinancialPlanConfig config,
    required IncomeBreakdown income,
    required ExpenseStructure expenses,
    required int days,
  }) {
    final tracks = <DailyBalanceTrack>[];
    final start = config.month.subtract(const Duration(days: 6));
    for (final s in config.scenarios) {
      final pts = <double>[];
      double balance = 0;
      for (int d = 0; d < days; d++) {
        final date = start.add(Duration(days: d));
        // Pay-day income.
        if (date.day == config.payDay) {
          balance += income.netRemainder;
          // Rent + recurring debits land same day.
          balance -= config.rentAmount;
          balance -= expenses.totalRecurring -
              config.rentAmount; // utilities/loans/etc
          // One-offs are paid out of pay-day too (e.g. колонка).
          balance -= expenses.totalOneOff;
          // Buy USD.
          balance -= s.savingsUsd * config.usdRate;
        }
        // Advance.
        if (date.day == config.advanceDay) {
          balance += config.advanceAmount;
          // Advance is mostly used up by the user already in the PDF model;
          // simulate that by spending it down across the next ~5 days.
        }
        // Daily food spend (only after first paycheck arrived).
        if (balance > 0 && d >= _daysUntilFirstPay(start, config)) {
          balance -= s.foodPerDay;
        }
        if (balance < 0) balance = 0;
        pts.add(balance);
      }
      tracks.add(DailyBalanceTrack(
        scenarioId: s.id,
        label: s.name,
        color: s.color,
        points: pts,
      ));
    }
    final markers = <DailyMarker>[
      DailyMarker(
        dayOffset: _daysUntilFirstPay(start, config),
        label: 'ЗП ${config.payDay}.${config.month.month}',
        color: 0xFF22C55E,
      ),
      DailyMarker(
        dayOffset: _daysUntilFirstAdvance(start, config),
        label: 'Аванс +аренда',
        color: 0xFFEF4444,
      ),
    ];
    return DailyBalanceSeries(
      start: start,
      days: days,
      scenarios: tracks,
      markers: markers,
    );
  }

  int _daysUntilFirstPay(DateTime start, FinancialPlanConfig config) {
    var date = DateTime(start.year, start.month, start.day);
    for (int i = 0; i < 60; i++) {
      if (date.day == config.payDay) return i;
      date = date.add(const Duration(days: 1));
    }
    return 0;
  }

  int _daysUntilFirstAdvance(DateTime start, FinancialPlanConfig config) {
    var date = DateTime(start.year, start.month, start.day);
    for (int i = 0; i < 60; i++) {
      if (date.day == config.advanceDay) return i;
      date = date.add(const Duration(days: 1));
    }
    return 0;
  }

  // --------------------------------------------------------------------------
  //  6. Weekly grouped bars: income vs expense (scenario A).
  // --------------------------------------------------------------------------

  WeeklyFlow computeWeeklyIncomeVsExpense({
    required FinancialPlanConfig config,
    required IncomeBreakdown income,
    required ExpenseStructure expenses,
  }) {
    final firstScen = config.scenarios.isNotEmpty
        ? config.scenarios.first
        : SavingsScenario.defaults().first;
    const week1Income = 0.0;
    final week2Income = config.payDay > 7 && config.payDay <= 14
        ? income.netRemainder
        : 0.0;
    final week3Income = config.payDay > 14 && config.payDay <= 21
        ? income.netRemainder
        : 0.0;
    final week4Income = config.payDay > 21
        ? income.netRemainder
        : (config.advanceDay > 21 ? config.advanceAmount : 0);
    final week5Income = config.advanceDay > 28 || config.advanceDay < 7
        ? config.advanceAmount
        : 0.0;
    final groceryWeek = firstScen.foodPerDay * 7;
    final week1Expense = groceryWeek;
    final week2Expense = groceryWeek + (config.payDay > 7 ? expenses.totalRecurring : 0);
    final week3Expense =
        config.payDay > 14 && config.payDay <= 21 ? expenses.totalRecurring + expenses.totalOneOff : groceryWeek;
    final week4Expense = groceryWeek + config.rentAmount * 0.0;
    final week5Expense = groceryWeek;
    return WeeklyFlow(
      weekLabels: const ['Нед 1', 'Нед 2', 'Нед 3', 'Нед 4', 'Нед 5'],
      income: [
        week1Income.toDouble(),
        week2Income.toDouble(),
        week3Income.toDouble(),
        week4Income.toDouble(),
        week5Income.toDouble(),
      ],
      expense: [
        week1Expense.toDouble(),
        week2Expense.toDouble(),
        week3Expense.toDouble(),
        week4Expense.toDouble(),
        week5Expense.toDouble(),
      ],
    );
  }

  // --------------------------------------------------------------------------
  //  7. Scenario comparison (savings/food/comfort + full table).
  // --------------------------------------------------------------------------

  List<ScenarioComparison> compareScenarios(FinancialPlanConfig config) {
    final goalUsd = _goalAsUsd(config);
    return config.scenarios.map((s) {
      final yearUsd = s.savingsUsd * 12 +
          (s.cashbackPerMonth + s.sideHustlePerMonth) * 12 / config.usdRate;
      final months16 =
          s.savingsUsd * 16 +
              (s.cashbackPerMonth + s.sideHustlePerMonth) * 16 / config.usdRate;
      final monthsToGoal = _monthsToGoal(s, goalUsd, config.usdRate);
      return ScenarioComparison(
        scenarioId: s.id,
        name: s.name,
        subtitle: s.subtitle,
        color: s.color,
        savingsUsdYear: yearUsd,
        savings16mUsd: months16,
        monthsToGoal: monthsToGoal,
        foodPerDay: s.foodPerDay,
        foodPerWeek: s.foodPerDay * 7,
        gym: s.includeGym ? 'Да (100 BYN)' : 'Нет',
        lenses: s.includeLenses ? 'Купить' : 'Отложить',
        cashback: s.cashbackPerMonth > 0
            ? '~${s.cashbackPerMonth.round()} BYN/мес'
            : 'нет',
        reserve: s.comfort >= 8
            ? 'Есть (~150)'
            : s.comfort >= 5
                ? 'Минимум'
                : 'Нет',
        stress: s.comfort >= 8
            ? 'Низкий'
            : s.comfort >= 5
                ? 'Средний'
                : 'Высокий',
        comfort: s.comfort,
        suitability: s.comfort >= 8
            ? 'только начинаешь'
            : s.comfort >= 5
                ? 'хочешь быстро + готов 1 мес без зала'
                : 'есть запас продуктов дома',
      );
    }).toList();
  }

  double _goalAsUsd(FinancialPlanConfig config) {
    if (config.goalCurrency == 'USD') return config.goalAmount;
    return config.goalAmount / config.usdRate;
  }

  int _monthsToGoal(SavingsScenario s, double goalUsd, double usdRate) {
    final perMonthUsd = s.savingsUsd +
        (s.cashbackPerMonth + s.sideHustlePerMonth) / usdRate;
    if (perMonthUsd <= 0) return 999;
    return (goalUsd / perMonthUsd).ceil();
  }

  // --------------------------------------------------------------------------
  //  8. Calendar grid 7 × N + heatmap variant.
  // --------------------------------------------------------------------------

  MonthCalendar computeMonthCalendar({
    required FinancialPlanConfig config,
    required IncomeBreakdown income,
    required ExpenseStructure expenses,
    required bool heatmap,
  }) {
    final firstDay = DateTime(config.month.year, config.month.month, 1);
    final lastDay = DateTime(config.month.year, config.month.month + 1, 0);
    final firstWeekday = firstDay.weekday; // Mon=1..Sun=7
    final daysInMonth = lastDay.day;

    final firstScen = config.scenarios.isNotEmpty
        ? config.scenarios.first
        : SavingsScenario.defaults().first;

    final weeks = <List<CalendarCell>>[];
    var current = <CalendarCell>[];
    for (int i = 1; i < firstWeekday; i++) {
      current.add(const CalendarCell(
        day: 0,
        label: '',
        delta: 0,
        kind: CalendarKind.filler,
      ));
    }
    for (int day = 1; day <= daysInMonth; day++) {
      late CalendarCell cell;
      if (day == config.payDay) {
        cell = CalendarCell(
          day: day,
          label: '+${income.netRemainder.round()}\nЗП',
          delta: income.netRemainder,
          kind: CalendarKind.income,
        );
      } else if (day == config.advanceDay) {
        cell = CalendarCell(
          day: day,
          label: '+${config.advanceAmount.round()}\n−1000 аренда!',
          delta: config.advanceAmount - config.rentAmount,
          kind: CalendarKind.rent,
        );
      } else if (day == config.rentDay && day != config.payDay) {
        cell = CalendarCell(
          day: day,
          label: '−${config.rentAmount.round()} аренда',
          delta: -config.rentAmount,
          kind: CalendarKind.bigSpend,
        );
      } else {
        final daily = -firstScen.foodPerDay;
        if (day < (DateTime.now().day) && config.month.month == DateTime.now().month) {
          cell = const CalendarCell(
            day: 0,
            label: '0 BYN',
            delta: 0,
            kind: CalendarKind.empty,
          );
        } else {
          cell = CalendarCell(
            day: day,
            label: daily.toStringAsFixed(0),
            delta: daily,
            kind: CalendarKind.spend,
          );
        }
      }
      // For early days before pay-day → "ничего тратить".
      if (day < config.payDay) {
        cell = CalendarCell(
          day: day,
          label: '0 BYN',
          delta: 0,
          kind: CalendarKind.empty,
        );
      }
      // Pay day overrides "ничего тратить".
      if (day == config.payDay) {
        cell = CalendarCell(
          day: day,
          label: '+${income.netRemainder.round()}\nЗП',
          delta: income.netRemainder,
          kind: CalendarKind.income,
        );
      }
      if (day == config.advanceDay) {
        cell = CalendarCell(
          day: day,
          label: '+${config.advanceAmount.round()}\n−${config.rentAmount.round()} аренда!',
          delta: config.advanceAmount - config.rentAmount,
          kind: CalendarKind.rent,
        );
      }
      current.add(cell);
      if (current.length == 7) {
        weeks.add(current);
        current = [];
      }
    }
    if (current.isNotEmpty) {
      while (current.length < 7) {
        current.add(const CalendarCell(
          day: 0,
          label: '',
          delta: 0,
          kind: CalendarKind.filler,
        ));
      }
      weeks.add(current);
    }
    final legend = const [
      HeatmapBucket(label: 'Поступление', color: 0xFF22C55E),
      HeatmapBucket(label: '0 BYN, нечего тратить', color: 0xFFFEE2E2),
      HeatmapBucket(label: 'До 30 BYN (норма)', color: 0xFFD1FAE5),
      HeatmapBucket(label: '30–100 BYN', color: 0xFFFEF3C7),
      HeatmapBucket(label: '100–500 BYN', color: 0xFFFED7AA),
      HeatmapBucket(label: '500+ BYN (крупный)', color: 0xFFEF4444),
    ];
    return MonthCalendar(
      weeks: weeks,
      firstWeekday: firstWeekday,
      daysInMonth: daysInMonth,
      legend: legend,
    );
  }

  // --------------------------------------------------------------------------
  //  9. Weekly basket (template).
  // --------------------------------------------------------------------------

  WeeklyBasket buildWeeklyBasket({required double foodPerDay}) {
    final scale = (foodPerDay * 7) / 100;
    final items = <BasketItem>[
      BasketItem(label: 'Хлеб (буханка)', amount: 7.5 * scale, color: 0xFF1E3A8A, group: 'Хлеб/молочка'),
      BasketItem(label: 'Молоко 1л', amount: 14.0 * scale, color: 0xFF93C5FD, group: 'Хлеб/молочка'),
      BasketItem(label: 'Яйца', amount: 5.5 * scale, color: 0xFFF97316, group: 'Мясо/яйца'),
      BasketItem(label: 'Гречка / рис', amount: 3.5 * scale, color: 0xFF22C55E, group: 'Крупы/макароны'),
      BasketItem(label: 'Макароны', amount: 3.0 * scale, color: 0xFF86EFAC, group: 'Крупы/макароны'),
      BasketItem(label: 'Курица (бедро)', amount: 12.0 * scale, color: 0xFFF87171, group: 'Мясо/яйца'),
      BasketItem(label: 'Картофель', amount: 4.5 * scale, color: 0xFF8B5CF6, group: 'Овощи'),
      BasketItem(label: 'Лук / морковь', amount: 3.6 * scale, color: 0xFF92400E, group: 'Овощи'),
      BasketItem(label: 'Капуста / огурцы', amount: 6.0 * scale, color: 0xFFD6BCAA, group: 'Овощи'),
      BasketItem(label: 'Сыр', amount: 12.0 * scale, color: 0xFFEC4899, group: 'Хлеб/молочка'),
      BasketItem(label: 'Творог', amount: 5.0 * scale, color: 0xFF6B7280, group: 'Хлеб/молочка'),
      BasketItem(label: 'Чай / кофе', amount: 8.0 * scale, color: 0xFFE5E7EB, group: 'Чай/масло/сахар'),
      BasketItem(label: 'Масло раст.', amount: 5.0 * scale, color: 0xFFFDE047, group: 'Чай/масло/сахар'),
      BasketItem(label: 'Сахар', amount: 2.5 * scale, color: 0xFF06B6D4, group: 'Чай/масло/сахар'),
      BasketItem(label: 'Бытовое (мыло, ШТ)', amount: 8.0 * scale, color: 0xFFA5F3FC, group: 'Бытовое'),
    ];
    final groupMap = <String, double>{};
    final groupColor = <String, int>{
      'Хлеб/молочка': 0xFF06B6D4,
      'Мясо/яйца': 0xFFF87171,
      'Крупы/макароны': 0xFFFB923C,
      'Овощи': 0xFF22C55E,
      'Чай/масло/сахар': 0xFF8B5CF6,
      'Бытовое': 0xFF6B7280,
    };
    for (final item in items) {
      groupMap.update(item.group, (v) => v + item.amount,
          ifAbsent: () => item.amount);
    }
    final groups = groupMap.entries
        .map((e) => BasketGroup(
              label: e.key,
              amount: e.value,
              color: groupColor[e.key] ?? 0xFF6B7280,
            ))
        .toList();
    return WeeklyBasket(items: items, groups: groups);
  }

  // --------------------------------------------------------------------------
  //  10. Long-term trajectory (months × scenarios).
  // --------------------------------------------------------------------------

  LongTermTrajectory computeLongTermTrajectory({
    required FinancialPlanConfig config,
    required int months,
  }) {
    final goalUsd = _goalAsUsd(config);
    final tracks = <TrajectoryTrack>[];
    for (final s in config.scenarios) {
      final perMonth = s.savingsUsd +
          (s.cashbackPerMonth + s.sideHustlePerMonth) / config.usdRate;
      final pts = <double>[];
      double total = 0;
      int reach = 0;
      for (int m = 0; m < months; m++) {
        if (total >= goalUsd && reach == 0) reach = m;
        pts.add(total);
        total += perMonth;
      }
      tracks.add(TrajectoryTrack(
        scenarioId: s.id,
        label: '${s.id} · \$${perMonth.toStringAsFixed(0)}/мес',
        color: s.color,
        points: pts,
        monthsToGoal: reach > 0 ? reach : _monthsToGoal(s, goalUsd, config.usdRate),
      ));
    }
    return LongTermTrajectory(
      months: months,
      tracks: tracks,
      goalUsd: goalUsd,
    );
  }

  // --------------------------------------------------------------------------
  //  11. Per-scenario progress bars.
  // --------------------------------------------------------------------------

  List<ScenarioProgress> computeScenarioProgress({
    required FinancialPlanConfig config,
  }) {
    final goalUsd = _goalAsUsd(config);
    return config.scenarios.map((s) {
      final perMonth = s.savingsUsd +
          (s.cashbackPerMonth + s.sideHustlePerMonth) / config.usdRate;
      return ScenarioProgress(
        scenarioId: s.id,
        name: s.name,
        color: s.color,
        totalMonths: perMonth > 0 ? (goalUsd / perMonth).ceil() : 999,
        savedUsd6m: perMonth * 6,
        savedUsd12m: perMonth * 12,
        goalUsd: goalUsd,
      );
    }).toList();
  }

  // --------------------------------------------------------------------------
  //  12. Portfolio donut + quarterly bars.
  // --------------------------------------------------------------------------

  PortfolioPlan computePortfolio({required FinancialPlanConfig config}) {
    final goalUsd = _goalAsUsd(config);
    final slices = <PortfolioSlice>[];
    final totalPercent =
        config.portfolio.fold<double>(0, (s, e) => s + e.percent);
    for (final p in config.portfolio) {
      final inst = findInstrument(p.instrumentId);
      slices.add(PortfolioSlice(
        instrumentId: p.instrumentId,
        label: inst?.shortName ?? p.instrumentId,
        percent: totalPercent > 0 ? p.percent / totalPercent * 100 : p.percent,
        amountUsd: goalUsd * (p.percent / 100.0),
        color: inst?.color ?? 0xFF6B7280,
      ));
    }

    final scen = config.scenarios.isNotEmpty
        ? config.scenarios.last
        : SavingsScenario.defaults().last;
    final perMonth = scen.savingsUsd +
        (scen.cashbackPerMonth + scen.sideHustlePerMonth) / config.usdRate;
    final palette = const [
      0xFF22C55E,
      0xFF14B8A6,
      0xFFF59E0B,
      0xFFEF4444,
      0xFF8B5CF6,
    ];
    final quarterly = <QuarterlyAccrual>[];
    for (int q = 1; q <= 5; q++) {
      quarterly.add(QuarterlyAccrual(
        label: 'Q$q',
        amountUsd: perMonth * 3 * q,
        color: palette[(q - 1) % palette.length],
      ));
    }
    return PortfolioPlan(
      allocations: slices,
      totalUsd: goalUsd,
      quarterly: quarterly,
    );
  }

  // --------------------------------------------------------------------------
  //  13. Action plan — rule-based 10 steps.
  // --------------------------------------------------------------------------

  List<ActionStep> generateActionPlan({
    required FinancialPlanConfig config,
    required ExpenseStructure expenses,
    required List<Loan> loans,
    required List<Account> accounts,
  }) {
    final out = <ActionStep>[];
    final mm = config.month.month.toString().padLeft(2, '0');
    final payday = '${config.payDay.toString().padLeft(2, '0')}.$mm';
    final advance = '${config.advanceDay.toString().padLeft(2, '0')}.$mm';

    out.add(ActionStep(
      dateLabel: 'до $payday',
      text: 'Не тратить ни копейки. Питаться домашними запасами.',
      urgency: ActionUrgency.urgent,
    ));

    final overdraft = accounts.firstWhere(
      (a) => a.name.toLowerCase().contains('овердрафт') ||
          a.name.toLowerCase().contains('mtbank'),
      orElse: () => Account(
        id: '_none',
        name: '',
        type:
            accounts.isNotEmpty ? accounts.first.type : AccountType.card,
        currency: 'BYN',
        initialBalance: 0,
        color: '#000',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    if (overdraft.id != '_none') {
      out.add(ActionStep(
        dateLabel: 'до $payday',
        text: 'Узнать сумму овердрафта ${overdraft.name} и его %.',
        urgency: ActionUrgency.urgent,
      ));
    } else {
      out.add(ActionStep(
        dateLabel: 'до $payday',
        text: 'Узнать сумму овердрафта MTBank и его %.',
        urgency: ActionUrgency.urgent,
      ));
    }

    final scen = config.scenarios.isNotEmpty
        ? config.scenarios.first
        : SavingsScenario.defaults().first;
    out.add(ActionStep(
      dateLabel: payday,
      text:
          'ЗП пришла → СРАЗУ купить \$${scen.savingsUsd.round()} (≈${(scen.savingsUsd * config.usdRate).round()} BYN). Если без зала/линз — сразу \$200.',
      urgency: ActionUrgency.now,
    ));

    out.add(ActionStep(
      dateLabel: payday,
      text:
          'Оплатить через ЕРИП: коммуналка ${expenses.recurring.firstWhere((e) => e.label.toLowerCase().contains('комм'), orElse: () => const ExpenseItem(id: '_', label: '', amount: 200, color: 0xFF000000, recurring: true)).amount.round()}, кредит ${expenses.recurring.where((e) => e.label.toLowerCase().contains('кредит')).fold<double>(0, (s, e) => s + e.amount).round()}.',
      urgency: ActionUrgency.soon,
    ));

    if (expenses.totalOneOff > 0) {
      final names = expenses.oneOff
          .map((e) => '${e.label} ${e.amount.round()}')
          .join(', ');
      out.add(ActionStep(
        dateLabel: payday,
        text: 'Купить разовое: $names (если не пропускаешь).',
        urgency: ActionUrgency.soon,
      ));
    } else {
      out.add(const ActionStep(
        dateLabel: '15.05',
        text: 'Купить колонку 300, проездной 50, оплатить зал 100 (если не пропускаешь).',
        urgency: ActionUrgency.soon,
      ));
    }

    out.add(ActionStep(
      dateLabel: '${(config.payDay + 1).toString().padLeft(2, '0')}.$mm — ${(config.advanceDay - 1).toString().padLeft(2, '0')}.$mm',
      text:
          'Бюджет ${scen.foodPerDay.toInt()}–${(scen.foodPerDay * 2).toInt()} BYN/день (зависит от сценария). Закупки в гипермаркетах.',
      urgency: ActionUrgency.later,
    ));

    if (config.scenarios.any((s) => s.cashbackPerMonth >= 30)) {
      out.add(const ActionStep(
        dateLabel: '16–29.05',
        text: 'Завести Halva или Карту №1 для кэшбэка 1–5%.',
        urgency: ActionUrgency.later,
      ));
    }

    out.add(ActionStep(
      dateLabel: advance,
      text:
          'Аванс ${config.advanceAmount.round()} → отделить ${config.rentAmount.round()} BYN на аренду (плюс \$${scen.savingsUsd.round()} если выбрал ${scen.id}).',
      urgency: ActionUrgency.urgent,
    ));

    out.add(const ActionStep(
      dateLabel: 'В июне',
      text:
          'Со 2-го мес нет 300 BYN на колонку → копи \$200/мес. Открой депозит BYN ~10%.',
      urgency: ActionUrgency.now,
    ));

    final hiRate = loans.where((l) => l.annualRate > 18).toList();
    if (hiRate.isNotEmpty) {
      final t = hiRate.map((l) => '${l.title} (${l.annualRate}%)').join(', ');
      out.add(ActionStep(
        dateLabel: 'За 2 мес',
        text: 'Закрыть овердрафт MTBank, рефинанс кредита: $t < 14–18%.',
        urgency: ActionUrgency.future,
      ));
    } else {
      out.add(const ActionStep(
        dateLabel: 'За 2 мес',
        text: 'Закрыть овердрафт MTBank, рассмотреть рефинанс кредита.',
        urgency: ActionUrgency.future,
      ));
    }
    return out;
  }

  // --------------------------------------------------------------------------
  //  14. Risk/return scatter for «Карта инструментов БРБ».
  // --------------------------------------------------------------------------

  RiskReturnScatter buildRiskReturnScatter() {
    final pts = brbInstruments
        .map((i) => ScatterPoint(
              label: i.shortName,
              risk: i.risk.toDouble(),
              yieldPct: i.midYield,
              color: i.color,
            ))
        .toList();
    return RiskReturnScatter(
      points: pts,
      sweetSpot: const ScatterRect(
        minRisk: 0.5,
        maxRisk: 3,
        minYield: 7,
        maxYield: 15,
      ),
      startArrow: const ScatterArrow(
        fromRisk: 2,
        fromYield: 10,
        toRisk: 6.5,
        toYield: 22,
        label: 'СТАРТУЙ ОТСЮДА:\nдепозит BYN или\nоблигации Минфина',
      ),
    );
  }
}

const FinancialPlanService kFinancialPlanService = FinancialPlanService();
