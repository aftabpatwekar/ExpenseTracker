import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';

final transcriptionServiceProvider = Provider<TranscriptionService>(
  (ref) => TranscriptionService(Supabase.instance.client),
);

/// Sends recorded audio to the `transcribe` Supabase Edge Function (which proxies
/// to a speech-to-text provider) and returns the recognised text. Used on web,
/// where the browser has no on-device speech API (esp. iOS Safari).
class TranscriptionService {
  final SupabaseClient _c;
  TranscriptionService(this._c);

  Future<String> transcribe(Uint8List audio,
      {String contentType = 'audio/webm'}) async {
    final token = _c.auth.currentSession?.accessToken;
    final url = '${Env.supabaseUrl}/functions/v1/transcribe';
    final resp = await http.post(
      Uri.parse(url),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'apikey': Env.supabaseAnonKey,
        'Content-Type': contentType,
      },
      body: audio,
    );
    if (resp.statusCode != 200) {
      throw Exception('Transcription failed (${resp.statusCode})');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['transcript'] as String?)?.trim() ?? '';
  }
}
