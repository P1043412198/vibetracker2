import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../finance/by_tax.dart';
import '../../finance/calculators.dart';
import '../../data/finlit_tips.dart';
import '../../data/glossary.dart';
import '../../data/tax_calendar.dart';
import '../../data/courses.dart' as courses_data;

/// Full "Tools" page — Belarus localisation pack (Phase 7).
/// Mirrors the 8-tab structure from the React Tools.tsx.
class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  static const _tabs = [
    Tab(text: 'Калькуляторы'),
    Tab(text: 'ФинГрамотность'),
    Tab(text: 'Календарь'),
    Tab(text: 'Что если'),
    Tab(text: 'Валюты'),
    Tab(text: 'Глоссарий'),
    Tab(text: 'Курсы'),
    Tab(text: 'Шаблоны'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Инструменты'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _CalcsTab(),
          _FinLitTab(),
          _TaxCalendarTab(),
          _WhatIfTab(),
          _FxConverterTab(),
          _GlossaryTab(),
          _CoursesTab(),
          _TemplatesTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _fmtCurrency(double v) =>
    '${v.toStringAsFixed(2)} BYN';

String _fmtPercent(double v) => '${v.toStringAsFixed(2)}%';

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: suffix,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                onChanged: (s) {
                  final v = double.tryParse(s);
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Calculators
// ---------------------------------------------------------------------------

class _CalcsTab extends StatefulWidget {
  const _CalcsTab();
  @override
  State<_CalcsTab> createState() => _CalcsTabState();
}

class _CalcsTabState extends State<_CalcsTab> {
  String _selected = 'compound';

  static const _calcList = [
    ('compound', 'Сложный процент', Icons.trending_up),
    ('deposit-by', 'Депозит (РБ)', Icons.savings_outlined),
    ('credit', 'Кредит', Icons.credit_card_outlined),
    ('salary-by', 'Зарплата на руки', Icons.account_balance_wallet_outlined),
    ('ip-usn', 'ИП на УСН', Icons.business_center_outlined),
    ('npd', 'НПД (самозанятые)', Icons.person_outline),
    ('safety-fund', 'Подушка безопасности', Icons.shield_outlined),
    ('fx-stress', 'Валютный стресс-тест', Icons.air_outlined),
    ('vacation', 'Отпускные', Icons.beach_access_outlined),
    ('fire', 'FIRE', Icons.whatshot_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _calcList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final (id, label, icon) = _calcList[i];
              final sel = id == _selected;
              return ChoiceChip(
                label: Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : null)),
                avatar: Icon(icon, size: 16),
                selected: sel,
                onSelected: (_) => setState(() => _selected = id),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildCalc(),
      ],
    );
  }

  Widget _buildCalc() {
    switch (_selected) {
      case 'compound':
        return const _CompoundCalc();
      case 'deposit-by':
        return const _DepositByCalc();
      case 'credit':
        return const _CreditCalc();
      case 'salary-by':
        return const _SalaryCalc();
      case 'ip-usn':
        return const _IpUsnCalc();
      case 'npd':
        return const _NpdCalc();
      case 'safety-fund':
        return const _SafetyFundCalc();
      case 'fx-stress':
        return const _FxStressCalc();
      case 'vacation':
        return const _VacationCalc();
      case 'fire':
        return const _FireCalc();
      default:
        return const SizedBox.shrink();
    }
  }
}

// -- Compound interest --
class _CompoundCalc extends StatefulWidget {
  const _CompoundCalc();
  @override
  State<_CompoundCalc> createState() => _CompoundCalcState();
}

class _CompoundCalcState extends State<_CompoundCalc> {
  double _principal = 10000;
  double _rate = 10;
  double _years = 10;
  double _monthly = 200;

  @override
  Widget build(BuildContext context) {
    final r = compoundInterest(
      principal: _principal,
      annualRatePct: _rate,
      years: _years.toInt(),
      monthlyContribution: _monthly,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Сложный процент', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(width: 150, child: _NumberField(label: 'Начальная сумма', value: _principal, onChanged: (v) => setState(() => _principal = v), suffix: 'BYN')),
            SizedBox(width: 120, child: _NumberField(label: 'Ставка', value: _rate, onChanged: (v) => setState(() => _rate = v), suffix: '%')),
            SizedBox(width: 100, child: _NumberField(label: 'Лет', value: _years, onChanged: (v) => setState(() => _years = v))),
            SizedBox(width: 150, child: _NumberField(label: 'В месяц', value: _monthly, onChanged: (v) => setState(() => _monthly = v), suffix: 'BYN')),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _ResultRow('Итоговый баланс', _fmtCurrency(r.finalBalance)),
              _ResultRow('Внесено всего', _fmtCurrency(r.totalContributed)),
              _ResultRow('Доход от процентов', _fmtCurrency(r.totalInterest)),
            ]),
          ),
        ),
      ],
    );
  }
}

// -- Deposit BY --
class _DepositByCalc extends StatefulWidget {
  const _DepositByCalc();
  @override
  State<_DepositByCalc> createState() => _DepositByCalcState();
}

class _DepositByCalcState extends State<_DepositByCalc> {
  double _amount = 10000;
  double _rate = 12;
  double _months = 12;
  bool _taxApplies = true;
  bool _capitalize = true;

  @override
  Widget build(BuildContext context) {
    final r = calcDepositBY(
      amount: _amount,
      annualRatePct: _rate,
      termMonths: _months.toInt(),
      taxApplies: _taxApplies,
      capitalize: _capitalize,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Депозит (РБ)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            SizedBox(width: 150, child: _NumberField(label: 'Сумма вклада', value: _amount, onChanged: (v) => setState(() => _amount = v), suffix: 'BYN')),
            SizedBox(width: 120, child: _NumberField(label: 'Ставка', value: _rate, onChanged: (v) => setState(() => _rate = v), suffix: '%')),
            SizedBox(width: 120, child: _NumberField(label: 'Срок', value: _months, onChanged: (v) => setState(() => _months = v), suffix: 'мес')),
          ],
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: CheckboxListTile(title: const Text('Налог 13%', style: TextStyle(fontSize: 13)), value: _taxApplies, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setState(() => _taxApplies = v!))),
          Expanded(child: CheckboxListTile(title: const Text('Капитализация', style: TextStyle(fontSize: 13)), value: _capitalize, dense: true, contentPadding: EdgeInsets.zero, onChanged: (v) => setState(() => _capitalize = v!))),
        ]),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _ResultRow('Проценты (грязные)', _fmtCurrency(r.totalInterestGross)),
              _ResultRow('Налог', _fmtCurrency(r.totalTax)),
              _ResultRow('Проценты (чистые)', _fmtCurrency(r.totalInterestNet)),
              _ResultRow('Итого на счёте', _fmtCurrency(r.finalBalance)),
            ]),
          ),
        ),
      ],
    );
  }
}

// -- Credit (loan) --
class _CreditCalc extends StatefulWidget {
  const _CreditCalc();
  @override
  State<_CreditCalc> createState() => _CreditCalcState();
}

class _CreditCalcState extends State<_CreditCalc> {
  double _amount = 20000;
  double _rate = 15;
  double _months = 36;
  String _type = 'annuity';

  @override
  Widget build(BuildContext context) {
    final r = buildLoanSchedule(
      amount: _amount,
      annualRatePct: _rate,
      termMonths: _months.toInt(),
      type: _type,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Кредит', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            SizedBox(width: 150, child: _NumberField(label: 'Сумма', value: _amount, onChanged: (v) => setState(() => _amount = v), suffix: 'BYN')),
            SizedBox(width: 120, child: _NumberField(label: 'Ставка', value: _rate, onChanged: (v) => setState(() => _rate = v), suffix: '%')),
            SizedBox(width: 120, child: _NumberField(label: 'Срок', value: _months, onChanged: (v) => setState(() => _months = v), suffix: 'мес')),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'annuity', label: Text('Аннуитет', style: TextStyle(fontSize: 12))),
            ButtonSegment(value: 'differential', label: Text('Дифференц.', style: TextStyle(fontSize: 12))),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _ResultRow('Ежемесячный платёж', _fmtCurrency(r.monthlyPayment)),
              _ResultRow('Всего выплат', _fmtCurrency(r.totalPayment)),
              _ResultRow('Переплата', _fmtCurrency(r.totalInterest)),
            ]),
          ),
        ),
      ],
    );
  }
}

// -- Salary --
class _SalaryCalc extends StatefulWidget {
  const _SalaryCalc();
  @override
  State<_SalaryCalc> createState() => _SalaryCalcState();
}

class _SalaryCalcState extends State<_SalaryCalc> {
  double _gross = 2000;
  int _children = 0;
  int _dependents = 0;

  @override
  Widget build(BuildContext context) {
    final r = calcNetSalary(gross: _gross, children: _children, dependents: _dependents);
    final totalKept = r.gross > 0 ? (r.net / r.gross * 100).round() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Зарплата на руки (РБ)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            SizedBox(width: 150, child: _NumberField(label: 'Грязная зарплата', value: _gross, onChanged: (v) => setState(() => _gross = v), suffix: 'BYN')),
            SizedBox(width: 100, child: _NumberField(label: 'Детей', value: _children.toDouble(), onChanged: (v) => setState(() => _children = v.toInt()))),
            SizedBox(width: 120, child: _NumberField(label: 'Иждивенцев', value: _dependents.toDouble(), onChanged: (v) => setState(() => _dependents = v.toInt()))),
          ],
        ),
        const SizedBox(height: 12),
        // Stacked bar
        if (r.gross > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(flex: (r.net / r.gross * 1000).round(), child: Container(color: Colors.green)),
                  Expanded(flex: (r.incomeTax / r.gross * 1000).round(), child: Container(color: Colors.red)),
                  Expanded(flex: (r.fszn / r.gross * 1000).round(), child: Container(color: Colors.amber)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('$totalKept% остаётся на руки', style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.end),
        ],
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _ResultRow('Подоходный 13%', _fmtCurrency(r.incomeTax)),
              _ResultRow('ФСЗН 1%', _fmtCurrency(r.fszn)),
              _ResultRow('Налогооблагаемая база', _fmtCurrency(r.taxableBase)),
              _ResultRow('Стандартные/детские вычеты', _fmtCurrency(r.deductions)),
              _ResultRow('На руки', _fmtCurrency(r.net)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Профсоюзные взносы по сложившейся практике не уменьшают подоходный налог. ДМС/пенсионную программу обычно можно оформить как соц. вычет.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

// -- IP USN --
class _IpUsnCalc extends StatefulWidget {
  const _IpUsnCalc();
  @override
  State<_IpUsnCalc> createState() => _IpUsnCalcState();
}

class _IpUsnCalcState extends State<_IpUsnCalc> {
  double _revenue = 80000;
  int _rate = 5;
  double _fszn = 220;

  @override
  Widget build(BuildContext context) {
    final r = calcIpUsn(annualRevenue: _revenue, ratePct: _rate, fsznMonthly: _fszn);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ИП на УСН', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            SizedBox(width: 150, child: _NumberField(label: 'Годовая выручка', value: _revenue, onChanged: (v) => setState(() => _revenue = v), suffix: 'BYN')),
            SizedBox(width: 150, child: _NumberField(label: 'ФСЗН в месяц', value: _fszn, onChanged: (v) => setState(() => _fszn = v), suffix: 'BYN')),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 5, label: Text('5% (без НДС)', style: TextStyle(fontSize: 12))),
            ButtonSegment(value: 3, label: Text('3% (с НДС)', style: TextStyle(fontSize: 12))),
          ],
          selected: {_rate},
          onSelectionChanged: (s) => setState(() => _rate = s.first),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _ResultRow('Налог УСН $_rate%', _fmtCurrency(r.usnTax)),
              _ResultRow('ФСЗН за год', _fmtCurrency(r.fsznTotal)),
              _ResultRow('Итого нагрузка', _fmtCurrency(r.totalLoad)),
              _ResultRow('Чистый доход', _fmtCurrency(r.net)),
              _ResultRow('Эффективная ставка', _fmtPercent(r.effectivePct)),
            ]),
          ),
        ),
      ],
    );
  }
}

// -- NPD --
class _NpdCalc extends StatefulWidget {
  const _NpdCalc();
  @override
  State<_NpdCalc> createState() => _NpdCalcState();
}

class _NpdCalcState extends State<_NpdCalc> {
  double _revenue = 40000;

  @override
  Widget build(BuildContext context) {
    final r = calcNpd(annualRevenue: _revenue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('НПД (самозанятые)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(width: 200, child: _NumberField(label: 'Годовой доход', value: _revenue, onChanged: (v) => setState(() => _revenue = v), suffix: 'BYN')),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _ResultRow('Налог 10%', _fmtCurrency(r.taxLow)),
              _ResultRow('Налог 20% (свыше 60 000)', _fmtCurrency(r.taxHigh)),
              _ResultRow('Итого налог', _fmtCurrency(r.total)),
              _ResultRow('Чистый доход', _fmtCurrency(r.net)),
              _ResultRow('Эффективная ставка', _fmtPercent(r.effectivePct)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Ставки НПД для самозанятых физлиц (РБ): 10% при работе с физлицами и иностранными организациями; превышение лимита 60 000 BYN/год \u2014 20%.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

// -- Safety fund --
class _SafetyFundCalc extends StatefulWidget {
  const _SafetyFundCalc();
  @override
  State<_SafetyFundCalc> createState() => _SafetyFundCalcState();
}

class _SafetyFundCalcState extends State<_SafetyFundCalc> {
  double _monthly = 1500;

  @override
  Widget build(BuildContext context) {
    final t3 = safetyFundTarget(_monthly, months: 3);
    final t6 = safetyFundTarget(_monthly, months: 6);
    final t12 = safetyFundTarget(_monthly, months: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Подушка безопасности', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(width: 200, child: _NumberField(label: 'Среднемесячные расходы', value: _monthly, onChanged: (v) => setState(() => _monthly = v), suffix: 'BYN')),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _ResultRow('3 месяца \u2014 старт', _fmtCurrency(t3)),
              _ResultRow('6 месяцев \u2014 рекомендуется', _fmtCurrency(t6)),
              _ResultRow('12 месяцев \u2014 спокойствие', _fmtCurrency(t12)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Храните подушку отдельно от основного счёта (валютный депозит/накопительный). В РБ \u2014 половина в BYN на бытовые форс-мажоры, половина в USD/EUR от девальвации.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

// -- FX stress test --
class _FxStressCalc extends StatefulWidget {
  const _FxStressCalc();
  @override
  State<_FxStressCalc> createState() => _FxStressCalcState();
}

class _FxStressCalcState extends State<_FxStressCalc> {
  double _byn = 5000;
  double _usd = 500;
  double _eur = 0;
  double _shock = 30;

  // Hardcoded fallback rates (NBRB-style: BYN per 1 unit)
  static const _defaultRates = {'BYN': 1.0, 'USD': 3.27, 'EUR': 3.56, 'RUB': 0.036};

  @override
  Widget build(BuildContext context) {
    final r = applyDevaluation(
      [
        StressBucket(currency: 'BYN', amount: _byn),
        StressBucket(currency: 'USD', amount: _usd),
        StressBucket(currency: 'EUR', amount: _eur),
      ],
      _defaultRates,
      _shock,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Валютный стресс-тест', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            SizedBox(width: 120, child: _NumberField(label: 'BYN', value: _byn, onChanged: (v) => setState(() => _byn = v))),
            SizedBox(width: 120, child: _NumberField(label: 'USD', value: _usd, onChanged: (v) => setState(() => _usd = v))),
            SizedBox(width: 120, child: _NumberField(label: 'EUR', value: _eur, onChanged: (v) => setState(() => _eur = v))),
            SizedBox(width: 120, child: _NumberField(label: 'Шок к BYN', value: _shock, onChanged: (v) => setState(() => _shock = v), suffix: '%')),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _ResultRow('До шока (в BYN)', _fmtCurrency(r.before)),
              _ResultRow('После шока (в BYN)', _fmtCurrency(r.after)),
              _ResultRow('Изменение', _fmtPercent(r.deltaPct)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Стресс-тест считает, что иностранная валюта дорожает к BYN, а сумма в иностранной валюте остаётся той же.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

// -- Vacation --
class _VacationCalc extends StatefulWidget {
  const _VacationCalc();
  @override
  State<_VacationCalc> createState() => _VacationCalcState();
}

class _VacationCalcState extends State<_VacationCalc> {
  double _earnings = 24000;
  double _days = 24;

  @override
  Widget build(BuildContext context) {
    final r = calcVacationPay(_earnings, _days.toInt());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Отпускные (РБ)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            SizedBox(width: 170, child: _NumberField(label: 'Доход за 12 мес', value: _earnings, onChanged: (v) => setState(() => _earnings = v), suffix: 'BYN')),
            SizedBox(width: 140, child: _NumberField(label: 'Дней отпуска', value: _days, onChanged: (v) => setState(() => _days = v))),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _ResultRow('Среднедневной заработок', _fmtCurrency(r.avgDaily)),
              _ResultRow('Сумма отпускных', _fmtCurrency(r.payment)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Упрощённая формула: средний доход за 12 месяцев / (12 \u00D7 29.7) \u00D7 количество календарных дней отпуска.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

// -- FIRE --
class _FireCalc extends StatefulWidget {
  const _FireCalc();
  @override
  State<_FireCalc> createState() => _FireCalcState();
}

class _FireCalcState extends State<_FireCalc> {
  double _annual = 24000;
  double _swr = 4;
  double _current = 20000;
  double _monthly = 500;
  double _returnPct = 7;

  @override
  Widget build(BuildContext context) {
    final target = fireNumber(annualExpenses: _annual, swrPct: _swr);
    final yrs = yearsToFire(
      currentNet: _current,
      monthlySaving: _monthly,
      annualReturnPct: _returnPct,
      targetNet: target,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('FIRE (Financial Independence)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            SizedBox(width: 150, child: _NumberField(label: 'Расходы в год', value: _annual, onChanged: (v) => setState(() => _annual = v), suffix: 'BYN')),
            SizedBox(width: 100, child: _NumberField(label: 'SWR', value: _swr, onChanged: (v) => setState(() => _swr = v), suffix: '%')),
            SizedBox(width: 150, child: _NumberField(label: 'Текущий капитал', value: _current, onChanged: (v) => setState(() => _current = v), suffix: 'BYN')),
            SizedBox(width: 150, child: _NumberField(label: 'В месяц инвестирую', value: _monthly, onChanged: (v) => setState(() => _monthly = v), suffix: 'BYN')),
            SizedBox(width: 150, child: _NumberField(label: 'Доходность портфеля', value: _returnPct, onChanged: (v) => setState(() => _returnPct = v), suffix: '%')),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _ResultRow('FIRE-число (целевой капитал)', _fmtCurrency(target)),
              _ResultRow('Лет до цели', yrs.isFinite ? '$yrs' : '> 100'),
            ]),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: FinLit
// ---------------------------------------------------------------------------

class _FinLitTab extends StatefulWidget {
  const _FinLitTab();
  @override
  State<_FinLitTab> createState() => _FinLitTabState();
}

class _FinLitTabState extends State<_FinLitTab> {
  String? _openCategoryId;

  Color _accentColor(FinTipAccent a) {
    switch (a) {
      case FinTipAccent.emerald: return Colors.green;
      case FinTipAccent.blue: return Colors.blue;
      case FinTipAccent.amber: return Colors.amber;
      case FinTipAccent.rose: return Colors.red;
      case FinTipAccent.indigo: return Colors.indigo;
      case FinTipAccent.violet: return Colors.purple;
    }
  }

  String _kindLabel(TipKind k) {
    switch (k) {
      case TipKind.tip: return 'Совет';
      case TipKind.warning: return 'Осторожно';
      case TipKind.rule: return 'Правило';
      case TipKind.fact: return 'Факт';
    }
  }

  Color _kindColor(TipKind k) {
    switch (k) {
      case TipKind.tip: return Colors.green;
      case TipKind.warning: return Colors.red;
      case TipKind.rule: return Colors.blue;
      case TipKind.fact: return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_openCategoryId != null) {
      final cat = finlitBy2026.firstWhere((c) => c.id == _openCategoryId, orElse: () => finlitBy2026.first);
      final accent = _accentColor(cat.accent);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _openCategoryId = null),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Все темы'),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withAlpha(60)),
            ),
            child: Row(
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.title, style: Theme.of(context).textTheme.titleLarge),
                    Text(cat.blurb, style: Theme.of(context).textTheme.bodySmall),
                  ],
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...cat.tips.map((tip) {
            final kColor = _kindColor(tip.kind);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_kindLabel(tip.kind),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kColor)),
                    ),
                    const SizedBox(height: 6),
                    Text(tip.title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(tip.body, style: Theme.of(context).textTheme.bodySmall),
                    if (tip.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4, runSpacing: 4,
                        children: tip.tags.map((t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          backgroundColor: accent.withAlpha(25),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    final totalTips = finlitBy2026.fold(0, (s, c) => s + c.tips.length);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE8F5E9), Color(0xFFE3F2FD)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('\u{1F1E7}\u{1F1FE}', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Финансовая грамотность \u00B7 Беларусь 2026',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${finlitBy2026.length} тем \u00B7 $totalTips практических советов и правил.',
                    style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('Не является индивидуальной налоговой/инвестиционной консультацией.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
                ],
              )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...finlitBy2026.map((cat) {
          final accent = _accentColor(cat.accent);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _openCategoryId = cat.id),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withAlpha(15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text(cat.blurb, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${cat.tips.length} советов', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accent)),
                        ),
                      ],
                    )),
                    Icon(Icons.chevron_right, color: accent),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Tax Calendar
// ---------------------------------------------------------------------------

class _TaxCalendarTab extends StatefulWidget {
  const _TaxCalendarTab();
  @override
  State<_TaxCalendarTab> createState() => _TaxCalendarTabState();
}

class _TaxCalendarTabState extends State<_TaxCalendarTab> {
  String _filter = 'all';

  Color _catColor(TaxEventCategory c) {
    switch (c) {
      case TaxEventCategory.individual: return Colors.blue;
      case TaxEventCategory.ip: return Colors.green;
      case TaxEventCategory.fszn: return Colors.purple;
      case TaxEventCategory.declaration: return Colors.amber;
      case TaxEventCategory.utility: return Colors.cyan;
      case TaxEventCategory.reminder: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = taxCalendar2026.where((e) =>
      _filter == 'all' || e.audience == 'all' || e.audience == _filter
    ).toList();
    final monthly = events.where((e) => e.month == null).toList();
    final byMonth = <int, List<TaxCalendarEvent>>{};
    for (final e in events.where((e) => e.month != null)) {
      byMonth.putIfAbsent(e.month!, () => []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withAlpha(60)),
          ),
          child: Text(
            'Налоговый и финансовый календарь РБ на 2026 год. Все даты \u2014 для физлиц, ИП и наёмных работников. Проверяйте актуальность на portal.nalog.gov.by.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: [
            _filterChip('all', 'Все'),
            _filterChip('individuals', 'Физлица'),
            _filterChip('employed', 'Наёмные'),
            _filterChip('ip', 'ИП / самозанятые'),
          ],
        ),
        const SizedBox(height: 16),
        if (monthly.isNotEmpty) ...[
          Text('Регулярные (каждый месяц)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...monthly.map((e) => _eventCard(e)),
          const SizedBox(height: 16),
        ],
        ...(byMonth.keys.toList()..sort()).expand((m) => [
          Text(monthNames[m - 1], style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...byMonth[m]!.map((e) => _eventCard(e)),
          const SizedBox(height: 16),
        ]),
      ],
    );
  }

  Widget _filterChip(String id, String label) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: _filter == id,
      onSelected: (_) => setState(() => _filter = id),
    );
  }

  Widget _eventCard(TaxCalendarEvent e) {
    final color = _catColor(e.category);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(e.title, style: Theme.of(context).textTheme.titleSmall)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(e.category.name, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(e.due, style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(e.description, style: Theme.of(context).textTheme.bodySmall),
              ],
            )),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 4: What-If
// ---------------------------------------------------------------------------

class _WhatIfTab extends StatefulWidget {
  const _WhatIfTab();
  @override
  State<_WhatIfTab> createState() => _WhatIfTabState();
}

class _WhatIfTabState extends State<_WhatIfTab> {
  double _income = 2000;
  double _expenses = 1500;
  double _savingsRate = 15;
  double _years = 5;
  double _returnRate = 8;
  double _emergencyMonths = 6;

  @override
  Widget build(BuildContext context) {
    final monthlySaved = math.max(0.0, _income - _expenses) * (_savingsRate / 100);
    double totalSaved = 0;
    {
      double bal = 0;
      for (int m = 0; m < _years.toInt() * 12; m++) {
        bal = bal * (1 + _returnRate / 100 / 12) + monthlySaved;
      }
      totalSaved = bal;
    }
    final fireTarget = _expenses * 12 * 25;
    final safetyTarget = _expenses * _emergencyMonths;
    final yearsToSafety = monthlySaved > 0 ? safetyTarget / (monthlySaved * 12) : double.infinity;
    final yearsToFireVal = monthlySaved > 0 && _returnRate > 0
        ? math.log(1 + (fireTarget * _returnRate / 100) / (monthlySaved * 12)) / math.log(1 + _returnRate / 100)
        : double.infinity;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withAlpha(40)),
          ),
          child: Text('Поиграйте со слайдерами и посмотрите, как меняется ваш финансовый план. Все расчёты \u2014 в BYN.',
            style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: 16),
        _slider('Доход в месяц', _income, 500, 10000, 50, 'BYN', (v) => setState(() => _income = v)),
        _slider('Расходы в месяц', _expenses, 300, math.max(_income - 100, 9500), 50, 'BYN', (v) => setState(() => _expenses = v)),
        _slider('Доля сбережений от свободных', _savingsRate, 0, 100, 5, '%', (v) => setState(() => _savingsRate = v),
          hint: 'Откладывается ${monthlySaved.toStringAsFixed(0)} BYN/мес'),
        _slider('Годовая доходность', _returnRate, 0, 20, 0.5, '%', (v) => setState(() => _returnRate = v),
          hint: 'Депозит РБ ~10\u201313%, USD ~5\u20137%, акции ~8\u201310%'),
        _slider('Горизонт планирования', _years, 1, 30, 1, 'лет', (v) => setState(() => _years = v)),
        _slider('Подушка безопасности', _emergencyMonths, 1, 24, 1, 'мес', (v) => setState(() => _emergencyMonths = v),
          hint: 'Стандарт 3-6 месяцев. Для ИП \u2014 больше'),
        const SizedBox(height: 16),
        _resultCard('Накоплено за ${_years.toInt()} лет', totalSaved, Colors.green,
          'При откладывании ${monthlySaved.toStringAsFixed(0)} BYN/мес под ${_returnRate.toStringAsFixed(1)}% годовых'),
        _resultCard('Подушка', safetyTarget, Colors.amber,
          'Накопится за ${yearsToSafety.isFinite ? '${yearsToSafety.toStringAsFixed(1)} лет' : '\u221E'}'),
        _resultCard('FIRE-цель (\u00D725 расходов)', fireTarget, Colors.purple,
          'До неё ${yearsToFireVal.isFinite ? '${yearsToFireVal.toStringAsFixed(0)} лет' : '\u221E'}'),
        _resultCard('Свободно в месяц', _income - _expenses, Colors.red,
          (_income - _expenses) <= 0
            ? 'Расходы превышают доход!'
            : '${((_income - _expenses) / _income * 100).toStringAsFixed(0)}% от дохода'),
      ],
    );
  }

  Widget _slider(String label, double value, double min, double max, double step, String suffix, ValueChanged<double> onChange, {String? hint}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text('${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)} $suffix',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green[700])),
              ],
            ),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              onChanged: onChange,
            ),
            if (hint != null) Text(hint, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(String title, double value, Color color, String subtitle) {
    return Card(
      color: color.withAlpha(15),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('${value.toStringAsFixed(0)} BYN', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color.withAlpha(220))),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: color.withAlpha(180))),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 5: FX Converter
// ---------------------------------------------------------------------------

class _FxConverterTab extends StatefulWidget {
  const _FxConverterTab();
  @override
  State<_FxConverterTab> createState() => _FxConverterTabState();
}

class _FxConverterTabState extends State<_FxConverterTab> {
  static const _currencies = ['BYN', 'USD', 'EUR', 'RUB', 'PLN'];
  // Hardcoded fallback NBRB-style rates (BYN per 1 unit)
  static const _rates = <String, double>{
    'BYN': 1.0,
    'USD': 3.27,
    'EUR': 3.56,
    'RUB': 0.036,
    'PLN': 0.83,
  };

  String _from = 'USD';
  String _to = 'BYN';
  double _amount = 100;

  @override
  Widget build(BuildContext context) {
    final fromRate = _from == 'BYN' ? 1.0 : (_rates[_from] ?? 0);
    final toRate = _to == 'BYN' ? 1.0 : (_rates[_to] ?? 0);
    final result = toRate > 0 ? (_amount * fromRate) / toRate : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.cyan.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyan.withAlpha(50)),
          ),
          child: Text('Курсы НБРБ (демо-значения). Для актуальных курсов используйте api.nbrb.by.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _amount.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      onChanged: (s) {
                        final v = double.tryParse(s);
                        if (v != null) setState(() => _amount = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _from,
                    items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _from = v!),
                  ),
                ]),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() { final f = _from; _from = _to; _to = f; }),
                  icon: const Icon(Icons.swap_vert),
                  label: const Text('Поменять местами'),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withAlpha(40)),
                      ),
                      child: Text(result.toStringAsFixed(4),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.green[800])),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _to,
                    items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _to = v!),
                  ),
                ]),
                const SizedBox(height: 8),
                if (fromRate > 0 && toRate > 0)
                  Text('1 $_from = ${(fromRate / toRate).toStringAsFixed(4)} $_to',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Курсы НБРБ к BYN', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _currencies.where((c) => c != 'BYN').map((c) {
            final r = _rates[c] ?? 0;
            return SizedBox(
              width: 130,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
                      Text('${r.toStringAsFixed(4)} BYN', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 6: Glossary
// ---------------------------------------------------------------------------

class _GlossaryTab extends StatelessWidget {
  const _GlossaryTab();

  static const _groupLabels = {
    GlossaryGroup.personal: 'Личные финансы',
    GlossaryGroup.belarus: 'Беларусь',
    GlossaryGroup.invest: 'Инвестиции',
    GlossaryGroup.tax: 'Налоги',
    GlossaryGroup.credit: 'Кредиты и долги',
  };

  @override
  Widget build(BuildContext context) {
    final grouped = <GlossaryGroup, List<GlossaryEntry>>{};
    for (final e in glossary) {
      grouped.putIfAbsent(e.group, () => []).add(e);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.expand((group) => [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            (_groupLabels[group.key] ?? group.key.name).toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
        ),
        ...group.value.map((e) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.term, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(e.definition, style: Theme.of(context).textTheme.bodySmall),
                if (e.example != null) ...[
                  const SizedBox(height: 6),
                  Text(e.example!, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ],
            ),
          ),
        )),
      ]).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 7: Courses
// ---------------------------------------------------------------------------

class _CoursesTab extends StatefulWidget {
  const _CoursesTab();
  @override
  State<_CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<_CoursesTab> {
  final Map<String, int> _progress = {};
  courses_data.Course? _openCourse;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  void _loadProgress() {
    try {
      final box = Hive.box<String>('settings');
      final raw = box.get('courseProgress');
      if (raw != null) {
        // Simple key=value storage
        // In practice we'd use JSON, but let's keep it simple
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_openCourse != null) {
      return _CoursePlayer(
        course: _openCourse!,
        currentStep: _progress[_openCourse!.id] ?? 0,
        onSetStep: (s) => setState(() => _progress[_openCourse!.id] = s),
        onClose: () => setState(() => _openCourse = null),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: courses_data.courses.map((c) {
        final done = _progress[c.id] ?? 0;
        final total = c.steps.length;
        final pct = total > 0 ? (done / total * 100).round() : 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _openCourse = c),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(c.blurb, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c.duration, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
                      Text('$done/$total \u00B7 $pct%', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: total > 0 ? done / total : 0, minHeight: 6),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CoursePlayer extends StatelessWidget {
  const _CoursePlayer({required this.course, required this.currentStep, required this.onSetStep, required this.onClose});
  final courses_data.Course course;
  final int currentStep;
  final ValueChanged<int> onSetStep;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final i = currentStep.clamp(0, course.steps.length - 1);
    final step = course.steps[i];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Все курсы'),
          ),
          Text(course.title, style: Theme.of(context).textTheme.titleLarge),
          Text('Шаг ${i + 1} из ${course.steps.length}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(step.body, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: i > 0 ? () => onSetStep(i - 1) : null,
                child: const Text('Назад'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => onSetStep(math.min(course.steps.length, i + 1)),
                child: Text(i == course.steps.length - 1 ? 'Закончить' : 'Далее'),
              ),
              if (step.actionRoute != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => context.go(step.actionRoute!),
                  child: Text(step.actionLabel ?? 'Перейти'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 8: Templates
// ---------------------------------------------------------------------------

class _TemplatesTab extends StatelessWidget {
  const _TemplatesTab();

  static const _habitTemplates = [
    ('Записывать каждую трату вечером', 'Главная привычка финграмотности. 1 минута в день.'),
    ('Читать про деньги 10 минут в день', 'Каждый месяц \u2014 новая глава, новая идея.'),
    ('Откладывать 20% сразу с дохода', 'Pay yourself first. До бюджета \u2014 на накопления.'),
    ('Раз в неделю смотреть на чистую стоимость', 'Net worth \u2014 главный показатель прогресса.'),
  ];

  static const _goalTemplates = [
    ('Накопить подушку 6 месяцев', 'Цель', 'Базовая защита от форс-мажоров.'),
    ('Закрыть кредит досрочно', 'Цель', 'Освободить cash flow от долговой петли.'),
    ('Прочитать 3 книги по финансам', 'Книга', 'Например: \u00ABБогатый папа\u00BB, \u00ABПсихология денег\u00BB, \u00ABСамый богатый человек в Вавилоне\u00BB.'),
    ('Освоить инвестиции для белоруса', 'Навык', 'Диверсификация по валютам, доступные инструменты, риски.'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('ПРИВЫЧКИ ФИНГРАМОТНОСТИ', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        ..._habitTemplates.map((h) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.$1, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(h.$2, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        )),
        const SizedBox(height: 16),
        Text('ЦЕЛИ НА ГОД', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        ..._goalTemplates.map((g) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.$1, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.green.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                  child: Text(g.$2, style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 4),
                Text(g.$3, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        )),
      ],
    );
  }
}
