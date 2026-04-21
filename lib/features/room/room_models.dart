// Shapes for `/api/video/room/:id/join`.
//
// The backend returns one of three things:
//   - 200 with the full LiveKit descriptor (token, wsUrl, etc).
//   - 202 with `{ waiting: true, message, reason }` — attendee
//     arrived before a moderator; client should poll.
//   - 403/404/409 — mapped into a [RoomJoinError] string at the
//     repo layer.

class RoomJoinResponse {
  const RoomJoinResponse({
    required this.engine,
    required this.role,
    required this.sessionTitle,
    required this.roomName,
    required this.wsUrl,
    required this.token,
    this.breakoutEndsAt,
  });

  /// 'livekit' — the only engine this app talks to directly.
  final String engine;
  /// 'moderator' | 'attendee' — drives which UI controls render.
  final String role;
  final String sessionTitle;
  /// LiveKit room name (either the main room or the breakout sub-room
  /// when /join does reload-recovery).
  final String roomName;
  /// `wss://meet.1rise.ru` — derived from the backend's LIVEKIT_URL.
  final String wsUrl;
  /// Per-user JWT. Room-scoped. Valid for a couple of hours.
  final String token;
  /// Present when reload-recovery detected an active breakout assignment
  /// and minted a token for the sub-room. Client uses this to show a
  /// countdown bar.
  final DateTime? breakoutEndsAt;

  bool get isModerator => role == 'moderator';

  factory RoomJoinResponse.fromJson(Map<String, dynamic> j) {
    return RoomJoinResponse(
      engine: (j['engine'] as String?) ?? '',
      role: (j['role'] as String?) ?? 'attendee',
      sessionTitle: (j['sessionTitle'] as String?) ?? '',
      roomName: (j['roomName'] as String?) ?? '',
      wsUrl: (j['wsUrl'] as String?) ?? '',
      token: (j['token'] as String?) ?? '',
      breakoutEndsAt: (j['breakoutEndsAt'] as String?) != null
          ? DateTime.parse(j['breakoutEndsAt'] as String)
          : null,
    );
  }
}

/// Result the screen actually consumes: either a valid join, or a
/// "waiting for teacher" banner. Modelled as a sealed pair so the UI
/// can `switch` cleanly.
sealed class RoomJoinResult {
  const RoomJoinResult();
}

class RoomJoinReady extends RoomJoinResult {
  const RoomJoinReady(this.response);
  final RoomJoinResponse response;
}

class RoomJoinWaiting extends RoomJoinResult {
  const RoomJoinWaiting({required this.message, this.reason});
  final String message;
  final String? reason;
}
