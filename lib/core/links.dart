import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public Molbhav website + legal pages.
const String kWebsiteUrl = 'https://aftabpatwekar.github.io/molbhav-site/';
const String kTermsUrl =
    'https://aftabpatwekar.github.io/molbhav-site/terms.html';
const String kPrivacyUrl =
    'https://aftabpatwekar.github.io/molbhav-site/privacy.html';

/// Opens [url] in the external browser; shows a snackbar on failure.
Future<void> openExternal(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the link')));
    }
  } catch (_) {
    messenger
        .showSnackBar(const SnackBar(content: Text('Could not open the link')));
  }
}
