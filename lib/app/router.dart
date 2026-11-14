import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/alerts/alerts_screen.dart';
import 'modules.dart';
import 'tab_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;

      if (session.isLoading && !session.hasValue) return loc == '/splash' ? null : '/splash';

      final user = session.value;
      if (user == null) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash') return '/home';

      for (final m in tabModules) {
        if (loc.startsWith(m.path) && !m.allows(user)) return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/alerts', builder: (_, _) => const AlertsScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => TabShell(shell: shell),
        branches: [
          for (final m in tabModules)
            StatefulShellBranch(
              routes: [GoRoute(path: m.path, builder: (context, _) => m.builder(context))],
            ),
        ],
      ),
    ],
  );
});
