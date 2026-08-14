import '../models/expense_category.dart';
import '../models/parsed_expense.dart';

/// On-device parser: turns a natural sentence like
/// "spent 250 on groceries, weekly veggies" into { amount, category, note }.
///
/// This is a faithful Dart port of the validated web-prototype parser. It takes
/// the user's own categories (each carrying keywords) so the mapping is fully
/// user-editable and loaded from Supabase at runtime.
class ExpenseParser {
  final List<ExpenseCategory> categories;

  /// Category id to use when no keyword matches (typically the "Other" id).
  final String? fallbackCategoryId;

  ExpenseParser(this.categories, {this.fallbackCategoryId});

  // Any comma sitting between two digits is a grouping separator
  // (western 1,250 and Indian 2,00,000 alike).
  static final RegExp _grouping = RegExp(r'(\d),(?=\d)');
  static final RegExp _number = RegExp(r'\d+(?:\.\d+)?');
  static final RegExp _fillers = RegExp(
    r'\b(rs|rs\.|inr|rupees?|dollars?|for|on|spent|paid|bought|of)\b',
    caseSensitive: false,
  );
  static final RegExp _symbols = RegExp(r'[₹$]');
  static final RegExp _spaces = RegExp(r'\s+');

  ParsedExpense parse(String raw) {
    final text = raw.trim();
    // Normalize once so the amount index and the note slice stay aligned.
    final clean = text.replaceAllMapped(_grouping, (m) => m.group(1)!);

    // Amount = first number.
    final match = _number.firstMatch(clean);
    final double amount = match != null ? double.parse(match.group(0)!) : 0.0;

    // Category = first keyword hit, scanning categories in order (space-bounded).
    final low = ' ${clean.toLowerCase()} ';
    ExpenseCategory? matched;
    outer:
    for (final c in categories) {
      for (final k in c.keywords) {
        final key = k.toLowerCase();
        if (low.contains(' $key ') ||
            low.contains(' $key') ||
            low.contains('$key ')) {
          matched = c;
          break outer;
        }
      }
    }
    final String? categoryId = matched?.id ?? fallbackCategoryId;

    // Note = the text minus the matched amount token, filler words tidied away.
    String note = clean;
    if (match != null) {
      note = clean.substring(0, match.start) + clean.substring(match.end);
    }
    note = note
        .replaceAll(_fillers, ' ')
        .replaceAll(_symbols, ' ')
        .replaceAll(_spaces, ' ')
        .trim();
    if (note.isEmpty) note = matched?.name ?? '';

    return ParsedExpense(
      amount: amount,
      categoryId: categoryId,
      note: note,
      raw: text,
    );
  }
}
