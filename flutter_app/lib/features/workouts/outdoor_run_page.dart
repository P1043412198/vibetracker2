import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../models/misc.dart';
import '../../state/providers.dart';

/// Outdoor running screen with GPS tracking, live stats and route planning.
///
/// The screen has four explicit phases:
///   - [_Phase.idle]      — just opened, no run in progress, no plan drawn.
///   - [_Phase.planning]  — user taps the map to drop waypoints for a planned
///                          route. The total planned distance is shown live.
///   - [_Phase.running]   — GPS-tracked run is active.
///   - [_Phase.paused]    — run paused but not finished.
///
/// Live stats (distance, time, pace, steps, calories) are **only** shown
/// once the user has actually pressed «Начать пробежку». Before that, the
/// stat panel renders placeholders so the user does not think the timer is
/// already counting (#15 follow-up bug report).
enum _Phase { idle, planning, running, paused }

class OutdoorRunPage extends ConsumerStatefulWidget {
  const OutdoorRunPage({super.key});

  @override
  ConsumerState<OutdoorRunPage> createState() => _OutdoorRunPageState();
}

class _OutdoorRunPageState extends ConsumerState<OutdoorRunPage> {
  final MapController _mapCtrl = MapController();

  _Phase _phase = _Phase.idle;

  // GPS state
  StreamSubscription<Position>? _posSub;
  final List<LatLng> _routePoints = [];
  LatLng? _currentPos;

  // Planned route
  final List<LatLng> _plannedWaypoints = [];
  List<LatLng> _plannedPath = [];
  double _plannedDistanceMeters = 0;
  bool _snappingRoute = false;

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

  bool get _hasStarted =>
      _phase == _Phase.running || _phase == _Phase.paused;
  bool get _isPlanning => _phase == _Phase.planning;
  bool get _hasPlan => _plannedWaypoints.length >= 2;

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
    // Get initial position (used to centre the map only — NOT counted as
    // run start, see #15 follow-up).
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

  // ─────────────────── Planning ───────────────────

  void _enterPlanning() {
    HapticFeedback.selectionClick();
    setState(() {
      _phase = _Phase.planning;
    });
  }

  void _exitPlanning() {
    setState(() {
      _phase = _Phase.idle;
    });
  }

  void _onPlanningTap(LatLng point) {
    if (!_isPlanning) return;
    HapticFeedback.lightImpact();
    setState(() {
      _plannedWaypoints.add(point);
      _recomputePlannedPathStraight();
    });
  }

  void _undoLastWaypoint() {
    if (_plannedWaypoints.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _plannedWaypoints.removeLast();
      _recomputePlannedPathStraight();
    });
  }

  void _clearPlan() {
    HapticFeedback.mediumImpact();
    setState(() {
      _plannedWaypoints.clear();
      _plannedPath = [];
      _plannedDistanceMeters = 0;
    });
  }

  void _recomputePlannedPathStraight() {
    _plannedPath = List.of(_plannedWaypoints);
    _plannedDistanceMeters = _polylineLengthMeters(_plannedPath);
  }

  double _polylineLengthMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    const dist = Distance();
    double total = 0;
    for (var i = 1; i < points.length; i++) {
      total += dist.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return total;
  }

  /// Optional: snap-to-roads via the public OSRM demo endpoint
  /// (router.project-osrm.org). Falls back to straight lines silently if
  /// the network is unavailable or the request fails — the run feature
  /// itself never depends on this. Profile: `foot`.
  Future<void> _snapPlannedRouteToRoads() async {
    if (_plannedWaypoints.length < 2) return;
    setState(() => _snappingRoute = true);
    try {
      final coords = _plannedWaypoints
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final uri = Uri.parse(
          'https://router.project-osrm.org/route/v1/foot/$coords?overview=full&geometries=geojson');
      final resp = await http
          .get(uri, headers: {'User-Agent': 'com.vibesight.tracker'})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final routes = body['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geom =
              (routes.first as Map)['geometry'] as Map<String, dynamic>?;
          final raw = geom?['coordinates'] as List?;
          if (raw != null && raw.isNotEmpty) {
            final snapped = raw
                .whereType<List>()
                .map((c) => LatLng(
                      (c[1] as num).toDouble(),
                      (c[0] as num).toDouble(),
                    ))
                .toList();
            final distance = (routes.first as Map)['distance'];
            if (mounted) {
              setState(() {
                _plannedPath = snapped;
                _plannedDistanceMeters = distance is num
                    ? distance.toDouble()
                    : _polylineLengthMeters(snapped);
              });
            }
            return;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Не удалось проложить по дорогам — '
                  'используются прямые линии.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Нет связи с сервером маршрутов — '
                  'используются прямые линии.')),
        );
      }
    } finally {
      if (mounted) setState(() => _snappingRoute = false);
    }
  }

  void _confirmPlan() {
    HapticFeedback.lightImpact();
    setState(() {
      _phase = _Phase.idle;
    });
  }

  // ─────────────────── Run lifecycle ───────────────────

  void _startRun() {
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _Phase.running;
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
      if (_phase == _Phase.running) {
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
    if (_phase != _Phase.running) return;
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
    setState(() => _phase = _Phase.paused);
  }

  void _resumeRun() {
    HapticFeedback.lightImpact();
    setState(() => _phase = _Phase.running);
  }

  Future<void> _stopRun() async {
    HapticFeedback.heavyImpact();
    _posSub?.cancel();
    _posSub = null;
    _timer?.cancel();
    _timer = null;
    final stoppedAt = DateTime.now();
    final session = RunSession(
      id: const Uuid().v4(),
      startedAt: _startTime?.toIso8601String() ?? stoppedAt.toIso8601String(),
      finishedAt: stoppedAt.toIso8601String(),
      distanceMeters: _distanceMeters,
      steps: _steps,
      caloriesBurned: _calories,
      durationSeconds: _elapsedSeconds,
      route: _routePoints.map((p) => [p.latitude, p.longitude]).toList(),
    );

    setState(() {
      _phase = _Phase.idle;
    });

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
            if (_plannedDistanceMeters > 0)
              _ResultRow(
                icon: Icons.flag_outlined,
                label: 'Запланировано',
                value: '${(_plannedDistanceMeters / 1000).toStringAsFixed(2)} км',
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
    if (h > 0) return '$hч $mм $sс';
    return '$mм $sс';
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
          if (sessions.isNotEmpty && !_hasStarted)
            IconButton(
              tooltip: 'История',
              icon: const Icon(Icons.history),
              onPressed: () => _showHistory(context, sessions),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isPlanning) _PlanningBanner(
            waypoints: _plannedWaypoints.length,
            distanceMeters: _plannedDistanceMeters,
            snapping: _snappingRoute,
            onUndo: _plannedWaypoints.isEmpty ? null : _undoLastWaypoint,
            onClear: _plannedWaypoints.isEmpty ? null : _clearPlan,
            onSnap: _plannedWaypoints.length >= 2 && !_snappingRoute
                ? _snapPlannedRouteToRoads
                : null,
            onDone: _plannedWaypoints.length >= 2 ? _confirmPlan : null,
            onCancel: _exitPlanning,
          ),
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
                    onTap: _isPlanning
                        ? (_, point) => _onPlanningTap(point)
                        : null,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.vibesight.tracker',
                    ),
                    if (_plannedPath.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _plannedPath,
                            strokeWidth: 5,
                            color: scheme.tertiary
                                .withValues(alpha: 0.85),
                            pattern: StrokePattern.dashed(
                                segments: const [10, 6]),
                          ),
                        ],
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
                    if (_plannedWaypoints.isNotEmpty)
                      MarkerLayer(
                        markers: [
                          for (var i = 0;
                              i < _plannedWaypoints.length;
                              i++)
                            Marker(
                              point: _plannedWaypoints[i],
                              width: 24,
                              height: 24,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: scheme.tertiary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
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
                _PhaseChip(
                  phase: _phase,
                  plannedDistanceMeters: _plannedDistanceMeters,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatTile(
                      icon: Icons.straighten,
                      value: _hasStarted
                          ? _distanceKm.toStringAsFixed(2)
                          : '—',
                      unit: 'км',
                    ),
                    _StatTile(
                      icon: Icons.timer_outlined,
                      value: _hasStarted ? _formatDuration(dur) : '—',
                      unit: '',
                    ),
                    _StatTile(
                      icon: Icons.speed,
                      value: _hasStarted
                          ? _speedKmH.toStringAsFixed(1)
                          : '—',
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
                      value: _hasStarted ? '$_steps' : '—',
                      unit: 'шагов',
                    ),
                    _StatTile(
                      icon: Icons.local_fire_department,
                      value: _hasStarted ? '$_calories' : '—',
                      unit: 'ккал',
                    ),
                    _StatTile(
                      icon: Icons.trending_up,
                      value: _hasStarted && _paceMinPerKm > 0
                          ? '${_paceMinPerKm.floor()}:${((_paceMinPerKm % 1) * 60).round().toString().padLeft(2, '0')}'
                          : '—',
                      unit: 'мин/км',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Control buttons
                _ControlRow(
                  phase: _phase,
                  hasPlan: _hasPlan,
                  onPlan: !_hasStarted ? _enterPlanning : null,
                  onClearPlan: !_hasStarted && _hasPlan ? _clearPlan : null,
                  onStart: !_hasStarted ? _startRun : null,
                  onPause: _phase == _Phase.running ? _pauseRun : null,
                  onResume: _phase == _Phase.paused ? _resumeRun : null,
                  onStop: _hasStarted ? _stopRun : null,
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
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (_, scroll) {
            return ListView.builder(
              controller: scroll,
              itemCount: sorted.length + 2,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.history),
                        const SizedBox(width: 8),
                        Text('История пробежек',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge),
                        const Spacer(),
                        Text('${sorted.length}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium),
                      ],
                    ),
                  );
                }
                if (i == 1) {
                  return _RunHistoryChart(sessions: sorted);
                }
                final s = sorted[i - 2];
                final pace = s.avgPaceMinPerKm;
                final paceMin = pace.floor();
                final paceSec = ((pace - paceMin) * 60).round();
                final dur = Duration(seconds: s.durationSeconds);
                return ListTile(
                  leading: const Icon(Icons.directions_run),
                  title: Text(
                      '${s.distanceKm.toStringAsFixed(2)} км · '
                      '${_formatDuration(dur)}'),
                  subtitle: Text(
                      '${dateFmt.format(DateTime.parse(s.startedAt))} · '
                      'темп $paceMin:${paceSec.toString().padLeft(2, '0')} мин/км · '
                      '${s.caloriesBurned} ккал'),
                  trailing: s.route.length >= 2
                      ? IconButton(
                          icon: const Icon(Icons.map_outlined),
                          tooltip: 'Маршрут',
                          onPressed: () =>
                              _showRouteDialog(context, s),
                        )
                      : null,
                  onLongPress: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: const Text('Удалить пробежку?'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dctx).pop(false),
                            child: const Text('Отмена'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () =>
                                Navigator.of(dctx).pop(true),
                            child: const Text('Удалить'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(runSessionsProvider.notifier)
                          .remove(s.id);
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showRouteDialog(BuildContext context, RunSession session) {
    final points = session.route
        .map((p) => LatLng(p[0], p[1]))
        .toList(growable: false);
    if (points.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 420,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(points),
                    padding: const EdgeInsets.all(24),
                  ),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.phase, required this.plannedDistanceMeters});
  final _Phase phase;
  final double plannedDistanceMeters;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (phase) {
      _Phase.idle => (
          plannedDistanceMeters > 0
              ? 'Готов · план ${(plannedDistanceMeters / 1000).toStringAsFixed(2)} км'
              : 'Готов — нажми «Начать»',
          Icons.play_circle_outline,
          scheme.primary,
        ),
      _Phase.planning => (
          'Прокладывание маршрута — тапай по карте',
          Icons.edit_location_alt_outlined,
          scheme.tertiary,
        ),
      _Phase.running => (
          'Идёт пробежка',
          Icons.directions_run,
          scheme.primary,
        ),
      _Phase.paused => (
          'Пауза',
          Icons.pause_circle_outline,
          scheme.error,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanningBanner extends StatelessWidget {
  const _PlanningBanner({
    required this.waypoints,
    required this.distanceMeters,
    required this.snapping,
    required this.onUndo,
    required this.onClear,
    required this.onSnap,
    required this.onDone,
    required this.onCancel,
  });

  final int waypoints;
  final double distanceMeters;
  final bool snapping;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;
  final VoidCallback? onSnap;
  final VoidCallback? onDone;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      color: scheme.tertiaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_location_alt_outlined,
                  size: 18, color: scheme.onTertiaryContainer),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  waypoints == 0
                      ? 'Тапни по карте, чтобы поставить точки маршрута.'
                      : 'Точек: $waypoints · ${(distanceMeters / 1000).toStringAsFixed(2)} км',
                  style: TextStyle(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Отмена',
                icon: const Icon(Icons.close),
                onPressed: onCancel,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Отменить точку'),
                onPressed: onUndo,
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Очистить'),
                onPressed: onClear,
              ),
              TextButton.icon(
                icon: snapping
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.alt_route, size: 16),
                label: const Text('По дорогам'),
                onPressed: onSnap,
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Готово'),
                onPressed: onDone,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.phase,
    required this.hasPlan,
    required this.onPlan,
    required this.onClearPlan,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final _Phase phase;
  final bool hasPlan;
  final VoidCallback? onPlan;
  final VoidCallback? onClearPlan;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    if (phase == _Phase.planning) {
      return const SizedBox.shrink();
    }
    if (phase == _Phase.idle) {
      return Column(
        children: [
          if (!hasPlan)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPlan,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Проложить маршрут'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPlan,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Изменить маршрут'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Удалить маршрут',
                  onPressed: onClearPlan,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Начать пробежку'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    }
    // running or paused
    return Row(
      children: [
        Expanded(
          child: phase == _Phase.paused
              ? FilledButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Продолжить'),
                )
              : OutlinedButton.icon(
                  onPressed: onPause,
                  icon: const Icon(Icons.pause),
                  label: const Text('Пауза'),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop),
            label: const Text('Завершить'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ),
      ],
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
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
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
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RunHistoryChart extends StatelessWidget {
  const _RunHistoryChart({required this.sessions});
  final List<RunSession> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    final asc = [...sessions]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final last = asc.take(20).toList();
    final spots = <FlSpot>[];
    double maxY = 0;
    for (var i = 0; i < last.length; i++) {
      final km = last[i].distanceKm;
      spots.add(FlSpot(i.toDouble(), km));
      maxY = math.max(maxY, km);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        height: 140,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY <= 0 ? 1 : maxY * 1.2,
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Theme.of(context).colorScheme.primary,
                belowBarData: BarAreaData(
                  show: true,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                ),
                dotData: const FlDotData(show: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
