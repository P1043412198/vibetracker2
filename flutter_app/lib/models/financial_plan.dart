// Models for the «Финансовый план» feature — a personalised, data-driven
// rebuild of the static PDF report (`financial_plan_may.pdf`). Everything is
// derived from the user's existing transactions, accounts, loans and a small
// editable [FinancialPlanConfig].
import 'package:flutter/material.dart';

/// Top-level configuration for the plan. Persisted via [AppStorage] under the
/// `financial_plan_config` key.
class FinancialPlanConfig {
  FinancialPlanConfig({
    required this.salaryGross,
    required this.advanceAmount,
    required this.advanceDay,
    required this.payDay,
    required this.rentAmount,
    required this.rentDay,
    required this.goalAmount,
    required this.goalCurrency,
    required this.usdRate,
    required this.children,
    required this.dependents,
    required this.applyStandardDeduction,
    required this.applyTradeUnion,
    required this.scenarios,
    required this.portfolio,
    required this.month,
  });

  /// Gross monthly salary (BYN).
  final double salaryGross;

  /// Amount of the salary advance (BYN).
  final double advanceAmount;

  /// Day-of-month the advance lands (1..31).
  final int advanceDay;

  /// Day-of-month the remainder of the salary lands (1..31).
  final int payDay;

  /// Monthly rent (BYN), debited on [rentDay] right after [payDay].
  final double rentAmount;

  /// Day-of-month rent is debited (typically same as [payDay]).
  final int rentDay;

  /// Long-term savings goal value (in [goalCurrency]).
  final double goalAmount;

  /// Currency of [goalAmount] — usually `BYN` or `USD`.
  final String goalCurrency;

  /// Buying USD rate (BYN per 1 USD) used for $→BYN conversions in scenarios.
  final double usdRate;

  /// Number of own children (used by BY std deduction rules).
  final int children;

  /// Number of dependents.
  final int dependents;

  /// Apply the BY standard deduction (174 BYN if gross ≤ 1054 BYN).
  final bool applyStandardDeduction;

  /// Apply the 1% trade-union deduction in the waterfall.
  final bool applyTradeUnion;

  /// Three savings scenarios ($/month + lifestyle toggles).
  final List<SavingsScenario> scenarios;

  /// Target portfolio allocation (percent must sum to 100).
  final List<PortfolioAllocation> portfolio;

  /// Month the plan is generated for (first day of the month).
  final DateTime month;

  factory FinancialPlanConfig.defaults() {
    return FinancialPlanConfig(
      salaryGross: 3300,
      advanceAmount: 513,
      advanceDay: 30,
      payDay: 15,
      rentAmount: 1000,
      rentDay: 15,
      goalAmount: 12000,
      goalCurrency: 'BYN',
      usdRate: 2.85,
      children: 0,
      dependents: 0,
      applyStandardDeduction: false,
      applyTradeUnion: true,
      scenarios: SavingsScenario.defaults(),
      portfolio: PortfolioAllocation.defaults(),
      month: DateTime(DateTime.now().year, DateTime.now().month, 1),
    );
  }

  FinancialPlanConfig copyWith({
    double? salaryGross,
    double? advanceAmount,
    int? advanceDay,
    int? payDay,
    double? rentAmount,
    int? rentDay,
    double? goalAmount,
    String? goalCurrency,
    double? usdRate,
    int? children,
    int? dependents,
    bool? applyStandardDeduction,
    bool? applyTradeUnion,
    List<SavingsScenario>? scenarios,
    List<PortfolioAllocation>? portfolio,
    DateTime? month,
  }) {
    return FinancialPlanConfig(
      salaryGross: salaryGross ?? this.salaryGross,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      advanceDay: advanceDay ?? this.advanceDay,
      payDay: payDay ?? this.payDay,
      rentAmount: rentAmount ?? this.rentAmount,
      rentDay: rentDay ?? this.rentDay,
      goalAmount: goalAmount ?? this.goalAmount,
      goalCurrency: goalCurrency ?? this.goalCurrency,
      usdRate: usdRate ?? this.usdRate,
      children: children ?? this.children,
      dependents: dependents ?? this.dependents,
      applyStandardDeduction:
          applyStandardDeduction ?? this.applyStandardDeduction,
      applyTradeUnion: applyTradeUnion ?? this.applyTradeUnion,
      scenarios: scenarios ?? this.scenarios,
      portfolio: portfolio ?? this.portfolio,
      month: month ?? this.month,
    );
  }

  Map<String, dynamic> toJson() => {
        'salaryGross': salaryGross,
        'advanceAmount': advanceAmount,
        'advanceDay': advanceDay,
        'payDay': payDay,
        'rentAmount': rentAmount,
        'rentDay': rentDay,
        'goalAmount': goalAmount,
        'goalCurrency': goalCurrency,
        'usdRate': usdRate,
        'children': children,
        'dependents': dependents,
        'applyStandardDeduction': applyStandardDeduction,
        'applyTradeUnion': applyTradeUnion,
        'scenarios': scenarios.map((s) => s.toJson()).toList(),
        'portfolio': portfolio.map((p) => p.toJson()).toList(),
        'month': month.toIso8601String(),
      };

  factory FinancialPlanConfig.fromJson(Map<String, dynamic> json) {
    final scenarios = (json['scenarios'] as List?)
            ?.whereType<Map>()
            .map((e) => SavingsScenario.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v))))
            .toList() ??
        SavingsScenario.defaults();
    final portfolio = (json['portfolio'] as List?)
            ?.whereType<Map>()
            .map((e) => PortfolioAllocation.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v))))
            .toList() ??
        PortfolioAllocation.defaults();
    final monthRaw = json['month'] as String?;
    final month = monthRaw != null
        ? DateTime.tryParse(monthRaw) ?? DateTime.now()
        : DateTime.now();
    return FinancialPlanConfig(
      salaryGross: ((json['salaryGross'] ?? 3300) as num).toDouble(),
      advanceAmount: ((json['advanceAmount'] ?? 513) as num).toDouble(),
      advanceDay: ((json['advanceDay'] ?? 30) as num).toInt(),
      payDay: ((json['payDay'] ?? 15) as num).toInt(),
      rentAmount: ((json['rentAmount'] ?? 1000) as num).toDouble(),
      rentDay: ((json['rentDay'] ?? 15) as num).toInt(),
      goalAmount: ((json['goalAmount'] ?? 12000) as num).toDouble(),
      goalCurrency: (json['goalCurrency'] ?? 'BYN') as String,
      usdRate: ((json['usdRate'] ?? 2.85) as num).toDouble(),
      children: ((json['children'] ?? 0) as num).toInt(),
      dependents: ((json['dependents'] ?? 0) as num).toInt(),
      applyStandardDeduction:
          (json['applyStandardDeduction'] ?? false) as bool,
      applyTradeUnion: (json['applyTradeUnion'] ?? true) as bool,
      scenarios: scenarios,
      portfolio: portfolio,
      month: DateTime(month.year, month.month, 1),
    );
  }
}

/// One named savings scenario — e.g. `A · $100 в мае`, `B · $200 без зала/линз`.
class SavingsScenario {
  SavingsScenario({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.savingsUsd,
    required this.includeGym,
    required this.includeLenses,
    required this.foodPerDay,
    required this.cashbackPerMonth,
    required this.sideHustlePerMonth,
    required this.comfort,
    required this.color,
  });

  final String id;
  final String name;
  final String subtitle;

  /// Amount in USD that the user buys/locks-up each month.
  final double savingsUsd;
  final bool includeGym;
  final bool includeLenses;

  /// BYN budget for groceries/everyday expenses per day.
  final double foodPerDay;

  /// Optional cashback (BYN/month) — Halva-style accelerator.
  final double cashbackPerMonth;

  /// Optional side-hustle income (BYN/month) — e.g. delivery 4h/week.
  final double sideHustlePerMonth;

  /// Subjective lifestyle comfort score 1..10.
  final int comfort;

  /// Display colour for the scenario (used across line/bar charts).
  final int color;

  Color get colorValue => Color(color);

  static List<SavingsScenario> defaults() => [
        SavingsScenario(
          id: 'A',
          name: 'A · \$100 в мае',
          subtitle: 'комфорт',
          savingsUsd: 100,
          includeGym: true,
          includeLenses: true,
          foodPerDay: 21,
          cashbackPerMonth: 30,
          sideHustlePerMonth: 0,
          comfort: 9,
          color: 0xFF22C55E,
        ),
        SavingsScenario(
          id: 'B',
          name: 'B · \$200 без зала/линз',
          subtitle: 'без зала/линз',
          savingsUsd: 200,
          includeGym: false,
          includeLenses: false,
          foodPerDay: 16,
          cashbackPerMonth: 30,
          sideHustlePerMonth: 0,
          comfort: 6,
          color: 0xFFF59E0B,
        ),
        SavingsScenario(
          id: 'C',
          name: 'C · \$200 + кэшбэк + подработка',
          subtitle: 'полный фикс',
          savingsUsd: 200,
          includeGym: true,
          includeLenses: true,
          foodPerDay: 11,
          cashbackPerMonth: 30,
          sideHustlePerMonth: 280,
          comfort: 4,
          color: 0xFFEF4444,
        ),
      ];

  SavingsScenario copyWith({
    String? name,
    String? subtitle,
    double? savingsUsd,
    bool? includeGym,
    bool? includeLenses,
    double? foodPerDay,
    double? cashbackPerMonth,
    double? sideHustlePerMonth,
    int? comfort,
    int? color,
  }) =>
      SavingsScenario(
        id: id,
        name: name ?? this.name,
        subtitle: subtitle ?? this.subtitle,
        savingsUsd: savingsUsd ?? this.savingsUsd,
        includeGym: includeGym ?? this.includeGym,
        includeLenses: includeLenses ?? this.includeLenses,
        foodPerDay: foodPerDay ?? this.foodPerDay,
        cashbackPerMonth: cashbackPerMonth ?? this.cashbackPerMonth,
        sideHustlePerMonth: sideHustlePerMonth ?? this.sideHustlePerMonth,
        comfort: comfort ?? this.comfort,
        color: color ?? this.color,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'savingsUsd': savingsUsd,
        'includeGym': includeGym,
        'includeLenses': includeLenses,
        'foodPerDay': foodPerDay,
        'cashbackPerMonth': cashbackPerMonth,
        'sideHustlePerMonth': sideHustlePerMonth,
        'comfort': comfort,
        'color': color,
      };

  factory SavingsScenario.fromJson(Map<String, dynamic> json) =>
      SavingsScenario(
        id: (json['id'] ?? '?') as String,
        name: (json['name'] ?? '') as String,
        subtitle: (json['subtitle'] ?? '') as String,
        savingsUsd: ((json['savingsUsd'] ?? 0) as num).toDouble(),
        includeGym: (json['includeGym'] ?? false) as bool,
        includeLenses: (json['includeLenses'] ?? false) as bool,
        foodPerDay: ((json['foodPerDay'] ?? 0) as num).toDouble(),
        cashbackPerMonth: ((json['cashbackPerMonth'] ?? 0) as num).toDouble(),
        sideHustlePerMonth:
            ((json['sideHustlePerMonth'] ?? 0) as num).toDouble(),
        comfort: ((json['comfort'] ?? 5) as num).toInt(),
        color: ((json['color'] ?? 0xFF22C55E) as num).toInt(),
      );
}

/// One slice of the long-term portfolio (Минфин-облигации, USD-депозит, …).
class PortfolioAllocation {
  PortfolioAllocation({
    required this.instrumentId,
    required this.percent,
  });

  final String instrumentId;

  /// 0..100.
  final double percent;

  static List<PortfolioAllocation> defaults() => [
        PortfolioAllocation(instrumentId: 'minfin_byn_bonds', percent: 50),
        PortfolioAllocation(instrumentId: 'usd_deposit', percent: 30),
        PortfolioAllocation(instrumentId: 'byn_deposit', percent: 15),
        PortfolioAllocation(instrumentId: 'cash', percent: 5),
      ];

  PortfolioAllocation copyWith({String? instrumentId, double? percent}) =>
      PortfolioAllocation(
        instrumentId: instrumentId ?? this.instrumentId,
        percent: percent ?? this.percent,
      );

  Map<String, dynamic> toJson() => {
        'instrumentId': instrumentId,
        'percent': percent,
      };

  factory PortfolioAllocation.fromJson(Map<String, dynamic> json) =>
      PortfolioAllocation(
        instrumentId: (json['instrumentId'] ?? '') as String,
        percent: ((json['percent'] ?? 0) as num).toDouble(),
      );
}

/// One investment instrument available on the BY market — used both by the
/// portfolio editor and by the «Карта инструментов БРБ» risk/return scatter.
class InvestmentInstrument {
  const InvestmentInstrument({
    required this.id,
    required this.name,
    required this.shortName,
    required this.currency,
    required this.yieldFromPct,
    required this.yieldToPct,
    required this.risk,
    required this.minAmount,
    required this.minAmountCurrency,
    required this.color,
    required this.note,
  });

  final String id;
  final String name;
  final String shortName;
  final String currency;

  /// Lower bound of the annual yield in percent.
  final double yieldFromPct;

  /// Upper bound of the annual yield in percent.
  final double yieldToPct;

  /// Risk score 1 (none) … 10 (lottery).
  final int risk;
  final double minAmount;
  final String minAmountCurrency;
  final int color;
  final String note;

  Color get colorValue => Color(color);

  double get midYield => (yieldFromPct + yieldToPct) / 2;
}

/// 12 instruments commonly available to a BY retail investor — values are
/// approximate as of mid-2026 and are used for the risk/return chart and the
/// instruments table at the bottom of the report.
const List<InvestmentInstrument> brbInstruments = [
  InvestmentInstrument(
    id: 'byn_deposit',
    name: 'Депозит BYN (Беларусбанк)',
    shortName: 'Депозит BYN 10%',
    currency: 'BYN',
    yieldFromPct: 9,
    yieldToPct: 11,
    risk: 2,
    minAmount: 100,
    minAmountCurrency: 'BYN',
    color: 0xFF22C55E,
    note: 'Гарантирован государством. Налог 13% на доход от краткосрочных.',
  ),
  InvestmentInstrument(
    id: 'minfin_byn_bonds',
    name: 'Облигации Минфина BYN',
    shortName: 'Облигации Минфина BYN',
    currency: 'BYN',
    yieldFromPct: 9,
    yieldToPct: 11,
    risk: 2,
    minAmount: 100,
    minAmountCurrency: 'BYN',
    color: 0xFF14B8A6,
    note: 'Государственные облигации. Без налога на купон.',
  ),
  InvestmentInstrument(
    id: 'minfin_usd_bonds',
    name: 'Облигации Минфина USD',
    shortName: 'Облигации Минфина USD',
    currency: 'USD',
    yieldFromPct: 4,
    yieldToPct: 6,
    risk: 2,
    minAmount: 100,
    minAmountCurrency: 'USD',
    color: 0xFF06B6D4,
    note: 'Защита от девальвации. Купонный доход в USD.',
  ),
  InvestmentInstrument(
    id: 'usd_deposit',
    name: 'Депозит USD',
    shortName: 'Депозит USD',
    currency: 'USD',
    yieldFromPct: 1,
    yieldToPct: 3,
    risk: 1,
    minAmount: 100,
    minAmountCurrency: 'USD',
    color: 0xFF1E40AF,
    note: 'Защита от девальвации. Низкий процент.',
  ),
  InvestmentInstrument(
    id: 'eur_deposit',
    name: 'Депозит EUR',
    shortName: 'Депозит EUR',
    currency: 'EUR',
    yieldFromPct: 0.5,
    yieldToPct: 2,
    risk: 1,
    minAmount: 100,
    minAmountCurrency: 'EUR',
    color: 0xFF1E3A8A,
    note: 'Стабильность, ниже доходность чем USD.',
  ),
  InvestmentInstrument(
    id: 'corp_bonds',
    name: 'Корпоративные облигации',
    shortName: 'Корп. облигации',
    currency: 'BYN',
    yieldFromPct: 12,
    yieldToPct: 14,
    risk: 4,
    minAmount: 1000,
    minAmountCurrency: 'BYN',
    color: 0xFFF59E0B,
    note: 'Выше риск, налог 13% на доход.',
  ),
  InvestmentInstrument(
    id: 'bcse_stocks',
    name: 'Акции БВФБ (BCSE)',
    shortName: 'Акции BCSE',
    currency: 'BYN',
    yieldFromPct: 8,
    yieldToPct: 16,
    risk: 6,
    minAmount: 100,
    minAmountCurrency: 'BYN',
    color: 0xFFEC4899,
    note: 'Волатильность, дивиденды нерегулярны.',
  ),
  InvestmentInstrument(
    id: 'currency_etf',
    name: 'ETF (currency.com)',
    shortName: 'ETF (Currency.com)',
    currency: 'USD',
    yieldFromPct: 7,
    yieldToPct: 12,
    risk: 6,
    minAmount: 50,
    minAmountCurrency: 'USD',
    color: 0xFF8B5CF6,
    note: 'Глобальные рынки, токенизированные акции.',
  ),
  InvestmentInstrument(
    id: 'crypto',
    name: 'Крипта BTC/ETH',
    shortName: 'Крипта BTC/ETH',
    currency: 'USD',
    yieldFromPct: 10,
    yieldToPct: 30,
    risk: 9,
    minAmount: 10,
    minAmountCurrency: 'USD',
    color: 0xFFDC2626,
    note: 'Высокий риск, нет страховки. Только избыток.',
  ),
  InvestmentInstrument(
    id: 'halva_cashback',
    name: 'Halva кэшбэк',
    shortName: 'Halva кэшбэк',
    currency: 'BYN',
    yieldFromPct: 1,
    yieldToPct: 5,
    risk: 1,
    minAmount: 0,
    minAmountCurrency: 'BYN',
    color: 0xFF65A30D,
    note: 'Возврат на каждую покупку. Без рисков.',
  ),
  InvestmentInstrument(
    id: 'whitebird',
    name: 'Whitebird (P2P USD)',
    shortName: 'Whitebird',
    currency: 'USD',
    yieldFromPct: 0,
    yieldToPct: 0,
    risk: 2,
    minAmount: 1,
    minAmountCurrency: 'USD',
    color: 0xFF0EA5E9,
    note: 'Покупка USD без хождения в банк, низкий спред.',
  ),
  InvestmentInstrument(
    id: 'cash',
    name: 'Наличные подушка',
    shortName: 'Наличные подушка',
    currency: 'USD',
    yieldFromPct: 0,
    yieldToPct: 0,
    risk: 1,
    minAmount: 0,
    minAmountCurrency: 'USD',
    color: 0xFF6B7280,
    note: 'На форс-мажор. Не работает, но всегда под рукой.',
  ),
];

/// Quick lookup helper.
InvestmentInstrument? findInstrument(String id) {
  for (final i in brbInstruments) {
    if (i.id == id) return i;
  }
  return null;
}

// ============================================================================
//  Computed report types — produced by FinancialPlanService.buildFinancialPlan.
// ============================================================================

class FinancialPlanReport {
  FinancialPlanReport({
    required this.config,
    required this.income,
    required this.expenses,
    required this.sankey,
    required this.nextMonthsExpenses,
    required this.dailyBalance,
    required this.weeklyFlow,
    required this.scenarioCompare,
    required this.calendar,
    required this.heatmap,
    required this.basket,
    required this.trajectory,
    required this.progress,
    required this.portfolio,
    required this.actionPlan,
    required this.scatter,
  });

  final FinancialPlanConfig config;
  final IncomeBreakdown income;
  final ExpenseStructure expenses;
  final SankeyData sankey;
  final NextMonthsExpenses nextMonthsExpenses;
  final DailyBalanceSeries dailyBalance;
  final WeeklyFlow weeklyFlow;
  final List<ScenarioComparison> scenarioCompare;
  final MonthCalendar calendar;
  final MonthCalendar heatmap;
  final WeeklyBasket basket;
  final LongTermTrajectory trajectory;
  final List<ScenarioProgress> progress;
  final PortfolioPlan portfolio;
  final List<ActionStep> actionPlan;
  final RiskReturnScatter scatter;

  /// 4 KPI cards on the cover.
  List<KpiCard> get kpis {
    final scen = config.scenarios.isNotEmpty
        ? config.scenarios.first
        : SavingsScenario.defaults().first;
    return [
      KpiCard(
        value: income.netRemainder.round().toDouble(),
        label: 'BYN ${_dd(config.payDay)}.${_dd(config.month.month)}',
        color: 0xFF22C55E,
      ),
      KpiCard(
        value: config.advanceAmount,
        label: 'BYN ${_dd(config.advanceDay)}.${_dd(config.month.month)}',
        color: 0xFFEF4444,
      ),
      KpiCard(
        value: expenses.totalRecurring + expenses.totalOneOff,
        label: 'фикс. расх.',
        color: 0xFFF59E0B,
      ),
      KpiCard(
        value: scen.savingsUsd * config.usdRate,
        label: 'BYN ≈ \$${scen.savingsUsd.round()}',
        color: 0xFF14B8A6,
      ),
    ];
  }
}

String _dd(int v) => v.toString().padLeft(2, '0');

class KpiCard {
  const KpiCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final double value;
  final String label;
  final int color;

  Color get colorValue => Color(color);
}

class IncomeBreakdown {
  const IncomeBreakdown({
    required this.gross,
    required this.incomeTax,
    required this.fszn,
    required this.tradeUnion,
    required this.net,
    required this.advance,
    required this.netRemainder,
    required this.steps,
  });

  final double gross;
  final double incomeTax;
  final double fszn;
  final double tradeUnion;
  final double net;
  final double advance;

  /// `net - advance` — что приходит на руки в день ZP.
  final double netRemainder;
  final List<WaterfallStep> steps;
}

class WaterfallStep {
  const WaterfallStep({
    required this.label,
    required this.value,
    required this.delta,
    required this.kind,
    required this.color,
  });

  final String label;

  /// Running balance after this step.
  final double value;

  /// Negative for deductions, positive for inflows. 0 for the final pillar.
  final double delta;
  final WaterfallKind kind;
  final int color;

  Color get colorValue => Color(color);
}

enum WaterfallKind { gross, deduction, net, advance, remainder }

class ExpenseStructure {
  const ExpenseStructure({
    required this.recurring,
    required this.oneOff,
    required this.totalRecurring,
    required this.totalOneOff,
  });

  final List<ExpenseItem> recurring;
  final List<ExpenseItem> oneOff;
  final double totalRecurring;
  final double totalOneOff;

  double get total => totalRecurring + totalOneOff;

  /// Recurring + one-off items combined, sorted by amount desc.
  List<ExpenseItem> get combined {
    final out = [...recurring, ...oneOff];
    out.sort((a, b) => b.amount.compareTo(a.amount));
    return out;
  }
}

class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.label,
    required this.amount,
    required this.color,
    required this.recurring,
  });

  final String id;
  final String label;
  final double amount;
  final int color;
  final bool recurring;

  Color get colorValue => Color(color);
}

class SankeyData {
  const SankeyData({
    required this.income,
    required this.outflows,
  });

  final double income;
  final List<ExpenseItem> outflows;
}

class NextMonthsExpenses {
  const NextMonthsExpenses({
    required this.thisMonth,
    required this.nextMonth,
  });

  final ExpenseStructure thisMonth;
  final ExpenseStructure nextMonth;
}

class DailyBalanceSeries {
  const DailyBalanceSeries({
    required this.start,
    required this.days,
    required this.scenarios,
    required this.markers,
  });

  final DateTime start;
  final int days;
  final List<DailyBalanceTrack> scenarios;
  final List<DailyMarker> markers;
}

class DailyBalanceTrack {
  const DailyBalanceTrack({
    required this.scenarioId,
    required this.label,
    required this.color,
    required this.points,
  });

  final String scenarioId;
  final String label;
  final int color;
  final List<double> points;

  Color get colorValue => Color(color);
}

class DailyMarker {
  const DailyMarker({
    required this.dayOffset,
    required this.label,
    required this.color,
  });

  final int dayOffset;
  final String label;
  final int color;

  Color get colorValue => Color(color);
}

class WeeklyFlow {
  const WeeklyFlow({
    required this.weekLabels,
    required this.income,
    required this.expense,
  });

  final List<String> weekLabels;
  final List<double> income;
  final List<double> expense;
}

class ScenarioComparison {
  const ScenarioComparison({
    required this.scenarioId,
    required this.name,
    required this.subtitle,
    required this.color,
    required this.savingsUsdYear,
    required this.savings16mUsd,
    required this.monthsToGoal,
    required this.foodPerDay,
    required this.foodPerWeek,
    required this.gym,
    required this.lenses,
    required this.cashback,
    required this.reserve,
    required this.stress,
    required this.comfort,
    required this.suitability,
  });

  final String scenarioId;
  final String name;
  final String subtitle;
  final int color;

  /// USD saved over 12 months.
  final double savingsUsdYear;

  /// USD saved over 16 months.
  final double savings16mUsd;

  /// Months until [config.goalAmount] is reached at this scenario's rate.
  final int monthsToGoal;
  final double foodPerDay;
  final double foodPerWeek;
  final String gym;
  final String lenses;
  final String cashback;
  final String reserve;
  final String stress;
  final int comfort;
  final String suitability;

  Color get colorValue => Color(color);
}

class MonthCalendar {
  const MonthCalendar({
    required this.weeks,
    required this.firstWeekday,
    required this.daysInMonth,
    required this.legend,
  });

  final List<List<CalendarCell>> weeks;
  final int firstWeekday;
  final int daysInMonth;
  final List<HeatmapBucket> legend;
}

class CalendarCell {
  const CalendarCell({
    required this.day,
    required this.label,
    required this.delta,
    required this.kind,
  });

  /// 0 means «filler» cell (outside the month).
  final int day;
  final String label;
  final double delta;
  final CalendarKind kind;
}

enum CalendarKind {
  filler,
  empty,
  income,
  rent,
  spend,
  bigSpend,
  none,
}

class HeatmapBucket {
  const HeatmapBucket({
    required this.label,
    required this.color,
  });

  final String label;
  final int color;

  Color get colorValue => Color(color);
}

class WeeklyBasket {
  const WeeklyBasket({
    required this.items,
    required this.groups,
  });

  final List<BasketItem> items;
  final List<BasketGroup> groups;

  double get totalByn => items.fold(0.0, (s, e) => s + e.amount);
}

class BasketItem {
  const BasketItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.group,
  });

  final String label;
  final double amount;
  final int color;
  final String group;

  Color get colorValue => Color(color);
}

class BasketGroup {
  const BasketGroup({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final int color;

  Color get colorValue => Color(color);
}

class LongTermTrajectory {
  const LongTermTrajectory({
    required this.months,
    required this.tracks,
    required this.goalUsd,
  });

  final int months;
  final List<TrajectoryTrack> tracks;
  final double goalUsd;
}

class TrajectoryTrack {
  const TrajectoryTrack({
    required this.scenarioId,
    required this.label,
    required this.color,
    required this.points,
    required this.monthsToGoal,
  });

  final String scenarioId;
  final String label;
  final int color;
  final List<double> points;
  final int monthsToGoal;

  Color get colorValue => Color(color);
}

class ScenarioProgress {
  const ScenarioProgress({
    required this.scenarioId,
    required this.name,
    required this.color,
    required this.totalMonths,
    required this.savedUsd6m,
    required this.savedUsd12m,
    required this.goalUsd,
  });

  final String scenarioId;
  final String name;
  final int color;
  final int totalMonths;
  final double savedUsd6m;
  final double savedUsd12m;
  final double goalUsd;

  Color get colorValue => Color(color);

  double get pct6m => goalUsd > 0 ? savedUsd6m / goalUsd : 0;
  double get pct12m => goalUsd > 0 ? savedUsd12m / goalUsd : 0;
}

class PortfolioPlan {
  const PortfolioPlan({
    required this.allocations,
    required this.totalUsd,
    required this.quarterly,
  });

  final List<PortfolioSlice> allocations;
  final double totalUsd;
  final List<QuarterlyAccrual> quarterly;
}

class PortfolioSlice {
  const PortfolioSlice({
    required this.instrumentId,
    required this.label,
    required this.percent,
    required this.amountUsd,
    required this.color,
  });

  final String instrumentId;
  final String label;
  final double percent;
  final double amountUsd;
  final int color;

  Color get colorValue => Color(color);
}

class QuarterlyAccrual {
  const QuarterlyAccrual({
    required this.label,
    required this.amountUsd,
    required this.color,
  });

  final String label;
  final double amountUsd;
  final int color;

  Color get colorValue => Color(color);
}

class ActionStep {
  const ActionStep({
    required this.dateLabel,
    required this.text,
    required this.urgency,
  });

  final String dateLabel;
  final String text;
  final ActionUrgency urgency;

  int get color {
    switch (urgency) {
      case ActionUrgency.urgent:
        return 0xFFEF4444;
      case ActionUrgency.now:
        return 0xFF22C55E;
      case ActionUrgency.soon:
        return 0xFF14B8A6;
      case ActionUrgency.later:
        return 0xFFF59E0B;
      case ActionUrgency.future:
        return 0xFF1E40AF;
    }
  }

  Color get colorValue => Color(color);
}

enum ActionUrgency { urgent, now, soon, later, future }

class RiskReturnScatter {
  const RiskReturnScatter({
    required this.points,
    required this.sweetSpot,
    required this.startArrow,
  });

  final List<ScatterPoint> points;
  final ScatterRect sweetSpot;
  final ScatterArrow startArrow;
}

class ScatterPoint {
  const ScatterPoint({
    required this.label,
    required this.risk,
    required this.yieldPct,
    required this.color,
  });

  final String label;
  final double risk;
  final double yieldPct;
  final int color;

  Color get colorValue => Color(color);
}

class ScatterRect {
  const ScatterRect({
    required this.minRisk,
    required this.maxRisk,
    required this.minYield,
    required this.maxYield,
  });

  final double minRisk;
  final double maxRisk;
  final double minYield;
  final double maxYield;
}

class ScatterArrow {
  const ScatterArrow({
    required this.fromRisk,
    required this.fromYield,
    required this.toRisk,
    required this.toYield,
    required this.label,
  });

  final double fromRisk;
  final double fromYield;
  final double toRisk;
  final double toYield;
  final String label;
}
