import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/go_router_refresh_stream.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/shell/home_shell.dart';

/// App router with an auth guard: unauthenticated users are sent to /sign-in,
/// authenticated users are kept out of it.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
    redirect: (context, state) {
      final loggedIn = auth.currentSession != null;
      final atSignIn = state.matchedLocation == '/sign-in';
      if (!loggedIn) return atSignIn ? null : '/sign-in';
      if (atSignIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeShell()),
      GoRoute(
          path: '/sign-in', builder: (context, state) => const SignInScreen()),
    ],
  );
});
