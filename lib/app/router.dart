import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/tracking/track_screen.dart';
import '../features/tracking/track_session.dart';
import 'modules.dart';
import 'tab_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.listen(trackSessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final track = ref.read(trackSessionProvider);
      final loc = state.matchedLocation;

      final loading = (session.isLoading && !session.hasValue) || (track.isLoading && !track.hasValue);
      if (loading) return loc == '/splash' ? null : '/splash';

      final user = session.value;
      if (user == null) {
        // Someone who made an enquiry, signed in with a one-time code.
        if (track.value != null) return loc == '/track' ? null : '/track';
        return loc == '/login' ? null : '/login';
      }
      if (loc == '/login' || loc == '/splash' || loc == '/track') return '/home';

      for (final m in tabModules) {
        if (loc.startsWith(m.path) && !m.allows(user)) return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/track', builder: (_, _) => const TrackScreen()),
      GoRoute(path: '/alerts', builder: (_, _) => const AlertsScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => TabShell(shell: shell),
        branches: [
          for (final m in tabModules)
            StatefulShellBranch(
              routes: [GoRoute(path: m.path, builder: (context, _) => m.builder(context), routes: m.routes)],
            ),
        ],
      ),
    ],
  );
});
