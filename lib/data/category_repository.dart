import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/expense_category.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(Supabase.instance.client);
});

/// The signed-in user's categories (RLS returns only their own rows).
final categoriesProvider = FutureProvider<List<ExpenseCategory>>((ref) {
  return ref.watch(categoryRepositoryProvider).fetchAll();
});

class CategoryRepository {
  final SupabaseClient _client;
  CategoryRepository(this._client);

  Future<List<ExpenseCategory>> fetchAll() async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('is_archived', false)
        .order('sort_order');
    return rows
        .map<ExpenseCategory>((m) => ExpenseCategory.fromMap(m))
        .toList();
  }

  Future<void> upsert({
    String? id,
    required String name,
    required String icon,
    required String color,
    required List<String> keywords,
  }) async {
    final uid = _client.auth.currentUser!.id;
    if (id == null) {
      await _client.from('categories').insert({
        'user_id': uid,
        'name': name,
        'icon': icon,
        'color': color,
        'keywords': keywords,
        'sort_order': 50,
      });
    } else {
      await _client.from('categories').update({
        'name': name,
        'icon': icon,
        'color': color,
        'keywords': keywords,
      }).eq('id', id);
    }
  }

  Future<void> delete(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }
}
