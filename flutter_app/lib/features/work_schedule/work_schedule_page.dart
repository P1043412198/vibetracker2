import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/misc.dart';
import '../../state/providers.dart';

const _shiftTypes = ['day', 'night', 'off', 'post_night', 'vacation'];

const _shiftLabels = {
  'day': 'День',
  'night': 'Ночь',
  'off': 'Вых.',
  'post_night': 'Отсыпной',
  'vacation': 'Отпуск',
};

const _shiftIcons = {
  'day': Icons.wb_sunny,
  'night': Icons.nightlight_round,
  'off': Icons.home,
  'post_night': Icons.coffee,
  'vacation': Icons.flight,
};

Color _shiftColor(String type) {
  switch (type) {
    case 'day':
      return Colors.amber;
    case 'night':
      return Colors.indigo;
    case 'post_night':
      return Colors.teal;
    case 'vacation':
      return Colors.pink;
    default:
      return Colors.grey;
  }
}

const _presets = {
  '2/2/2/2': _Preset(
    'День, Вых., Ночь, Отсыпной',
    ['day', 'day', 'off', 'off', 'night', 'night', 'post_night', 'off'],
  ),
  '2/2': _Preset(
    'Два через два',
    ['day', 'day', 'off', 'off'],
  ),
  '5/2': _Preset(
    'Пятидневка',
    ['day', 'day', 'day', 'day', 'day', 'off', 'off'],
  ),
  '3/3': _Preset(
    'Три через три',
    ['day', 'day', 'day', 'off', 'off', 'off'],
  ),
  '1/3': _Preset(
    'Сутки через трое',
    ['day', 'night', 'off', 'off', 'off', 'off'],
  ),
};

class _Preset {
  const _Preset(this.label, this.cycle);
  final String label;
  final List<String> cycle;
}

class WorkSchedulePage extends ConsumerStatefulWidget {
  const WorkSchedulePage({super.key});

  @override
  ConsumerState<WorkSchedulePage> createState() => _WorkSchedulePageState();
}

class _WorkSchedulePageState extends ConsumerState<WorkSchedulePage> {
  DateTime _currentMonth = DateTime.now();
  bool _showSettings = false;

  String _tempAnchor = DateFormat('yyyy-MM-dd').format(DateTime.now());
  List<String> _tempCycle = List.from(_presets['2/2/2/2']!.cycle);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ws = ref.read(workScheduleProvider);
      if (ws == null) {
        _showSettings = true;
      } else {
        _tempAnchor = ws.anchorDate;
        _tempCycle = List.from(ws.cycle);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(workScheduleProvider);
    final dateFmt = DateFormat('LLLL yyyy', 'ru');

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Row(
          children: [
            Icon(Icons.calendar_today, size: 22),
            SizedBox(width: 8),
            Text('График работы'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flight),
            tooltip: 'Добавить отпуск',
            onPressed: ws != null ? () => _showVacationDialog() : null,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Настройки',
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (_showSettings) _settingsCard(),

          // Month calendar
          _monthCalendar(ws, dateFmt),

          // Vacations
          if (ws != null && ws.vacations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Ваши отпуска',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final v in ws.vacations) _vacationTile(v),
          ],

          // Legend
          const SizedBox(height: 16),
          _legend(),
        ],
      ),
    );
  }

  // ---- Settings ----
  Widget _settingsCard() {
    final dayFmt = DateFormat('d MMMM (EEEE)', 'ru');
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Настройка графика',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _showSettings = false),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Anchor date
            Text('Дата начала цикла',
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(_tempAnchor) ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() =>
                      _tempAnchor = DateFormat('yyyy-MM-dd').format(picked));
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withAlpha(60)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_tempAnchor),
              ),
            ),

            const SizedBox(height: 12),

            // Presets
            Text('Пресеты', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _presets.entries.map((e) {
                return ActionChip(
                  label: Text(e.key, style: const TextStyle(fontSize: 11)),
                  onPressed: () =>
                      setState(() => _tempCycle = List.from(e.value.cycle)),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Cycle editor
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Цикл (${_tempCycle.length} дн.)',
                    style: Theme.of(context).textTheme.labelSmall),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _tempCycle = [..._tempCycle, 'off']),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('День', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(_tempCycle.length, (i) {
                final shift = _tempCycle[i];
                return GestureDetector(
                  onTap: () {
                    final types = ['day', 'night', 'post_night', 'off'];
                    final next =
                        types[(types.indexOf(shift) + 1) % types.length];
                    setState(() => _tempCycle[i] = next);
                  },
                  onLongPress: () {
                    if (_tempCycle.length > 1) {
                      setState(() => _tempCycle.removeAt(i));
                    }
                  },
                  child: Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _shiftColor(shift).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _shiftColor(shift).withAlpha(80)),
                    ),
                    child: Column(
                      children: [
                        Icon(_shiftIcons[shift], size: 14,
                            color: _shiftColor(shift)),
                        Text(_shiftLabels[shift] ?? shift,
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: _shiftColor(shift))),
                      ],
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 12),

            // Preview
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Проверка (первые 3 дня):',
                        style:
                            TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    for (var offset = 0; offset < 3; offset++)
                      _previewRow(offset, dayFmt),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Сохранить настройки'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewRow(int offset, DateFormat dayFmt) {
    final anchor = DateTime.tryParse(_tempAnchor) ?? DateTime.now();
    final date = anchor.add(Duration(days: offset));
    final shift = _tempCycle[offset % _tempCycle.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(dayFmt.format(date), style: const TextStyle(fontSize: 11)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _shiftColor(shift).withAlpha(30),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _shiftColor(shift).withAlpha(80)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_shiftIcons[shift], size: 12, color: _shiftColor(shift)),
                const SizedBox(width: 4),
                Text(_shiftLabels[shift] ?? shift,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _shiftColor(shift))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    final ws = ref.read(workScheduleProvider);
    ref.read(workScheduleProvider.notifier).save(WorkScheduleData(
          anchorDate: _tempAnchor,
          cycle: _tempCycle,
          vacations: ws?.vacations ?? [],
        ));
    setState(() => _showSettings = false);
  }

  // ---- Calendar ----
  Widget _monthCalendar(WorkScheduleData? ws, DateFormat dateFmt) {
    final firstDay =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=Mon .. 7=Sun
    final daysInMonth = lastDay.day;

    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    return Card(
      child: Column(
        children: [
          // Month header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _currentMonth =
                      DateTime(_currentMonth.year, _currentMonth.month - 1)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _currentMonth = DateTime.now()),
                  child: Text(
                    dateFmt.format(_currentMonth),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _currentMonth =
                      DateTime(_currentMonth.year, _currentMonth.month + 1)),
                ),
              ],
            ),
          ),

          // Weekday headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),

          // Calendar grid
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Column(
              children: _buildCalendarRows(
                  ws, firstDay, startWeekday, daysInMonth, todayStr),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCalendarRows(WorkScheduleData? ws, DateTime firstDay,
      int startWeekday, int daysInMonth, String todayStr) {
    final rows = <Widget>[];
    var dayCounter = 1;

    while (dayCounter <= daysInMonth) {
      final cells = <Widget>[];
      for (var col = 0; col < 7; col++) {
        if ((rows.isEmpty && col < startWeekday - 1) ||
            dayCounter > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 60)));
          continue;
        }

        final date = DateTime(firstDay.year, firstDay.month, dayCounter);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final isToday = dateStr == todayStr;
        final shift = _getShiftForDate(ws, date);

        cells.add(Expanded(
          child: Container(
            height: 60,
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: shift != null
                  ? _shiftColor(shift).withAlpha(20)
                  : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: isToday
                      ? BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        )
                      : null,
                  alignment: Alignment.center,
                  child: Text(
                    '$dayCounter',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isToday ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
                if (shift != null) ...[
                  const SizedBox(height: 2),
                  Icon(_shiftIcons[shift],
                      size: 12, color: _shiftColor(shift)),
                  Text(_shiftLabels[shift] ?? '',
                      style: TextStyle(
                          fontSize: 6,
                          fontWeight: FontWeight.bold,
                          color: _shiftColor(shift))),
                ],
              ],
            ),
          ),
        ));
        dayCounter++;
      }
      rows.add(Row(children: cells));
    }
    return rows;
  }

  String? _getShiftForDate(WorkScheduleData? ws, DateTime date) {
    if (ws == null || ws.cycle.isEmpty) return null;

    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Check vacations
    for (final v in ws.vacations) {
      if (dateStr.compareTo(v.startDate) >= 0 &&
          dateStr.compareTo(v.endDate) <= 0) {
        return 'vacation';
      }
    }

    final anchor = DateTime.parse(ws.anchorDate);
    final diff = date.difference(anchor).inDays;
    final cycleLen = ws.cycle.length;
    final index = ((diff % cycleLen) + cycleLen) % cycleLen;
    return ws.cycle[index];
  }

  // ---- Vacation ----
  void _showVacationDialog() {
    final titleCtrl = TextEditingController();
    String startDate = '';
    String endDate = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDState) {
          return AlertDialog(
            title: const Text('Запланировать отпуск'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Название (например, Отпуск в горах)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDState(() => startDate =
                              DateFormat('yyyy-MM-dd').format(picked));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withAlpha(60)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                            startDate.isEmpty ? 'Начало' : startDate,
                            style: TextStyle(
                                fontSize: 12,
                                color: startDate.isEmpty
                                    ? Colors.grey
                                    : null)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDState(() => endDate =
                              DateFormat('yyyy-MM-dd').format(picked));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withAlpha(60)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(endDate.isEmpty ? 'Конец' : endDate,
                            style: TextStyle(
                                fontSize: 12,
                                color: endDate.isEmpty
                                    ? Colors.grey
                                    : null)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty || startDate.isEmpty || endDate.isEmpty) {
                    return;
                  }
                  ref.read(workScheduleProvider.notifier).addVacation(Vacation(
                        id: const Uuid().v4(),
                        title: title,
                        startDate: startDate,
                        endDate: endDate,
                      ));
                  Navigator.pop(ctx);
                },
                child: const Text('Добавить'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _vacationTile(Vacation v) {
    final start = DateTime.tryParse(v.startDate);
    final end = DateTime.tryParse(v.endDate);
    final days = start != null && end != null
        ? end.difference(start).inDays + 1
        : 0;
    final dateFmt = DateFormat('d MMM', 'ru');
    final yearFmt = DateFormat('d MMM yyyy', 'ru');

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.pink.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.flight, size: 18, color: Colors.pink),
        ),
        title: Text(v.title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          start != null && end != null
              ? '${dateFmt.format(start)} — ${yearFmt.format(end)} ($days дн.)'
              : '${v.startDate} — ${v.endDate}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
          onPressed: () =>
              ref.read(workScheduleProvider.notifier).deleteVacation(v.id),
        ),
      ),
    );
  }

  // ---- Legend ----
  Widget _legend() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _shiftTypes.map((type) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _shiftColor(type).withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _shiftColor(type).withAlpha(60)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_shiftIcons[type], size: 14, color: _shiftColor(type)),
              const SizedBox(width: 4),
              Text(_shiftLabels[type] ?? type,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _shiftColor(type))),
            ],
          ),
        );
      }).toList(),
    );
  }
}
