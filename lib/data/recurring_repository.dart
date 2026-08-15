import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/recurring.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(Supabase.instance.client);
});

final recurringProvider = FutureProvider<List<Recurring>>((ref) {
  return ref.watch(recurringRepositoryProvider).fetchAll();
});

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _advance(DateTime d, String frequency) {
  switch (frequency) {
    case 'daily':
      return d.add(const Duration(days: 1));
    case 'weekly':
      return d.add(const Duration(days: 7));
    case 'monthly':
    default:
      return DateTime(d.year, d.month + 1, d.day);
  }
}

class RecurringRepository {
  final SupabaseClient _client;
  RecurringRepository(this._client);

  Future<List<Recurring>> fetchAll() async {
    final rows = await _client
        .from('recurring_transactions')
        .select()
        .order('next_run');
    return rows.map<Recurring>((m) => Recurring.fromMap(m)).toList();
  }

  Future<void> upsert({
    String? id,
    required double amount,
    required String type,
    String? categoryId,
    String? accountId,
    required String note,
    required String frequency,
    required DateTime nextRun,
    bool isActive = true,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final data = {
      'amount': amount,
      'type': type,
      'category_id': categoryId,
      'account_id': accountId,
      'note': note,
      'frequency': frequency,
      'next_run': _dateStr(nextRun),
      'is_active': isActive,
    };
    if (id == null) {
      await _client
          .from('recurring_transactions')
          .insert({'user_id': uid, ...data});
    } else {
      await _client.from('recurring_transactions').update(data).eq('id', id);
    }
  }

  Future<void> delete(String id) async {
    await _client.from('recurring_transactions').delete().eq('id', id);
  }

  /// Generates any transactions that are due (next_run ≤ today) and advances
  /// each rule's next_run past today. Runs on app open. Returns count created.
  Future<int> catchUp() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final rows = await _client
        .from('recurring_transactions')
        .select()
        .eq('is_active', true)
        .lte('next_run', _dateStr(today));

    var created = 0;
    for (final m in rows) {
      final r = Recurring.fromMap(m);
      var next = r.nextRun;
      final inserts = <Map<String, dynamic>>[];
      var guard = 0;
      while (!next.isAfter(today) && guard < 366) {
        inserts.add({
          'user_id': uid,
          'amount': r.amount,
          'category_id': r.categoryId,
          'account_id': r.accountId,
          'note': r.note,
          'type': r.type,
          'spent_at': next.toUtc().toIso8601String(),
          'tags': <String>[],
        });
        next = _advance(next, r.frequency);
        guard++;
      }
      if (inserts.isNotEmpty) {
        await _client.from('expenses').insert(inserts);
        await _client
            .from('recurring_transactions')
            .update({'next_run': _dateStr(next)}).eq('id', r.id);
        created += inserts.length;
      }
    }
    return created;
  }
}
