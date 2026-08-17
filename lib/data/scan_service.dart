import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';

final scanServiceProvider = Provider<ScanService>(
  (ref) => ScanService(Supabase.instance.client),
);

/// What the AI read off a receipt photo. Any field may be null when it wasn't
/// clearly visible.
class ScanResult {
  final double? amount;
  final String? merchant;
  final DateTime? date;
  const ScanResult({this.amount, this.merchant, this.date});
}

/// Sends a receipt photo to the `scan-receipt` Supabase Edge Function (which
/// proxies to OpenAI vision) and returns the extracted total, merchant, and
/// date. Works on Android and the iPhone PWA alike.
class ScanService {
  final SupabaseClient _c;
  ScanService(this._c);

  Future<ScanResult> scan(Uint8List image,
      {String contentType = 'image/jpeg'}) async {
    final token = _c.auth.currentSession?.accessToken;
    final url = '${Env.supabaseUrl}/functions/v1/scan-receipt';
    final resp = await http.post(
      Uri.parse(url),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'apikey': Env.supabaseAnonKey,
        'Content-Type': contentType,
      },
      body: image,
    );
    if (resp.statusCode != 200) {
      throw Exception('Scan failed (${resp.statusCode})');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return ScanResult(
      amount: _toDouble(data['amount']),
      merchant: (data['merchant'] as String?)?.trim(),
      date: _toDate(data['date']),
    );
  }

  static double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    // Strip anything that isn't a digit or decimal point ("₹1,299.00").
    final cleaned = v.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned);
  }

  static DateTime? _toDate(Object? v) {
    if (v is String && v.trim().isNotEmpty) return DateTime.tryParse(v.trim());
    return null;
  }
}
