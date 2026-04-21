import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onerise_mobile/core/api_client.dart';
import 'package:onerise_mobile/features/schedule/session_models.dart';

/// Data access for upcoming lessons + booking lifecycle.
///
/// `/api/sessions/upcoming` — all future + recently-started lessons
/// the caller can see. The backend handles visibility: admin gets
/// everything, teacher + student see only published + not-archived.
///
/// `/api/sessions/:id/book` — creates an active booking row (POST).
/// `/api/me/active-booking` + `/api/me/next-upcoming-booking` —
/// caller's own booking state, used to decorate cards.
class SessionRepository {
  SessionRepository(this._api);

  final ApiClient _api;

  Future<List<SessionSummary>> fetchUpcoming() async {
    final res = await _api.dio.get('/api/sessions/upcoming');
    if (res.statusCode != 200) {
      throw _err(res, 'Не удалось загрузить расписание');
    }
    final list = (res.data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SessionSummary.fromJson)
        .toList();
    return list;
  }

  /// Book a session. Returns the booking id on success; surfaces the
  /// server error message on 4xx (e.g. "already has an active
  /// booking for this time").
  Future<int> book(int sessionId) async {
    final res = await _api.dio.post('/api/sessions/$sessionId/book');
    if (res.statusCode == 201 || res.statusCode == 200) {
      final data = res.data as Map<String, dynamic>;
      final booking = data['booking'] as Map<String, dynamic>?;
      return (booking?['id'] as int?) ?? 0;
    }
    throw _err(res, 'Не удалось забронировать занятие');
  }

  /// Cancel an active booking by its own id (not session id). The
  /// backend endpoint is DELETE /api/bookings/:id on the web app;
  /// mirror that here.
  Future<void> cancel(int bookingId) async {
    final res = await _api.dio.delete('/api/bookings/$bookingId');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw _err(res, 'Не удалось отменить бронь');
    }
  }

  Exception _err(Response<dynamic> r, String fallback) {
    final d = r.data;
    if (d is Map<String, dynamic> && d['error'] is String) {
      return Exception(d['error'] as String);
    }
    return Exception('$fallback (HTTP ${r.statusCode})');
  }
}

final sessionRepositoryProvider =
    FutureProvider<SessionRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return SessionRepository(api);
});

/// Live list of upcoming sessions. Invalidate on pull-to-refresh
/// or after a booking mutation to re-fetch.
final upcomingSessionsProvider =
    FutureProvider.autoDispose<List<SessionSummary>>((ref) async {
  final repo = await ref.watch(sessionRepositoryProvider.future);
  return repo.fetchUpcoming();
});
