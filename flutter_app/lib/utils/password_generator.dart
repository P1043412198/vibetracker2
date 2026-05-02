import 'dart:math';

class ParanoiaLevel {
  final int value;
  final String label;
  final String desc;
  final int length;
  final String chars;

  const ParanoiaLevel({
    required this.value,
    required this.label,
    required this.desc,
    required this.length,
    required this.chars,
  });
}

const paranoiaLevels = [
  ParanoiaLevel(
    value: 1,
    label: 'Для форума',
    desc: '8 символов, буквы и цифры',
    length: 8,
    chars: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
  ),
  ParanoiaLevel(
    value: 2,
    label: 'Стандарт',
    desc: '12 символов, спецсимволы',
    length: 12,
    chars: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*',
  ),
  ParanoiaLevel(
    value: 3,
    label: 'Секретный агент',
    desc: '16 символов, сложный микс',
    length: 16,
    chars: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()_+-=[]{}|;:,.<>?',
  ),
  ParanoiaLevel(
    value: 4,
    label: 'Шапочка из фольги',
    desc: '32 символа, полная жесть',
    length: 32,
    chars: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()_+-=[]{}|;:,.<>?~`',
  ),
];

String generatePassword(int levelIndex) {
  final config = paranoiaLevels[levelIndex.clamp(0, paranoiaLevels.length - 1)];
  final rng = Random.secure();
  return List.generate(
    config.length,
    (_) => config.chars[rng.nextInt(config.chars.length)],
  ).join();
}
