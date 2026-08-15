/// A single transaction. Mirrors the `expenses` table in Supabase.
/// [type] is 'expense' | 'income' | 'transfer'.
class Expense {
  final String id;
  final String? categoryId;
  final double amount;
  final String currency;
  final String note;
  final String? rawText; // original voice/typed input, kept for audit
  final DateTime spentAt; // local time
  final String type;
  final String? accountId;
  final List<String> tags;
  final String? receiptUrl; // storage path in the private 'receipts' bucket
  final String? groupId; // when set, shared with this group

  const Expense({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.currency,
    required this.note,
    required this.rawText,
    required this.spentAt,
    this.type = 'expense',
    this.accountId,
    this.tags = const [],
    this.receiptUrl,
    this.groupId,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  // Postgres numeric can arrive as num or String; be tolerant.
  static double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as String,
        categoryId: m['category_id'] as String?,
        amount: _toDouble(m['amount']),
        currency: (m['currency'] as String?) ?? 'INR',
        note: (m['note'] as String?) ?? '',
        rawText: m['raw_text'] as String?,
        spentAt: DateTime.parse(m['spent_at'] as String).toLocal(),
        type: (m['type'] as String?) ?? 'expense',
        accountId: m['account_id'] as String?,
        tags: (m['tags'] as List?)
                ?.map((e) => e.toString())
                .toList(growable: false) ??
            const [],
        receiptUrl: m['receipt_url'] as String?,
        groupId: m['group_id'] as String?,
      );
}
