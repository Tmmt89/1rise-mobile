import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onerise_mobile/core/api_client.dart';
import 'package:onerise_mobile/features/profile/profile_models.dart';

/// Talks to `/api/me/*`.
///
/// All endpoints follow the same convention: 200 with a typed JSON
/// payload when the user has the resource, 204 or an absent key when
/// they don't. The repo normalises "no active booking" to a null
/// return rather than throwing, because the UI treats that case as
/// normal state, not an error.
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<ProfileStats> fetchStats() async {
    final res = await _api.dio.get('/api/me/profile-stats');
    if (res.statusCode == 200) {
      return ProfileStats.fromJson(res.data as Map<String, dynamic>);
    }
    // 401 means logout-in-flight — just return empty rather than
    // surfacing the error; the auth controller's redirect handles
    // the actual navigation.
    if (res.statusCode == 401) return ProfileStats.empty;
    throw _err(res, 'Не удалось загрузить статистику');
  }

  /// Returns the caller's currently-active booking, or null if none.
  /// "Currently active" in backend vocabulary = between bookAt and
  /// bookingCutoff (startAt + 15 min). After the cutoff the session
  /// archives.
  Future<ActiveBooking?> fetchActiveBooking() async {
    final res = await _api.dio.get('/api/me/active-booking');
    if (res.statusCode == 200) {
      final data = res.data;
      if (data is Map<String, dynamic> && data['booking'] != null) {
        return ActiveBooking.fromJson(data);
      }
      return null;
    }
    if (res.statusCode == 204 || res.statusCode == 404) return null;
    throw _err(res, 'Не удалось получить бронь');
  }

  /// Same shape as [fetchActiveBooking] but for the NEXT booking in
  /// the dual-slot window (user has one active + one upcoming).
  Future<ActiveBooking?> fetchNextUpcomingBooking() async {
    final res = await _api.dio.get('/api/me/next-upcoming-booking');
    if (res.statusCode == 200) {
      final data = res.data;
      if (data is Map<String, dynamic> && data['booking'] != null) {
        return ActiveBooking.fromJson(data);
      }
      return null;
    }
    if (res.statusCode == 204 || res.statusCode == 404) return null;
    throw _err(res, 'Не удалось получить следующую бронь');
  }

  Exception _err(Response<dynamic> r, String fallback) {
    final d = r.data;
    if (d is Map<String, dynamic> && d['error'] is String) {
      return Exception(d['error'] as String);
    }
    return Exception('$fallback (HTTP ${r.statusCode})');
  }
}

final profileRepositoryProvider = FutureProvider<ProfileRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return ProfileRepository(api);
});

/// Combined booking state the schedule screen consumes to resolve
/// sessionId → bookingId when the user taps "Отменить бронь".
///
/// Keyed by sessionId so the card widget can do an O(1) lookup.
final myBookingsBySessionIdProvider =
    FutureProvider.autoDispose<Map<int, int>>((ref) async {
  final repo = await ref.watch(profileRepositoryProvider.future);
  final results = await Future.wait([
    repo.fetchActiveBooking(),
    repo.fetchNextUpcomingBooking(),
  ]);
  final map = <int, int>{};
  for (final b in results) {
    if (b != null) map[b.sessionId] = b.bookingId;
  }
  return map;
});

final profileStatsProvider =
    FutureProvider.autoDispose<ProfileStats>((ref) async {
  final repo = await ref.watch(profileRepositoryProvider.future);
  return repo.fetchStats();
});
