/// A money account / payment mode. Mirrors the `accounts` table.
class Account {
  final String id;
  final String name;
  final String type; // cash | bank | card | wallet | other
  final String icon;
  final String color;
  final double openingBalance;
  final int sortOrder;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.openingBalance,
    required this.sortOrder,
  });

  static double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as String,
        name: m['name'] as String,
        type: (m['type'] as String?) ?? 'cash',
        icon: (m['icon'] as String?) ?? '💵',
        color: (m['color'] as String?) ?? '#1baf7a',
        openingBalance: _toDouble(m['opening_balance']),
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      );
}
