import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/budget.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(Supabase.instance.client);
});

final budgetsProvider = FutureProvider<List<Budget>>((ref) {
  return ref.watch(budgetRepositoryProvider).fetchAll();
});

class BudgetRepository {
  final SupabaseClient _client;
  BudgetRepository(this._client);

  Future<List<Budget>> fetchAll() async {
    final rows = await _client.from('budgets').select();
    return rows.map<Budget>((m) => Budget.fromMap(m)).toList();
  }

  /// Sets (or clears, when amount <= 0) the overall budget for a period.
  Future<void> setOverall(String period, double amount) async {
    final uid = _client.auth.currentUser!.id;
    final existing = await _client
        .from('budgets')
        .select('id')
        .eq('user_id', uid)
        .eq('period', period)
        .filter('category_id', 'is', null)
        .limit(1);

    if (amount <= 0) {
      if (existing.isNotEmpty) {
        await _client
            .from('budgets')
            .delete()
            .eq('id', existing.first['id'] as String);
      }
      return;
    }

    if (existing.isNotEmpty) {
      await _client
          .from('budgets')
          .update({'amount': amount}).eq('id', existing.first['id'] as String);
    } else {
      await _client.from('budgets').insert({
        'user_id': uid,
        'period': period,
        'amount': amount,
        'category_id': null,
      });
    }
  }
}
