import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../widgets/viz/heat_color.dart';

/// A front/back body silhouette whose muscle regions are shaded by relative
/// training volume ("heatmap"): the more a group was trained, the hotter
/// (amber → red) its region. Groups with no volume stay a cool grey.
class MuscleHeatmap extends StatelessWidget {
  const MuscleHeatmap({super.key, required this.byMuscle});

  /// Volume (or set count) per muscle group.
  final Map<MuscleGroup, num> byMuscle;

  @override
  Widget build(BuildContext context) {
    final maxV = byMuscle.values.fold<num>(0, (m, v) => v > m ? v : m);
    final intensity = <MuscleGroup, double>{
      for (final g in MuscleGroup.values)
        g: maxV <= 0 ? 0 : (byMuscle[g] ?? 0) / maxV,
    };

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Figure(
                title: 'Спереди',
                front: true,
                intensity: intensity,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Figure(
                title: 'Сзади',
                front: false,
                intensity: intensity,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _HeatLegend(),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.title,
    required this.front,
    required this.intensity,
  });

  final String title;
  final bool front;
  final Map<MuscleGroup, double> intensity;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 0.5,
          child: CustomPaint(
            painter: _BodyPainter(
              front: front,
              intensity: intensity,
              base: base,
              outline: outline,
            ),
          ),
        ),
      ],
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.front,
    required this.intensity,
    required this.base,
    required this.outline,
  });

  final bool front;
  final Map<MuscleGroup, double> intensity;
  final Color base;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = outline;

    // Normalised layout helpers.
    Rect r(double l, double t, double rr, double b) =>
        Rect.fromLTRB(l * w, t * h, rr * w, b * h);

    void region(Rect rect, MuscleGroup? g, {double radius = 8}) {
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = g == null ? base : heatColor(intensity[g] ?? 0, base);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, stroke);
    }

    // Head.
    final headC = Offset(w * 0.5, h * 0.08);
    final headP = Paint()
      ..style = PaintingStyle.fill
      ..color = base;
    canvas.drawCircle(headC, h * 0.055, headP);
    canvas.drawCircle(headC, h * 0.055, stroke);

    // Shoulders (both figures).
    region(r(0.14, 0.16, 0.36, 0.24), MuscleGroup.shoulders);
    region(r(0.64, 0.16, 0.86, 0.24), MuscleGroup.shoulders);

    // Upper arms.
    region(r(0.06, 0.24, 0.22, 0.46), MuscleGroup.arms);
    region(r(0.78, 0.24, 0.94, 0.46), MuscleGroup.arms);

    // Torso: chest/core on front, back/lower-back on the back view.
    region(r(0.30, 0.20, 0.70, 0.36), front ? MuscleGroup.chest : MuscleGroup.back);
    region(r(0.32, 0.37, 0.68, 0.52),
        front ? MuscleGroup.core : MuscleGroup.back);

    // Legs (quads front / hamstrings back → same MuscleGroup.legs).
    region(r(0.30, 0.54, 0.48, 0.92), MuscleGroup.legs);
    region(r(0.52, 0.54, 0.70, 0.92), MuscleGroup.legs);
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) =>
      old.front != front ||
      old.base != base ||
      old.outline != outline ||
      !mapEquals(old.intensity, intensity);
}

class _HeatLegend extends StatelessWidget {
  const _HeatLegend();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (var i = 0; i <= 20; i++)
                  Expanded(
                    child: Container(color: heatColor(i / 20, base)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('меньше нагрузки',
                style: Theme.of(context).textTheme.labelSmall),
            Text('больше', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}
