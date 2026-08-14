import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/account.dart';
import '../domain/models/expense.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(Supabase.instance.client);
});

final accountsProvider = FutureProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).fetchAll();
});

/// Current balance = opening balance + income into it − expenses from it.
double accountBalance(Account a, List<Expense> expenses) {
  var b = a.openingBalance;
  for (final e in expenses) {
    if (e.accountId != a.id) continue;
    if (e.isIncome) {
      b += e.amount;
    } else if (e.isExpense) {
      b -= e.amount;
    }
  }
  return b;
}

class AccountRepository {
  final SupabaseClient _client;
  AccountRepository(this._client);

  Future<List<Account>> fetchAll() async {
    final rows = await _client
        .from('accounts')
        .select()
        .eq('is_archived', false)
        .order('sort_order');
    return rows.map<Account>((m) => Account.fromMap(m)).toList();
  }

  Future<void> upsert({
    String? id,
    required String name,
    required String type,
    required String icon,
    required String color,
    required double openingBalance,
  }) async {
    final uid = _client.auth.currentUser!.id;
    if (id == null) {
      await _client.from('accounts').insert({
        'user_id': uid,
        'name': name,
        'type': type,
        'icon': icon,
        'color': color,
        'opening_balance': openingBalance,
        'sort_order': 50,
      });
    } else {
      await _client.from('accounts').update({
        'name': name,
        'type': type,
        'icon': icon,
        'color': color,
        'opening_balance': openingBalance,
      }).eq('id', id);
    }
  }

  Future<void> archive(String id) async {
    await _client.from('accounts').update({'is_archived': true}).eq('id', id);
  }
}
