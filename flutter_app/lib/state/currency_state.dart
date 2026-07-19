import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/nbrb_service.dart';
import '../services/storage.dart';

/// Persisted FX rates expressed as: 1 unit of [currency] equals
/// `rates[currency]` units of the **anchor** currency (USD).
///
/// React stores these the same way in `useStore.ts` as `fxRates`. Keeping
/// the same shape lets us later sync rates from a CBR/NBRB endpoint without
/// changing the consumers.
class CurrencyRatesController extends StateNotifier<Map<String, num>> {
  CurrencyRatesController() : super(_defaults) {
    final raw = AppStorage.readString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as Map;
        state = decoded.map((k, v) => MapEntry(k.toString(), (v as num)));
      } catch (_) {
        state = _defaults;
      }
    }
    // Phase 18: auto-refresh from NBRB when rates are missing or stale
    // (older than 12h) so users don't have to tap the refresh button on a
    // fresh install. Failures are swallowed silently — the persisted /
    // default rates remain in state.
    _maybeAutoRefresh();
  }

  Future<void> _maybeAutoRefresh() async {
    try {
      final lastIso = AppStorage.readString(_updatedAtKey);
      final lastTs = lastIso == null ? null : DateTime.tryParse(lastIso);
      final stale = lastTs == null ||
          DateTime.now().difference(lastTs) > const Duration(hours: 12);
      if (!stale) return;
      await refreshFromNbrb();
    } catch (_) {
      // Network failure / parse error — keep persisted/default rates.
    }
  }

  static const _key = 'fxRates';
  static const Map<String, num> _defaults = {
    'USD': 1.0,
    'EUR': 1.05,
    'BYN': 0.31,
    'RUB': 0.011,
    'PLN': 0.25,
    'USDT': 1.0,
  };

  Future<void> set(Map<String, num> rates) async {
    state = Map.unmodifiable({...state, ...rates});
    await AppStorage.writeString(_key, json.encode(state));
    await AppStorage.writeString(
        _updatedAtKey, DateTime.now().toIso8601String());
  }

  /// Pulls fresh USD-anchored rates from NBRB and merges them into state.
  /// Returns the number of currency codes that were updated. Throws on
  /// failure so the caller can show an error toast.
  Future<int> refreshFromNbrb() async {
    final fresh = await NbrbService.fetchUsdAnchoredRates();
    await set(fresh);
    return fresh.length;
  }

  /// ISO timestamp of the last successful refresh, or null if never.
  String? get lastUpdatedIso => AppStorage.readString(_updatedAtKey);

  static const _updatedAtKey = 'fxRatesUpdatedAt';
}

final currencyRatesProvider =
    StateNotifierProvider<CurrencyRatesController, Map<String, num>>((ref) {
  return CurrencyRatesController();
});

/// Outcome of a currency conversion, including whether every required rate
/// was available. Mirrors `ConversionResult` in the React `utils.ts`.
class ConversionResult {
  /// Converted amount. Falls back to the unconverted amount when a rate is missing.
  final num value;

  /// True when every rate needed for the conversion was available.
  final bool ok;

  /// Currency codes whose rate was missing (empty when [ok]).
  final List<String> missing;

  const ConversionResult({
    required this.value,
    required this.ok,
    required this.missing,
  });
}

final Set<String> _warnedMissingRates = <String>{};

/// Convert [amount] from [from] to [to] using the persisted rates, reporting
/// whether the conversion was actually possible.
///
/// Unlike a bare lookup, this never silently fabricates a 1:1 cross-rate: when
/// a rate is missing the caller gets `ok: false` and the missing codes, so the
/// UI can flag totals as approximate instead of distorting net worth.
ConversionResult tryConvertCurrency({
  required num amount,
  required String from,
  required String to,
  required Map<String, num> rates,
}) {
  if (from == to) {
    return ConversionResult(value: amount, ok: true, missing: const []);
  }

  final missing = <String>[];
  final fromRate = rates[from];
  final toRate = rates[to];
  if (fromRate == null) missing.add(from);
  if (toRate == null) missing.add(to);

  if (missing.isNotEmpty) {
    // Best-effort fallback keeps the UI rendering, but the result is flagged.
    return ConversionResult(value: amount, ok: false, missing: missing);
  }

  // Convert via the anchor: amount_anchor = amount * fromRate; result = amount_anchor / toRate.
  return ConversionResult(value: (amount * fromRate!) / toRate!, ok: true, missing: const []);
}

/// Convert [amount] from [from] to [to] using the persisted rates. When a rate
/// is missing this logs a warning and returns the unconverted amount instead of
/// silently treating the currency as 1:1.
num convertCurrency({
  required num amount,
  required String from,
  required String to,
  required Map<String, num> rates,
}) {
  final result = tryConvertCurrency(
    amount: amount,
    from: from,
    to: to,
    rates: rates,
  );
  if (!result.ok) {
    final key = result.missing.join(',');
    if (_warnedMissingRates.add(key)) {
      // ignore: avoid_print
      print(
        'convertCurrency: missing FX rate(s) for $key; using unconverted '
        'amount. Totals may be inaccurate until rates load.',
      );
    }
  }
  return result.value;
}

/// Convenience hook used by widgets that already have access to ref.
CurrencyConvertFn currencyConverter(WidgetRef ref) {
  final rates = ref.watch(currencyRatesProvider);
  return (amount, from, to) => convertCurrency(
        amount: amount,
        from: from,
        to: to,
        rates: rates,
      );
}

typedef CurrencyConvertFn = num Function(num amount, String from, String to);
