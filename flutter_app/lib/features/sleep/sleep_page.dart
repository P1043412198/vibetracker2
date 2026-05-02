import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/misc.dart';
import '../../state/providers.dart';

/// Sleep tracker page — port of `SleepRecoveryWidget.tsx`.
///
/// Log hours + quality (1–5), view last-7-days chart, readiness score,
/// and a scrollable history list with delete.
class SleepPage extends ConsumerStatefulWidget {
  const SleepPage({super.key});

  @override
  ConsumerState<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends ConsumerState<SleepPage> {
  bool _isLogging = false;
  double _hours = 7.5;
  int _quality = 3;
  String _notes = '';

  void _save() {
    ref.read(sleepLogsProvider.notifier).add(SleepLog(
          id: const Uuid().v4(),
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          hours: _hours,
          quality: _quality,
          notes: _notes.isEmpty ? null : _notes,
        ));
    setState(() {
      _isLogging = false;
      _hours = 7.5;
      _quality = 3;
      _notes = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(sleepLogsProvider);
    final scheme = Theme.of(context).colorScheme;

    final averageHours = logs.isEmpty
        ? 0.0
        : logs.fold<num>(0, (s, l) => s + l.hours) / logs.length;
    final readiness =
        (averageHours / 8 * 70 + _quality / 5 * 30).round().clamp(0, 100);

    // last 7 days
    final now = DateTime.now();
    final last7 = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      final log = logs.cast<SleepLog?>().firstWhere(
            (l) => l!.date == key,
            orElse: () => null,
          );
      return _DayPoint(
        label: DateFormat('dd.MM').format(d),
        hours: log?.hours.toDouble() ?? 0,
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сон и Восстановление'),
        actions: [
          IconButton(
            icon: Icon(_isLogging ? Icons.close : Icons.add),
            onPressed: () => setState(() => _isLogging = !_isLogging),
            tooltip: 'Добавить запись',
          ),
        ],
      ),
      body: _isLogging
          ? _LogForm(
              hours: _hours,
              quality: _quality,
              notes: _notes,
              onHoursChanged: (v) => setState(() => _hours = v),
              onQualityChanged: (v) => setState(() => _quality = v),
              onNotesChanged: (v) => setState(() => _notes = v),
              onSave: _save,
              onCancel: () => setState(() => _isLogging = false),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stats cards
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.trending_up,
                      iconColor: const Color(0xFF22C55E),
                      label: 'Готовность',
                      value: '$readiness%',
                      subtitle: readiness > 80
                          ? 'Высокая'
                          : readiness > 60
                              ? 'Средняя'
                              : 'Низкая',
                      subtitleColor: readiness > 80
                          ? const Color(0xFF22C55E)
                          : readiness > 60
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.star,
                      iconColor: const Color(0xFFF59E0B),
                      label: 'Средний сон',
                      value: '${averageHours.toStringAsFixed(1)}ч',
                      subtitle: 'в сутки',
                      subtitleColor: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Chart
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    child: SizedBox(
                      height: 160,
                      child: _SleepChart(data: last7, scheme: scheme),
                    ),
                  ),
                ),
                if (readiness < 60) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber,
                              color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Низкий уровень восстановления. Рекомендуется снизить интенсивность тренировок.',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // History
                Text('История',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (logs.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.bedtime_outlined,
                              size: 48, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('Нет записей сна',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  )
                else
                  ...logs.reversed.map((log) => _SleepTile(
                        log: log,
                        onDelete: () => ref
                            .read(sleepLogsProvider.notifier)
                            .remove(log.id),
                      )),
              ],
            ),
    );
  }
}

class _DayPoint {
  _DayPoint({required this.label, required this.hours});
  final String label;
  final double hours;
}

class _SleepChart extends StatelessWidget {
  const _SleepChart({required this.data, required this.scheme});
  final List<_DayPoint> data;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 12,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    data[idx].label,
                    style: TextStyle(
                        fontSize: 9, color: scheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < data.length; i++)
                FlSpot(i.toDouble(), data[i].hours),
            ],
            isCurved: true,
            color: scheme.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                radius: 3,
                color: scheme.primary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              return LineTooltipItem(
                '${s.y.toStringAsFixed(1)}ч',
                TextStyle(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.subtitleColor,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: iconColor),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(subtitle,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogForm extends StatelessWidget {
  const _LogForm({
    required this.hours,
    required this.quality,
    required this.notes,
    required this.onHoursChanged,
    required this.onQualityChanged,
    required this.onNotesChanged,
    required this.onSave,
    required this.onCancel,
  });
  final double hours;
  final int quality;
  final String notes;
  final ValueChanged<double> onHoursChanged;
  final ValueChanged<int> onQualityChanged;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Часов сна: ${hours.toStringAsFixed(1)}ч',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Slider(
                  value: hours,
                  min: 0,
                  max: 12,
                  divisions: 24,
                  label: '${hours.toStringAsFixed(1)}ч',
                  onChanged: onHoursChanged,
                ),
                const SizedBox(height: 20),
                Text('Качество (1-5): $quality',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                    5,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: i > 0 ? 6 : 0),
                        child: _QualityButton(
                          value: i + 1,
                          selected: quality == i + 1,
                          onTap: () => onQualityChanged(i + 1),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Заметки',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 2,
                  onChanged: onNotesChanged,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: onSave,
                        child: const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QualityButton extends StatelessWidget {
  const _QualityButton({
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _SleepTile extends StatelessWidget {
  const _SleepTile({required this.log, required this.onDelete});
  final SleepLog log;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.bedtime, color: scheme.primary, size: 20),
        ),
        title: Text('${log.hours}ч  —  ${'★' * log.quality}${'☆' * (5 - log.quality)}'),
        subtitle: Text(
          log.date,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
