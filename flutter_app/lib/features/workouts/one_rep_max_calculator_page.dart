import 'package:flutter/material.dart';

import '../../widgets/app_back_button.dart';
import 'workout_format.dart';
import 'workout_viz.dart';

/// Standalone 1RM calculator: enter a working weight × reps, get the estimated
/// one-rep max (Epley) plus a table of training loads at common %1RM.
class OneRepMaxCalculatorPage extends StatefulWidget {
  const OneRepMaxCalculatorPage({super.key, this.initialWeight});

  final num? initialWeight;

  @override
  State<OneRepMaxCalculatorPage> createState() =>
      _OneRepMaxCalculatorPageState();
}

class _OneRepMaxCalculatorPageState extends State<OneRepMaxCalculatorPage> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(
        text: widget.initialWeight == null ? '' : fmtNum(widget.initialWeight!));
    _reps = TextEditingController(text: '5');
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  static const _percents = [100, 95, 90, 85, 80, 75, 70, 65, 60, 50];
  // Typical reps achievable at each %1RM (Prilepin-ish reference).
  static const _repsAt = {
    100: '1',
    95: '2',
    90: '3–4',
    85: '5–6',
    80: '7–8',
    75: '9–10',
    70: '11–12',
    65: '13–15',
    60: '16–18',
    50: '20+',
  };

  @override
  Widget build(BuildContext context) {
    final w = double.tryParse(_weight.text.trim().replaceAll(',', '.')) ?? 0;
    final r = double.tryParse(_reps.text.trim()) ?? 0;
    final epley = estimatedOneRepMax(w, r);
    final brzycki = brzyckiOneRepMax(w, r);
    // Use the average of Epley & Brzycki for the headline number — Epley alone
    // over-estimates on high-rep sets.
    final oneRm = averagedOneRepMax(w, r);
    final lowConfidence = r > 10;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Калькулятор 1ПМ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Вес, кг',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _reps,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Повторы',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withValues(alpha: 0.14),
                  scheme.primary.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: scheme.primary, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Расчётный 1ПМ',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        oneRm <= 0 ? '—' : '${fmtNum(oneRm)} кг',
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (oneRm > 0)
            Text(
              'Эпли ${fmtNum(epley)} кг · Бжицки ${brzycki <= 0 ? '—' : '${fmtNum(brzycki)} кг'} (показано среднее)',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Text('Среднее формул Эпли и Бжицки',
                style: Theme.of(context).textTheme.bodySmall),
          if (lowConfidence) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.info_outline, size: 15, color: scheme.tertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Оценка надёжна до ~10 повторов. Выше — считайте её ориентиром.',
                    style: TextStyle(fontSize: 12, color: scheme.tertiary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('Рабочие веса по % от 1ПМ',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (oneRm <= 0)
            Text('Введите вес и повторы, чтобы увидеть таблицу.',
                style: TextStyle(color: scheme.outline))
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _percents.length; i++)
                    _PercentRow(
                      pct: _percents[i],
                      weight: oneRm * _percents[i] / 100,
                      reps: _repsAt[_percents[i]]!,
                      shaded: i.isOdd,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PercentRow extends StatelessWidget {
  const _PercentRow({
    required this.pct,
    required this.weight,
    required this.reps,
    required this.shaded,
  });

  final int pct;
  final double weight;
  final String reps;
  final bool shaded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: shaded
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text('$pct%',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text('${fmtNum(weight)} кг',
                style: const TextStyle(fontSize: 16)),
          ),
          Text('~$reps повт.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
