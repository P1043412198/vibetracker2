import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/utils/totp.dart';

void main() {
  // RFC 6238 Appendix B test vectors for the SHA-1 variant. The shared secret
  // is the ASCII string "12345678901234567890" (20 bytes), whose Base32
  // encoding is the constant below.
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

  String at(int seconds) => generateTOTP(
        secret,
        digits: 8,
        atTime: DateTime.fromMillisecondsSinceEpoch(seconds * 1000,
            isUtc: true),
      );

  group('generateTOTP RFC 6238 vectors (SHA-1)', () {
    test('T = 59', () => expect(at(59), '94287082'));
    test('T = 1111111109', () => expect(at(1111111109), '07081804'));
    test('T = 1111111111', () => expect(at(1111111111), '14050471'));
    test('T = 1234567890', () => expect(at(1234567890), '89005924'));
    test('T = 2000000000', () => expect(at(2000000000), '69279037'));
    test('T = 20000000000', () => expect(at(20000000000), '65353130'));
  });

  test('default 6-digit output has the right shape', () {
    final code = generateTOTP(
      secret,
      atTime: DateTime.fromMillisecondsSinceEpoch(59 * 1000, isUtc: true),
    );
    expect(code.length, 6);
    // Last 6 digits of the 8-digit vector.
    expect(code, '287082');
  });
}
