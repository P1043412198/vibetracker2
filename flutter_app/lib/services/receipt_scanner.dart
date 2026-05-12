import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ai_service.dart';
import 'gemini_service.dart';

/// Best-effort OCR-based parser for paper receipts.
/// Pulls four signals from the recognized text:
///   - merchant: the first reasonably long non-numeric line
///   - date: first line matching `dd.MM.yyyy` / `yyyy-MM-dd` / `dd/MM/yy`
///   - total: the largest currency-shaped number on the receipt
///   - line items: rows looking like `<name> ... <price>`
///
/// Heuristic only — the user always reviews and confirms before save.
class ReceiptScanner {
  ReceiptScanner._();
  static final ReceiptScanner instance = ReceiptScanner._();

  // Latin script covers Cyrillic too on Android via base latin pack; Belarus
  // receipts mix Russian/Belarusian/English so latin script is enough.
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<ReceiptScanResult> scan(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(input);

    final allLines = <String>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final t = line.text.trim();
        if (t.isNotEmpty) allLines.add(t);
      }
    }

    return _parseLines(allLines);
  }

  ReceiptScanResult _parseLines(List<String> lines) {
    String? merchant;
    String? dateIso;
    num? total;
    final items = <ReceiptLineItem>[];

    final dateRegex = RegExp(
      r'(\d{1,2})[.\-/ ](\d{1,2})[.\-/ ](\d{2,4})|(\d{4})[.\-/ ](\d{1,2})[.\-/ ](\d{1,2})',
    );
    final amountRegex = RegExp(r'(\d{1,5}(?:[.,]\d{2}))(?!\d)');
    final totalKeyword = RegExp(
      r'итог|итого|всего|total|разам|сума|к ?оплате|к ?аплаце|до ?оплаты',
      caseSensitive: false,
    );

    final candidateAmounts = <num>[];

    for (final raw in lines) {
      final line = raw.replaceAll('\u00A0', ' ');
      // Date.
      if (dateIso == null) {
        final m = dateRegex.firstMatch(line);
        if (m != null) {
          dateIso = _normalizeDate(m);
        }
      }
      // Merchant: first long-ish non-numeric, non-date line.
      if (merchant == null &&
          line.length >= 4 &&
          !RegExp(r'^[\d\s.,:/-]+$').hasMatch(line) &&
          !dateRegex.hasMatch(line)) {
        merchant = line;
      }
      // Amounts.
      for (final am in amountRegex.allMatches(line)) {
        final raw = am.group(1)!.replaceAll(',', '.');
        final v = num.tryParse(raw);
        if (v != null) candidateAmounts.add(v);
      }
      // "ИТОГО 12,34" — strong total signal.
      if (total == null && totalKeyword.hasMatch(line)) {
        final m = amountRegex.firstMatch(line);
        if (m != null) {
          total = num.tryParse(m.group(1)!.replaceAll(',', '.'));
        }
      }
      // Line items: name + trailing price.
      final tail = amountRegex.allMatches(line).toList();
      if (tail.isNotEmpty) {
        final last = tail.last;
        final price = num.tryParse(last.group(1)!.replaceAll(',', '.'));
        final name = line.substring(0, last.start).trim();
        if (price != null && name.length >= 2 && !totalKeyword.hasMatch(name)) {
          items.add(ReceiptLineItem(name: name, price: price));
        }
      }
    }

    total ??= candidateAmounts.isEmpty
        ? null
        : candidateAmounts.reduce((a, b) => a >= b ? a : b);

    return ReceiptScanResult(
      merchant: merchant,
      dateIso: dateIso,
      total: total,
      items: items,
    );
  }

  String? _normalizeDate(RegExpMatch m) {
    int? y, mo, d;
    if (m.group(1) != null) {
      d = int.tryParse(m.group(1)!);
      mo = int.tryParse(m.group(2)!);
      y = int.tryParse(m.group(3)!);
      if (y != null && y < 100) y += 2000;
    } else {
      y = int.tryParse(m.group(4)!);
      mo = int.tryParse(m.group(5)!);
      d = int.tryParse(m.group(6)!);
    }
    if (y == null || mo == null || d == null) return null;
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return '${y.toString().padLeft(4, '0')}-'
        '${mo.toString().padLeft(2, '0')}-'
        '${d.toString().padLeft(2, '0')}';
  }

  /// OCR + Gemini: scan an image and let AI extract structured data.
  /// Falls back to heuristic [scan] if the API key is missing.
  Future<ReceiptScanResult> scanWithAi(String imagePath) async {
    final key = AiService.apiKey;
    final base = await scan(imagePath);

    if (key == null || key.isEmpty) return base;

    // Re-read OCR lines for the AI prompt.
    final input = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(input);
    final sb = StringBuffer();
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        sb.writeln(line.text.trim());
      }
    }
    final ocrText = sb.toString().trim();
    if (ocrText.isEmpty) return base;

    try {
      final aiResult = await GeminiService.parseReceipt(ocrText);
      if (aiResult == null) return base;

      final aiItems = (aiResult['items'] as List?)
              ?.whereType<Map>()
              .map((m) => ReceiptLineItem(
                    name: (m['name'] ?? '') as String,
                    price: (m['price'] as num?) ?? 0,
                    category: m['category'] as String?,
                  ))
              .toList() ??
          [];

      return ReceiptScanResult(
        merchant: (aiResult['store'] as String?) ?? base.merchant,
        dateIso: (aiResult['date'] as String?) ?? base.dateIso,
        total: (aiResult['total'] as num?) ?? base.total,
        items: aiItems.isNotEmpty ? aiItems : base.items,
        suggestedCategory: aiResult['suggestedCategory'] as String?,
      );
    } catch (_) {
      return base;
    }
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}

class ReceiptScanResult {
  ReceiptScanResult({
    this.merchant,
    this.dateIso,
    this.total,
    this.items = const [],
    this.suggestedCategory,
  });

  final String? merchant;
  final String? dateIso;
  final num? total;
  final List<ReceiptLineItem> items;
  final String? suggestedCategory;

  bool get isEmpty => merchant == null && dateIso == null && total == null;
}

class ReceiptLineItem {
  ReceiptLineItem({required this.name, required this.price, this.category});
  final String name;
  final num price;
  final String? category;
}
