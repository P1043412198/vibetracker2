import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/models/misc.dart';

void main() {
  PasswordEntry base() => PasswordEntry(
        id: 'id-1',
        title: 'GitHub',
        username: 'octocat',
        password: 'hunter2',
        category: 'Работа',
        createdAt: '2026-01-01T00:00:00.000',
        updatedAt: '2026-01-01T00:00:00.000',
        isPinned: false,
      );

  group('PasswordEntry.copyWith', () {
    test('overrides only the given fields', () {
      final updated = base().copyWith(isPinned: true, title: 'GitLab');
      expect(updated.id, 'id-1');
      expect(updated.title, 'GitLab');
      expect(updated.isPinned, true);
      expect(updated.username, 'octocat');
      expect(updated.password, 'hunter2');
    });

    test('keeps unspecified fields unchanged', () {
      final same = base().copyWith();
      expect(same.toJson(), base().toJson());
    });

    test('survives a JSON round-trip', () {
      final back = PasswordEntry.fromJson(base().toJson());
      expect(back.title, 'GitHub');
      expect(back.password, 'hunter2');
      expect(back.category, 'Работа');
    });
  });
}
