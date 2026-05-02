import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/finance.dart';
import '../../services/receipt_service.dart';
import '../../state/providers.dart';

/// Browses every receipt photo across all transactions, grouped by month.
/// Tap any thumbnail to open the source transaction's receipts in a sheet.
class ReceiptGalleryPage extends ConsumerWidget {
  const ReceiptGalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final byMonth = <String, List<_ReceiptEntry>>{};
    for (final tx in transactions) {
      final paths = tx.receiptPaths;
      if (paths == null || paths.isEmpty) continue;
      final monthKey = tx.date.length >= 7 ? tx.date.substring(0, 7) : 'unknown';
      for (final p in paths) {
        byMonth.putIfAbsent(monthKey, () => []).add(_ReceiptEntry(tx, p));
      }
    }
    final sortedKeys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('Чеки')),
      body: sortedKeys.isEmpty
          ? const _Empty()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: sortedKeys.length,
              itemBuilder: (context, i) {
                final key = sortedKeys[i];
                final entries = byMonth[key]!;
                return _MonthSection(
                  monthLabel: _monthLabel(key),
                  entries: entries,
                  accounts: accounts,
                );
              },
            ),
    );
  }

  static String _monthLabel(String key) {
    if (key == 'unknown') return 'Без даты';
    final dt = DateTime.tryParse('$key-01');
    if (dt == null) return key;
    return DateFormat.yMMMM('ru').format(dt);
  }
}

class _ReceiptEntry {
  _ReceiptEntry(this.tx, this.path);
  final Transaction tx;
  final String path;
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.monthLabel,
    required this.entries,
    required this.accounts,
  });

  final String monthLabel;
  final List<_ReceiptEntry> entries;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            monthLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            for (final e in entries)
              _ReceiptThumbCard(entry: e, fmt: fmt),
          ],
        ),
      ],
    );
  }
}

class _ReceiptThumbCard extends StatelessWidget {
  const _ReceiptThumbCard({required this.entry, required this.fmt});
  final _ReceiptEntry entry;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final tx = entry.tx;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openDetail(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<File>(
              future: ReceiptService.instance.resolve(entry.path),
              builder: (context, snap) {
                final f = snap.data;
                if (f == null) {
                  return Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  );
                }
                return Image.file(
                  f,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.merchant?.isNotEmpty == true
                        ? tx.merchant!
                        : tx.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    fmt.format(tx.amount),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(BuildContext context) async {
    final paths = entry.tx.receiptPaths ?? const [];
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              entry.tx.merchant?.isNotEmpty == true
                  ? entry.tx.merchant!
                  : entry.tx.category,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${entry.tx.date} · ${entry.tx.category}'),
            const SizedBox(height: 12),
            for (final p in paths)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FutureBuilder<File>(
                  future: ReceiptService.instance.resolve(p),
                  builder: (context, snap) {
                    final f = snap.data;
                    if (f == null) {
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(f, fit: BoxFit.contain),
                    );
                  },
                ),
              ),
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
            const Text('🧾', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Чеков пока нет',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Прикрепи фото чека к транзакции — оно появится здесь.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
