/// A shared group. Members share a budget and group-tagged expenses.
class Group {
  final String id;
  final String name;
  final String ownerId;
  final String inviteCode;
  final String currency;

  const Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
    this.currency = 'INR',
  });

  factory Group.fromMap(Map<String, dynamic> m) => Group(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? 'Group',
        ownerId: m['owner_id'] as String,
        inviteCode: (m['invite_code'] as String?) ?? '',
        currency: (m['currency'] as String?) ?? 'INR',
      );
}

class GroupMember {
  final String userId;
  final String role;
  final String? name;

  const GroupMember({required this.userId, required this.role, this.name});

  bool get isOwner => role == 'owner';
}
