import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/category_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/expense_category.dart';

/// Builds a real .xlsx of all transactions and opens the share sheet.
Future<void> exportExcel(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final expenses =
      ref.read(expensesProvider).asData?.value ?? const <Expense>[];
  final cats =
      ref.read(categoriesProvider).asData?.value ?? const <ExpenseCategory>[];
  final catMap = {for (final c in cats) c.id: c};

  if (expenses.isEmpty) {
    messenger
        .showSnackBar(const SnackBar(content: Text('No expenses to export yet')));
    return;
  }

  final book = xls.Excel.createExcel();
  final sheet = book[book.getDefaultSheet() ?? 'Sheet1'];
  sheet.appendRow([
    xls.TextCellValue('Date'),
    xls.TextCellValue('Type'),
    xls.TextCellValue('Amount'),
    xls.TextCellValue('Category'),
    xls.TextCellValue('Note'),
    xls.TextCellValue('Tags'),
  ]);
  for (final e in expenses) {
    sheet.appendRow([
      xls.TextCellValue(e.spentAt.toIso8601String()),
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
    final file = File('${dir.path}/expenses.xlsx');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'My expenses (Excel)'),
    );
  } catch (_) {
    if (context.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not export')));
    }
  }
}
