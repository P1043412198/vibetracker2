import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'claude_service.dart';
import 'storage.dart';

/// Generic AI service used by feature-level code (predictive budget,
/// receipt scanner, receipt-driven inbox, etc.). All calls now route
/// through [ClaudeService] — the legacy Gemini code has been removed.
/// The public API ([generateContent], [generateJson], [generateWorkout])
/// is unchanged so existing callers keep working.
class AiService {
  AiService._();

  static const _systemPrompt =
      'Ты — генеративный API. Возвращай только то, что просит prompt. '
      'Никаких пояснений, никакого markdown — если prompt просит JSON, '
      'возвращай чистый JSON без обрамления ```json. Если просит текст — '
      'возвращай только текст без префиксов вроде "Конечно," или "Вот".';

  /// Backwards-compat key the React/Flutter UI may still ask about. The
  /// underlying credential is now [ClaudeService.apiKey]; the Gemini tile
  /// is hidden in Settings. This getter exists so callers that probe for
  /// "is there an AI key at all" keep returning `true` after migration.
  static String? get apiKey {
    final claude = ClaudeService.apiKey;
    if (claude != null && claude.isNotEmpty) return claude;
    // Legacy stored Gemini key — kept for backup/restore compatibility
    // only, never sent anywhere now.
    final legacy = AppStorage.readString('geminiApiKey');
    return (legacy == null || legacy.isEmpty) ? null : legacy;
  }

  /// No-op kept for backup/restore compatibility — the new AI flow uses
  /// [ClaudeService.setApiKey] instead.
  static Future<void> setApiKey(String? key) async {
    final trimmed = key?.trim() ?? '';
    if (trimmed.isEmpty) {
      await AppStorage.remove('geminiApiKey');
    } else {
      await AppStorage.writeString('geminiApiKey', trimmed);
    }
  }

  static String get currentModel => ClaudeService.currentModel;

  /// Plain text generation — used by Predictive Budget for natural-language
  /// insights and several other feature pages. Returns the raw model text.
  static Future<String> generateContent(String prompt) async {
    try {
      return await ClaudeService.chat(
        messages: [
          {'role': 'user', 'content': prompt},
        ],
        system: _systemPrompt,
        maxTokens: 2048,
        temperature: 0.4,
      );
    } on ClaudeServiceException catch (e) {
      throw AiServiceException(e.message);
    }
  }

  /// Convenience: call [generateContent] and parse the response as JSON.
  /// Strips markdown fences if Claude wraps the output in ```json…```.
  static Future<Map<String, dynamic>?> generateJson(String prompt) async {
    final raw = await generateContent(prompt);
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```\w*\n?'), '')
          .replaceFirst(RegExp(r'\n?```$'), '');
    }
    try {
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
    // Some models emit prose before the JSON block — grab the first balanced
    // {...} substring if direct parse fails.
    final braceStart = cleaned.indexOf('{');
    final braceEnd = cleaned.lastIndexOf('}');
    if (braceStart != -1 && braceEnd > braceStart) {
      try {
        final parsed =
            jsonDecode(cleaned.substring(braceStart, braceEnd + 1));
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {}
    }
    return null;
  }

  /// Generate a workout plan. Returns parsed JSON object or null on error.
  ///
  /// Schema: `{ title: string, exercises: [{ name, sets, reps, notes }] }`.
  static Future<Map<String, dynamic>?> generateWorkout({
    required List<String> targetMuscleGroups,
    int duration = 60,
    String focus = 'general',
    List<String> equipment = const ['all'],
    List<Map<String, dynamic>> pastLogs = const [],
  }) async {
    final prompt = '''
Сформируй план тренировки на сегодня. Целевые группы мышц: ${targetMuscleGroups.join(', ')}.
Длительность: $duration минут. Фокус: $focus. Оборудование: ${equipment.join(', ')}.
История последних тренировок (JSON): ${jsonEncode(pastLogs)}

Верни ТОЛЬКО JSON-объект (без обрамления ```), точно такой формы:
{
  "title": "string — короткое название (3-5 слов)",
  "exercises": [
    {
      "name": "string — название упражнения",
      "sets": <number — кол-во подходов>,
      "reps": "string — формат повторов, напр. \\"10-12\\" или \\"30 сек\\"",
      "notes": "string — короткая подсказка по технике"
    }
  ]
}

Никакого текста до или после JSON.
''';
    return generateJson(prompt);
  }
}

class AiServiceException implements Exception {
  const AiServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reactive notifier kept for backup/restore compatibility. Now mirrors
/// [ClaudeService.apiKey] — the Settings UI tile points at Claude instead
/// of the (removed) Gemini integration.
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
