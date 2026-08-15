import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';

String _d(DateTime x) =>
    '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';

// Plain amount for files (no ₹ glyph — keeps CSV/PDF portable & offline-safe).
String _amt(double v) => v.toStringAsFixed(2);

Future<void> exportCsvReport(
  BuildContext context,
  List<Expense> expenses,
  Map<String, ExpenseCategory> catMap, {
  required String title,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final buf = StringBuffer('Date,Type,Amount (INR),Category,Note,Tags\n');
  for (final e in expenses) {
    final cat = (catMap[e.categoryId]?.name ?? '').replaceAll('"', '""');
    final note = e.note.replaceAll('"', '""');
    final tags = e.tags.join('; ').replaceAll('"', '""');
    buf.writeln('${e.spentAt.toIso8601String()},${e.type},${_amt(e.amount)},'
        '"$cat","$note","$tags"');
  }
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/report.csv');
    await file.writeAsString(buf.toString());
    await SharePlus.instance
        .share(ShareParams(files: [XFile(file.path)], text: title));
  } catch (_) {
    messenger
        .showSnackBar(const SnackBar(content: Text('Could not export CSV')));
  }
}

Future<void> exportExcelReport(
  BuildContext context,
  List<Expense> expenses,
  Map<String, ExpenseCategory> catMap, {
  required String title,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final book = xls.Excel.createExcel();
  final sheet = book[book.getDefaultSheet() ?? 'Sheet1'];
  sheet.appendRow([
    xls.TextCellValue('Date'),
    xls.TextCellValue('Type'),
    xls.TextCellValue('Amount (INR)'),
    xls.TextCellValue('Category'),
    xls.TextCellValue('Note'),
    xls.TextCellValue('Tags'),
  ]);
  for (final e in expenses) {
    sheet.appendRow([
      xls.TextCellValue(_d(e.spentAt)),
      xls.TextCellValue(e.type),
      xls.DoubleCellValue(e.amount),
      xls.TextCellValue(catMap[e.categoryId]?.name ?? ''),
      xls.TextCellValue(e.note),
      xls.TextCellValue(e.tags.join(', ')),
    ]);
  }
  try {
    final bytes = book.encode();
    if (bytes == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not build the file')));
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/report.xlsx');
    await file.writeAsBytes(bytes);
    await SharePlus.instance
        .share(ShareParams(files: [XFile(file.path)], text: title));
  } catch (_) {
    messenger
        .showSnackBar(const SnackBar(content: Text('Could not export Excel')));
  }
}

Future<void> exportPdfReport(
  BuildContext context,
  List<Expense> expenses,
  Map<String, ExpenseCategory> catMap, {
  required String title,
  required DateTimeRange range,
  required double spent,
  required double income,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Text(title,
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('${_d(range.start)}  to  ${_d(range.end)}',
              style: const pw.TextStyle(color: PdfColors.grey700)),
          pw.SizedBox(height: 14),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfStat('Total spent', 'INR ${_amt(spent)}'),
              _pdfStat('Total income', 'INR ${_amt(income)}'),
              _pdfStat('Net', 'INR ${_amt(income - spent)}'),
              _pdfStat('Entries', '${expenses.length}'),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.4),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(2.2),
              4: const pw.FlexColumnWidth(3),
            },
            headers: const ['Date', 'Type', 'Amount', 'Category', 'Note'],
            data: [
              for (final e in expenses)
                [
                  _d(e.spentAt),
                  e.type,
                  _amt(e.amount),
                  catMap[e.categoryId]?.name ?? '',
                  e.note,
                ],
            ],
          ),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'report.pdf');
  } catch (_) {
    messenger
        .showSnackBar(const SnackBar(content: Text('Could not export PDF')));
  }
}

pw.Widget _pdfStat(String label, String value) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(),
            style:
                const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    );
