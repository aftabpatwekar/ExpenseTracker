import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/expense.dart';
import '../domain/models/group.dart';

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => GroupRepository(Supabase.instance.client),
);

/// Groups the signed-in user belongs to.
final groupsProvider = FutureProvider<List<Group>>(
  (ref) => ref.watch(groupRepositoryProvider).fetchGroups(),
);

class GroupRepository {
  final SupabaseClient _c;
  GroupRepository(this._c);

  Future<List<Group>> fetchGroups() async {
    final rows = await _c
        .from('groups')
        .select()
        .filter('deleted_at', 'is', null)
        .order('created_at');
    return rows.map<Group>((m) => Group.fromMap(m)).toList();
  }

  Future<String> createGroup(String name) async {
    final res = await _c.rpc('create_group', params: {'p_name': name});
    return res as String;
  }

  Future<String> joinGroup(String code) async {
    final res = await _c.rpc('join_group', params: {'p_code': code});
    return res as String;
  }

  Future<void> leaveGroup(String groupId) =>
      _c.rpc('leave_group', params: {'p_group': groupId});

  Future<void> deleteGroup(String groupId) => _c
      .from('groups')
      .update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq(
          'id', groupId);

  Future<List<GroupMember>> members(String groupId) async {
    final rows = await _c
        .from('group_members')
        .select('user_id, role')
        .eq('group_id', groupId);
    final ids = rows.map((m) => m['user_id'] as String).toList();
    final nameById = <String, String?>{};
    if (ids.isNotEmpty) {
      final profs =
          await _c.from('profiles').select('id, display_name').inFilter('id', ids);
      for (final p in profs) {
        nameById[p['id'] as String] = p['display_name'] as String?;
      }
    }
    return rows
        .map<GroupMember>((m) => GroupMember(
              userId: m['user_id'] as String,
              role: (m['role'] as String?) ?? 'member',
              name: nameById[m['user_id']],
            ))
        .toList();
  }

  Future<List<Expense>> groupExpenses(String groupId) async {
    final rows = await _c
        .from('expenses')
        .select()
        .eq('group_id', groupId)
        .filter('deleted_at', 'is', null)
        .order('spent_at', ascending: false)
        .limit(500);
    return rows.map<Expense>((m) => Expense.fromMap(m)).toList();
  }

  Future<double?> monthlyBudget(String groupId) async {
    final rows = await _c
        .from('group_budgets')
        .select('amount')
        .eq('group_id', groupId)
        .eq('period', 'monthly')
        .limit(1);
    if (rows.isEmpty) return null;
    return (rows.first['amount'] as num).toDouble();
  }

  Future<void> setMonthlyBudget(String groupId, double amount) => _c
      .from('group_budgets')
      .upsert({'group_id': groupId, 'period': 'monthly', 'amount': amount},
          onConflict: 'group_id,period');
}

/// Members of a specific group.
final groupMembersProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, groupId) {
  return ref.watch(groupRepositoryProvider).members(groupId);
});

/// Expenses shared into a specific group (all members).
final groupExpensesProvider =
    FutureProvider.family<List<Expense>, String>((ref, groupId) {
  return ref.watch(groupRepositoryProvider).groupExpenses(groupId);
});

/// The group's monthly budget cap (null = not set).
final groupBudgetProvider =
    FutureProvider.family<double?, String>((ref, groupId) {
  return ref.watch(groupRepositoryProvider).monthlyBudget(groupId);
});
