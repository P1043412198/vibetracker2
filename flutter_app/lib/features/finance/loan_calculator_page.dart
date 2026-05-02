import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/finance_calc.dart';

/// Three-scenario loan calculator:
///  1) Need: principal + term + rate → monthly + overpayment.
///  2) Capability: principal + rate + monthly I can pay → term + overpayment.
///  3) Affordability: monthly I can pay + rate + term → max principal I can borrow.
class LoanCalculatorPage extends StatefulWidget {
  const LoanCalculatorPage({super.key, required this.currency});
  final String currency;

  @override
  State<LoanCalculatorPage> createState() => _LoanCalculatorPageState();
}

class _LoanCalculatorPageState extends State<LoanCalculatorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
        title: const Text('Кредитный калькулятор'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Сколько нужно'),
            Tab(text: 'Сколько могу'),
            Tab(text: 'Сколько дадут'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _NeedTab(currency: widget.currency),
          _CanPayTab(currency: widget.currency),
          _AffordTab(currency: widget.currency),
        ],
      ),
    );
  }
}

NumberFormat _money() =>
    NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);

String _formatTerm(int months) {
  final y = months ~/ 12;
  final m = months % 12;
  if (y > 0 && m > 0) return '$y лет $m мес';
  if (y > 0) return '$y лет';
  return '$m мес';
}

/* ───────────────────────────  Scenario 1  ───────────────────────────── */

class _NeedTab extends StatefulWidget {
  const _NeedTab({required this.currency});
  final String currency;
  @override
  State<_NeedTab> createState() => _NeedTabState();
}

class _NeedTabState extends State<_NeedTab> {
  double _principal = 50000;
  double _ratePct = 14;
  double _months = 60;

  @override
  Widget build(BuildContext context) {
    final monthly = suggestAnnuityPayment(
      principal: _principal,
      annualRatePct: _ratePct,
      months: _months.toInt(),
    );
    final total = monthly * _months;
    final overpay = total - _principal;
    final overpayPct = _principal > 0
        ? ((overpay / _principal) * 100).clamp(0.0, 999.0).toDouble()
        : 0.0;
    final fmt = _money();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Считаем платёж и переплату по фиксированной сумме и сроку.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        _NumField(
          label: 'Сумма кредита, ${widget.currency}',
          value: _principal,
          decimal: false,
          onChanged: (v) => setState(() => _principal = v),
        ),
        _NumField(
          label: 'Ставка, % годовых',
          value: _ratePct,
          decimal: true,
          onChanged: (v) => setState(() => _ratePct = v),
        ),
        _SliderField(
          label: 'Срок, мес',
          value: _months,
          min: 3,
          max: 360,
          onChanged: (v) => setState(() => _months = v),
          formatter: (v) => '${v.toInt()} мес · ${_formatTerm(v.toInt())}',
        ),
        const SizedBox(height: 12),
        _ResultGrid(
          rows: [
            _Res('Платёж в месяц', '${fmt.format(monthly)} ${widget.currency}',
                accent: true),
            _Res('Итого выплатишь',
                '${fmt.format(total)} ${widget.currency}'),
            _Res('Переплата',
                '${fmt.format(overpay)} ${widget.currency}'),
            _Res('Переплата к телу', '${overpayPct.toStringAsFixed(1)} %'),
          ],
        ),
        const SizedBox(height: 16),
        _BreakdownPie(principal: _principal, overpay: overpay),
        const SizedBox(height: 16),
        _Hint(
            text:
                'Аннуитет: одинаковая сумма каждый месяц. В начале платежа большая часть — проценты, в конце — тело. Чем длиннее срок, тем больше переплата.'),
      ],
    );
  }
}

/* ───────────────────────────  Scenario 2  ───────────────────────────── */

class _CanPayTab extends StatefulWidget {
  const _CanPayTab({required this.currency});
  final String currency;
  @override
  State<_CanPayTab> createState() => _CanPayTabState();
}

class _CanPayTabState extends State<_CanPayTab> {
  double _principal = 50000;
  double _ratePct = 14;
  double _monthly = 1200;

  @override
  Widget build(BuildContext context) {
    final months = termMonthsForPayment(
      principal: _principal,
      annualRatePct: _ratePct,
      monthlyPayment: _monthly,
    );
    final fmt = _money();

    if (months == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NumField(
            label: 'Сумма кредита, ${widget.currency}',
            value: _principal,
            decimal: false,
            onChanged: (v) => setState(() => _principal = v),
          ),
          _NumField(
            label: 'Ставка, % годовых',
            value: _ratePct,
            decimal: true,
            onChanged: (v) => setState(() => _ratePct = v),
          ),
          _NumField(
            label: 'Платёж в месяц, ${widget.currency}',
            value: _monthly,
            decimal: false,
            onChanged: (v) => setState(() => _monthly = v),
          ),
          const SizedBox(height: 12),
          _Hint(
              text:
                  'Платёж не покрывает даже проценты — кредит никогда не закроется. Увеличь платёж или уменьши сумму.',
              warn: true),
        ],
      );
    }

    final total = _monthly * months;
    final overpay = total - _principal;
    final overpayPct = _principal > 0
        ? ((overpay / _principal) * 100).clamp(0.0, 999.0).toDouble()
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
            'Считаем срок: задаёшь свою посильную сумму в месяц — приложение покажет, за сколько закроешь и сколько переплатишь.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        _NumField(
          label: 'Сумма кредита, ${widget.currency}',
          value: _principal,
          decimal: false,
          onChanged: (v) => setState(() => _principal = v),
        ),
        _NumField(
          label: 'Ставка, % годовых',
          value: _ratePct,
          decimal: true,
          onChanged: (v) => setState(() => _ratePct = v),
        ),
        _NumField(
          label: 'Платёж в месяц, ${widget.currency}',
          value: _monthly,
          decimal: false,
          onChanged: (v) => setState(() => _monthly = v),
        ),
        const SizedBox(height: 12),
        _ResultGrid(rows: [
          _Res('Срок', '$months мес · ${_formatTerm(months)}', accent: true),
          _Res('Итого выплатишь',
              '${fmt.format(total)} ${widget.currency}'),
          _Res('Переплата', '${fmt.format(overpay)} ${widget.currency}'),
          _Res('Переплата к телу', '${overpayPct.toStringAsFixed(1)} %'),
        ]),
        const SizedBox(height: 16),
        _BreakdownPie(principal: _principal, overpay: overpay),
      ],
    );
  }
}

/* ───────────────────────────  Scenario 3  ───────────────────────────── */

class _AffordTab extends StatefulWidget {
  const _AffordTab({required this.currency});
  final String currency;
  @override
  State<_AffordTab> createState() => _AffordTabState();
}

class _AffordTabState extends State<_AffordTab> {
  double _monthly = 1200;
  double _ratePct = 14;
  double _months = 60;

  @override
  Widget build(BuildContext context) {
    final principal = maxPrincipalForPayment(
      monthlyPayment: _monthly,
      annualRatePct: _ratePct,
      months: _months.toInt(),
    );
    final total = _monthly * _months;
    final overpay = total - principal;
    final overpayPct = principal > 0
        ? ((overpay / principal) * 100).clamp(0.0, 999.0).toDouble()
        : 0.0;
    final fmt = _money();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
            'Считаем максимальную сумму: исходя из посильного платежа, ставки и срока.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        _NumField(
          label: 'Платёж в месяц, ${widget.currency}',
          value: _monthly,
          decimal: false,
          onChanged: (v) => setState(() => _monthly = v),
        ),
        _NumField(
          label: 'Ставка, % годовых',
          value: _ratePct,
          decimal: true,
          onChanged: (v) => setState(() => _ratePct = v),
        ),
        _SliderField(
          label: 'Срок, мес',
          value: _months,
          min: 3,
          max: 360,
          onChanged: (v) => setState(() => _months = v),
          formatter: (v) => '${v.toInt()} мес · ${_formatTerm(v.toInt())}',
        ),
        const SizedBox(height: 12),
        _ResultGrid(rows: [
          _Res('Максимальная сумма',
              '${fmt.format(principal)} ${widget.currency}',
              accent: true),
          _Res('Итого выплатишь',
              '${fmt.format(total)} ${widget.currency}'),
          _Res('Переплата', '${fmt.format(overpay)} ${widget.currency}'),
          _Res('Переплата к телу', '${overpayPct.toStringAsFixed(1)} %'),
        ]),
        const SizedBox(height: 16),
        _BreakdownPie(principal: principal, overpay: overpay),
        const SizedBox(height: 16),
        _Hint(
            text:
                'Здравая практика: совокупный платёж по кредитам ≤ 30 % дохода. Если выйдет больше — лучше брать меньшую сумму.'),
      ],
    );
  }
}

/* ───────────────────────────  shared parts  ─────────────────────────── */

class _NumField extends StatefulWidget {
  const _NumField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.decimal = false,
  });
  final String label;
  final double value;
  final bool decimal;
  final ValueChanged<double> onChanged;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: _format(widget.value));
  }

  String _format(double v) =>
      widget.decimal ? v.toStringAsFixed(2) : v.toStringAsFixed(0);

  @override
  void didUpdateWidget(covariant _NumField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value &&
        double.tryParse(_ctl.text.replaceAll(',', '.')) != widget.value) {
      _ctl.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _ctl,
        keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
        decoration: InputDecoration(labelText: widget.label),
        onChanged: (raw) {
          final v = double.tryParse(raw.replaceAll(',', '.'));
          if (v != null && v >= 0) widget.onChanged(v);
        },
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.formatter,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double) formatter;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text('$label · ${formatter(value)}',
              style: Theme.of(context).textTheme.labelLarge),
        ),
        Slider(
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          value: value.clamp(min, max),
          label: formatter(value),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Res {
  _Res(this.label, this.value, {this.accent = false});
  final String label;
  final String value;
  final bool accent;
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.rows});
  final List<_Res> rows;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final r in rows)
          Container(
            constraints: const BoxConstraints(minWidth: 150),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: r.accent
                  ? scheme.primary.withValues(alpha: 0.10)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: r.accent
                    ? scheme.primary.withValues(alpha: 0.4)
                    : scheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.label,
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                const SizedBox(height: 2),
                Text(r.value,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: r.accent ? scheme.primary : scheme.onSurface,
                    )),
              ],
            ),
          ),
      ],
    );
  }
}

class _BreakdownPie extends StatelessWidget {
  const _BreakdownPie({required this.principal, required this.overpay});
  final num principal;
  final num overpay;
  @override
  Widget build(BuildContext context) {
    final p = principal <= 0 ? 0 : principal.toDouble();
    final o = overpay <= 0 ? 0 : overpay.toDouble();
    if (p + o <= 0) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тело vs проценты',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 28,
                  sections: [
                    PieChartSectionData(
                      value: p.toDouble(),
                      color: const Color(0xFF22C55E),
                      title: 'тело',
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11),
                      radius: 28,
                    ),
                    PieChartSectionData(
                      value: o.toDouble(),
                      color: const Color(0xFFF59E0B),
                      title: '%',
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11),
                      radius: 28,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, this.warn = false});
  final String text;
  final bool warn;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = warn ? const Color(0xFFEF4444) : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warn ? Icons.warning_amber_outlined : Icons.lightbulb_outline,
              color: c),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
