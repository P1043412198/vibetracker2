import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../ai/claude_tools.dart';
import '../services/claude_service.dart';
import '../services/storage.dart';
import 'settings_state.dart';
import 'tool_confirmation_state.dart';

const _uuid = Uuid();

/// A record of a single tool invocation performed during one assistant turn.
/// Stored on the [ClaudeMessage] so we can render it as a chip in the chat
/// AND replay the conversation as proper Anthropic content blocks on the
/// next request (Claude needs to see its own tool_use + the tool_result).
class ChatToolCall {
  ChatToolCall({
    required this.id,
    required this.name,
    required this.input,
    required this.result,
    this.isError = false,
  });

  /// Anthropic-issued `tool_use_id` — must be echoed back in `tool_result`.
  final String id;
  final String name;
  final Map<String, dynamic> input;
  final String result;
  final bool isError;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'input': input,
        'result': result,
        if (isError) 'isError': true,
      };

  factory ChatToolCall.fromJson(Map<String, dynamic> j) => ChatToolCall(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        input: (j['input'] as Map?)?.cast<String, dynamic>() ?? const {},
        result: j['result']?.toString() ?? '',
        isError: j['isError'] == true,
      );
}

/// A single chat message persisted in Hive. Can carry both text (the
/// assistant's prose) and a list of tool calls executed in the same turn.
class ClaudeMessage {
  ClaudeMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isError = false,
    this.toolCalls = const [],
  });

  /// 'user' or 'assistant' — matches Anthropic API.
  final String role;
  final String content;
  final String id;
  final String createdAt;
  final bool isError;
  final List<ChatToolCall> toolCalls;

  bool get hasToolCalls => toolCalls.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'createdAt': createdAt,
        if (isError) 'isError': true,
        if (toolCalls.isNotEmpty)
          'toolCalls': toolCalls.map((t) => t.toJson()).toList(),
      };

  factory ClaudeMessage.fromJson(Map<String, dynamic> j) => ClaudeMessage(
        id: j['id']?.toString() ?? _uuid.v4(),
        role: j['role']?.toString() ?? 'user',
        content: j['content']?.toString() ?? '',
        createdAt: j['createdAt']?.toString() ??
            DateTime.now().toIso8601String(),
        isError: j['isError'] == true,
        toolCalls: (j['toolCalls'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    ChatToolCall.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

class ClaudeChatState {
  const ClaudeChatState({
    required this.messages,
    required this.busy,
    this.error,
    this.busyStatus,
  });

  final List<ClaudeMessage> messages;
  final bool busy;
  final String? error;

  /// Short label shown while [busy], e.g. "Думаю…", "Вызываю add_task…".
  final String? busyStatus;

  ClaudeChatState copyWith({
    List<ClaudeMessage>? messages,
    bool? busy,
    Object? error = _sentinel,
    Object? busyStatus = _sentinel,
  }) =>
      ClaudeChatState(
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
        error: identical(error, _sentinel) ? this.error : error as String?,
        busyStatus: identical(busyStatus, _sentinel)
            ? this.busyStatus
            : busyStatus as String?,
      );

  static const _sentinel = Object();
}

class ClaudeChatController extends StateNotifier<ClaudeChatState> {
  ClaudeChatController(this._ref)
      : super(const ClaudeChatState(messages: [], busy: false)) {
    _load();
  }

  final Ref _ref;
  static const _storageKey = 'claudeChatMessages';
  static const _maxToolLoops = 8;

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
    state = state.copyWith(
      messages: [],
      error: null,
      busyStatus: null,
    );
    await AppStorage.remove(_storageKey);
  }

  /// Build the Anthropic-format payload from our [messages] list. Drops
  /// error turns (we never feed our own error blurbs back to the model)
  /// and re-hydrates `tool_use` + `tool_result` blocks from [ChatToolCall]
  /// records so Claude sees a coherent history.
  List<Map<String, dynamic>> _buildPayload() {
    final out = <Map<String, dynamic>>[];
    for (final m in state.messages) {
      if (m.isError) continue;
      if (m.role == 'user') {
        out.add({'role': 'user', 'content': m.content});
        continue;
      }
      // role == 'assistant'
      if (m.toolCalls.isEmpty) {
        out.add({'role': 'assistant', 'content': m.content});
        continue;
      }
      // Assistant turn with tool calls. Anthropic expects an assistant
      // message with text + tool_use blocks, immediately followed by a
      // user message containing tool_result blocks.
      final assistantBlocks = <Map<String, dynamic>>[];
      if (m.content.isNotEmpty) {
        assistantBlocks.add({'type': 'text', 'text': m.content});
      }
      for (final t in m.toolCalls) {
        assistantBlocks.add({
          'type': 'tool_use',
          'id': t.id,
          'name': t.name,
          'input': t.input,
        });
      }
      out.add({'role': 'assistant', 'content': assistantBlocks});

      final toolResults = <Map<String, dynamic>>[];
      for (final t in m.toolCalls) {
        toolResults.add({
          'type': 'tool_result',
          'tool_use_id': t.id,
          'content': t.result,
          if (t.isError) 'is_error': true,
        });
      }
      out.add({'role': 'user', 'content': toolResults});
    }
    return out;
  }

  /// Execute a single tool by name, returning the JSON string result and
  /// whether the tool errored out. For [ClaudeTool.destructive] tools, we
  /// first surface a confirmation dialog via [toolConfirmationProvider] and
  /// short-circuit with a "cancelled" tool_result if the user declines.
  Future<({String result, bool isError})> _runTool(
      String name, Map<String, dynamic> input) async {
    final matches = claudeToolRegistry.where((t) => t.name == name);
    if (matches.isEmpty) {
      return (
        result: jsonEncode({'error': 'Unknown tool: $name'}),
        isError: true,
      );
    }
    final tool = matches.first;

    if (tool.destructive) {
      state = state.copyWith(busyStatus: 'Жду подтверждения для $name…');
      final ok = await _ref
          .read(toolConfirmationProvider.notifier)
          .request(name, input);
      if (!ok) {
        return (
          result: jsonEncode({
            'ok': false,
            'cancelled': true,
            'reason':
                'Пользователь отклонил вызов $name. Не повторяй автоматически — '
                'спроси, что делать дальше.',
          }),
          isError: false,
        );
      }
      state = state.copyWith(busyStatus: 'Вызываю $name…');
    }

    try {
      final result = await tool.handler(_ref, input);
      return (result: result, isError: false);
    } catch (e) {
      // Intentionally drop the stack trace — it can leak local file paths
      // back to Anthropic on the next request. The message alone is enough
      // for Claude to recover or apologise.
      return (
        result: jsonEncode({'error': e.toString()}),
        isError: true,
      );
    }
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
      busyStatus: 'Думаю…',
    );
    await _persist();
    await _runClaudeLoop();
  }

  /// Run the tool-use loop: send messages → if response has tool_use,
  /// execute tools and feed results back → repeat until pure-text response
  /// or [_maxToolLoops] is exceeded.
  Future<void> _runClaudeLoop() async {
    try {
      final toolsEnabled = _ref.read(claudeToolsEnabledProvider);
      final tools = toolsEnabled
          ? claudeToolRegistry.map((t) => t.toApiJson()).toList()
          : null;

      for (var loop = 0; loop < _maxToolLoops; loop++) {
        state = state.copyWith(busyStatus: 'Думаю…');
        final resp = await ClaudeService.chatRaw(
          messages: _buildPayload(),
          tools: tools,
        );

        final textBlocks = resp.content
            .whereType<ClaudeTextBlock>()
            .map((b) => b.text)
            .join('')
            .trim();

        if (!resp.hasToolUse) {
          // Final text — append and exit.
          final assistant = ClaudeMessage(
            id: _uuid.v4(),
            role: 'assistant',
            content: textBlocks.isEmpty
                ? '(Claude вернул пустой ответ)'
                : textBlocks,
            createdAt: DateTime.now().toIso8601String(),
          );
          state = state.copyWith(
            messages: [...state.messages, assistant],
            busy: false,
            busyStatus: null,
          );
          await _persist();
          return;
        }

        // Tool-use turn: execute each tool, persist as a single assistant
        // message that carries both the assistant prose AND the calls, then
        // loop back so the next request includes the tool_results.
        final calls = <ChatToolCall>[];
        for (final tu in resp.toolUses) {
          state = state.copyWith(busyStatus: 'Вызываю ${tu.name}…');
          final r = await _runTool(tu.name, tu.input);
          calls.add(ChatToolCall(
            id: tu.id,
            name: tu.name,
            input: tu.input,
            result: r.result,
            isError: r.isError,
          ));
        }
        final assistant = ClaudeMessage(
          id: _uuid.v4(),
          role: 'assistant',
          content: textBlocks,
          createdAt: DateTime.now().toIso8601String(),
          toolCalls: calls,
        );
        state = state.copyWith(
          messages: [...state.messages, assistant],
        );
        await _persist();
      }

      // Exceeded loop budget — bail out gracefully.
      final err = ClaudeMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: '⚠️ Слишком много вызовов tools подряд ($_maxToolLoops). '
            'Прерываю, чтобы не зациклиться.',
        createdAt: DateTime.now().toIso8601String(),
        isError: true,
      );
      state = state.copyWith(
        messages: [...state.messages, err],
        busy: false,
        error: 'Tool-loop overflow',
        busyStatus: null,
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
        busyStatus: null,
      );
      await _persist();
    }
  }

  /// Re-send the last user message. Useful after fixing an error (e.g.
  /// pasting the API key) without retyping.
  Future<void> retryLast() async {
    final lastUserIdx =
        state.messages.lastIndexWhere((m) => m.role == 'user');
    if (lastUserIdx == -1) return;
    final trimmed = state.messages.sublist(0, lastUserIdx + 1);
    state = state.copyWith(
      messages: trimmed,
      error: null,
      busy: true,
      busyStatus: 'Повторяю…',
    );
    await _persist();
    await _runClaudeLoop();
  }
}

final claudeChatProvider =
    StateNotifierProvider<ClaudeChatController, ClaudeChatState>((ref) {
  return ClaudeChatController(ref);
});
