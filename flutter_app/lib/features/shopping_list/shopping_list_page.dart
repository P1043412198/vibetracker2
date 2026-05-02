import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/misc.dart';
import '../../state/providers.dart';

/// Counterpart of `src/pages/ShoppingList.tsx`. Lightweight checklist view
/// in the first port pass — categories/photos/price-history come later.
class ShoppingListPage extends ConsumerWidget {
  const ShoppingListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(shoppingListProvider);
    final pending = items.where((i) => !i.completed).toList();
    final done = items.where((i) => i.completed).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Список покупок')),
      body: items.isEmpty
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (pending.isNotEmpty) ...[
                  Text('К покупке (${pending.length})',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  for (final i in pending) _Tile(item: i),
                ],
                if (done.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Куплено (${done.length})',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  for (final i in done) _Tile(item: i),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItem(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Позиция'),
      ),
    );
  }

  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final priceController = TextEditingController();
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
              Text('Добавить позицию',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Что купить?'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Бюджет (опционально)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  await ref.read(shoppingListProvider.notifier).add(
                        ShoppingItem(
                          id: const Uuid().v4(),
                          text: text,
                          completed: false,
                          price: double.tryParse(priceController.text.trim()),
                          createdAt: DateTime.now().toIso8601String(),
                        ),
                      );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
                child: const Text('Добавить'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.item});
  final ShoppingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: item.completed,
        onChanged: (_) async {
          await ref.read(shoppingListProvider.notifier).upsert(
                ShoppingItem(
                  id: item.id,
                  text: item.text,
                  completed: !item.completed,
                  price: item.price,
                  category: item.category,
                  hashtags: item.hashtags,
                  photo: item.photo,
                  createdAt: item.createdAt,
                  completedAt: !item.completed
                      ? DateTime.now().toIso8601String()
                      : null,
                ),
              );
        },
        title: Text(
          item.text,
          style: TextStyle(
            decoration: item.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: item.price != null
            ? Text('~ ${item.price!.toStringAsFixed(2)}')
            : null,
        secondary: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () =>
              ref.read(shoppingListProvider.notifier).remove(item.id),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛒', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Список пуст',
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
