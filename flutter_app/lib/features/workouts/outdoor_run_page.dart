import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../models/misc.dart';
import '../../state/providers.dart';

class OutdoorRunPage extends ConsumerStatefulWidget {
  const OutdoorRunPage({super.key});

  @override
  ConsumerState<OutdoorRunPage> createState() => _OutdoorRunPageState();
}

class _OutdoorRunPageState extends ConsumerState<OutdoorRunPage> {
  final MapController _mapCtrl = MapController();

  // GPS state
  StreamSubscription<Position>? _posSub;
  final List<LatLng> _routePoints = [];
  LatLng? _currentPos;
  bool _tracking = false;
  bool _paused = false;

  // Stats
  double _distanceMeters = 0;
  int _steps = 0;
  int _elapsedSeconds = 0;
  Timer? _timer;
  DateTime? _startTime;

  // Step estimation from GPS
  double _lastStepDistance = 0;
  static const _stepLength = 0.78; // average step length in meters

  // Calorie estimation: ~60 kcal per km (approximate for running)
  int get _calories => (_distanceMeters / 1000 * 60).round();
  double get _distanceKm => _distanceMeters / 1000;
  double get _paceMinPerKm =>
      _distanceKm > 0 ? (_elapsedSeconds / 60) / _distanceKm : 0;
  double get _speedKmH =>
      _elapsedSeconds > 0 ? _distanceKm / (_elapsedSeconds / 3600) : 0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Включите GPS для отслеживания бега')),
        );
      }
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Нужно разрешение на доступ к геолокации')),
        );
      }
      return;
    }
    // Get initial position
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _currentPos = LatLng(pos.latitude, pos.longitude);
        });
        _mapCtrl.move(_currentPos!, 16);
      }
    } catch (_) {}
  }

  void _startRun() {
    HapticFeedback.mediumImpact();
    setState(() {
      _tracking = true;
      _paused = false;
      _distanceMeters = 0;
      _steps = 0;
      _elapsedSeconds = 0;
      _lastStepDistance = 0;
      _routePoints.clear();
      _startTime = DateTime.now();
    });

    if (_currentPos != null) {
      _routePoints.add(_currentPos!);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused) {
        setState(() => _elapsedSeconds++);
      }
    });

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 meters
      ),
    ).listen(_onPosition);
  }

  void _onPosition(Position pos) {
    if (_paused) return;
    final newPoint = LatLng(pos.latitude, pos.longitude);

    setState(() {
      if (_routePoints.isNotEmpty) {
        final prev = _routePoints.last;
        final dist = const Distance().as(LengthUnit.Meter, prev, newPoint);
        if (dist > 2) {
          _distanceMeters += dist;
          _lastStepDistance += dist;
          // Estimate steps from distance
          while (_lastStepDistance >= _stepLength) {
            _steps++;
            _lastStepDistance -= _stepLength;
          }
        }
      }
      _routePoints.add(newPoint);
      _currentPos = newPoint;
    });

    _mapCtrl.move(newPoint, _mapCtrl.camera.zoom);
  }

  void _pauseRun() {
    HapticFeedback.lightImpact();
    setState(() => _paused = true);
  }

  void _resumeRun() {
    HapticFeedback.lightImpact();
    setState(() => _paused = false);
  }

  Future<void> _stopRun() async {
    HapticFeedback.heavyImpact();
    _posSub?.cancel();
    _timer?.cancel();
    setState(() {
      _tracking = false;
      _paused = false;
    });

    // Save the session
    final session = RunSession(
      id: const Uuid().v4(),
      startedAt: _startTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
      finishedAt: DateTime.now().toIso8601String(),
      distanceMeters: _distanceMeters,
      steps: _steps,
      caloriesBurned: _calories,
      durationSeconds: _elapsedSeconds,
      route: _routePoints.map((p) => [p.latitude, p.longitude]).toList(),
    );

    await ref.read(runSessionsProvider.notifier).add(session);

    if (mounted) {
      _showResultDialog(session);
    }
  }

  void _showResultDialog(RunSession session) {
    final pace = session.avgPaceMinPerKm;
    final paceMin = pace.floor();
    final paceSec = ((pace - paceMin) * 60).round();
    final dur = Duration(seconds: session.durationSeconds);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber),
            SizedBox(width: 8),
            Text('Пробежка завершена!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ResultRow(
              icon: Icons.straighten,
              label: 'Дистанция',
              value: '${session.distanceKm.toStringAsFixed(2)} км',
            ),
            _ResultRow(
              icon: Icons.timer_outlined,
              label: 'Время',
              value: _formatDuration(dur),
            ),
            _ResultRow(
              icon: Icons.speed,
              label: 'Средний темп',
              value: '$paceMin:${paceSec.toString().padLeft(2, '0')} мин/км',
            ),
            _ResultRow(
              icon: Icons.directions_walk,
              label: 'Шаги',
              value: '${session.steps}',
            ),
            _ResultRow(
              icon: Icons.local_fire_department,
              label: 'Калории',
              value: '${session.caloriesBurned} ккал',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}ч ${m}м ${s}с';
    return '${m}м ${s}с';
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _timer?.cancel();
    _mapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sessions = ref.watch(runSessionsProvider);
    final dur = Duration(seconds: _elapsedSeconds);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Бег на улице'),
        actions: [
          if (sessions.isNotEmpty)
            IconButton(
              tooltip: 'История',
              icon: const Icon(Icons.history),
              onPressed: () => _showHistory(context, sessions),
            ),
        ],
      ),
      body: Column(
        children: [
          // Map area
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _currentPos ?? const LatLng(53.9, 27.56),
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.vibesight.tracker',
                    ),
                    if (_routePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    if (_currentPos != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPos!,
                            width: 20,
                            height: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.primary
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Center on me button
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'center',
                    onPressed: () {
                      if (_currentPos != null) {
                        _mapCtrl.move(
                            _currentPos!, _mapCtrl.camera.zoom);
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),

          // Stats panel
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatTile(
                      icon: Icons.straighten,
                      value: _distanceKm.toStringAsFixed(2),
                      unit: 'км',
                    ),
                    _StatTile(
                      icon: Icons.timer_outlined,
                      value: _formatDuration(dur),
                      unit: '',
                    ),
                    _StatTile(
                      icon: Icons.speed,
                      value: _speedKmH.toStringAsFixed(1),
                      unit: 'км/ч',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatTile(
                      icon: Icons.directions_walk,
                      value: '$_steps',
                      unit: 'шагов',
                    ),
                    _StatTile(
                      icon: Icons.local_fire_department,
                      value: '$_calories',
                      unit: 'ккал',
                    ),
                    _StatTile(
                      icon: Icons.trending_up,
                      value: _paceMinPerKm > 0
                          ? '${_paceMinPerKm.floor()}:${((_paceMinPerKm % 1) * 60).round().toString().padLeft(2, '0')}'
                          : '--',
                      unit: 'мин/км',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Control buttons
                if (!_tracking)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _startRun,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Начать пробежку'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _paused
                            ? FilledButton.icon(
                                onPressed: _resumeRun,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Продолжить'),
                              )
                            : OutlinedButton.icon(
                                onPressed: _pauseRun,
                                icon: const Icon(Icons.pause),
                                label: const Text('Пауза'),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _stopRun,
                          icon: const Icon(Icons.stop),
                          label: const Text('Завершить'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, List<RunSession> sessions) {
    final sorted = [...sessions]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm', 'ru');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 8),
                  Text('История пробежек (${sorted.length})',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            if (sorted.length >= 2) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 120,
                  child: _HistoryChart(sessions: sorted),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final s = sorted[i];
                  DateTime? dt;
                  try {
                    dt = DateTime.parse(s.startedAt);
                  } catch (_) {}
                  final pace = s.avgPaceMinPerKm;
                  final pMin = pace.floor();
                  final pSec = ((pace - pMin) * 60).round();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(Icons.directions_run,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(
                        '${s.distanceKm.toStringAsFixed(2)} км — ${_formatDuration(Duration(seconds: s.durationSeconds))}'),
                    subtitle: Text(
                      '${dt != null ? dateFmt.format(dt) : s.startedAt} • '
                      '${s.steps} шагов • ${s.caloriesBurned} ккал • '
                      '$pMin:${pSec.toString().padLeft(2, '0')} мин/км',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.map_outlined, size: 20),
                      tooltip: 'Маршрут',
                      onPressed: s.route.length >= 2
                          ? () => _showRouteDialog(context, s)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRouteDialog(BuildContext context, RunSession session) {
    final points = session.route
        .map((p) => LatLng(p[0], p[1]))
        .toList();
    if (points.isEmpty) return;
    final center = points[points.length ~/ 2];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          height: 400,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Маршрут — ${session.distanceKm.toStringAsFixed(2)} км',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.vibesight.tracker',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          strokeWidth: 4,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: points.first,
                          width: 16,
                          height: 16,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Marker(
                          point: points.last,
                          width: 16,
                          height: 16,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.unit,
  });
  final IconData icon;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (unit.isNotEmpty)
          Text(unit,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.sessions});
  final List<RunSession> sessions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recent = sessions.take(10).toList().reversed.toList();
    final maxKm = recent.fold<double>(
        0, (m, s) => math.max(m, s.distanceKm));
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxKm <= 0 ? 1 : maxKm * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= recent.length) {
                  return const SizedBox.shrink();
                }
                DateTime? dt;
                try {
                  dt = DateTime.parse(recent[i].startedAt);
                } catch (_) {}
                return Text(
                  dt != null ? DateFormat('d/MM').format(dt) : '',
                  style: const TextStyle(fontSize: 8),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < recent.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: recent[i].distanceKm,
                  color: scheme.primary,
                  width: 14,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
              showingTooltipIndicators: [0],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(4),
            tooltipMargin: 4,
            getTooltipItem: (group, groupIdx, rod, rodIdx) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)} км',
                const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}
