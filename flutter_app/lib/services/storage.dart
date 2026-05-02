import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Centralised access to the persistent JSON store.
///
/// Mirrors the role of `idb-keyval` + Zustand `persist` in the React app:
/// every collection is stored as a single JSON-encoded string in a Hive box.
/// This keeps migrations trivial and avoids the `build_runner` step required
/// by typed Hive adapters during the early Flutter port.
class AppStorage {
  AppStorage._();

  static const String _boxName = 'vibesight_v1';
  static late Box<String> _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get box => _box;

  static List<Map<String, dynamic>> readList(String key) {
    final raw = _box.get(key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = json.decode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  static Future<void> writeList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    await _box.put(key, json.encode(value));
  }

  static Map<String, dynamic>? readMap(String key) {
    final raw = _box.get(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = json.decode(raw);
    if (decoded is! Map) return null;
    return decoded.map((k, v) => MapEntry(k.toString(), v));
  }

  static Future<void> writeMap(
    String key,
    Map<String, dynamic> value,
  ) async {
    await _box.put(key, json.encode(value));
  }

  static String? readString(String key) => _box.get(key);

  static Future<void> writeString(String key, String value) =>
      _box.put(key, value);

  static Future<void> remove(String key) => _box.delete(key);

  /// Snapshot every entry of the box as a `{key: decodedJson}` map.
  /// Decoded values may be `Map`, `List`, `String`, `num`, `bool` or null.
  static Map<String, dynamic> dumpAll() {
    final out = <String, dynamic>{};
    for (final k in _box.keys) {
      final raw = _box.get(k as String);
      if (raw == null || raw.isEmpty) continue;
      try {
        out[k] = json.decode(raw);
      } catch (_) {
        out[k] = raw;
      }
    }
    return out;
  }

  /// Replace every key in the box with the supplied snapshot. Keys not
  /// present in [snapshot] are left untouched (use [clearAll] first to
  /// fully reset).
  static Future<void> restoreAll(Map<String, dynamic> snapshot,
      {bool replace = true}) async {
    if (replace) {
      await _box.clear();
    }
    for (final entry in snapshot.entries) {
      final v = entry.value;
      if (v is String) {
        await _box.put(entry.key, v);
      } else {
        await _box.put(entry.key, json.encode(v));
      }
    }
  }
}
