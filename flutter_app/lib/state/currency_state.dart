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

/// Convert [amount] from [from] to [to] using the persisted rates. Falls
/// back to 1.0 when a rate is missing so the UI stays stable.
num convertCurrency({
  required num amount,
  required String from,
  required String to,
  required Map<String, num> rates,
}) {
  if (from == to) return amount;
  final fromRate = rates[from] ?? 1;
  final toRate = rates[to] ?? 1;
  // Convert via USD anchor: amount_usd = amount * fromRate; result = amount_usd / toRate.
  final inAnchor = amount * fromRate;
  return inAnchor / toRate;
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
