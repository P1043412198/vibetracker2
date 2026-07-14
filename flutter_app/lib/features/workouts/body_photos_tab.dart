import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/misc.dart';
import '../../services/photo_storage.dart';
import '../../state/providers.dart';

/// Photo journal of body progress with before/after slider comparison.
class BodyPhotosTab extends ConsumerWidget {
  const BodyPhotosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = [...ref.watch(bodyPhotosProvider)]
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return Stack(
      children: [
        if (photos.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📸', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text('Фото прогресса',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  const Text(
                    'Снимки до/после, один раз в неделю — заметнее изменения, чем на весах.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (photos.length >= 2)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.compare_outlined),
                    title: const Text('Сравнить до/после'),
                    subtitle: const Text(
                        'Открыть слайдер с двумя фото за разные даты'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _ComparePage(photos: photos),
                      ));
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Text('История (${photos.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                itemCount: photos.length,
                itemBuilder: (ctx, i) {
                  final p = photos[i];
                  return InkWell(
                    onTap: () => _openPhoto(context, ref, p, photos),
                    borderRadius: BorderRadius.circular(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _PhotoImage(path: p.path),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.65),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(_humanDate(p.takenAt),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11)),
                                  if (p.label != null)
                                    Text(p.label!,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'workouts_photo_add',
            onPressed: () => _addPhoto(context, ref),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Фото'),
          ),
        ),
      ],
    );
  }

  String _humanDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('d MMM y', 'ru').format(dt);
  }
}

Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Снять с камеры'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Выбрать из галереи'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
        ],
      ),
    ),
  );
  if (source == null) return;
  final id = const Uuid().v4();
  final String? path = source == 'camera'
      ? await PhotoStorage.instance
          .captureAndStore(bucket: 'body_photos', entityId: id)
      : await PhotoStorage.instance
          .pickAndStore(bucket: 'body_photos', entityId: id);
  if (path == null) return;
  if (!context.mounted) return;
  await _showPhotoForm(context, ref, id: id, path: path);
}

Future<void> _showPhotoForm(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required String path,
  BodyPhoto? existing,
}) async {
  final labelCtl =
      TextEditingController(text: existing?.label ?? '');
  final weightCtl = TextEditingController(
      text: existing?.weight != null ? existing!.weight.toString() : '');
  final noteCtl = TextEditingController(text: existing?.note ?? '');
  DateTime date = existing == null
      ? DateTime.now()
      : (DateTime.tryParse(existing.takenAt) ?? DateTime.now());

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
            Text(existing == null ? 'Новое фото' : 'Изменить фото',
                style: Theme.of(ctx2).textTheme.titleLarge),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _PhotoImage(path: path),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(DateFormat('d MMM y', 'ru').format(date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx2,
                  initialDate: date,
                  firstDate: DateTime.now()
                      .subtract(const Duration(days: 365 * 5)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => date = picked);
              },
            ),
            TextField(
              controller: labelCtl,
              decoration: const InputDecoration(
                  labelText: 'Подпись',
                  hintText: 'фронт / спина / профиль'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: weightCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Вес, кг (опционально)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtl,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Заметка'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final iso = DateFormat('yyyy-MM-dd').format(date);
                final entry = BodyPhoto(
                  id: existing?.id ?? id,
                  path: existing?.path ?? path,
                  takenAt: iso,
                  label: labelCtl.text.trim().isEmpty
                      ? null
                      : labelCtl.text.trim(),
                  weight: num.tryParse(
                      weightCtl.text.trim().replaceAll(',', '.')),
                  note: noteCtl.text.trim().isEmpty
                      ? null
                      : noteCtl.text.trim(),
                );
                await ref
                    .read(bodyPhotosProvider.notifier)
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
  labelCtl.dispose();
  weightCtl.dispose();
  noteCtl.dispose();
}

Future<void> _openPhoto(BuildContext context, WidgetRef ref,
    BodyPhoto photo, List<BodyPhoto> all) async {
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => _PhotoViewer(photo: photo, all: all, ref: ref),
  ));
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer(
      {required this.photo, required this.all, required this.ref});
  final BodyPhoto photo;
  final List<BodyPhoto> all;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(photo.takenAt),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                _showPhotoForm(context, ref, id: photo.id, path: photo.path,
                    existing: photo),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ref.read(bodyPhotosProvider.notifier).remove(photo.id);
              await PhotoStorage.instance.delete(photo.path);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Center(child: _PhotoImage(path: photo.path)),
              ),
            ),
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photo.label != null)
                    Text(photo.label!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  if (photo.weight != null)
                    Text('${photo.weight} кг',
                        style: const TextStyle(color: Colors.white70)),
                  if (photo.note != null) ...[
                    const SizedBox(height: 4),
                    Text(photo.note!,
                        style: const TextStyle(color: Colors.white70)),
                  ],
                  if (all.length >= 2) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => _ComparePage(
                              photos: all, initial: photo),
                        ));
                      },
                      icon: const Icon(Icons.compare_outlined),
                      label: const Text('Сравнить с другим фото'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoImage extends StatelessWidget {
  const _PhotoImage({required this.path});
  final String path;
  @override
  Widget build(BuildContext context) {
    final f = File(PhotoStorage.instance.resolve(path));
    if (!f.existsSync()) {
      return Container(
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.broken_image_outlined,
              color: Colors.white54, size: 36),
        ),
      );
    }
    return Image.file(f, fit: BoxFit.cover);
  }
}

/* --------------------------- compare page ------------------------------ */

class _ComparePage extends StatefulWidget {
  const _ComparePage({required this.photos, this.initial});
  final List<BodyPhoto> photos;
  final BodyPhoto? initial;

  @override
  State<_ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<_ComparePage> {
  late BodyPhoto _left;
  late BodyPhoto _right;
  double _slider = 0.5;

  @override
  void initState() {
    super.initState();
    final sorted = [...widget.photos]
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    _left = sorted.first;
    _right = widget.initial ?? sorted.last;
    if (_right == _left && sorted.length > 1) {
      _right = sorted[sorted.length - 1];
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.photos]
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('До / после'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _BeforeAfter(
                  beforePath: _left.path,
                  afterPath: _right.path,
                  slider: _slider,
                  onChanged: (v) => setState(() => _slider = v),
                  beforeLabel: _left.takenAt,
                  afterLabel: _right.takenAt,
                ),
              ),
            ),
          ),
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPicker(
                  label: 'До',
                  current: _left,
                  options: sorted,
                  onSelect: (p) => setState(() => _left = p),
                ),
                const SizedBox(height: 8),
                _buildPicker(
                  label: 'После',
                  current: _right,
                  options: sorted,
                  onSelect: (p) => setState(() => _right = p),
                ),
                if (_left.weight != null && _right.weight != null) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (_) {
                    final diff = (_right.weight! - _left.weight!).toDouble();
                    final color = diff <= 0
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444);
                    return Row(children: [
                      const Icon(Icons.monitor_weight_outlined,
                          color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                          '${_left.weight} → ${_right.weight} кг (${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)})',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800)),
                    ]);
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker({
    required String label,
    required BodyPhoto current,
    required List<BodyPhoto> options,
    required void Function(BodyPhoto) onSelect,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in options)
                  GestureDetector(
                    onTap: () => onSelect(p),
                    child: Container(
                      width: 56,
                      height: 64,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: p.id == current.id
                              ? Colors.white
                              : Colors.white24,
                          width: p.id == current.id ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(fit: StackFit.expand, children: [
                          _PhotoImage(path: p.path),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 1),
                              child: Text(
                                p.takenAt.substring(5),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BeforeAfter extends StatelessWidget {
  const _BeforeAfter({
    required this.beforePath,
    required this.afterPath,
    required this.slider,
    required this.onChanged,
    required this.beforeLabel,
    required this.afterLabel,
  });
  final String beforePath;
  final String afterPath;
  final double slider;
  final ValueChanged<double> onChanged;
  final String beforeLabel;
  final String afterLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      final dx = (w * slider).clamp(0.0, w);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) {
          final next = (slider + d.delta.dx / w).clamp(0.0, 1.0);
          onChanged(next.toDouble());
        },
        onTapDown: (d) => onChanged(
            (d.localPosition.dx / w).clamp(0.0, 1.0).toDouble()),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // After image (full)
            _PhotoImage(path: afterPath),
            // Before image clipped to slider position
            ClipRect(
              clipper: _SliderClipper(slider),
              child: _PhotoImage(path: beforePath),
            ),
            // Slider seam
            Positioned(
              left: dx - 1,
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: Colors.white),
            ),
            Positioned(
              left: dx - 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(Icons.compare_arrows,
                      color: Colors.black87),
                ),
              ),
            ),
            // Labels
            Positioned(
              top: 8,
              left: 8,
              child: _Tag(text: 'до · $beforeLabel'),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _Tag(text: 'после · $afterLabel'),
            ),
          ],
        ),
      );
    });
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  _SliderClipper(this.fraction);
  final double fraction;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);
  @override
  bool shouldReclip(covariant _SliderClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}
