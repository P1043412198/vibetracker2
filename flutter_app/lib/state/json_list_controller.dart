import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage.dart';

/// Generic Riverpod state-notifier that owns a list of `T` persisted as JSON
/// in the shared Hive box. Each entity has a typed [fromJson]/[toJson] which
/// makes adding a new model just a matter of writing two converters.
abstract class JsonListController<T> extends StateNotifier<List<T>> {
  JsonListController({
    required this.storageKey,
    required this.fromJson,
    required this.toJson,
  }) : super(const []) {
    _load();
  }

  final String storageKey;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  void _load() {
    final raw = AppStorage.readList(storageKey);
    state = raw.map(fromJson).toList(growable: false);
  }

  Future<void> _persist() async {
    await AppStorage.writeList(
      storageKey,
      state.map(toJson).toList(growable: false),
    );
  }

  String idOf(T item);

  Future<void> add(T item) async {
    state = [...state, item];
    await _persist();
  }

  Future<void> upsert(T item) async {
    final id = idOf(item);
    final existingIndex = state.indexWhere((e) => idOf(e) == id);
    if (existingIndex == -1) {
      state = [...state, item];
    } else {
      final next = [...state];
      next[existingIndex] = item;
      state = next;
    }
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((e) => idOf(e) != id).toList(growable: false);
    await _persist();
  }

  /// Apply [transform] to the entry with [id] in place. No-op if missing.
  Future<void> update(String id, T Function(T) transform) async {
    bool changed = false;
    final next = state.map((e) {
      if (idOf(e) != id) return e;
      changed = true;
      return transform(e);
    }).toList(growable: false);
    if (!changed) return;
    state = next;
    await _persist();
  }

  Future<void> replaceAll(List<T> items) async {
    state = List.unmodifiable(items);
    await _persist();
  }
}
