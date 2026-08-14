/// A spending limit. Mirrors the `budgets` table.
/// [categoryId] null = overall budget. [period] = 'monthly' | 'annual' | 'weekly'.
class Budget {
  final String id;
  final String? categoryId;
  final String period;
  final double amount;

  const Budget({
    required this.id,
    required this.categoryId,
    required this.period,
    required this.amount,
  });

  static double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        id: m['id'] as String,
        categoryId: m['category_id'] as String?,
        period: (m['period'] as String?) ?? 'monthly',
        amount: _toDouble(m['amount']),
      );
}
