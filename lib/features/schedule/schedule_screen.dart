import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onerise_mobile/features/auth/auth_controller.dart';
import 'package:onerise_mobile/features/schedule/session_card.dart';
import 'package:onerise_mobile/features/schedule/session_models.dart';
import 'package:onerise_mobile/features/schedule/session_repository.dart';

/// Home screen: upcoming lessons list. Pull-to-refresh against
/// `/api/sessions/upcoming`. Book / cancel actions call the repo
/// directly; on success we invalidate the provider so the list
/// re-fetches with the updated `hasActiveBooking` flag.
///
/// Join action is a stub until T1 day 3 (LiveKit room screen).
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final async = ref.watch(upcomingSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Расписание'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(upcomingSessionsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            error: e,
            onRetry: () => ref.invalidate(upcomingSessionsProvider),
          ),
          data: (sessions) => _SessionList(
            sessions: sessions,
            greetingName: auth.user?.name,
            onBook: (s) => _book(context, ref, s),
            onCancel: (s) => _cancel(context, ref, s),
            onJoin: (s) => _join(context, s),
          ),
        ),
      ),
    );
  }

  Future<void> _book(
    BuildContext context, WidgetRef ref, SessionSummary s,
  ) async {
    final repo = await ref.read(sessionRepositoryProvider.future);
    try {
      await repo.book(s.id);
      if (!context.mounted) return;
      _toast(context, 'Забронировали: ${s.title}');
      ref.invalidate(upcomingSessionsProvider);
    } on Exception catch (e) {
      if (!context.mounted) return;
      _toast(context, _clean(e));
    }
  }

  Future<void> _cancel(
    BuildContext context, WidgetRef ref, SessionSummary s,
  ) async {
    // The cancel endpoint needs the booking id, not the session id.
    // T1 day 2 simplification: GET `/api/me/active-booking` would
    // give us the id, but we don't have that flow yet. For the first
    // iteration we punt: ask the user to cancel from the web app.
    // Day 2.5 follow-up is to add a "my bookings" fetch and expose
    // the booking id on the SessionSummary server-side.
    // Params accepted for forward-compat; cancel-by-booking-id needs
    // a /api/me/active-booking hop we haven't wired yet (next slice).
    debugPrint('cancel requested for session ${s.id}; ref=$ref');
    _toast(
      context,
      'Отмена бронирования — скоро. Пока это можно сделать на 1rise.ru.',
    );
  }

  void _join(BuildContext context, SessionSummary s) {
    // Forward-compat: next slice SPA-navs to /room/:id.
    debugPrint('join requested for session ${s.id}');
    _toast(context, 'Подключение к уроку — T1 день 3. Пока через 1rise.ru.');
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _clean(Exception e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring('Exception: '.length) : s;
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    required this.greetingName,
    required this.onBook,
    required this.onCancel,
    required this.onJoin,
  });

  final List<SessionSummary> sessions;
  final String? greetingName;
  final void Function(SessionSummary) onBook;
  final void Function(SessionSummary) onCancel;
  final void Function(SessionSummary) onJoin;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return ListView(
        // Empty-but-scrollable so pull-to-refresh still works.
        children: const [
          SizedBox(height: 120),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Пока нет запланированных уроков.\nПотяните вниз, чтобы обновить.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sessions.length + 1,
      itemBuilder: (context, idx) {
        if (idx == 0 && greetingName != null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              'Привет, $greetingName',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          );
        }
        final s = sessions[idx - (greetingName != null ? 1 : 0)];
        if (idx - (greetingName != null ? 1 : 0) >= sessions.length) {
          return const SizedBox.shrink();
        }
        return SessionCard(
          session: s,
          onBook: () => onBook(s),
          onCancel: () => onCancel(s),
          onJoin: () => onJoin(s),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Center(child: Icon(Icons.error_outline, size: 48)),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Не удалось загрузить расписание\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Повторить'),
          ),
        ),
      ],
    );
  }
}
