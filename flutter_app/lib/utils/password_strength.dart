/// Lightweight, dependency-free password strength estimate.
///
/// Returns a [score] from 0 (very weak) to 4 (very strong) based on length and
/// character-class diversity, plus penalties for obvious patterns. This is a
/// heuristic for a local strength meter, not a substitute for a real estimator
/// like zxcvbn.
class PasswordStrength {
  const PasswordStrength(this.score, this.label);

  final int score; // 0..4
  final String label;
}

PasswordStrength estimatePasswordStrength(String password) {
  if (password.isEmpty) return const PasswordStrength(0, 'Пусто');

  final hasLower = RegExp(r'[a-zа-я]').hasMatch(password);
  final hasUpper = RegExp(r'[A-ZА-Я]').hasMatch(password);
  final hasDigit = RegExp(r'\d').hasMatch(password);
  final hasSymbol = RegExp(r'[^A-Za-zА-Яа-я0-9]').hasMatch(password);
  final classes =
      [hasLower, hasUpper, hasDigit, hasSymbol].where((b) => b).length;

  var points = 0;
  final len = password.length;
  if (len >= 8) points++;
  if (len >= 12) points++;
  if (len >= 16) points++;
  points += classes - 1; // 0..3 for extra classes beyond the first

  // Penalise low entropy: a single repeated character or a pure sequence.
  if (RegExp(r'^(.)\1+$').hasMatch(password)) points -= 3;
  if (len < 6) points -= 2;

  final score = points.clamp(0, 4);
  const labels = [
    'Очень слабый',
    'Слабый',
    'Средний',
    'Хороший',
    'Отличный',
  ];
  return PasswordStrength(score, labels[score]);
}
