import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/misc.dart';
import '../../state/providers.dart';

/// Phase 4.5: live pose-tracking workout screen.
///
/// Equivalent of `src/components/CameraTracker.tsx`. Uses ML Kit's on-device
/// Pose Detection (no network) and counts reps via joint angles, mirroring
/// the React thresholds 1:1.
enum CameraExercise { squats, pushups, pullups, benchpress, abs }

class WorkoutCameraPage extends ConsumerStatefulWidget {
  const WorkoutCameraPage({super.key});

  @override
  ConsumerState<WorkoutCameraPage> createState() => _WorkoutCameraPageState();
}

class _WorkoutCameraPageState extends ConsumerState<WorkoutCameraPage>
    with WidgetsBindingObserver {
  CameraController? _cam;
  CameraDescription? _camDesc;
  PoseDetector? _detector;
  Pose? _pose;
  Size? _poseImageSize;
  int _landmarkCount = 0;
  bool _busy = false;
  bool _starting = true;
  String? _error;
  CameraExercise _exercise = CameraExercise.squats;
  int _count = 0;
  bool _down = false;
  double _angle = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detector = PoseDetector(options: PoseDetectorOptions());
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _cam;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _stopStream();
    } else if (state == AppLifecycleState.resumed) {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    final granted = await Permission.camera.request();
    if (!granted.isGranted) {
      setState(() {
        _error = 'Доступ к камере запрещён.';
        _starting = false;
      });
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'Камера не найдена.';
          _starting = false;
        });
        return;
      }
      final desc = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camDesc = desc;
      final controller = CameraController(
        desc,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _cam = controller;
      await controller.startImageStream(_onFrame);
      setState(() => _starting = false);
    } catch (e) {
      setState(() {
        _error = 'Не удалось запустить камеру: $e';
        _starting = false;
      });
    }
  }

  Future<void> _stopStream() async {
    final c = _cam;
    if (c != null && c.value.isStreamingImages) {
      try {
        await c.stopImageStream();
      } catch (_) {}
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_busy || _detector == null || _camDesc == null) return;
    _busy = true;
    try {
      final input = _toInputImage(img, _camDesc!);
      if (input == null) return;
      final poses = await _detector!.processImage(input);
      if (!mounted) return;
      if (poses.isNotEmpty) {
        final p = poses.first;
        _pose = p;
        _poseImageSize = Size(img.width.toDouble(), img.height.toDouble());
        _landmarkCount = p.landmarks.length;
        _evaluate(p);
        if (mounted) setState(() {});
      } else if (_pose != null) {
        _pose = null;
        _landmarkCount = 0;
        if (mounted) setState(() {});
      }
    } catch (_) {
      // swallow per-frame errors
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage img, CameraDescription desc) {
    final rotation =
        InputImageRotationValue.fromRawValue(desc.sensorOrientation);
    final fmt = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormatValue.fromRawValue(img.format.raw);
    if (rotation == null || fmt == null) return null;
    if (img.planes.isEmpty) return null;
    // ML Kit on Android needs a contiguous NV21 buffer (Y + interleaved VU).
    // Many devices return separate planes for camera streams, so we
    // concatenate all plane bytes here. Bug fix for "silhouette doesn't draw,
    // reps not counted" — on some devices passing only plane[0].bytes makes
    // the detector silently return zero poses.
    final bytes = Platform.isAndroid
        ? _concatPlanes(img.planes)
        : img.planes.first.bytes;
    final bytesPerRow = img.planes.first.bytesPerRow;
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(img.width.toDouble(), img.height.toDouble()),
        rotation: rotation,
        format: fmt,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  Uint8List _concatPlanes(List<Plane> planes) {
    if (planes.length == 1) return planes.first.bytes;
    var total = 0;
    for (final p in planes) {
      total += p.bytes.length;
    }
    final out = Uint8List(total);
    var offset = 0;
    for (final p in planes) {
      out.setRange(offset, offset + p.bytes.length, p.bytes);
      offset += p.bytes.length;
    }
    return out;
  }

  void _evaluate(Pose pose) {
    final lm = pose.landmarks;
    PoseLandmark? get(PoseLandmarkType t) => lm[t];
    double? angle;
    double down = 0, up = 0;
    switch (_exercise) {
      case CameraExercise.squats:
        final hip = get(PoseLandmarkType.rightHip);
        final knee = get(PoseLandmarkType.rightKnee);
        final ankle = get(PoseLandmarkType.rightAnkle);
        if (hip != null && knee != null && ankle != null) {
          angle = _angleAt(knee, hip, ankle);
        }
        down = 100;
        up = 160;
        break;
      case CameraExercise.pushups:
      case CameraExercise.pullups:
      case CameraExercise.benchpress:
        final shoulder = get(PoseLandmarkType.rightShoulder);
        final elbow = get(PoseLandmarkType.rightElbow);
        final wrist = get(PoseLandmarkType.rightWrist);
        if (shoulder != null && elbow != null && wrist != null) {
          angle = _angleAt(elbow, shoulder, wrist);
        }
        down = 90;
        up = 160;
        break;
      case CameraExercise.abs:
        final shoulder = get(PoseLandmarkType.rightShoulder);
        final hip = get(PoseLandmarkType.rightHip);
        final knee = get(PoseLandmarkType.rightKnee);
        if (shoulder != null && hip != null && knee != null) {
          angle = _angleAt(hip, shoulder, knee);
        }
        down = 90;
        up = 130;
        break;
    }
    if (angle == null) return;
    _angle = angle;
    if (angle < down && !_down) {
      _down = true;
      HapticFeedback.lightImpact();
    } else if (angle > up && _down) {
      _down = false;
      _count += 1;
      HapticFeedback.mediumImpact();
    }
  }

  double _angleAt(PoseLandmark vertex, PoseLandmark a, PoseLandmark c) {
    final r = math.atan2(c.y - vertex.y, c.x - vertex.x) -
        math.atan2(a.y - vertex.y, a.x - vertex.x);
    var deg = (r * 180 / math.pi).abs();
    if (deg > 180) deg = 360 - deg;
    return deg;
  }

  Future<void> _saveSet() async {
    if (_count <= 0) return;
    final exercises = ref
        .read(workoutNodesProvider)
        .where((n) => n.type == WorkoutNodeType.exercise)
        .toList();
    final selected = await showModalBottomSheet<WorkoutNode?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text(
                  'Создать новое упражнение из текущей сессии'),
              onTap: () => Navigator.pop<WorkoutNode?>(ctx, null),
            ),
            const Divider(height: 0),
            for (final e in exercises)
              ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(e.name),
                onTap: () => Navigator.pop<WorkoutNode>(ctx, e),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    String exerciseId;
    if (selected == null) {
      final node = WorkoutNode(
        id: const Uuid().v4(),
        parentId: null,
        name: '${_exerciseLabel(_exercise)} (камера)',
        type: WorkoutNodeType.exercise,
        metrics: const [WorkoutMetric.reps],
      );
      await ref.read(workoutNodesProvider.notifier).add(node);
      exerciseId = node.id;
    } else {
      exerciseId = selected.id;
    }
    final log = ExerciseLog(
      id: const Uuid().v4(),
      exerciseId: exerciseId,
      date: DateFormat('y-MM-dd').format(DateTime.now()),
      metrics: {WorkoutMetric.reps: _count},
      notes: 'Камера: ${_exerciseLabel(_exercise)}',
    );
    await ref.read(exerciseLogsProvider.notifier).add(log);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Сохранено: $_count повторений'),
    ));
    setState(() {
      _count = 0;
      _down = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _cam?.dispose();
    _detector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Камера-тренер'),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _previewLayer()),
          Positioned(
            left: 16,
            top: 16,
            right: 16,
            child: _topPanel(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => setState(() {
                        _count = 0;
                        _down = false;
                      }),
                      child: const Text('Сброс'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _count > 0 ? _saveSet : null,
                      icon: const Icon(Icons.save_outlined),
                      label: Text('Записать ($_count)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewLayer() {
    if (_starting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center),
        ),
      );
    }
    final c = _cam;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    final pose = _pose;
    // Painter scaling needs the actual frame size (post sensor-rotation) that
    // ML Kit consumed. We swap width/height because preview is rotated to
    // portrait while landmark coords come from the unrotated camera frame.
    final raw = _poseImageSize ??
        Size(
          (c.value.previewSize?.width ?? 1).toDouble(),
          (c.value.previewSize?.height ?? 1).toDouble(),
        );
    final rot = _camDesc?.sensorOrientation ?? 0;
    final imgSize = (rot == 90 || rot == 270)
        ? Size(raw.height, raw.width)
        : raw;
    final isFront =
        _camDesc?.lensDirection == CameraLensDirection.front;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(c),
            if (pose != null)
              IgnorePointer(
                child: CustomPaint(
                  painter: _PosePainter(
                    pose: pose,
                    imageSize: imgSize,
                    canvasSize:
                        Size(constraints.maxWidth, constraints.maxHeight),
                    mirrored: isFront,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _topPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<CameraExercise>(
            value: _exercise,
            dropdownColor: Colors.black87,
            isExpanded: true,
            iconEnabledColor: Colors.white,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            underline: const SizedBox.shrink(),
            items: [
              for (final e in CameraExercise.values)
                DropdownMenuItem(
                  value: e,
                  child: Text(_exerciseLabel(e)),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _exercise = v;
                _count = 0;
                _down = false;
              });
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Повторения: $_count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              Text('Угол: ${_angle.toStringAsFixed(0)}°',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                _pose != null ? Icons.visibility : Icons.visibility_off,
                size: 14,
                color: _pose != null
                    ? const Color(0xFF34D399)
                    : Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                _pose != null
                    ? 'Силуэт виден ($_landmarkCount точек)'
                    : 'Не вижу позу — отойди дальше, в кадр должен попасть весь силуэт',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _exerciseLabel(CameraExercise e) => switch (e) {
      CameraExercise.squats => 'Приседания',
      CameraExercise.pushups => 'Отжимания',
      CameraExercise.pullups => 'Подтягивания',
      CameraExercise.benchpress => 'Жим лёжа',
      CameraExercise.abs => 'Пресс',
    };

class _PosePainter extends CustomPainter {
  _PosePainter({
    required this.pose,
    required this.imageSize,
    required this.canvasSize,
    required this.mirrored,
  });
  final Pose pose;
  final Size imageSize;
  final Size canvasSize;
  final bool mirrored;

  static const _connections = <List<PoseLandmarkType>>[
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    Offset map(PoseLandmark p) {
      final x = mirrored ? imageSize.width - p.x : p.x;
      return Offset(x * scaleX, p.y * scaleY);
    }

    final line = Paint()
      ..color = const Color(0xFF34D399)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final dot = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;

    for (final c in _connections) {
      final a = pose.landmarks[c[0]];
      final b = pose.landmarks[c[1]];
      if (a == null || b == null) continue;
      canvas.drawLine(map(a), map(b), line);
    }
    for (final l in pose.landmarks.values) {
      canvas.drawCircle(map(l), 5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _PosePainter old) =>
      old.pose != pose || old.canvasSize != canvasSize;
}
