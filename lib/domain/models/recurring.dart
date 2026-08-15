/// A recurring/scheduled transaction rule. Mirrors `recurring_transactions`.
class Recurring {
  final String id;
  final double amount;
  final String type; // expense | income
  final String? categoryId;
  final String? accountId;
  final String note;
  final String frequency; // daily | weekly | monthly
  final DateTime nextRun; // date (local midnight)
  final bool isActive;

  const Recurring({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    required this.note,
    required this.frequency,
    required this.nextRun,
    required this.isActive,
  });

  static double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  factory Recurring.fromMap(Map<String, dynamic> m) => Recurring(
        id: m['id'] as String,
        amount: _toDouble(m['amount']),
        type: (m['type'] as String?) ?? 'expense',
        categoryId: m['category_id'] as String?,
        accountId: m['account_id'] as String?,
        note: (m['note'] as String?) ?? '',
        frequency: (m['frequency'] as String?) ?? 'monthly',
        nextRun: DateTime.parse(m['next_run'] as String),
        isActive: (m['is_active'] as bool?) ?? true,
      );
}
