import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onerise_mobile/features/auth/auth_controller.dart';

/// Temporary home screen — the real list fetch against
/// `/api/sessions/upcoming` lands in the next T1 slice. For now this
/// just proves the auth flow wired end-to-end: if you see your own
/// name here, login + cookie persistence + /api/me all worked.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rise Speaking Club'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                auth.user == null
                    ? 'Загружаем профиль…'
                    : 'Привет, ${auth.user!.name}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (auth.user != null)
                Text(
                  'Роль: ${auth.user!.role}',
                  style: const TextStyle(color: Colors.black54),
                ),
              const SizedBox(height: 32),
              const Text(
                'Расписание уроков появится здесь на следующем шаге.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
