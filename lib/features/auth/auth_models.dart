// Shapes that match the backend's /api/auth/* and /api/me responses.
//
// We hand-write these rather than code-gen via `freezed` because the
// surface is small enough that the boilerplate cost is lower than the
// build-runner setup tax. If this grows past ~5 models we'll introduce
// freezed and migrate in one go.

class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.status,
    this.gender,
    this.telegramLinked = false,
  });

  final String id;
  final String name;
  final String email;
  /// 'admin' | 'teacher' | 'user'
  final String role;
  final String? status;
  final String? gender;
  final bool telegramLinked;

  bool get isAdmin => role == 'admin';
  bool get isTeacher => role == 'teacher';

  factory CurrentUser.fromJson(Map<String, dynamic> j) => CurrentUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        role: (j['role'] as String?) ?? 'user',
        status: j['status'] as String?,
        gender: j['gender'] as String?,
        telegramLinked: (j['telegramLinked'] as bool?) ?? false,
      );
}

/// Thin wrapper so the provider layer can distinguish "we haven't
/// checked yet" (null) from "we checked and there's no session"
/// (not-null with [user] == null).
class AuthState {
  const AuthState({this.user, this.loading = false, this.error});

  final CurrentUser? user;
  final bool loading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    CurrentUser? user,
    bool? loading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );

  static const initial = AuthState();
}
