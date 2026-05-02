import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../models/sphere.dart';
import '../../state/providers.dart';

/// Counterpart of `src/pages/Spheres.tsx`. Renders pinned & active spheres
/// with the ability to add a new one.
class SpheresPage extends ConsumerWidget {
  const SpheresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spheres = [...ref.watch(spheresProvider)]
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('Сферы')),
      body: spheres.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: spheres.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  _SphereTile(sphere: spheres[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Новая сфера'),
      ),
    );
  }

  static Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final descController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Новая сфера',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Описание'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final title = controller.text.trim();
                  if (title.isEmpty) return;
                  final sphere = Sphere(
                    id: const Uuid().v4(),
                    title: title,
                    description: descController.text.trim().isEmpty
                        ? null
                        : descController.text.trim(),
                    notes: '',
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  await ref.read(spheresProvider.notifier).add(sphere);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
                child: const Text('Создать'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SphereTile extends StatelessWidget {
  const _SphereTile({required this.sphere});
  final Sphere sphere;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _parseColor(sphere.color) ?? scheme.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/spheres/${sphere.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sphere.icon ?? '✨',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sphere.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (sphere.isPinned == true)
                          Icon(Icons.push_pin, size: 16, color: scheme.primary),
                      ],
                    ),
                    if (sphere.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        sphere.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length != 6) return null;
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Создай первую сферу',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Сферы — это области твоей жизни: семья, здоровье, работа, обучение. Заметки и задачи привязываются к сфере.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
