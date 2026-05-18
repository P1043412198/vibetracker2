import '../../widgets/app_back_button.dart';
import 'dart:math' as math;

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
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  /// Bounding boxes of QR codes currently visible in the camera preview.
  /// Updated on every frame the platform reports — drives the live overlay
  /// so the user sees exactly where the camera detects the QR.
  List<Barcode> _detected = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
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
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      fit: BoxFit.cover,
                      onDetect: (capture) => _onDetect(capture),
                    ),
                    // Live overlay: bounding box around any QR codes the
                    // camera is currently seeing. Repaints every frame the
                    // scanner emits a detection.
                    IgnorePointer(
                      child: CustomPaint(
                        size: size,
                        painter: _QrOverlayPainter(
                          barcodes: _detected,
                          previewSize: size,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    // Static viewfinder frame that hints the user where to
                    // point the camera. Sits underneath the live overlay.
                    IgnorePointer(
                      child: CustomPaint(
                        size: size,
                        painter: _ViewfinderPainter(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              _detected.isEmpty
                  ? 'Наведи камеру на QR-код в чеке.\n'
                      'Рамка обведёт код, как только он попадёт в кадр.'
                  : 'QR найден — держи камеру неподвижно…',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    // Update overlay on every frame (even before we commit to handling the
    // payload). Filter out empty corner lists — those can't be drawn.
    final visible = capture.barcodes
        .where((b) => b.corners.isNotEmpty)
        .toList(growable: false);
    if (mounted) {
      setState(() => _detected = visible);
    }
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

/// Live overlay that draws the bounding polygon of every detected QR code
/// on top of the camera preview. Coordinates from `mobile_scanner` are in
/// the camera frame's coordinate space (matched to the widget size since we
/// use `BoxFit.cover`), so we can draw them directly.
class _QrOverlayPainter extends CustomPainter {
  _QrOverlayPainter({
    required this.barcodes,
    required this.previewSize,
    required this.color,
  });

  final List<Barcode> barcodes;
  final Size previewSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (barcodes.isEmpty) return;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    for (final b in barcodes) {
      final corners = b.corners;
      if (corners.length < 3) continue;
      final path = Path()..moveTo(corners.first.dx, corners.first.dy);
      for (var i = 1; i < corners.length; i++) {
        path.lineTo(corners[i].dx, corners[i].dy);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);

      // Centered checkmark / label
      double cx = 0;
      double cy = 0;
      for (final c in corners) {
        cx += c.dx;
        cy += c.dy;
      }
      cx /= corners.length;
      cy /= corners.length;
      final marker = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), 6, marker);
    }
  }

  @override
  bool shouldRepaint(covariant _QrOverlayPainter old) =>
      old.barcodes != barcodes ||
      old.previewSize != previewSize ||
      old.color != color;
}

/// Subtle viewfinder corner brackets to hint where the user should aim the
/// camera. Pure cosmetic — does not affect scanning.
class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shorter = math.min(size.width, size.height);
    final frame = shorter * 0.7;
    final left = (size.width - frame) / 2;
    final top = (size.height - frame) / 2;
    final rect = Rect.fromLTWH(left, top, frame, frame);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final corner = frame * 0.12;

    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(corner, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, corner), paint);
    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight - Offset(corner, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, corner), paint);
    // Bottom-left
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft + Offset(corner, 0), paint);
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft - Offset(0, corner), paint);
    // Bottom-right
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight - Offset(corner, 0), paint);
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight - Offset(0, corner), paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter old) => old.color != color;
}
