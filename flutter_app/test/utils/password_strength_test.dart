import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/utils/password_strength.dart';

void main() {
  group('estimatePasswordStrength', () {
    test('empty password scores 0', () {
      expect(estimatePasswordStrength('').score, 0);
    });

    test('short single-class password is weak', () {
      expect(estimatePasswordStrength('abc').score, lessThanOrEqualTo(1));
    });

    test('repeated character is penalised', () {
      expect(estimatePasswordStrength('aaaaaaaa').score, 0);
    });

    test('long multi-class password is strong', () {
      expect(
          estimatePasswordStrength('Xy7!qP2\$mZ9#wL4&').score,
          greaterThanOrEqualTo(4));
    });

    test('score is always within 0..4', () {
      for (final p in ['a', 'Password1', 'aB3\$', 'x' * 40]) {
        final s = estimatePasswordStrength(p).score;
        expect(s, inInclusiveRange(0, 4));
      }
    });
  });
}
