import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/misc.dart';
import '../../state/providers.dart';
import 'challenges_page.dart';

const _kStatusDone = 'done';
const _kStatusFailed = 'failed';
const _kStatusSkip = 'skip';

class ChallengeDetailsPage extends ConsumerWidget {
  const ChallengeDetailsPage({super.key, required this.challengeId});
  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(challengesProvider);
    final c = challenges.cast<Challenge?>().firstWhere(
        (x) => x?.id == challengeId,
        orElse: () => null);
    if (c == null) {
      return const Scaffold(body: Center(child: Text('Челлендж не найден')));
    }
    final checkIns = ref
        .watch(challengeCheckInsProvider)
        .where((x) => x.challengeId == c.id)
        .toList(growable: false);
    final stats = computeChallengeStats(c, checkIns);
    final color = c.color != null ? Color(c.color!) : const Color(0xFF6D5CFF);
    final feelings = checkIns
        .where((x) =>
            (x.feeling != null && x.feeling!.isNotEmpty) ||
            (x.note != null && x.note!.isNotEmpty))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _HeaderCard(challenge: c, stats: stats, color: color),
          const SizedBox(height: 12),
          _DayGrid(challenge: c, checkIns: checkIns, color: color),
          const SizedBox(height: 12),
          if (stats.dayIndex > 0)
            _MoodTrendChart(
              challenge: c,
              checkIns: checkIns,
              color: color,
            ),
          const SizedBox(height: 12),
          _StatusBreakdown(stats: stats),
          const SizedBox(height: 12),
          if (feelings.isNotEmpty) ...[
            Text('История ощущений',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final f in feelings)
              _FeelingCard(checkIn: f),
          ],
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.challenge,
    required this.stats,
    required this.color,
  });
  final Challenge challenge;
  final ChallengeStats stats;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.25),
                  child: Text(
                    challenge.icon ??
                        (challenge.kind == 'avoid' ? '🚫' : '✅'),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(challenge.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                      Text(
                        challenge.kind == 'avoid'
                            ? '${challenge.durationDays} дн. без ${challenge.target ?? "…"}'
                            : 'Делать ${challenge.target ?? "…"} ${challenge.durationDays} дн.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (challenge.description != null) ...[
              const SizedBox(height: 8),
              Text(challenge.description!),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: stats.progressFraction,
                minHeight: 12,
                color: color,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _MetricSmall(
                    label: 'День', value: '${stats.dayIndex} / ${challenge.durationDays}'),
                _MetricSmall(label: 'Серия', value: '${stats.currentStreak}'),
                _MetricSmall(label: 'Лучшая', value: '${stats.bestStreak}'),
                _MetricSmall(
                    label: 'Успех', value: '${(stats.successRate * 100).round()}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricSmall extends StatelessWidget {
  const _MetricSmall({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14)),
      ],
    );
  }
}

class _DayGrid extends ConsumerWidget {
  const _DayGrid({
    required this.challenge,
    required this.checkIns,
    required this.color,
  });
  final Challenge challenge;
  final List<ChallengeCheckIn> checkIns;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = DateTime.tryParse(challenge.startDate);
    if (start == null) return const SizedBox.shrink();
    final today = DateTime.now();
    final byDate = <String, ChallengeCheckIn>{
      for (final ci in checkIns) ci.date: ci,
    };
    final perRow = challenge.durationDays > 60 ? 14 : 7;
    final rows = (challenge.durationDays / perRow).ceil();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Дни', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (var r = 0; r < rows; r++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    for (var i = r * perRow;
                        i < (r + 1) * perRow && i < challenge.durationDays;
                        i++)
                      Expanded(
                        child: _DayCell(
                          day: i + 1,
                          date: DateTime(start.year, start.month,
                              start.day + i),
                          today: today,
                          checkIn: byDate[DateFormat('yyyy-MM-dd')
                              .format(DateTime(start.year, start.month,
                                  start.day + i))],
                          color: color,
                          onTap: () => _editDay(
                            context,
                            ref,
                            challenge,
                            DateFormat('yyyy-MM-dd').format(DateTime(
                                start.year,
                                start.month,
                                start.day + i)),
                          ),
                        ),
                      ),
                    // pad
                    for (var pad = 0;
                        pad <
                            (r + 1) * perRow - challenge.durationDays &&
                                r == rows - 1;
                        pad++)
                      const Spacer(),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _LegendDot(color: color, label: 'Сделано'),
                const _LegendDot(
                    color: Color(0xFFEF4444), label: 'Сорвался'),
                const _LegendDot(
                    color: Color(0xFFF59E0B), label: 'Пропуск'),
                _LegendDot(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  label: 'Пусто',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editDay(BuildContext context, WidgetRef ref,
      Challenge c, String date) async {
    final existing = ref
        .read(challengeCheckInsProvider)
        .cast<ChallengeCheckIn?>()
        .firstWhere((x) => x?.challengeId == c.id && x?.date == date,
            orElse: () => null);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check, color: Color(0xFF22C55E)),
              title: const Text('Сделано'),
              onTap: () => Navigator.pop(ctx, _kStatusDone),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Color(0xFFEF4444)),
              title: const Text('Сорвался'),
              onTap: () => Navigator.pop(ctx, _kStatusFailed),
            ),
            ListTile(
              leading: const Icon(Icons.do_not_disturb_on_outlined,
                  color: Color(0xFFF59E0B)),
              title: const Text('Пропуск'),
              onTap: () => Navigator.pop(ctx, _kStatusSkip),
            ),
            if (existing != null)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                title: const Text('Очистить отметку'),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == 'clear' && existing != null) {
      await ref
          .read(challengeCheckInsProvider.notifier)
          .remove(existing.id);
      return;
    }
    final entry = ChallengeCheckIn(
      id: existing?.id ?? const Uuid().v4(),
      challengeId: c.id,
      date: date,
      status: action,
      feeling: existing?.feeling,
      note: existing?.note,
      mood: existing?.mood,
    );
    await ref
        .read(challengeCheckInsProvider.notifier)
        .upsert(entry);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.date,
    required this.today,
    required this.checkIn,
    required this.color,
    required this.onTap,
  });
  final int day;
  final DateTime date;
  final DateTime today;
  final ChallengeCheckIn? checkIn;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color fill;
    Color text = Theme.of(context).colorScheme.onSurface;
    if (checkIn?.status == _kStatusDone) {
      fill = color;
      text = Colors.white;
    } else if (checkIn?.status == _kStatusFailed) {
      fill = const Color(0xFFEF4444);
      text = Colors.white;
    } else if (checkIn?.status == _kStatusSkip) {
      fill = const Color(0xFFF59E0B);
      text = Colors.white;
    } else if (date.isAfter(today)) {
      fill = scheme.surfaceContainerHighest.withValues(alpha: 0.4);
    } else {
      fill = scheme.surfaceContainerHighest;
    }
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
              border: isToday
                  ? Border.all(color: scheme.primary, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text('$day',
                style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ]);
  }
}

class _MoodTrendChart extends StatelessWidget {
  const _MoodTrendChart({
    required this.challenge,
    required this.checkIns,
    required this.color,
  });
  final Challenge challenge;
  final List<ChallengeCheckIn> checkIns;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(challenge.startDate);
    if (start == null) return const SizedBox.shrink();
    final byDate = <String, ChallengeCheckIn>{
      for (final ci in checkIns) ci.date: ci,
    };
    final spots = <FlSpot>[];
    for (var i = 0; i < challenge.durationDays; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final ci = byDate[DateFormat('yyyy-MM-dd').format(d)];
      if (ci?.mood != null) {
        spots.add(FlSpot(i.toDouble(), ci!.mood!.toDouble()));
      }
    }
    if (spots.length < 2) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Настроение по дням',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (challenge.durationDays - 1).toDouble(),
                  minY: 0.5,
                  maxY: 5.5,
                  gridData: const FlGridData(
                      show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) {
                          const e = ['', '😣', '😕', '😐', '🙂', '😄'];
                          final i = v.toInt();
                          if (i < 1 || i >= e.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(e[i],
                              style: const TextStyle(fontSize: 12));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (challenge.durationDays / 5)
                            .clamp(1, 30)
                            .toDouble(),
                        reservedSize: 18,
                        getTitlesWidget: (v, _) => Text('${v.toInt() + 1}',
                            style: const TextStyle(fontSize: 9)),
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2.4,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.18),
                      ),
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

class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.stats});
  final ChallengeStats stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.doneDays + stats.failedDays + stats.skipDays;
    if (total == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Разбивка по дням',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 110,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 22,
                        sections: [
                          if (stats.doneDays > 0)
                            PieChartSectionData(
                              value: stats.doneDays.toDouble(),
                              color: const Color(0xFF22C55E),
                              title: 'Done',
                              radius: 26,
                              titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10),
                            ),
                          if (stats.failedDays > 0)
                            PieChartSectionData(
                              value: stats.failedDays.toDouble(),
                              color: const Color(0xFFEF4444),
                              title: 'Fail',
                              radius: 26,
                              titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10),
                            ),
                          if (stats.skipDays > 0)
                            PieChartSectionData(
                              value: stats.skipDays.toDouble(),
                              color: const Color(0xFFF59E0B),
                              title: 'Skip',
                              radius: 26,
                              titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatRow(
                        label: 'Сделано',
                        value: '${stats.doneDays}',
                        color: const Color(0xFF22C55E),
                        scheme: scheme,
                        ratio:
                            total == 0 ? 0 : stats.doneDays / total,
                      ),
                      _StatRow(
                        label: 'Сорвался',
                        value: '${stats.failedDays}',
                        color: const Color(0xFFEF4444),
                        scheme: scheme,
                        ratio: total == 0
                            ? 0
                            : stats.failedDays / total,
                      ),
                      _StatRow(
                        label: 'Пропуски',
                        value: '${stats.skipDays}',
                        color: const Color(0xFFF59E0B),
                        scheme: scheme,
                        ratio:
                            total == 0 ? 0 : stats.skipDays / total,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
    required this.scheme,
    required this.ratio,
  });
  final String label;
  final String value;
  final Color color;
  final ColorScheme scheme;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 6),
            Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodySmall)),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 4,
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeelingCard extends StatelessWidget {
  const _FeelingCard({required this.checkIn});
  final ChallengeCheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    final mood = checkIn.mood;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (mood != null && mood >= 1 && mood <= 5)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                      const ['😣', '😕', '😐', '🙂', '😄'][mood - 1],
                      style: const TextStyle(fontSize: 18)),
                ),
              Text(checkIn.date,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (checkIn.feeling != null && checkIn.feeling!.isNotEmpty)
                Text(checkIn.feeling!,
                    style: Theme.of(context).textTheme.bodySmall),
            ]),
            if (checkIn.note != null && checkIn.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(checkIn.note!),
            ],
          ],
        ),
      ),
    );
  }
}
