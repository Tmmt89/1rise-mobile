import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onerise_mobile/core/api_client.dart';
import 'package:onerise_mobile/features/room/room_models.dart';

/// Talks to `/api/video/room/:id/*` for join + moderator actions.
///
/// The join endpoint is dual-purpose: on first entry it issues a
/// token for the main room, and on reconnect during an active
/// breakout it issues a token for the sub-room (reload-recovery).
/// The client is oblivious — it just gets a (wsUrl, token, roomName)
/// tuple either way.
///
/// Moderator actions (`/mod/kick`, `/mod/mute`, `/breakouts/*`) are
/// defined here as `Future<void>` stubs for T3 — wiring them to the
/// UI is the day-3 work, backend side is already live on 1rise.ru.
class RoomRepository {
  RoomRepository(this._api);

  final ApiClient _api;

  /// Join flow.
  ///
  ///   200 → RoomJoinReady.
  ///   202 → RoomJoinWaiting (caller polls).
  ///   403 BANNED → Exception with the "N minutes left" message.
  ///   any other status → Exception with the server's error string.
  Future<RoomJoinResult> join(int sessionId) async {
    final res = await _api.dio.get('/api/video/room/$sessionId/join');

    if (res.statusCode == 202) {
      final d = res.data as Map<String, dynamic>;
      return RoomJoinWaiting(
        message: (d['message'] as String?) ??
            'Преподаватель ещё не зашёл в комнату.',
        reason: d['reason'] as String?,
      );
    }

    if (res.statusCode == 200) {
      final data = res.data as Map<String, dynamic>;
      final r = RoomJoinResponse.fromJson(data);
      if (r.engine != 'livekit' || r.token.isEmpty || r.wsUrl.isEmpty) {
        throw Exception(
          'Неожиданный ответ сервера — engine=${r.engine}, '
          'token=${r.token.isEmpty ? "empty" : "ok"}',
        );
      }
      return RoomJoinReady(r);
    }

    throw _err(res, 'Не удалось подключиться к уроку');
  }

  // T3 stubs — not wired to UI yet but the backend is ready.

  Future<void> kick(int sessionId, String identity) async {
    final res = await _api.dio.post(
      '/api/video/room/$sessionId/mod/kick',
      data: {'identity': identity},
    );
    if (res.statusCode != 200) throw _err(res, 'Не удалось удалить участника');
  }

  Future<void> mute({
    required int sessionId,
    required String identity,
    required String kind, // 'audio' | 'video'
    bool muted = true,
  }) async {
    final res = await _api.dio.post(
      '/api/video/room/$sessionId/mod/mute',
      data: {'identity': identity, 'kind': kind, 'muted': muted},
    );
    if (res.statusCode != 200) throw _err(res, 'Не удалось отключить дорожку');
  }

  Exception _err(Response<dynamic> r, String fallback) {
    final d = r.data;
    if (d is Map<String, dynamic> && d['error'] is String) {
      return Exception(d['error'] as String);
    }
    return Exception('$fallback (HTTP ${r.statusCode})');
  }
}

final roomRepositoryProvider = FutureProvider<RoomRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RoomRepository(api);
});
