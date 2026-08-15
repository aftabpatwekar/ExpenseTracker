import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(Supabase.instance.client),
);

/// The signed-in user's profile (null while loading / if signed out).
final profileProvider = FutureProvider<Profile?>((ref) {
  return ref.watch(profileRepositoryProvider).fetch();
});

class ProfileRepository {
  final SupabaseClient _c;
  ProfileRepository(this._c);

  Future<Profile?> fetch() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _c.from('profiles').select().eq('id', uid).maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(row);
  }

  Future<void> update({
    String? displayName,
    DateTime? dob,
    String? gender,
    String? address,
    String? phone,
    String? avatarUrl,
  }) async {
    final uid = _c.auth.currentUser!.id;
    final dobStr = dob == null
        ? null
        : '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
    final data = <String, dynamic>{
      'display_name': displayName,
      'gender': gender,
      'address': address,
      'phone': phone,
      'dob': ?dobStr,
      'avatar_url': ?avatarUrl,
    };
    await _c.from('profiles').update(data).eq('id', uid);
  }

  /// Uploads an avatar to the public `avatars` bucket, returns its public URL.
  Future<String> uploadAvatar(Uint8List bytes, {String ext = 'jpg'}) async {
    final uid = _c.auth.currentUser!.id;
    final path = '$uid/avatar.$ext';
    await _c.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
            upsert: true,
          ),
        );
    // Cache-bust so the new image shows immediately.
    final url = _c.storage.from('avatars').getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
