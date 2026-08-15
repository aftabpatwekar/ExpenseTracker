/// The signed-in user's profile (row in `public.profiles`).
class Profile {
  final String id;
  final String? displayName;
  final DateTime? dob;
  final String? gender;
  final String? address;
  final String? phone;
  final String? avatarUrl;
  final String currency;

  const Profile({
    required this.id,
    this.displayName,
    this.dob,
    this.gender,
    this.address,
    this.phone,
    this.avatarUrl,
    this.currency = 'INR',
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        displayName: m['display_name'] as String?,
        dob: m['dob'] == null ? null : DateTime.tryParse(m['dob'].toString()),
        gender: m['gender'] as String?,
        address: m['address'] as String?,
        phone: m['phone'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        currency: (m['currency'] as String?) ?? 'INR',
      );
}
