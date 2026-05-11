import 'dart:convert';

import 'ai_service.dart';

/// High-level Gemini helpers for Wave 2 AI features.
///
/// All methods rely on [AiService.generateContent] /
/// [AiService.generateJson] under the hood, so they respect the same
/// API key stored in Hive and throw [AiServiceException] on errors.
class GeminiService {
  GeminiService._();

  // ───────────────────────────── Inbox ─────────────────────────────

  /// Classify an inbox entry into one of the supported targets.
  ///
  /// Returns a JSON map with:
  /// - `type`: `task` | `expense` | `link` | `reminder` | `note` | `habit`
  /// - `confidence`: 0.0–1.0
  /// - `suggestedTitle`: short cleaned-up title for the target entity
  /// - `suggestedCategory`: optional category / sphere hint
  /// - `suggestedDate`: optional ISO date if a temporal reference is found
  /// - `suggestedAmount`: optional number if an expense reference is found
  /// - `suggestedCurrency`: optional currency code (BYN/USD/EUR/RUB)
  static Future<Map<String, dynamic>?> classifyInbox(String text) async {
    final prompt = '''
Classify the following inbox message into exactly one type.
Types: task, expense, link, reminder, note, habit.

Rules:
- If the text mentions money, a price, or a purchase → expense
- If the text looks like an action item / TODO → task
- If the text contains a URL → link
- If the text mentions a time or "напомни" / "remind" → reminder
- If the text describes a recurring activity → habit
- Otherwise → note

Extract any amount, currency, date, and suggest a clean title.

Message:
"""$text"""

Return ONLY valid JSON (no markdown fences):
{
  "type": "...",
  "confidence": 0.85,
  "suggestedTitle": "...",
  "suggestedCategory": "...",
  "suggestedDate": "YYYY-MM-DD or null",
  "suggestedAmount": null or number,
  "suggestedCurrency": "BYN or null"
}''';
    return AiService.generateJson(prompt);
  }

  /// Parse a free-text expense description into a structured transaction.
  static Future<Map<String, dynamic>?> parseExpense(String text) async {
    final prompt = '''
Parse the following text as a financial expense/income.

Text:
"""$text"""

Return ONLY valid JSON (no markdown fences):
{
  "title": "short description",
  "amount": 50.0,
  "currency": "BYN",
  "category": "Еда" or other category,
  "type": "expense" or "income",
  "date": "YYYY-MM-DD"
}''';
    return AiService.generateJson(prompt);
  }

  // ────────────────────── Financial Coach ──────────────────────────

  /// Analyse a month's financial plan and return coaching advice as markdown.
  static Future<String> coachMonth({
    required String monthLabel,
    required double planIncome,
    required double planExpense,
    required double planSavings,
    required double planDebt,
    required double factIncome,
    required double factExpense,
    required List<Map<String, dynamic>> sections,
  }) async {
    final prompt = '''
Ты — персональный финансовый коуч. Пользователь ведёт бюджет в Беларуси (BYN).
Проанализируй месячный план и факт, дай краткие рекомендации на русском языке.

Месяц: $monthLabel
План: доход $planIncome BYN, расход $planExpense BYN, сбережения $planSavings BYN, долги $planDebt BYN
Факт: доход $factIncome BYN, расход $factExpense BYN

Секции плана:
${jsonEncode(sections)}

Дай ответ в Markdown (заголовки ##, списки, жирный текст). Включи:
1. Краткую оценку (хорошо / есть проблемы)
2. Где перерасход или экономия
3. 2–3 конкретных совета
4. Прогноз остатка к концу месяца (если есть факт)

Будь кратким (до 300 слов).''';
    return AiService.generateContent(prompt);
  }

  /// Suggest a plan structure for a new month based on historical data.
  static Future<String> suggestMonthStructure({
    required String monthLabel,
    required List<Map<String, dynamic>> previousMonths,
  }) async {
    final prompt = '''
На основе истории прошлых месяцев предложи структуру финплана на $monthLabel.
Отвечай на русском. Формат: Markdown.

История:
${jsonEncode(previousMonths)}

Предложи секции (доход, расход, сбережения, долги) со статьями и примерными суммами.
Кратко (до 200 слов).''';
    return AiService.generateContent(prompt);
  }

  /// Explain a plan-vs-fact discrepancy for a section.
  static Future<String> explainDiscrepancy({
    required String sectionName,
    required double planned,
    required double actual,
    required String kind,
  }) async {
    final diff = actual - planned;
    final prompt = '''
Объясни расхождение плана и факта по секции «$sectionName» ($kind).
Запланировано: $planned BYN, Факт: $actual BYN, Разница: $diff BYN.
Дай краткое объяснение и совет (2–3 предложения, русский язык).''';
    return AiService.generateContent(prompt);
  }

  // ──────────────────── Receipt Parsing ────────────────────────────

  /// Parse OCR text from a receipt into structured transaction data.
  static Future<Map<String, dynamic>?> parseReceipt(String ocrText) async {
    final prompt = '''
Проанализируй OCR-текст белорусского чека и извлеки данные.

OCR текст:
"""$ocrText"""

Return ONLY valid JSON (no markdown fences):
{
  "store": "название магазина",
  "date": "YYYY-MM-DD",
  "total": 45.50,
  "currency": "BYN",
  "items": [
    {"name": "Молоко", "qty": 1, "price": 3.50, "category": "Еда"},
    {"name": "Хлеб", "qty": 2, "price": 1.20, "category": "Еда"}
  ],
  "suggestedCategory": "Продукты"
}''';
    return AiService.generateJson(prompt);
  }

  // ──────────────────────── Spheres ────────────────────────────────

  /// Generate a summary for a life sphere based on its recent activity.
  static Future<String> summarizeSphere({
    required String sphereTitle,
    required int notesCount,
    required int tasksTotal,
    required int tasksCompleted,
    required int habitsCount,
    required int categoriesCount,
    required List<String> recentNotes,
    required List<String> recentTasks,
  }) async {
    final prompt = '''
Сделай краткую еженедельную сводку по сфере жизни «$sphereTitle» (русский язык, Markdown).

Статистика:
- Заметок: $notesCount
- Задач: $tasksTotal (выполнено: $tasksCompleted)
- Привычек: $habitsCount
- Категорий: $categoriesCount

Последние заметки: ${recentNotes.take(5).join('; ')}
Последние задачи: ${recentTasks.take(5).join('; ')}

Дай:
1. Краткую оценку активности
2. Что идёт хорошо
3. Что можно улучшить
4. Одну конкретную рекомендацию

До 150 слов.''';
    return AiService.generateContent(prompt);
  }

  // ──────────────────── Search / Explain ───────────────────────────

  /// Natural-language search: takes a query and structured data, returns
  /// a markdown answer.
  static Future<String> naturalSearch({
    required String query,
    required Map<String, dynamic> context,
  }) async {
    final prompt = '''
Пользователь ищет: «$query»

Данные приложения (JSON):
${jsonEncode(context)}

Найди релевантную информацию и дай краткий ответ на русском (Markdown).
Если ничего не нашлось, так и скажи. До 100 слов.''';
    return AiService.generateContent(prompt);
  }

  /// Explain a chart / numeric summary to the user.
  static Future<String> explainChart({
    required String chartTitle,
    required Map<String, dynamic> data,
  }) async {
    final prompt = '''
Объясни пользователю график «$chartTitle» простым языком (русский, Markdown).

Данные:
${jsonEncode(data)}

Кратко: что показывает, ключевые выводы, тренды. До 100 слов.''';
    return AiService.generateContent(prompt);
  }
}
