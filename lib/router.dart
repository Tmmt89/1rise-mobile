import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:onerise_mobile/features/auth/auth_controller.dart';
import 'package:onerise_mobile/features/auth/login_screen.dart';
import 'package:onerise_mobile/features/profile/profile_screen.dart';
import 'package:onerise_mobile/features/room/room_screen.dart';
import 'package:onerise_mobile/features/schedule/schedule_screen.dart';

/// Global router. Auth guard redirects to /login whenever
/// `authControllerProvider` has no user; the post-login "where do I
/// send them" rule is simple for now (home), gets more nuanced when
/// we add deep-link handling for `/room/:id` push notifications in T2.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggingIn = state.matchedLocation == '/login';

      // Still loading the initial restore — don't bounce anywhere; the
      // root splash handles this case.
      if (auth.loading && auth.user == null) return null;

      if (!auth.isAuthenticated && !loggingIn) return '/login';
      if (auth.isAuthenticated && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const ScheduleScreen(),
      ),
      GoRoute(
        path: '/room/:sessionId',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['sessionId'] ?? '');
          if (id == null) {
            return const Scaffold(
              body: Center(child: Text('Некорректный id урока')),
            );
          }
          return RoomScreen(sessionId: id);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
    ],
  );
});

/// Tiny adapter so go_router listens to our Riverpod auth state.
/// go_router wants a ChangeNotifier; we expose one that fires every
/// time the AuthState changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _sub = _ref.listen<dynamic>(authControllerProvider, (_, __) {
      notifyListeners();
    }, fireImmediately: false);
  }

  final Ref _ref;
  late final ProviderSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
