import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while an `expensetracker://add` deep link (Back-Tap / "Speak expense"
/// shortcut) is waiting to be handled. [HomeShell] watches this, opens the
/// voice-add sheet, and resets it to false.
///
/// Kept in a root-scoped provider on purpose: the router refreshes on Supabase
/// auth events, which can remount HomeShell right as a link arrives. Handling
/// the link inside HomeShell's own state lost it to that race (it only ever
/// worked on the very first launch). A root provider survives the remount, so
/// the pending link is replayed as soon as home is ready.
class PendingAddNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final pendingAddProvider =
    NotifierProvider<PendingAddNotifier, bool>(PendingAddNotifier.new);

/// App-lifetime listener for incoming deep links. Instantiated once from the
/// app root ([ExpenseApp]) so it is never disposed mid-session.
final deepLinkListenerProvider = Provider<DeepLinkListener>((ref) {
  final listener = DeepLinkListener(
    onAdd: () => ref.read(pendingAddProvider.notifier).set(true),
  );
  ref.onDispose(listener.dispose);
  return listener;
});

class DeepLinkListener {
  DeepLinkListener({required this.onAdd}) {
    _appLinks = AppLinks();
    // Warm start: links delivered while the app is already running.
    _sub = _appLinks.uriLinkStream.listen(_handle);
    // Cold start: the link that launched the app.
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handle(uri);
    });
  }

  final void Function() onAdd;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  void _handle(Uri uri) {
    // expensetracker://add  → host == 'add'. Also accept .../add path forms.
    if (uri.host == 'add' || uri.pathSegments.contains('add')) {
      onAdd();
    }
  }

  void dispose() => _sub?.cancel();
}
