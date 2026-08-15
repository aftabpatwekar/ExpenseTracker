import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(Supabase.instance.client);
});

/// Recent *live* expenses for the signed-in user, newest first.
final expensesProvider = FutureProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).fetchRecent();
});

class ExpenseRepository {
  final SupabaseClient _client;
  ExpenseRepository(this._client);

  Future<List<Expense>> fetchRecent({int limit = 200}) async {
    final rows = await _client
        .from('expenses')
        .select()
        .filter('deleted_at', 'is', null) // exclude soft-deleted
        .order('spent_at', ascending: false)
        .limit(limit);
    return rows.map<Expense>((m) => Expense.fromMap(m)).toList();
  }

  Future<void> add({
    required double amount,
    String? categoryId,
    required String note,
    String? rawText,
    DateTime? spentAt,
    String type = 'expense',
    String? accountId,
    List<String> tags = const [],
    String? receiptUrl,
  }) async {
    // RLS requires user_id == auth.uid() on insert.
    final uid = _client.auth.currentUser!.id;
    await _client.from('expenses').insert({
      'user_id': uid,
      'category_id': categoryId,
      'amount': amount,
      'note': note,
      'raw_text': rawText,
      'spent_at': (spentAt ?? DateTime.now()).toUtc().toIso8601String(),
      'type': type,
      'account_id': accountId,
      'tags': tags,
      'receipt_url': receiptUrl,
    });
  }

  /// Soft delete — the row stays in the DB (recoverable), just hidden.
  Future<void> softDelete(String id) async {
    await _client
        .from('expenses')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Undo a soft delete.
  Future<void> restore(String id) async {
    await _client.from('expenses').update({'deleted_at': null}).eq('id', id);
  }
}
