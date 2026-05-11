import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';
import '../../state/providers.dart';

/// QR scanner that parses Belarusian fiscal-receipt QR payloads.
///
/// The Belarus fiscal-receipt QR contains semicolon-separated fields:
///   `<terminal>;<seq>;<DD-MM-YYYY HH:MM>;<amount>;<UNN>;<n>;<m>;<sign>`
/// We extract amount and date and pre-fill a transaction draft. The user
/// confirms category and saves; the receipt URL (if any) lives in `notes`.
class QrReceiptScannerPage extends ConsumerStatefulWidget {
  const QrReceiptScannerPage({super.key});

  @override
  ConsumerState<QrReceiptScannerPage> createState() =>
      _QrReceiptScannerPageState();
}

class _QrReceiptScannerPageState extends ConsumerState<QrReceiptScannerPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Скан QR чека'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) => _onDetect(capture),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Наведи камеру на QR-код в чеке.\n'
              'Поддерживаются белорусские фискальные чеки.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    HapticFeedback.mediumImpact();

    final parsed = _parseFiscalQr(raw);
    if (!mounted) return;

    final txn = await _confirmAndCreate(parsed, raw);
    if (txn != null) {
      await ref.read(transactionsProvider.notifier).upsert(txn);
      if (!mounted) return;
      Navigator.of(context).pop(txn);
      return;
    }
    _handled = false;
  }

  Future<Transaction?> _confirmAndCreate(
      _ParsedReceipt parsed, String raw) async {
    final amountController =
        TextEditingController(text: parsed.amount?.toStringAsFixed(2) ?? '');
    final categoryController =
        TextEditingController(text: 'Покупки');

    return showDialog<Transaction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Найден чек'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Сумма'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoryController,
                decoration:
                    const InputDecoration(labelText: 'Категория'),
              ),
              const SizedBox(height: 12),
              Text(
                'Дата: ${parsed.date ?? DateTime.now().toIso8601String().substring(0, 10)}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(
                  amountController.text.replaceAll(',', '.'));
              if (amt == null || amt <= 0) return;
              final date = parsed.date ??
                  DateTime.now().toIso8601String().substring(0, 10);
              Navigator.of(ctx).pop(
                Transaction(
                  id: const Uuid().v4(),
                  type: TransactionType.expense,
                  amount: amt,
                  category: categoryController.text.trim().isEmpty
                      ? 'Покупки'
                      : categoryController.text.trim(),
                  date: date,
                  notes: 'QR: $raw',
                  source: 'qr-receipt',
                ),
              );
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}

class _ParsedReceipt {
  _ParsedReceipt({this.amount, this.date});
  final double? amount;
  final String? date;
}

_ParsedReceipt _parseFiscalQr(String raw) {
  // Belarus fiscal-receipt format: terminal;seq;DD-MM-YYYY HH:MM;amount;...
  // We tolerate generic semicolon-separated payloads.
  final parts = raw.split(';');
  if (parts.length >= 4) {
    final dateRaw = parts[2].trim();
    final amtRaw = parts[3].trim();
    final amt = double.tryParse(amtRaw.replaceAll(',', '.'));
    final isoDate = _toIso(dateRaw);
    return _ParsedReceipt(amount: amt, date: isoDate);
  }
  return _ParsedReceipt();
}

String? _toIso(String d) {
  // expected like 12-04-2025 14:32 or 12.04.2025
  final cleaned = d.replaceAll('.', '-');
  final m = RegExp(r'^(\d{2})-(\d{2})-(\d{4})').firstMatch(cleaned);
  if (m == null) return null;
  return '${m[3]}-${m[2]}-${m[1]}';
}
