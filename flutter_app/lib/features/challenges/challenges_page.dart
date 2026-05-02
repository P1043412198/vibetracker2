import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/misc.dart';
import '../../state/providers.dart';

const _kStatusDone = 'done';
const _kStatusFailed = 'failed';
const _kStatusSkip = 'skip';

class ChallengesPage extends ConsumerWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = [...ref.watch(challengesProvider)]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final active =
        challenges.where((c) => !c.archived).toList(growable: false);
    final archived =
        challenges.where((c) => c.archived).toList(growable: false);
    final checkIns = ref.watch(challengeCheckInsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Челленджи')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addChallenge(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Челлендж'),
      ),
      body: challenges.isEmpty
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _OverallStats(challenges: active, checkIns: checkIns),
                const SizedBox(height: 12),
                if (active.isNotEmpty)
                  Text('Активные',
                      style: Theme.of(context).textTheme.titleSmall),
                for (final c in active) ...[
                  const SizedBox(height: 8),
                  _ChallengeCard(
                    challenge: c,
                    checkIns: checkIns
                        .where((x) => x.challengeId == c.id)
                        .toList(growable: false),
                  ),
                ],
                if (archived.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Архив',
                      style: Theme.of(context).textTheme.titleSmall),
                  for (final c in archived) ...[
                    const SizedBox(height: 8),
                    _ChallengeCard(
                      challenge: c,
                      checkIns: checkIns
                          .where((x) => x.challengeId == c.id)
                          .toList(growable: false),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text('Челленджей пока нет',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Поставь себе вызов: «30 дней без сахара», «21 день медитации» — и отмечай каждый день.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallStats extends StatelessWidget {
  const _OverallStats({required this.challenges, required this.checkIns});
  final List<Challenge> challenges;
  final List<ChallengeCheckIn> checkIns;

  @override
  Widget build(BuildContext context) {
    if (challenges.isEmpty) return const SizedBox.shrink();
    var totalDays = 0;
    var doneDays = 0;
    var failedDays = 0;
    for (final c in challenges) {
      totalDays += c.durationDays;
      for (final ci in checkIns.where((x) => x.challengeId == c.id)) {
        if (ci.status == _kStatusDone) doneDays++;
        if (ci.status == _kStatusFailed) failedDays++;
      }
    }
    final pendingDays = (totalDays - doneDays - failedDays)
        .clamp(0, double.infinity)
        .toInt();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 22,
                  sections: [
                    if (doneDays > 0)
                      PieChartSectionData(
                        value: doneDays.toDouble(),
                        color: const Color(0xFF22C55E),
                        title: '$doneDays',
                        radius: 22,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11),
                      ),
                    if (failedDays > 0)
                      PieChartSectionData(
                        value: failedDays.toDouble(),
                        color: const Color(0xFFEF4444),
                        title: '$failedDays',
                        radius: 22,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11),
                      ),
                    if (pendingDays > 0)
                      PieChartSectionData(
                        value: pendingDays.toDouble(),
                        color: const Color(0xFF94A3B8),
                        title: '$pendingDays',
                        radius: 22,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${challenges.length} активных',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    '$doneDays / $totalDays дней пройдено',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: totalDays == 0
                          ? 0
                          : (doneDays / totalDays).clamp(0.0, 1.0).toDouble(),
                      minHeight: 8,
                      color: const Color(0xFF22C55E),
                      backgroundColor:
                          scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({required this.challenge, required this.checkIns});
  final Challenge challenge;
  final List<ChallengeCheckIn> checkIns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = computeChallengeStats(challenge, checkIns);
    final color = challenge.color != null
        ? Color(challenge.color!)
        : const Color(0xFF6D5CFF);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayCheck = checkIns
        .cast<ChallengeCheckIn?>()
        .firstWhere((c) => c?.date == today, orElse: () => null);

    Future<void> markStatus(String status) async {
      final entry = ChallengeCheckIn(
        id: todayCheck?.id ?? const Uuid().v4(),
        challengeId: challenge.id,
        date: today,
        status: status,
        feeling: todayCheck?.feeling,
        note: todayCheck?.note,
        mood: todayCheck?.mood,
      );
      await ref
          .read(challengeCheckInsProvider.notifier)
          .upsert(entry);
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/challenges/${challenge.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withValues(alpha: 0.18),
                    child: Text(
                      challenge.icon ??
                          (challenge.kind == 'avoid' ? '🚫' : '✅'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(challenge.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('${stats.dayIndex} / ${challenge.durationDays}',
                      style: Theme.of(context).textTheme.labelSmall),
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () =>
                        _menu(context, ref, challenge),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: stats.progressFraction,
                  minHeight: 8,
                  color: color,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Pill(label: 'серия', value: '${stats.currentStreak}'),
                  _Pill(label: 'лучшая', value: '${stats.bestStreak}'),
                  _Pill(
                      label: 'успех',
                      value:
                          '${(stats.successRate * 100).round()}%'),
                  _Pill(
                      label: 'осталось',
                      value: '${stats.remainingDays} дн.'),
                ],
              ),
              const SizedBox(height: 8),
              _DayDotsRow(
                challenge: challenge,
                checkIns: checkIns,
                color: color,
              ),
              const SizedBox(height: 10),
              if (!challenge.archived) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: todayCheck?.status == _kStatusDone
                              ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                              : null,
                        ),
                        onPressed: () => markStatus(_kStatusDone),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Сегодня'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: () => markStatus(_kStatusFailed),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Сорвался'),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: () => markStatus(_kStatusSkip),
                      icon: const Icon(
                          Icons.do_not_disturb_on_outlined,
                          size: 16),
                      label: const Text('Пропуск'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () =>
                      _addFeelingsSheet(context, ref, challenge, today),
                  icon: const Icon(Icons.edit_note_outlined, size: 18),
                  label: const Text('Записать ощущения'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _menu(
      BuildContext context, WidgetRef ref, Challenge c) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Изменить'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(c.archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined),
              title: Text(c.archived ? 'Вернуть из архива' : 'В архив'),
              onTap: () => Navigator.pop(ctx, 'archive'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Удалить'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'edit') {
      _editChallenge(context, ref, existing: c);
    } else if (action == 'archive') {
      await ref
          .read(challengesProvider.notifier)
          .upsert(c.copyWith(archived: !c.archived));
    } else if (action == 'delete') {
      await ref.read(challengesProvider.notifier).remove(c.id);
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _DayDotsRow extends StatelessWidget {
  const _DayDotsRow({
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
    final scheme = Theme.of(context).colorScheme;
    final byDate = <String, ChallengeCheckIn>{
      for (final ci in checkIns) ci.date: ci,
    };
    final today = DateTime.now();
    final cells = <Widget>[];
    for (var i = 0; i < challenge.durationDays; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final iso = DateFormat('yyyy-MM-dd').format(d);
      final ci = byDate[iso];
      Color c;
      if (ci?.status == _kStatusDone) {
        c = color;
      } else if (ci?.status == _kStatusFailed) {
        c = const Color(0xFFEF4444);
      } else if (ci?.status == _kStatusSkip) {
        c = const Color(0xFFF59E0B);
      } else if (d.isAfter(today)) {
        c = scheme.surfaceContainerHighest;
      } else {
        c = scheme.surfaceContainerHighest;
      }
      cells.add(Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(2),
          border: _isSameDay(d, today)
              ? Border.all(color: scheme.primary, width: 1.2)
              : null,
        ),
      ));
    }
    return SizedBox(
      height: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: cells),
            ),
          ),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/* ------------------------- stats utility ------------------------------- */

class ChallengeStats {
  ChallengeStats({
    required this.dayIndex,
    required this.remainingDays,
    required this.currentStreak,
    required this.bestStreak,
    required this.successRate,
    required this.progressFraction,
    required this.doneDays,
    required this.failedDays,
    required this.skipDays,
  });
  final int dayIndex;
  final int remainingDays;
  final int currentStreak;
  final int bestStreak;
  final double successRate;
  final double progressFraction;
  final int doneDays;
  final int failedDays;
  final int skipDays;
}

ChallengeStats computeChallengeStats(
    Challenge c, List<ChallengeCheckIn> checkIns) {
  final start = DateTime.tryParse(c.startDate);
  final today = DateTime.now();
  final byDate = <String, ChallengeCheckIn>{
    for (final ci in checkIns) ci.date: ci,
  };
  final dayIndex = start == null
      ? 0
      : (today.difference(DateTime(start.year, start.month, start.day))
                  .inDays +
              1)
          .clamp(0, c.durationDays);
  final remaining = c.durationDays - dayIndex;
  var done = 0;
  var failed = 0;
  var skip = 0;
  var current = 0;
  var best = 0;
  for (var i = 0; i < c.durationDays && start != null; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    if (d.isAfter(today)) break;
    final ci = byDate[DateFormat('yyyy-MM-dd').format(d)];
    if (ci?.status == _kStatusDone) {
      done++;
      current++;
      if (current > best) best = current;
    } else if (ci?.status == _kStatusFailed) {
      failed++;
      current = 0;
    } else if (ci?.status == _kStatusSkip) {
      skip++;
    } else {
      current = 0;
    }
  }
  final touched = done + failed;
  return ChallengeStats(
    dayIndex: dayIndex,
    remainingDays: remaining < 0 ? 0 : remaining,
    currentStreak: current,
    bestStreak: best,
    successRate: touched == 0 ? 0 : done / touched,
    progressFraction: c.durationDays == 0
        ? 0
        : (done / c.durationDays).clamp(0.0, 1.0).toDouble(),
    doneDays: done,
    failedDays: failed,
    skipDays: skip,
  );
}

/* ------------------------- create / edit ------------------------------- */

Future<void> _addChallenge(BuildContext context, WidgetRef ref) =>
    _editChallenge(context, ref);

Future<void> _editChallenge(
  BuildContext context,
  WidgetRef ref, {
  Challenge? existing,
}) async {
  final titleCtl = TextEditingController(text: existing?.title ?? '');
  final descCtl = TextEditingController(text: existing?.description ?? '');
  final targetCtl = TextEditingController(text: existing?.target ?? '');
  final durationCtl = TextEditingController(
      text: existing?.durationDays.toString() ?? '30');
  String kind = existing?.kind ?? 'avoid';
  String emoji = existing?.icon ?? '🚫';
  DateTime startDate = existing == null
      ? DateTime.now()
      : (DateTime.tryParse(existing.startDate) ?? DateTime.now());
  Color color = existing?.color != null
      ? Color(existing!.color!)
      : const Color(0xFF6D5CFF);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx2, setState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 4,
            bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? 'Новый челлендж' : 'Редактирование',
                    style: Theme.of(ctx2).textTheme.titleLarge),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'avoid', label: Text('Без чего-то')),
                    ButtonSegment(value: 'do', label: Text('Делать')),
                  ],
                  selected: {kind},
                  onSelectionChanged: (s) => setState(() {
                    kind = s.first;
                    if (existing == null) {
                      emoji = kind == 'avoid' ? '🚫' : '✅';
                    }
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtl,
                  autofocus: existing == null,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    hintText:
                        'Например: 30 дней без сахара или 21 день медитации',
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: durationCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Длительность, дн.'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          DateFormat('d MMM y', 'ru').format(startDate),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: const Text('Старт'),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx2,
                          initialDate: startDate,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => startDate = picked);
                        }
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: targetCtl,
                  decoration: const InputDecoration(
                      labelText: 'Что именно?',
                      hintText: 'сахар, кофе, медитация…'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Заметка (зачем мне это)'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('Иконка'),
                  const SizedBox(width: 8),
                  for (final e in const [
                    '🚫',
                    '✅',
                    '🔥',
                    '💧',
                    '🥦',
                    '🏃',
                    '🧘',
                    '📚',
                    '🛌',
                    '🚭',
                    '🍷',
                    '📵'
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () => setState(() => emoji = e),
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: emoji == e
                                ? Theme.of(ctx2)
                                    .colorScheme
                                    .primaryContainer
                                : Colors.transparent,
                            border: Border.all(
                                color: emoji == e
                                    ? Theme.of(ctx2).colorScheme.primary
                                    : Colors.transparent),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(e,
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Цвет'),
                  const SizedBox(width: 8),
                  for (final col in const [
                    Color(0xFF6D5CFF),
                    Color(0xFF22C55E),
                    Color(0xFFF59E0B),
                    Color(0xFFEF4444),
                    Color(0xFF3B82F6),
                    Color(0xFFEC4899),
                    Color(0xFF14B8A6),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => setState(() => color = col),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: col == color
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2),
                            boxShadow: col == color
                                ? const [
                                    BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4)
                                  ]
                                : const [],
                          ),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final title = titleCtl.text.trim();
                    if (title.isEmpty) return;
                    final dur = int.tryParse(durationCtl.text.trim()) ?? 30;
                    final iso =
                        DateFormat('yyyy-MM-dd').format(startDate);
                    if (existing == null) {
                      await ref.read(challengesProvider.notifier).add(
                            Challenge(
                              id: const Uuid().v4(),
                              title: title,
                              kind: kind,
                              durationDays: dur.clamp(1, 365),
                              startDate: iso,
                              description: descCtl.text.trim().isEmpty
                                  ? null
                                  : descCtl.text.trim(),
                              target: targetCtl.text.trim().isEmpty
                                  ? null
                                  : targetCtl.text.trim(),
                              icon: emoji,
                              color: color.toARGB32(),
                            ),
                          );
                    } else {
                      await ref
                          .read(challengesProvider.notifier)
                          .upsert(existing.copyWith(
                            title: title,
                            kind: kind,
                            durationDays: dur.clamp(1, 365),
                            startDate: iso,
                            description: descCtl.text.trim().isEmpty
                                ? null
                                : descCtl.text.trim(),
                            target: targetCtl.text.trim().isEmpty
                                ? null
                                : targetCtl.text.trim(),
                            icon: emoji,
                            color: color.toARGB32(),
                          ));
                    }
                    if (ctx2.mounted) Navigator.of(ctx2).pop();
                  },
                  child: Text(
                      existing == null ? 'Создать' : 'Сохранить'),
                ),
              ],
            ),
          ),
        );
      });
    },
  );
}

Future<void> _addFeelingsSheet(BuildContext context, WidgetRef ref,
    Challenge c, String date) async {
  final existing = ref
      .read(challengeCheckInsProvider)
      .cast<ChallengeCheckIn?>()
      .firstWhere((x) => x?.challengeId == c.id && x?.date == date,
          orElse: () => null);
  final feelingCtl =
      TextEditingController(text: existing?.feeling ?? '');
  final noteCtl = TextEditingController(text: existing?.note ?? '');
  int mood = existing?.mood ?? 3;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx2, setState) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 4,
          bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ощущения за $date',
                style: Theme.of(ctx2).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    iconSize: 30,
                    onPressed: () => setState(() => mood = i),
                    icon: Text(
                      const ['😣', '😕', '😐', '🙂', '😄'][i - 1],
                      style: TextStyle(
                          fontSize: mood == i ? 28 : 24,
                          color: mood == i ? null : Colors.grey),
                    ),
                  ),
              ],
            ),
            TextField(
              controller: feelingCtl,
              decoration: const InputDecoration(
                  labelText: 'Чувства одной строкой',
                  hintText: 'спокойно, тяжело, радостно…'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtl,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Заметка',
                  hintText: 'Что помогло / что хотелось / триггеры'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final entry = ChallengeCheckIn(
                  id: existing?.id ?? const Uuid().v4(),
                  challengeId: c.id,
                  date: date,
                  status: existing?.status ?? _kStatusDone,
                  feeling: feelingCtl.text.trim().isEmpty
                      ? null
                      : feelingCtl.text.trim(),
                  note: noteCtl.text.trim().isEmpty
                      ? null
                      : noteCtl.text.trim(),
                  mood: mood,
                );
                await ref
                    .read(challengeCheckInsProvider.notifier)
                    .upsert(entry);
                if (ctx2.mounted) Navigator.of(ctx2).pop();
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
    }),
  );
}
