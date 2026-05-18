import '../../widgets/app_back_button.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/misc.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';

/// Water intake tracker — port of `WaterWidget.tsx`.
///
/// Cup/bottle visualisation with animated fill level, configurable daily goal
/// and increment, today's log list.
class WaterPage extends ConsumerStatefulWidget {
  const WaterPage({super.key});

  @override
  ConsumerState<WaterPage> createState() => _WaterPageState();
}

class _WaterPageState extends ConsumerState<WaterPage>
    with SingleTickerProviderStateMixin {
  bool _showSettings = false;
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  void _addWater() {
    final increment = ref.read(waterIncrementProvider);
    ref.read(waterLogsProvider.notifier).add(WaterLog(
          id: const Uuid().v4(),
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          timestamp: DateTime.now().toIso8601String(),
          amount: increment,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(waterLogsProvider);
    final goal = ref.watch(waterGoalProvider);
    final increment = ref.watch(waterIncrementProvider);
    final vizMode = ref.watch(waterVisualizationProvider);
    final scheme = Theme.of(context).colorScheme;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayLogs = logs.where((l) => l.date == todayStr).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final total = todayLogs.fold<num>(0, (s, l) => s + l.amount);
    final progress = goal > 0 ? (total / goal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Водный баланс'),
        actions: [
          IconButton(
            icon: Icon(_showSettings
                ? Icons.close
                : Icons.settings_outlined),
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
        ],
      ),
      body: _showSettings
          ? _SettingsView(
              goal: goal,
              increment: increment,
              vizMode: vizMode,
              onGoalChanged: (v) =>
                  ref.read(waterGoalProvider.notifier).set(v),
              onIncrementChanged: (v) =>
                  ref.read(waterIncrementProvider.notifier).set(v),
              onVizChanged: (v) =>
                  ref.read(waterVisualizationProvider.notifier).set(v),
              onDone: () => setState(() => _showSettings = false),
            )
          : Column(
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.water_drop,
                              color: const Color(0xFF3B82F6), size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '${total.toInt()} / $goal мл',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: progress >= 1.0
                              ? const Color(0xFF22C55E)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Visualization
                Expanded(
                  flex: 3,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _waveCtrl,
                      builder: (context, _) => CustomPaint(
                        size: vizMode == 'glass'
                            ? const Size(140, 180)
                            : const Size(110, 220),
                        painter: _VesselPainter(
                          mode: vizMode,
                          fillPercent: progress.toDouble(),
                          wavePhase: _waveCtrl.value * 2 * math.pi,
                        ),
                      ),
                    ),
                  ),
                ),
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.toDouble(),
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF3B82F6)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                onPressed: () {
                                  final next = (increment - 50).clamp(50, 2000);
                                  ref
                                      .read(waterIncrementProvider.notifier)
                                      .set(next);
                                },
                              ),
                              Expanded(
                                child: Text(
                                  '$increment мл',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: () {
                                  ref
                                      .read(waterIncrementProvider.notifier)
                                      .set(increment + 50);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FloatingActionButton(
                        heroTag: 'water_add',
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        onPressed: _addWater,
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Today's logs
                Expanded(
                  flex: 2,
                  child: todayLogs.isEmpty
                      ? Center(
                          child: Text('Логи воды отсутствуют',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: todayLogs.length,
                          itemBuilder: (_, i) {
                            final log = todayLogs[i];
                            final time = DateTime.tryParse(log.timestamp);
                            final timeStr = time != null
                                ? DateFormat.Hm().format(time)
                                : '';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                leading: const CircleAvatar(
                                  radius: 4,
                                  backgroundColor: Color(0xFF3B82F6),
                                ),
                                title: Text('${log.amount} мл',
                                    style: const TextStyle(fontSize: 13)),
                                subtitle: Text(timeStr,
                                    style: const TextStyle(fontSize: 11)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  onPressed: () => ref
                                      .read(waterLogsProvider.notifier)
                                      .remove(log.id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}

/// Custom painter that renders a glass or bottle shape with animated water.
class _VesselPainter extends CustomPainter {
  _VesselPainter({
    required this.mode,
    required this.fillPercent,
    required this.wavePhase,
  });
  final String mode;
  final double fillPercent;
  final double wavePhase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Vessel outline
    final vesselPaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final vesselPath = Path();
    if (mode == 'bottle') {
      // Bottle shape
      const neckW = 24.0;
      const neckH = 20.0;
      final bodyTop = neckH;
      vesselPath.moveTo(w / 2 - neckW / 2, 0);
      vesselPath.lineTo(w / 2 - neckW / 2, neckH);
      vesselPath.quadraticBezierTo(0, bodyTop + 10, 4, h - 16);
      vesselPath.quadraticBezierTo(4, h, 20, h);
      vesselPath.lineTo(w - 20, h);
      vesselPath.quadraticBezierTo(w - 4, h, w - 4, h - 16);
      vesselPath.quadraticBezierTo(w, bodyTop + 10, w / 2 + neckW / 2, neckH);
      vesselPath.lineTo(w / 2 + neckW / 2, 0);
    } else {
      // Glass shape — wider at top
      vesselPath.moveTo(6, 0);
      vesselPath.lineTo(0, h - 12);
      vesselPath.quadraticBezierTo(0, h, 12, h);
      vesselPath.lineTo(w - 12, h);
      vesselPath.quadraticBezierTo(w, h, w, h - 12);
      vesselPath.lineTo(w - 6, 0);
    }

    canvas.drawPath(vesselPath, vesselPaint);

    // Water fill
    if (fillPercent <= 0) return;

    final waterH = h * fillPercent;
    final waterTop = h - waterH;

    final waterPaint = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final waterPath = Path();
    // Wave
    const waveAmp = 4.0;
    waterPath.moveTo(0, waterTop);
    for (double x = 0; x <= w; x += 1) {
      final y = waterTop +
          math.sin(wavePhase + x / w * 2 * math.pi) * waveAmp;
      waterPath.lineTo(x, y);
    }
    waterPath.lineTo(w, h);
    waterPath.lineTo(0, h);
    waterPath.close();

    canvas.save();
    canvas.clipPath(vesselPath);
    canvas.drawPath(waterPath, waterPaint);
    canvas.restore();

    // Shine
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(
        Offset(w * 0.8, 12), Offset(w * 0.82, h * 0.6), shinePaint);
  }

  @override
  bool shouldRepaint(_VesselPainter old) =>
      old.fillPercent != fillPercent || old.wavePhase != wavePhase;
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({
    required this.goal,
    required this.increment,
    required this.vizMode,
    required this.onGoalChanged,
    required this.onIncrementChanged,
    required this.onVizChanged,
    required this.onDone,
  });
  final int goal;
  final int increment;
  final String vizMode;
  final ValueChanged<int> onGoalChanged;
  final ValueChanged<int> onIncrementChanged;
  final ValueChanged<String> onVizChanged;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Настройки', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),
        TextField(
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: goal.toString()),
          decoration: InputDecoration(
            labelText: 'Цель на день (мл)',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0) onGoalChanged(n);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: increment.toString()),
          decoration: InputDecoration(
            labelText: 'Шаг добавления (мл)',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0) onIncrementChanged(n);
          },
        ),
        const SizedBox(height: 20),
        Text('Визуализация',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(
          children: [
            _VizOption(
                label: 'Стакан',
                value: 'glass',
                current: vizMode,
                onTap: onVizChanged),
            const SizedBox(width: 12),
            _VizOption(
                label: 'Бутылка',
                value: 'bottle',
                current: vizMode,
                onTap: onVizChanged),
          ],
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: onDone,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}

class _VizOption extends StatelessWidget {
  const _VizOption({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor:
              sel ? const Color(0xFF3B82F6) : scheme.surface,
          side: BorderSide(
              color: sel ? const Color(0xFF3B82F6) : scheme.outline),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => onTap(value),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : scheme.onSurface,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
