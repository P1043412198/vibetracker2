import '../../widgets/app_back_button.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/misc.dart';
import '../../state/providers.dart';

/// Full-page Pomodoro timer — port of `PomodoroWidget.tsx`.
///
/// Circular progress ring, work/break toggle, configurable durations,
/// session counter and sound notification on completion.
class PomodoroPage extends ConsumerStatefulWidget {
  const PomodoroPage({super.key});

  @override
  ConsumerState<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends ConsumerState<PomodoroPage> {
  Timer? _timer;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _startTimerIfRunning();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerIfRunning() {
    final pomo = ref.read(pomodoroProvider);
    if (pomo.isRunning) _ensureTimer();
  }

  void _ensureTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(pomodoroProvider.notifier).tick();
    });
  }

  void _toggleRunning() {
    ref.read(pomodoroProvider.notifier).toggleRunning();
    final pomo = ref.read(pomodoroProvider);
    if (pomo.isRunning) {
      _ensureTimer();
    } else {
      _timer?.cancel();
    }
  }

  void _reset() {
    _timer?.cancel();
    ref.read(pomodoroProvider.notifier).reset();
  }

  void _switchType(String type) {
    _timer?.cancel();
    ref.read(pomodoroProvider.notifier).startType(type);
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pomo = ref.watch(pomodoroProvider);
    final scheme = Theme.of(context).colorScheme;
    final progress =
        pomo.totalTime > 0 ? pomo.timeLeft / pomo.totalTime : 0.0;
    final isWork = pomo.type == 'work';
    final accentColor = isWork ? scheme.primary : const Color(0xFF22C55E);

    // Stop timer when done
    if (pomo.timeLeft <= 0 && !pomo.isRunning) {
      _timer?.cancel();
    }

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Pomodoro'),
        actions: [
          IconButton(
            icon: Icon(_showSettings
                ? Icons.close
                : Icons.settings_outlined),
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ],
      ),
      body: SafeArea(
        child: _showSettings
            ? _SettingsPanel(
                settings: pomo.settings,
                onDone: (s) {
                  ref.read(pomodoroProvider.notifier).updateSettings(s);
                  setState(() => _showSettings = false);
                },
              )
            : Column(
                children: [
                  const SizedBox(height: 16),
                  // Type selector
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _TypeChip(
                            label: 'Работа',
                            selected: pomo.type == 'work',
                            color: scheme.primary,
                            onTap: () => _switchType('work'),
                          ),
                          _TypeChip(
                            label: 'Перерыв',
                            selected: pomo.type == 'shortBreak',
                            color: const Color(0xFF22C55E),
                            onTap: () => _switchType('shortBreak'),
                          ),
                          _TypeChip(
                            label: 'Длинный',
                            selected: pomo.type == 'longBreak',
                            color: const Color(0xFFF59E0B),
                            onTap: () => _switchType('longBreak'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Timer ring
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 240,
                        height: 240,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(240, 240),
                              painter: _RingPainter(
                                progress: progress,
                                color: accentColor,
                                bg: scheme.surfaceContainerHighest,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(pomo.timeLeft),
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                    color: scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  isWork ? 'Фокус' : 'Отдых',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Controls
                  Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.outlined(
                          icon: const Icon(Icons.refresh),
                          onPressed: _reset,
                          tooltip: 'Сбросить',
                        ),
                        const SizedBox(width: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: Icon(pomo.isRunning
                              ? Icons.pause
                              : Icons.play_arrow),
                          label: Text(pomo.isRunning ? 'Пауза' : 'Старт'),
                          onPressed: _toggleRunning,
                        ),
                        const SizedBox(width: 20),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${pomo.sessionsCompleted}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              'Сессий',
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.bg,
  });
  final double progress;
  final Color color;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({
    required this.settings,
    required this.onDone,
  });
  final PomodoroSettings settings;
  final ValueChanged<PomodoroSettings> onDone;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  late int _work;
  late int _short;
  late int _long;
  late bool _sound;

  @override
  void initState() {
    super.initState();
    _work = widget.settings.workTime;
    _short = widget.settings.shortBreakTime;
    _long = widget.settings.longBreakTime;
    _sound = widget.settings.soundEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Настройки таймера',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),
        _NumberField(
          label: 'Работа (мин)',
          value: _work,
          onChanged: (v) => setState(() => _work = v),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Короткий перерыв (мин)',
          value: _short,
          onChanged: (v) => setState(() => _short = v),
        ),
        const SizedBox(height: 16),
        _NumberField(
          label: 'Длинный перерыв (мин)',
          value: _long,
          onChanged: (v) => setState(() => _long = v),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Звуковой сигнал'),
          secondary: Icon(_sound ? Icons.notifications : Icons.notifications_off),
          value: _sound,
          onChanged: (v) => setState(() => _sound = v),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () {
            widget.onDone(PomodoroSettings(
              workTime: _work.clamp(1, 120),
              shortBreakTime: _short.clamp(1, 60),
              longBreakTime: _long.clamp(1, 60),
              soundEnabled: _sound,
            ));
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: TextInputType.number,
      controller: TextEditingController(text: value.toString()),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: (v) {
        final parsed = int.tryParse(v);
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}
