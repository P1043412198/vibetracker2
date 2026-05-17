import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'storage.dart';

/// Anthropic Claude chat service.
///
/// Talks to the Anthropic Messages API. By default the request goes directly
/// to `https://api.anthropic.com/v1/messages`, but the user can override the
/// endpoint in Settings — useful when Anthropic blocks the user's region
/// (returns HTTP 403 "Request not allowed", e.g. Belarus, Russia) and they
/// route through a self-hosted Cloudflare Worker / nginx proxy.
///
/// All credentials (API key, model, system prompt, custom base URL) are
/// stored locally in Hive. Nothing is sent through a Cognition/Devin backend.
class ClaudeService {
  ClaudeService._();

  static const _defaultModel = 'claude-3-5-sonnet-latest';
  static const _defaultBaseUrl = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';

  /// Path appended to a bare host when the user pastes only the origin of
  /// their proxy (e.g. `https://anth-proxy.workers.dev`).
  static const _endpointSuffix = '/v1/messages';

  static const _availableModels = <String>[
    'claude-opus-4-7',
    'claude-haiku-4-5',
    'claude-opus-4-1',
    'claude-sonnet-4-5',
    'claude-sonnet-4-0',
    'claude-3-5-sonnet-latest',
    'claude-3-5-haiku-latest',
    'claude-3-opus-latest',
  ];

  static String get defaultModel => _defaultModel;
  static String get defaultBaseUrl => _defaultBaseUrl;
  static List<String> get availableModels =>
      List.unmodifiable(_availableModels);

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

  /// Base URL the chat hits. Default is `https://api.anthropic.com/v1/messages`;
  /// users in regions Anthropic refuses (HTTP 403) can paste their own
  /// proxy origin here.
  static String get baseUrl {
    final raw = AppStorage.readString('claudeBaseUrl');
    if (raw == null || raw.trim().isEmpty) return _defaultBaseUrl;
    return raw.trim();
  }

  static Future<void> setBaseUrl(String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == _defaultBaseUrl) {
      await AppStorage.remove('claudeBaseUrl');
    } else {
      await AppStorage.writeString('claudeBaseUrl', trimmed);
    }
  }

  /// Normalise [baseUrl] into a real URI: prepend `https://` if missing,
  /// append `/v1/messages` if the path is empty.
  static Uri get resolvedEndpoint {
    var raw = baseUrl;
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }
    Uri uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      return Uri.parse(_defaultBaseUrl);
    }
    final path = uri.path;
    if (path.isEmpty || path == '/') {
      uri = uri.replace(path: _endpointSuffix);
    }
    return uri;
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

    final endpoint = resolvedEndpoint;
    http.Response resp;
    try {
      resp = await http.post(
        endpoint,
        headers: {
          'x-api-key': key,
          'anthropic-version': _apiVersion,
          'content-type': 'application/json',
          // Required when calling api.anthropic.com directly from a browser
          // build (Flutter web). Harmless on native Android/iOS.
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: body,
      );
    } catch (e) {
      throw ClaudeServiceException('Сеть недоступна: $e');
    }

    if (resp.statusCode != 200) {
      throw ClaudeServiceException(_humanizeError(resp, endpoint));
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

  /// Translate HTTP errors into something a user can act on. We special-case
  /// the most common failures so the message in the chat bubble is helpful
  /// instead of just `HTTP 403: …raw json…`.
  static String _humanizeError(http.Response resp, Uri endpoint) {
    final body = _truncate(resp.body, 280);
    final hitDefault = endpoint.host == 'api.anthropic.com';

    String? hint;
    if (resp.statusCode == 403) {
      hint = hitDefault
          ? 'HTTP 403 — Anthropic заблокировал запрос. Чаще всего это значит:\n'
              '• ваш регион не обслуживается Anthropic (например, Беларусь/РФ);\n'
              '• ключ выдан в воркспейсе без прав на этот endpoint.\n\n'
              'Решение: в Настройках → Claude → Base URL вставьте свой прокси '
              '(Cloudflare Worker / nginx reverse-proxy на api.anthropic.com) — '
              'тогда запросы пойдут через него.'
          : 'HTTP 403 от вашего прокси ($endpoint). Проверьте, что прокси '
              'проксирует POST /v1/messages на api.anthropic.com и пробрасывает '
              'заголовок x-api-key.';
    } else if (resp.statusCode == 401) {
      hint = 'HTTP 401 — ключ не принят. Проверьте, что в Настройках сохранён '
          'актуальный sk-ant-… ключ из console.anthropic.com.';
    } else if (resp.statusCode == 404) {
      hint = hitDefault
          ? 'HTTP 404 — endpoint не найден. Возможно, имя модели устарело — выберите другую в пикере.'
          : 'HTTP 404 — endpoint не найден. Проверьте Base URL прокси: ожидается путь /v1/messages.';
    } else if (resp.statusCode == 429) {
      hint = 'HTTP 429 — Anthropic ограничил частоту. Подождите несколько '
          'секунд и попробуйте ещё раз.';
    } else if (resp.statusCode >= 500) {
      hint = 'HTTP ${resp.statusCode} — на стороне сервера Anthropic ошибка. '
          'Повторите запрос позже.';
    }

    if (hint != null) {
      return '$hint\n\n[raw] $body';
    }
    return 'HTTP ${resp.statusCode}: $body';
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

class ClaudeBaseUrlController extends StateNotifier<String> {
  ClaudeBaseUrlController() : super(ClaudeService.baseUrl);

  Future<void> save(String? url) async {
    await ClaudeService.setBaseUrl(url);
    state = ClaudeService.baseUrl;
  }
}

final claudeBaseUrlProvider =
    StateNotifierProvider<ClaudeBaseUrlController, String>((ref) {
  return ClaudeBaseUrlController();
});
