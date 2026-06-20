// Session shape — subset of what /api/sessions/upcoming returns.
//
// The backend ships ~25 fields per row (legacy + BBB + LiveKit +
// client-computed state). We pull only what the list+card needs.
// Later screens (detail, booking cancellation) can extend or copy
// this without breaking the list.

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.title,
    required this.teacher,
    required this.date,
    required this.time,
    required this.startAtUtc,
    required this.capacity,
    required this.durationMinutes,
    required this.level,
    required this.hasActiveBooking,
    required this.stateForUser,
    required this.videoEngine,
    required this.hasBbb,
    this.description,
    this.zoomLink,
    this.imageUrl,
    this.tags,
    this.endAtIso,
    this.sessionStartIso,
  });

  final int id;
  final String title;
  final String teacher;
  /// 'YYYY-MM-DD' in Moscow-local (legacy string shape).
  final String date;
  /// 'HH:MM' in Moscow-local (legacy string shape).
  final String time;
  /// Authoritative UTC ISO-8601. Prefer this over [date]+[time] for
  /// any computation.
  final DateTime startAtUtc;
  final int capacity;
  final int durationMinutes;
  final String level; // 'Beginner' | 'Middle' | 'Advanced'
  final bool hasActiveBooking;
  /// Server-computed UI hint: 'upcoming' | 'in_progress' | 'archived'.
  final String stateForUser;
  /// 'bbb' | 'livekit' — which engine was provisioned. Drives where
  /// the join button sends the user.
  final String videoEngine;
  /// True if a room record exists in the sessions table (either
  /// BBB or LiveKit). When false + zoomLink empty, join is disabled.
  final bool hasBbb;

  final String? description;
  final String? zoomLink;
  final String? imageUrl;
  final String? tags;
  final DateTime? endAtIso;
  final DateTime? sessionStartIso;

  bool get isLive => stateForUser == 'in_progress';

  List<String> get tagList => (tags ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  factory SessionSummary.fromJson(Map<String, dynamic> j) {
    DateTime? parseOpt(Object? v) =>
        v is String && v.isNotEmpty ? DateTime.parse(v) : null;
    return SessionSummary(
      id: j['id'] as int,
      title: j['title'] as String,
      teacher: (j['teacher'] as String?) ?? '',
      date: j['date'] as String,
      time: j['time'] as String,
      startAtUtc: DateTime.parse(j['startAtUtc'] as String),
      capacity: (j['capacity'] as int?) ?? 0,
      durationMinutes: (j['durationMinutes'] as int?) ??
          (j['duration'] as int?) ??
          60,
      level: (j['level'] as String?) ?? 'Beginner',
      hasActiveBooking: (j['hasActiveBooking'] as bool?) ?? false,
      stateForUser: (j['stateForUser'] as String?) ?? 'upcoming',
      videoEngine: (j['videoEngine'] as String?) ?? 'bbb',
      hasBbb: (j['hasBbb'] as bool?) ?? false,
      description: j['description'] as String?,
      zoomLink: j['zoomLink'] as String?,
      imageUrl: j['imageUrl'] as String?,
      tags: j['tags'] as String?,
      endAtIso: parseOpt(j['endAtISO']),
      sessionStartIso: parseOpt(j['sessionStartISO']),
    );
  }
}
