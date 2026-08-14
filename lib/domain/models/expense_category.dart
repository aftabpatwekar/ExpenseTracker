/// A spending category. Mirrors the `categories` table in Supabase.
/// Pure Dart (no Flutter imports) so it stays trivially testable.
class ExpenseCategory {
  final String id;
  final String name;
  final String icon; // emoji shown in the UI
  final String color; // hex, e.g. #2a78d6 (from the validated palette)
  final List<String> keywords; // spoken words the parser matches on
  final int sortOrder;

  const ExpenseCategory({
    required this.id,
    required this.name,
    this.icon = '•',
    this.color = '#2a78d6',
    this.keywords = const [],
    this.sortOrder = 0,
  });

  factory ExpenseCategory.fromMap(Map<String, dynamic> m) => ExpenseCategory(
        id: m['id'] as String,
        name: m['name'] as String,
        icon: (m['icon'] as String?) ?? '•',
        color: (m['color'] as String?) ?? '#2a78d6',
        keywords: (m['keywords'] as List?)
                ?.map((e) => e.toString())
                .toList(growable: false) ??
            const [],
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'keywords': keywords,
        'sort_order': sortOrder,
      };

  ExpenseCategory copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    List<String>? keywords,
    int? sortOrder,
  }) =>
      ExpenseCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        keywords: keywords ?? this.keywords,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
