import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final receiptRepositoryProvider = Provider<ReceiptRepository>(
  (ref) => ReceiptRepository(Supabase.instance.client),
);

/// Uploads and reads receipt images in the private `receipts` storage bucket.
/// Files live under `{userId}/...` so RLS keeps each user to their own folder.
class ReceiptRepository {
  final SupabaseClient _client;
  ReceiptRepository(this._client);

  static const _uuid = Uuid();
  static const _bucket = 'receipts';

  /// Uploads [bytes] and returns the storage path (stored on the expense row).
  Future<String> upload(Uint8List bytes, {String ext = 'jpg'}) async {
    final uid = _client.auth.currentUser!.id;
    final path = '$uid/${_uuid.v4()}.$ext';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
            upsert: false,
          ),
        );
    return path;
  }

  /// A short-lived signed URL for displaying a stored receipt.
  Future<String> signedUrl(String path) =>
      _client.storage.from(_bucket).createSignedUrl(path, 3600);

  Future<void> remove(String path) =>
      _client.storage.from(_bucket).remove([path]);
}
