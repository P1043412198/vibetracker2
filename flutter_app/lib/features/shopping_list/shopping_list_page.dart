import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/misc.dart';
import '../../state/providers.dart';

class ShoppingListPage extends ConsumerStatefulWidget {
  const ShoppingListPage({super.key});

  @override
  ConsumerState<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends ConsumerState<ShoppingListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _textCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _hashtagCtrl = TextEditingController();
  String? _selectedCategory;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _textCtrl.dispose();
    _priceCtrl.dispose();
    _hashtagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(shoppingListProvider);
    final categories = ref.watch(shoppingCategoriesProvider);
    final priceHistory = ref.watch(priceHistoryProvider);

    final pending = items.where((i) => !i.completed).toList();
    final completed = items.where((i) => i.completed).toList();
    final totalPlan = pending.fold<num>(0, (s, i) => s + (i.price ?? 0));
    final totalDone = completed.fold<num>(0, (s, i) => s + (i.price ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shopping_cart_outlined, size: 22),
            SizedBox(width: 8),
            Text('Список покупок'),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Список'),
            Tab(text: 'Анализ'),
            Tab(text: 'Категории'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _listTab(pending, completed, categories, totalPlan, totalDone,
              priceHistory),
          _analyticsTab(items, categories),
          _categoriesTab(categories),
        ],
      ),
    );
  }

  // ---- List tab ----
  Widget _listTab(
    List<ShoppingItem> pending,
    List<ShoppingItem> completed,
    List<ShoppingCategory> categories,
    num totalPlan,
    num totalDone,
    List<PriceHistoryEntry> priceHistory,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // Summary cards
        Row(children: [
          _summaryCard('План', totalPlan, Colors.grey),
          const SizedBox(width: 12),
          _summaryCard('Куплено', totalDone, Colors.green),
        ]),
        const SizedBox(height: 16),

        // Add form
        _addForm(categories),
        const SizedBox(height: 16),

        // Pending items
        if (pending.isNotEmpty) ...[
          for (final item in pending)
            _itemTile(item, categories, false),
        ],

        if (pending.isEmpty && completed.isEmpty)
          const _Empty(),

        // Completed section
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _showCompleted = !_showCompleted),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text('Куплено (${completed.length})',
                      style: Theme.of(context).textTheme.labelLarge),
                  Icon(_showCompleted
                      ? Icons.expand_less
                      : Icons.expand_more),
                  const Spacer(),
                  if (_showCompleted)
                    TextButton.icon(
                      onPressed: () {
                        for (final item in completed) {
                          ref
                              .read(shoppingListProvider.notifier)
                              .remove(item.id);
                        }
                      },
                      icon: const Icon(Icons.cleaning_services, size: 14),
                      label: const Text('Очистить', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
          ),
          if (_showCompleted)
            for (final item in completed)
              _itemTile(item, categories, true),
        ],
      ],
    );
  }

  Widget _summaryCard(String label, num value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                '${value.toStringAsFixed(0)} BYN',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addForm(List<ShoppingCategory> categories) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textCtrl,
              decoration: const InputDecoration(
                hintText: 'Что купить?',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _addItem(),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Цена (опц.)',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _hashtagCtrl,
                  decoration: const InputDecoration(
                    hintText: '#теги',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Категория',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Без категории')),
                    ...categories.map((c) => DropdownMenuItem(
                        value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _addItem() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final price = double.tryParse(_priceCtrl.text.trim());
    final hashtags = _hashtagCtrl.text
        .split(' ')
        .where((h) => h.startsWith('#'))
        .map((h) => h.substring(1))
        .where((h) => h.isNotEmpty)
        .toList();

    ref.read(shoppingListProvider.notifier).add(ShoppingItem(
          id: const Uuid().v4(),
          text: text,
          completed: false,
          price: price,
          category: _selectedCategory,
          hashtags: hashtags.isNotEmpty ? hashtags : null,
          createdAt: DateTime.now().toIso8601String(),
        ));

    if (price != null) {
      ref.read(priceHistoryProvider.notifier).add(PriceHistoryEntry(
            id: const Uuid().v4(),
            itemName: text,
            price: price,
            date: DateTime.now().toIso8601String(),
          ));
    }

    _textCtrl.clear();
    _priceCtrl.clear();
    _hashtagCtrl.clear();
  }

  Widget _itemTile(
      ShoppingItem item, List<ShoppingCategory> categories, bool isDone) {
    final cat =
        categories.where((c) => c.id == item.category).firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            isDone ? Icons.check_circle : Icons.circle_outlined,
            color: isDone ? Colors.green : Colors.grey,
          ),
          onPressed: () {
            ref.read(shoppingListProvider.notifier).upsert(ShoppingItem(
                  id: item.id,
                  text: item.text,
                  completed: !item.completed,
                  price: item.price,
                  category: item.category,
                  hashtags: item.hashtags,
                  photo: item.photo,
                  createdAt: item.createdAt,
                  completedAt:
                      !item.completed ? DateTime.now().toIso8601String() : null,
                ));
          },
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                item.text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? Colors.grey : null,
                ),
              ),
            ),
            if (cat != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _parseColor(cat.color).withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(cat.name,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _parseColor(cat.color))),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.price != null)
              Text('${item.price!.toStringAsFixed(2)} BYN',
                  style: const TextStyle(fontSize: 11)),
            if (item.hashtags != null && item.hashtags!.isNotEmpty)
              Wrap(
                spacing: 4,
                children: item.hashtags!
                    .map((t) => Text('#$t',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.blue)))
                    .toList(),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
          onPressed: () =>
              ref.read(shoppingListProvider.notifier).remove(item.id),
        ),
      ),
    );
  }

  // ---- Analytics tab ----
  Widget _analyticsTab(
      List<ShoppingItem> items, List<ShoppingCategory> categories) {
    final Map<String, _CatSum> byCategory = {};
    for (final item in items) {
      if (item.price == null || item.price == 0) continue;
      final cat = categories.where((c) => c.id == item.category).firstOrNull;
      final name = cat?.name ?? 'Другое';
      final color = cat?.color ?? '#71717a';
      byCategory.putIfAbsent(name, () => _CatSum(name, color));
      byCategory[name]!.value += item.price!.toDouble();
    }
    final catData = byCategory.values.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, double> byTag = {};
    for (final item in items) {
      if (item.price == null || item.hashtags == null) continue;
      for (final tag in item.hashtags!) {
        byTag[tag] = (byTag[tag] ?? 0) + item.price!.toDouble();
      }
    }
    final tagData = byTag.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = catData.fold<double>(0, (s, c) => s + c.value);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Траты по категориям',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        if (catData.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child:
                Center(child: Text('Нет данных', style: TextStyle(color: Colors.grey))),
          )
        else ...[
          for (final c in catData)
            _analyticRow(c.name, c.value, total, _parseColor(c.color)),
        ],

        if (tagData.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Траты по тегам',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          for (final t in tagData)
            _analyticRow('#${t.key}', t.value, total, Colors.blue),
        ],
      ],
    );
  }

  Widget _analyticRow(String label, double value, double total, Color color) {
    final fraction = total > 0 ? value / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text('${value.toStringAsFixed(0)} BYN',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.grey.withAlpha(30),
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Categories tab ----
  Widget _categoriesTab(List<ShoppingCategory> categories) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final cat in categories)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _parseColor(cat.color),
                radius: 14,
              ),
              title: Text(cat.name),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: Colors.red[300]),
                onPressed: () => ref
                    .read(shoppingCategoriesProvider.notifier)
                    .remove(cat.id),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _AddCategoryButton(ref: ref),
      ],
    );
  }

  Color _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return Colors.grey;
  }
}

class _CatSum {
  _CatSum(this.name, this.color);
  final String name;
  final String color;
  double value = 0;
}

class _AddCategoryButton extends StatefulWidget {
  const _AddCategoryButton({required this.ref});
  final WidgetRef ref;

  @override
  State<_AddCategoryButton> createState() => _AddCategoryButtonState();
}

class _AddCategoryButtonState extends State<_AddCategoryButton> {
  bool _adding = false;
  final _nameCtrl = TextEditingController();
  Color _color = Colors.blue;

  static const _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_adding) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _adding = true),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Новая категория'),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Название категории',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: _colors
                  .map((c) => GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: c,
                          child: _color == c
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _adding = false),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final name = _nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final hex =
                        '#${_color.value.toRadixString(16).substring(2)}';
                    widget.ref
                        .read(shoppingCategoriesProvider.notifier)
                        .add(ShoppingCategory(
                          id: const Uuid().v4(),
                          name: name,
                          color: hex,
                        ));
                    _nameCtrl.clear();
                    setState(() => _adding = false);
                  },
                  child: const Text('Добавить'),
                ),
              ),
            ]),
          ],
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
            Icon(Icons.shopping_cart_outlined,
                size: 48, color: Colors.grey.withAlpha(60)),
            const SizedBox(height: 12),
            Text('Список покупок пуст',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
