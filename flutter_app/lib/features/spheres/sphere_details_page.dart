import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

class SphereDetailsPage extends ConsumerWidget {
  const SphereDetailsPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sphere = ref.watch(spheresProvider).firstWhere(
          (s) => s.id == id,
          orElse: () => throw StateError('Sphere $id not found'),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(sphere.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (sphere.description?.isNotEmpty == true)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(sphere.description!),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Заметки',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    sphere.notes.isEmpty
                        ? 'Пока пусто. Редактирование заметок будет в следующей фазе порта.'
                        : sphere.notes,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
