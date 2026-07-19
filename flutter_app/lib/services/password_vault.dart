import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'storage.dart';

/// Encryption-at-rest for password entries.
///
/// Values are stored in [FlutterSecureStorage], which is backed by the Android
/// Keystore / iOS Keychain, so the password + TOTP blob is never written to the
/// plain Hive box on disk. On first run any legacy plaintext `passwords` list
/// living in Hive is migrated into secure storage and then removed.
class PasswordVault {
  PasswordVault._();

  static final PasswordVault instance = PasswordVault._();

  static const _key = 'passwords';
  static const _legacyKey = 'passwords';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Loads the stored entries, migrating any legacy plaintext data on first
  /// access. Returns a list of JSON maps (same shape the controller expects).
  Future<List<Map<String, dynamic>>> load() async {
    String? raw;
    try {
      raw = await _storage.read(key: _key);
    } catch (_) {
      raw = null;
    }

    if (raw == null) {
      final migrated = await _migrateLegacy();
      if (migrated != null) return migrated;
      return [];
    }
    return _decode(raw);
  }

  Future<void> save(List<Map<String, dynamic>> entries) async {
    await _storage.write(key: _key, value: json.encode(entries));
  }

  /// Reads any plaintext list previously kept in Hive, moves it into secure
  /// storage and clears the plaintext copy. Returns the migrated entries, or
  /// null when there was nothing to migrate.
  Future<List<Map<String, dynamic>>?> _migrateLegacy() async {
    final legacy = AppStorage.readList(_legacyKey);
    if (legacy.isEmpty) return null;
    final entries = legacy
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    await save(entries);
    await AppStorage.remove(_legacyKey);
    return entries;
  }

  List<Map<String, dynamic>> _decode(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }
}
