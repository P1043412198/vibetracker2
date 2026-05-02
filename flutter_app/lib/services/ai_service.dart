import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'storage.dart';

/// Mirrors `src/services/aiService.ts` for the Flutter port.
///
/// Talks directly to the Gemini REST API so we don't have to ship the
/// `google_generative_ai` Dart package (which significantly bloats the APK).
/// The user supplies their own API key via Settings; we store it in Hive
/// under the key `geminiApiKey`.
class AiService {
  AiService._();

  static const _model = 'gemini-1.5-flash-latest';
  static const _endpointBase =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static String? get apiKey {
    final raw = AppStorage.readString('geminiApiKey');
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  static Future<void> setApiKey(String? key) async {
    final trimmed = key?.trim() ?? '';
    if (trimmed.isEmpty) {
      await AppStorage.remove('geminiApiKey');
    } else {
      await AppStorage.writeString('geminiApiKey', trimmed);
    }
  }

  /// Generate a workout plan. Returns parsed JSON object or null on error.
  ///
  /// Mirrors the schema of `generateWorkout()` in aiService.ts:
  /// `{ title: string, exercises: [{ name, sets, reps, notes }] }`.
  static Future<Map<String, dynamic>?> generateWorkout({
    required List<String> targetMuscleGroups,
    int duration = 60,
    String focus = 'general',
    List<String> equipment = const ['all'],
    List<Map<String, dynamic>> pastLogs = const [],
  }) async {
    final key = apiKey;
    if (key == null) {
      throw const AiServiceException('GEMINI_API_KEY не задан в Настройках.');
    }
    final prompt =
        'Generate a workout plan for today based on past logs, target muscle '
        'groups: ${targetMuscleGroups.join(', ')}, duration: $duration '
        'minutes, focus: $focus, and available equipment: '
        '${equipment.join(', ')}.\n'
        'Past Logs: ${jsonEncode(pastLogs)}\n\n'
        'Return a JSON object with:\n'
        '- title: string\n'
        '- exercises: array of { name: string, sets: number, reps: string, '
        'notes: string }';

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ],
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'exercises': {
              'type': 'ARRAY',
              'items': {
                'type': 'OBJECT',
                'properties': {
                  'name': {'type': 'STRING'},
                  'sets': {'type': 'NUMBER'},
                  'reps': {'type': 'STRING'},
                  'notes': {'type': 'STRING'},
                },
                'required': ['name', 'sets', 'reps'],
              },
            },
          },
          'required': ['title', 'exercises'],
        },
      },
    });

    final uri =
        Uri.parse('$_endpointBase/$_model:generateContent?key=$key');
    final resp = await http.post(uri,
        headers: const {'Content-Type': 'application/json'}, body: body);

    if (resp.statusCode != 200) {
      throw AiServiceException(
          'HTTP ${resp.statusCode}: ${_truncate(resp.body, 200)}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = (data['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) return null;
    final parts = ((candidates.first as Map?)?['content']
            as Map?)?['parts'] as List? ??
        const [];
    if (parts.isEmpty) return null;
    final text = (parts.first as Map?)?['text'] as String?;
    if (text == null) return null;
    try {
      final parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) return parsed;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Plain text generation — used by Predictive Budget for natural-language
  /// insights. Returns the raw model text or throws [AiServiceException].
  static Future<String> generateContent(String prompt) async {
    final key = apiKey;
    if (key == null) {
      throw const AiServiceException('GEMINI_API_KEY не задан в Настройках.');
    }
    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ],
        }
      ],
    });
    final uri =
        Uri.parse('$_endpointBase/$_model:generateContent?key=$key');
    final resp = await http.post(uri,
        headers: const {'Content-Type': 'application/json'}, body: body);
    if (resp.statusCode != 200) {
      throw AiServiceException(
          'HTTP ${resp.statusCode}: ${_truncate(resp.body, 200)}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = (data['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) {
      throw const AiServiceException('Пустой ответ от Gemini.');
    }
    final parts = ((candidates.first as Map?)?['content']
            as Map?)?['parts'] as List? ??
        const [];
    if (parts.isEmpty) {
      throw const AiServiceException('Пустой ответ от Gemini.');
    }
    final text = (parts.first as Map?)?['text'] as String?;
    if (text == null || text.isEmpty) {
      throw const AiServiceException('Пустой ответ от Gemini.');
    }
    return text.trim();
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}

class AiServiceException implements Exception {
  const AiServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reactive notifier so Settings UI can observe key presence.
class GeminiKeyController extends StateNotifier<String?> {
  GeminiKeyController() : super(AiService.apiKey);

  Future<void> save(String? key) async {
    await AiService.setApiKey(key);
    state = AiService.apiKey;
  }
}

final geminiKeyProvider =
    StateNotifierProvider<GeminiKeyController, String?>((ref) {
  return GeminiKeyController();
});
