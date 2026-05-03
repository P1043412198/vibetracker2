import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches FX rates from the National Bank of Belarus (api.nbrb.by) and
/// converts them to the app's USD-anchored representation
/// (`1 unit of CCY = N USD`).
///
/// NBRB returns BYN-per-N-units (e.g. `Cur_Scale: 100, Cur_OfficialRate: 32.55`
/// means 100 RUB = 32.55 BYN, so 1 RUB = 0.3255 BYN). We compute every
/// currency in USD by dividing by the BYN-per-USD reference rate.
class NbrbService {
  NbrbService._();
  static const String _url =
      'https://api.nbrb.by/exrates/rates?periodicity=0';

  /// Currencies we care about. Anything not listed here is ignored.
  static const Set<String> _supported = {
    'USD',
    'EUR',
    'RUB',
    'PLN',
    'GBP',
    'CHF',
    'CNY',
    'KZT',
    'TRY',
  };

  /// Returns USD-anchored rates: `1 unit of code = rates[code] USD`.
  /// Always includes `USD: 1.0` and `BYN: <byn-per-usd inverse>` if usd row
  /// is present. Throws on network/parse failure so the UI can show error.
  static Future<Map<String, num>> fetchUsdAnchoredRates() async {
    final res = await http
        .get(Uri.parse(_url))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('NBRB ${res.statusCode}');
    }
    final raw = json.decode(res.body);
    if (raw is! List) {
      throw Exception('NBRB: unexpected payload');
    }
    final List rows = raw;

    // Find USD-per-BYN reference: NBRB gives BYN-per-N-USD. We want USD/BYN.
    num? bynPerUsd;
    for (final r in rows) {
      if (r is Map &&
          (r['Cur_Abbreviation'] ?? '') == 'USD') {
        final scale = (r['Cur_Scale'] as num?) ?? 1;
        final rate = (r['Cur_OfficialRate'] as num?);
        if (rate != null && scale > 0) {
          bynPerUsd = rate / scale; // BYN per 1 USD
        }
        break;
      }
    }
    if (bynPerUsd == null || bynPerUsd <= 0) {
      throw Exception('NBRB: USD rate missing');
    }

    final result = <String, num>{
      'USD': 1.0,
      'BYN': 1.0 / bynPerUsd,
    };
    for (final r in rows) {
      if (r is! Map) continue;
      final code = (r['Cur_Abbreviation'] ?? '') as String;
      if (!_supported.contains(code) || code == 'USD') continue;
      final scale = (r['Cur_Scale'] as num?) ?? 1;
      final rate = (r['Cur_OfficialRate'] as num?);
      if (rate == null || scale <= 0) continue;
      // BYN per 1 unit of code:
      final bynPerCode = rate / scale;
      // USD per 1 unit of code:
      result[code] = bynPerCode / bynPerUsd;
    }
    return result;
  }
}
