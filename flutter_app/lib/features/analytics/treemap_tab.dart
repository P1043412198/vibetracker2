import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/finance.dart';
import '../../services/finance_calc.dart';
import '../../state/currency_state.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';

/// "Treemap" — port of `src/components/charts/TreemapExpenses.tsx`.
///
/// A squarified treemap of expense categories for the selected month.
/// Tile colour encodes spend vs. plan:
///   < 80%  → green, < 100% emerald, < 120% amber, ≥ 120% red,
///   no plan → grey.
class TreemapTab extends ConsumerStatefulWidget {
  const TreemapTab({super.key});

  @override
  ConsumerState<TreemapTab> createState() => _TreemapTabState();
}

class _TreemapTabState extends ConsumerState<TreemapTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final accounts = ref.watch(accountsProvider);
    final budgetPlans = ref.watch(monthlyBudgetPlansProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider);

    num convert(num amount, String from, String to) =>
        convertCurrency(amount: amount, from: from, to: to, rates: rates);

    final facts = computeMonthFacts(
      month: _month,
      transactions: transactions,
      accounts: accounts,
      baseCurrency: baseCurrency,
      convert: convert,
    );
    final monthKey = monthKeyOf(_month);
    final plan = budgetPlans
        .cast<MonthlyBudgetPlan?>()
        .firstWhere((p) => p?.monthKey == monthKey, orElse: () => null);
    final planByCategory = <String, num>{};
    if (plan != null) {
      for (final cp in plan.categoryPlans) {
        planByCategory[cp.category] = cp.planned;
      }
    }
    final entries = facts.expenseByCategory.entries
        .map((e) => _Tile(category: e.key, value: e.value, plan: planByCategory[e.key]))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final money = NumberFormat.simpleCurrency(
      locale: 'ru',
      name: baseCurrency,
      decimalDigits: 0,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text(
                    DateFormat('LLLL y', 'ru').format(_month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Нет расходов в выбранном месяце.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  )
                else
                  AspectRatio(
                    aspectRatio: 1.4,
                    child: _Treemap(
                      tiles: entries,
                      formatter: money,
                    ),
                  ),
                const SizedBox(height: 12),
                _Legend(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile {
  _Tile({required this.category, required this.value, this.plan});
  final String category;
  final num value;
  final num? plan;
}

class _Treemap extends StatelessWidget {
  const _Treemap({required this.tiles, required this.formatter});
  final List<_Tile> tiles;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final rects = _squarify(
        tiles,
        Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight),
      );
      return Stack(
        children: [
          for (final entry in rects.entries)
            Positioned.fromRect(
              rect: entry.value.deflate(2),
              child: _TileBox(
                tile: entry.key,
                formatter: formatter,
              ),
            ),
        ],
      );
    });
  }
}

class _TileBox extends StatelessWidget {
  const _TileBox({required this.tile, required this.formatter});
  final _Tile tile;
  final NumberFormat formatter;

  Color _color() {
    final plan = tile.plan;
    if (plan == null || plan <= 0) return const Color(0xFF6B7280);
    final ratio = tile.value / plan;
    if (ratio < 0.8) return const Color(0xFF10B981);
    if (ratio < 1.0) return const Color(0xFF34D399);
    if (ratio < 1.2) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _color(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tile.category,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                formatter.format(tile.value),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (tile.plan != null && (tile.plan ?? 0) > 0)
                Text(
                  '${(tile.value / (tile.plan ?? 1) * 100).toStringAsFixed(0)}% / плана',
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget swatch(Color c, String label) => Padding(
          padding: const EdgeInsets.only(right: 12, top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
    return Wrap(
      children: [
        swatch(const Color(0xFF10B981), 'до 80% плана'),
        swatch(const Color(0xFF34D399), '80–100%'),
        swatch(const Color(0xFFF59E0B), '100–120%'),
        swatch(const Color(0xFFDC2626), '> 120%'),
        swatch(const Color(0xFF6B7280), 'без плана'),
      ],
    );
  }
}

/// Squarified treemap layout (Bruls et al., 2000): pack tiles into [container]
/// keeping aspect ratios as close to 1 as possible.
Map<_Tile, Rect> _squarify(List<_Tile> tiles, Rect container) {
  if (tiles.isEmpty) return const {};
  final total = tiles.fold<double>(0, (s, t) => s + t.value.toDouble());
  if (total <= 0) return const {};
  final scaled = [
    for (final t in tiles)
      t.value.toDouble() * container.width * container.height / total
  ];
  final result = <_Tile, Rect>{};
  final remainingTiles = [...tiles];
  final remainingAreas = [...scaled];
  Rect r = container;
  final List<_Tile> rowTiles = [];
  final List<double> rowAreas = [];

  while (remainingTiles.isNotEmpty) {
    final shortSide = r.width < r.height ? r.width : r.height;
    final next = remainingAreas.first;
    final withNext = [...rowAreas, next];
    final worstWith = _worst(withNext, shortSide);
    final worstWithout =
        rowAreas.isEmpty ? double.infinity : _worst(rowAreas, shortSide);
    if (rowAreas.isEmpty || worstWith <= worstWithout) {
      rowTiles.add(remainingTiles.removeAt(0));
      rowAreas.add(remainingAreas.removeAt(0));
    } else {
      r = _placeRow(rowTiles, rowAreas, r, result);
      rowTiles.clear();
      rowAreas.clear();
    }
  }
  if (rowTiles.isNotEmpty) {
    _placeRow(rowTiles, rowAreas, r, result);
  }
  return result;
}

Rect _placeRow(
  List<_Tile> rowTiles,
  List<double> rowAreas,
  Rect rect,
  Map<_Tile, Rect> out,
) {
  final sum = rowAreas.fold<double>(0, (s, a) => s + a);
  if (sum <= 0) return rect;
  final isWide = rect.width >= rect.height;
  if (isWide) {
    final w = sum / rect.height;
    double y = rect.top;
    for (var i = 0; i < rowTiles.length; i++) {
      final h = rowAreas[i] / w;
      out[rowTiles[i]] = Rect.fromLTWH(rect.left, y, w, h);
      y += h;
    }
    return Rect.fromLTWH(rect.left + w, rect.top, rect.width - w, rect.height);
  } else {
    final h = sum / rect.width;
    double x = rect.left;
    for (var i = 0; i < rowTiles.length; i++) {
      final w = rowAreas[i] / h;
      out[rowTiles[i]] = Rect.fromLTWH(x, rect.top, w, h);
      x += w;
    }
    return Rect.fromLTWH(rect.left, rect.top + h, rect.width, rect.height - h);
  }
}

double _worst(List<double> areas, double shortSide) {
  if (areas.isEmpty) return double.infinity;
  final sum = areas.fold<double>(0, (s, a) => s + a);
  final s2 = shortSide * shortSide;
  final sum2 = sum * sum;
  double maxA = areas.first;
  double minA = areas.first;
  for (final a in areas) {
    if (a > maxA) maxA = a;
    if (a < minA) minA = a;
  }
  final w1 = (s2 * maxA) / sum2;
  final w2 = sum2 / (s2 * minA);
  return w1 > w2 ? w1 : w2;
}
