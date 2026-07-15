import 'dart:typed_data';
import 'package:crypto/crypto.dart';

const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

Uint8List _base32Decode(String input) {
  final cleaned = input.replaceAll(RegExp(r'[\s=-]+'), '').toUpperCase();
  final bits = StringBuffer();
  for (final c in cleaned.codeUnits) {
    final idx = _base32Alphabet.indexOf(String.fromCharCode(c));
    if (idx < 0) continue;
    bits.write(idx.toRadixString(2).padLeft(5, '0'));
  }
  final s = bits.toString();
  final bytes = <int>[];
  for (var i = 0; i + 8 <= s.length; i += 8) {
    bytes.add(int.parse(s.substring(i, i + 8), radix: 2));
  }
  return Uint8List.fromList(bytes);
}

/// Generates a TOTP code (RFC 6238).
///
/// [atTime] pins the moment used to derive the counter; defaults to now. It is
/// exposed so the algorithm can be exercised against the RFC 6238 test
/// vectors. [algorithm] selects the HMAC hash (SHA-1 by default, as used by
/// almost every authenticator).
String generateTOTP(
  String secret, {
  int digits = 6,
  int period = 30,
  DateTime? atTime,
  Hash? algorithm,
}) {
  final key = _base32Decode(secret);
  final epoch =
      (atTime ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  final counter = epoch ~/ period;

  final counterBytes = Uint8List(8);
  var c = counter;
  for (var i = 7; i >= 0; i--) {
    counterBytes[i] = c & 0xFF;
    c >>= 8;
  }

  final hmac = Hmac(algorithm ?? sha1, key);
  final hash = hmac.convert(counterBytes).bytes;

  final offset = hash.last & 0x0F;
  final code = ((hash[offset] & 0x7F) << 24 |
          (hash[offset + 1] & 0xFF) << 16 |
          (hash[offset + 2] & 0xFF) << 8 |
          (hash[offset + 3] & 0xFF)) %
      _pow10(digits);

  return code.toString().padLeft(digits, '0');
}

int totpRemainingSeconds({int period = 30}) {
  final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return period - (epoch % period);
}

double totpProgressFraction({int period = 30}) {
  return totpRemainingSeconds(period: period) / period;
}

int _pow10(int n) {
  var result = 1;
  for (var i = 0; i < n; i++) {
    result *= 10;
  }
  return result;
}

String? parseTotpSecretFromUri(String input) {
  if (input.startsWith('otpauth://totp/')) {
    final uri = Uri.tryParse(input);
    if (uri != null) return uri.queryParameters['secret'];
  }
  return input.replaceAll(RegExp(r'\s+'), '');
}
