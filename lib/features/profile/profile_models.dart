// Profile-area API shapes.
//
// The backend exposes three endpoints the app uses here:
//   GET /api/me/profile-stats     — { attended, missed }
//   GET /api/me/active-booking    — current active booking (null if none)
//   GET /api/me/next-upcoming-booking — next upcoming booking when the
//     user has two active ones (rare; the dual-slot feature).
//
// We only hand-write what the mobile surface needs. The full set of
// booking fields (lockUntil, expiredAt, …) is elided — add them if
// a screen starts wanting them.

class ProfileStats {
  const ProfileStats({required this.attended, required this.missed});

  final int attended;
  final int missed;

  factory ProfileStats.fromJson(Map<String, dynamic> j) => ProfileStats(
        attended: (j['attended'] as int?) ?? 0,
        missed: (j['missed'] as int?) ?? 0,
      );

  static const empty = ProfileStats(attended: 0, missed: 0);
}

/// Return shape of `/api/me/active-booking` and
/// `/api/me/next-upcoming-booking` — a (booking, session) pair.
class ActiveBooking {
  const ActiveBooking({
    required this.bookingId,
    required this.sessionId,
    required this.status,
  });

  final int bookingId;
  final int sessionId;
  /// 'active' | 'cancelled' | 'expired' — on this endpoint it's always
  /// 'active', but we parse it for forward-compat if the server adds
  /// a "pending" variant.
  final String status;

  factory ActiveBooking.fromJson(Map<String, dynamic> j) {
    final b = j['booking'] as Map<String, dynamic>?;
    if (b == null) {
      throw const FormatException('Expected { booking: {...} } in response');
    }
    return ActiveBooking(
      bookingId: b['id'] as int,
      sessionId: b['sessionId'] as int,
      status: (b['status'] as String?) ?? 'active',
    );
  }
}
