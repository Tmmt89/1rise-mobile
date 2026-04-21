import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onerise_mobile/features/auth/auth_models.dart';
import 'package:onerise_mobile/features/auth/auth_repository.dart';

/// UI-facing state machine for login. Owns the `loading` + `error`
/// flags the screens read; delegates actual network to the repo.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repoFuture) : super(AuthState.initial);

  final Future<AuthRepository> _repoFuture;

  /// Called at app start to hydrate the user if the persisted cookie
  /// is still valid.
  Future<void> restore() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final repo = await _repoFuture;
      final user = await repo.currentUser();
      state = state.copyWith(user: user, loading: false, clearUser: user == null);
    } catch (e) {
      // Don't surface the error on silent restore — the login screen
      // is a fine fallback for "we couldn't reach the backend right
      // now". If we set an error here it would flash on cold start
      // for anyone with a flaky connection.
      state = state.copyWith(loading: false, clearUser: true);
    }
  }

  Future<void> requestOtp(String email) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final repo = await _repoFuture;
      await repo.requestOtp(email);
      state = state.copyWith(loading: false);
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: _cleanErr(e));
    }
  }

  Future<bool> verifyOtp({required String email, required String code}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final repo = await _repoFuture;
      final user = await repo.verifyOtp(email: email, code: code);
      state = state.copyWith(user: user, loading: false);
      return true;
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: _cleanErr(e));
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final repo = await _repoFuture;
      await repo.logout();
    } finally {
      state = const AuthState();
    }
  }

  /// Returns true if the account was created. Caller then kicks off
  /// the OTP flow with the same email — we deliberately do NOT auto-
  /// login, because the email must be verified before the user is
  /// trusted to hold a session.
  Future<bool> register({
    required String name,
    required String email,
    String? phone,
    required bool privacyAccepted,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final repo = await _repoFuture;
      await repo.register(
        name: name,
        email: email,
        phone: phone,
        privacyAccepted: privacyAccepted,
      );
      state = state.copyWith(loading: false);
      return true;
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: _cleanErr(e));
      return false;
    }
  }

  String _cleanErr(Exception e) {
    final s = e.toString();
    // `Exception: <msg>` → `<msg>` for a nicer UI surface.
    return s.startsWith('Exception: ') ? s.substring('Exception: '.length) : s;
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repoFuture = ref.watch(authRepositoryProvider.future);
  return AuthController(repoFuture);
});
