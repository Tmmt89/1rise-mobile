import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onerise_mobile/features/auth/auth_controller.dart';
import 'package:onerise_mobile/router.dart';

void main() {
  runApp(const ProviderScope(child: _BootstrapApp()));
}

/// Two-stage startup:
///   1. `_BootstrapApp` mounts the Riverpod scope and fires the
///      initial auth restore. While that's in flight we show a
///      tiny splash. This keeps the router from bouncing
///      unauthenticated-guessing-users to /login before the
///      cookie jar has been queried.
///   2. Once the restore settles, hand off to the real router.
class _BootstrapApp extends ConsumerStatefulWidget {
  const _BootstrapApp();

  @override
  ConsumerState<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends ConsumerState<_BootstrapApp> {
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget: the controller already sets `loading=true`
    // during the call, so the first frame renders the splash and
    // the second (after restore completes) renders the router.
    Future.microtask(() async {
      await ref.read(authControllerProvider.notifier).restore();
      if (mounted) setState(() => _restored = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_restored) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '1rise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E0DFF)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
