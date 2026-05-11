import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/finance.dart';
import '../../../models/financial_plan_month.dart';
import '../financial_plan_helpers.dart';

/// Builds and prints / shares the monthly plan as a PDF document.
///
/// The PDF lists every section with its items and the actual fact pulled
/// from [transactions]. Russian glyphs need a Unicode font, so we ship a
/// Noto Sans .ttf in assets and embed it into the document.
Future<void> exportMonthAsPdf({
  required FinancialPlanMonth plan,
  required FinPlanScenario scenario,
  required List<Transaction> transactions,
}) async {
  final summary = computeSummary(scenario, transactions, plan.monthKey);
  final fact = factForMonth(transactions, plan.monthKey);
  final doc = pw.Document();

  // Noto Sans is pulled at runtime from Google Fonts (via the `printing`
  // package). It includes the full Cyrillic range so Russian glyphs render
  // correctly. If the network call fails we fall back to the default theme.
  pw.ThemeData theme;
  try {
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    theme = pw.ThemeData.withFont(base: base, bold: bold);
  } catch (_) {
    theme = pw.ThemeData.base();
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 32),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Финансовый план — ${humanMonth(plan.monthKey)}',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Сценарий: ${scenario.name}',
                style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
      ),
      build: (context) => [
        // ---- summary table ----
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _kpi('Доход', summary.income, fact.income, PdfColors.green800),
              _kpi('Расход', summary.expense, fact.expense, PdfColors.red800),
              _kpi('Сбережения', summary.savings, 0, PdfColors.blue800),
              _kpi('Долг', summary.debt, 0, PdfColors.orange800),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // ---- one block per section ----
        for (final section in scenario.sections) ...[
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(section.title,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(section.kind.name,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    )),
              ],
            ),
          ),
          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                children: [
                  _th('Статья'),
                  _th('День'),
                  _th('План', alignRight: true),
                  _th('Факт', alignRight: true),
                ],
              ),
              for (final it in section.items)
                pw.TableRow(children: [
                  _td(it.label),
                  _td(it.day?.toString() ?? '—'),
                  _td('${it.amount.toStringAsFixed(0)} ${it.currency}',
                      alignRight: true),
                  _td(_factText(it, transactions, plan.monthKey),
                      alignRight: true),
                ]),
            ],
          ),
        ],

        pw.SizedBox(height: 12),
        pw.Divider(color: PdfColors.grey400),
        pw.Text(
          'Сгенерировано Vibesight Tracker · ${DateTime.now().toIso8601String().substring(0, 10)}',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
        ),
      ],
    ),
  );

  await Printing.sharePdf(
    bytes: await doc.save(),
    filename:
        'finplan-${plan.monthKey}-${scenario.name.replaceAll(' ', '-')}.pdf',
  );
}

/// Exports the list of [transactions] as a CSV file using the standard
/// comma separator and an UTF-8 BOM so Excel opens it without mojibake.
Future<void> exportTransactionsAsCsv(List<Transaction> transactions) async {
  final rows = <List<dynamic>>[
    ['Дата', 'Тип', 'Сумма', 'Категория', 'Заметка', 'Магазин'],
    for (final t in transactions)
      [
        t.date,
        t.type.name,
        t.amount,
        t.category,
        t.notes ?? '',
        t.merchant ?? '',
      ],
  ];
  final csv = const ListToCsvConverter().convert(rows);
  // Prepend BOM so Excel detects UTF-8 correctly.
  final bytes = <int>[0xEF, 0xBB, 0xBF, ...csv.codeUnits];

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/transactions.csv');
  await file.writeAsBytes(bytes, flush: true);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv', name: 'transactions.csv')],
    subject: 'Транзакции',
  );
}

// -------------------- internal PDF helpers --------------------

pw.Widget _kpi(String label, num plan, num fact, PdfColor color) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 2),
      pw.Text(
        plan.toStringAsFixed(0),
        style: pw.TextStyle(
            fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
      ),
      if (fact > 0)
        pw.Text('факт ${fact.toStringAsFixed(0)}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ],
  );
}

pw.Widget _th(String text, {bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
    ),
  );
}

pw.Widget _td(String text, {bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 9),
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
    ),
  );
}

String _factText(FinPlanItem item, List<Transaction> txs, String monthKey) {
  final v = factForItem(item, txs, monthKey);
  if (v <= 0) return '—';
  return '${v.toStringAsFixed(0)} ${item.currency}';
}
