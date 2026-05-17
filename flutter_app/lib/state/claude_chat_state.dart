import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../services/claude_service.dart';
import '../services/storage.dart';

const _uuid = Uuid();

/// A single chat message persisted in Hive.
class ClaudeMessage {
  ClaudeMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isError = false,
  });

  /// 'user' or 'assistant' — matches Anthropic API.
  final String role;
  final String content;
  final String id;
  final String createdAt;
  final bool isError;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'createdAt': createdAt,
        if (isError) 'isError': true,
      };

  factory ClaudeMessage.fromJson(Map<String, dynamic> j) => ClaudeMessage(
        id: j['id']?.toString() ?? _uuid.v4(),
        role: j['role']?.toString() ?? 'user',
        content: j['content']?.toString() ?? '',
        createdAt: j['createdAt']?.toString() ??
            DateTime.now().toIso8601String(),
        isError: j['isError'] == true,
      );
}

class ClaudeChatState {
  const ClaudeChatState({
    required this.messages,
    required this.busy,
    this.error,
  });

  final List<ClaudeMessage> messages;
  final bool busy;
  final String? error;

  ClaudeChatState copyWith({
    List<ClaudeMessage>? messages,
    bool? busy,
    Object? error = _sentinel,
  }) =>
      ClaudeChatState(
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );

  static const _sentinel = Object();
}

class ClaudeChatController extends StateNotifier<ClaudeChatState> {
  ClaudeChatController()
      : super(const ClaudeChatState(messages: [], busy: false)) {
    _load();
  }

  static const _storageKey = 'claudeChatMessages';

  void _load() {
    final raw = AppStorage.readString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ClaudeMessage.fromJson)
          .toList(growable: true);
      state = state.copyWith(messages: list);
    } catch (_) {
      // corrupt storage — drop silently, user will get a fresh chat.
    }
  }

  Future<void> _persist() async {
    final encoded =
        jsonEncode(state.messages.map((m) => m.toJson()).toList());
    await AppStorage.writeString(_storageKey, encoded);
  }

  Future<void> clear() async {
    state = state.copyWith(messages: [], error: null);
    await AppStorage.remove(_storageKey);
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;

    final user = ClaudeMessage(
      id: _uuid.v4(),
      role: 'user',
      content: trimmed,
      createdAt: DateTime.now().toIso8601String(),
    );
    state = state.copyWith(
      messages: [...state.messages, user],
      busy: true,
      error: null,
    );
    await _persist();

    try {
      // Build conversation payload — drop error messages so we never echo
      // them back to the model as if they were assistant turns.
      final payload = state.messages
          .where((m) => !m.isError)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      final reply = await ClaudeService.chat(messages: payload);
      final assistant = ClaudeMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: reply,
        createdAt: DateTime.now().toIso8601String(),
      );
      state = state.copyWith(
        messages: [...state.messages, assistant],
        busy: false,
      );
      await _persist();
    } catch (e) {
      final msg = e is ClaudeServiceException ? e.message : e.toString();
      final err = ClaudeMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: '⚠️ $msg',
        createdAt: DateTime.now().toIso8601String(),
        isError: true,
      );
      state = state.copyWith(
        messages: [...state.messages, err],
        busy: false,
        error: msg,
      );
      await _persist();
    }
  }

  /// Re-send the last user message. Useful after fixing an error (e.g.
  /// pasting the API key) without retyping.
  Future<void> retryLast() async {
    final lastUser = state.messages.lastWhere(
      (m) => m.role == 'user',
      orElse: () => ClaudeMessage(
        id: '',
        role: 'user',
        content: '',
        createdAt: '',
      ),
    );
    if (lastUser.content.isEmpty) return;
    // Drop any trailing error turns so the retry produces a single new reply.
    final trimmed = [...state.messages];
    while (trimmed.isNotEmpty && trimmed.last.isError) {
      trimmed.removeLast();
    }
    state = state.copyWith(messages: trimmed, error: null);
    await _persist();
    // The last user message is already in the history, so we call the API
    // again with the existing list (no new user turn).
    state = state.copyWith(busy: true);
    try {
      final payload = state.messages
          .where((m) => !m.isError)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      final reply = await ClaudeService.chat(messages: payload);
      final assistant = ClaudeMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: reply,
        createdAt: DateTime.now().toIso8601String(),
      );
      state = state.copyWith(
        messages: [...state.messages, assistant],
        busy: false,
      );
      await _persist();
    } catch (e) {
      final msg = e is ClaudeServiceException ? e.message : e.toString();
      final err = ClaudeMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: '⚠️ $msg',
        createdAt: DateTime.now().toIso8601String(),
        isError: true,
      );
      state = state.copyWith(
        messages: [...state.messages, err],
        busy: false,
        error: msg,
      );
      await _persist();
    }
  }
}

final claudeChatProvider =
    StateNotifierProvider<ClaudeChatController, ClaudeChatState>((ref) {
  return ClaudeChatController();
});
