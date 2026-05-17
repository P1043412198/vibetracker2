import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'storage.dart';

/// Anthropic Claude chat service.
///
/// Talks directly to the Anthropic Messages API
/// (https://api.anthropic.com/v1/messages). The user supplies their own API
/// key via Settings — it is stored locally in Hive under `claudeApiKey`. The
/// active model is stored under `claudeModel` and defaults to
/// [defaultModel].
///
/// We never proxy through any backend — the request goes directly to
/// `api.anthropic.com` from the device.
class ClaudeService {
  ClaudeService._();

  static const _defaultModel = 'claude-3-5-sonnet-latest';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';

  static const _availableModels = <String>[
    'claude-3-5-sonnet-latest',
    'claude-3-5-haiku-latest',
    'claude-3-opus-latest',
    'claude-sonnet-4-5',
    'claude-sonnet-4-0',
    'claude-opus-4-1',
    'claude-haiku-4-5',
  ];

  static String get defaultModel => _defaultModel;
  static List<String> get availableModels => List.unmodifiable(_availableModels);

  static String get currentModel {
    final raw = AppStorage.readString('claudeModel');
    if (raw == null || raw.trim().isEmpty) return _defaultModel;
    return raw.trim();
  }

  static Future<void> setModel(String? model) async {
    final trimmed = model?.trim() ?? '';
    if (trimmed.isEmpty) {
      await AppStorage.remove('claudeModel');
    } else {
      await AppStorage.writeString('claudeModel', trimmed);
    }
  }

  static String? get apiKey {
    final raw = AppStorage.readString('claudeApiKey');
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  static Future<void> setApiKey(String? key) async {
    final trimmed = key?.trim() ?? '';
    if (trimmed.isEmpty) {
      await AppStorage.remove('claudeApiKey');
    } else {
      await AppStorage.writeString('claudeApiKey', trimmed);
    }
  }

  static String get systemPrompt {
    final raw = AppStorage.readString('claudeSystemPrompt');
    if (raw == null || raw.trim().isEmpty) return _defaultSystemPrompt;
    return raw;
  }

  static Future<void> setSystemPrompt(String? prompt) async {
    final trimmed = prompt?.trim() ?? '';
    if (trimmed.isEmpty) {
      await AppStorage.remove('claudeSystemPrompt');
    } else {
      await AppStorage.writeString('claudeSystemPrompt', trimmed);
    }
  }

  static const _defaultSystemPrompt =
      'Ты — личный ассистент в трекере привычек, задач, тренировок и финансов. '
      'Отвечай кратко, по делу, по-русски, в стиле дружелюбного коуча. '
      'Когда уместно — используй маркированные списки и конкретные числа. '
      'Никогда не выдумывай данные пользователя.';

  /// Send a chat completion request. [messages] is the conversation history
  /// in Anthropic format (`role: 'user' | 'assistant'`, `content: string`).
  /// Returns the assistant's reply text.
  static Future<String> chat({
    required List<Map<String, String>> messages,
    String? system,
    int maxTokens = 1024,
    double temperature = 0.7,
  }) async {
    final key = apiKey;
    if (key == null) {
      throw const ClaudeServiceException(
          'CLAUDE_API_KEY не задан. Откройте Настройки и вставьте ключ.');
    }

    final body = jsonEncode({
      'model': currentModel,
      'max_tokens': maxTokens,
      'temperature': temperature,
      'system': system ?? systemPrompt,
      'messages': messages,
    });

    http.Response resp;
    try {
      resp = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'x-api-key': key,
          'anthropic-version': _apiVersion,
          'content-type': 'application/json',
          // Required when calling directly from a browser/web build.
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: body,
      );
    } catch (e) {
      throw ClaudeServiceException('Сеть недоступна: $e');
    }

    if (resp.statusCode != 200) {
      throw ClaudeServiceException(
          'HTTP ${resp.statusCode}: ${_truncate(resp.body, 240)}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = (data['content'] as List?) ?? const [];
    if (content.isEmpty) {
      throw const ClaudeServiceException('Пустой ответ от Claude.');
    }
    final parts = <String>[];
    for (final part in content) {
      if (part is Map && part['type'] == 'text') {
        final text = part['text'];
        if (text is String) parts.add(text);
      }
    }
    final text = parts.join('').trim();
    if (text.isEmpty) {
      throw const ClaudeServiceException('Пустой текст в ответе Claude.');
    }
    return text;
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}

class ClaudeServiceException implements Exception {
  const ClaudeServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reactive notifier so Settings UI can observe key/model presence and the
/// chat page can react instantly when either changes.
class ClaudeKeyController extends StateNotifier<String?> {
  ClaudeKeyController() : super(ClaudeService.apiKey);

  Future<void> save(String? key) async {
    await ClaudeService.setApiKey(key);
    state = ClaudeService.apiKey;
  }
}

final claudeKeyProvider =
    StateNotifierProvider<ClaudeKeyController, String?>((ref) {
  return ClaudeKeyController();
});

class ClaudeModelController extends StateNotifier<String> {
  ClaudeModelController() : super(ClaudeService.currentModel);

  Future<void> save(String model) async {
    await ClaudeService.setModel(model);
    state = ClaudeService.currentModel;
  }
}

final claudeModelProvider =
    StateNotifierProvider<ClaudeModelController, String>((ref) {
  return ClaudeModelController();
});
