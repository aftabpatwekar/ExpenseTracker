/// Result of running [ExpenseParser] over a spoken/typed sentence.
class ParsedExpense {
  final double amount;
  final String? categoryId; // matched category id, or the fallback ("Other")
  final String note;
  final String raw; // the original input, kept verbatim

  const ParsedExpense({
    required this.amount,
    required this.categoryId,
    required this.note,
    required this.raw,
  });

  @override
  String toString() =>
      'ParsedExpense(amount: $amount, categoryId: $categoryId, note: "$note")';
}
