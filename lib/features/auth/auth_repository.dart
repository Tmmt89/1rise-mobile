import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onerise_mobile/core/api_client.dart';
import 'package:onerise_mobile/features/auth/auth_models.dart';

/// Talks to `/api/auth/*` and `/api/me`.
///
/// The API mirrors the web app's flow:
///   1. `POST /api/auth/request-otp { email }` — backend generates a
///      6-digit code, stores its bcrypt hash, sends via UniSender.
///   2. `POST /api/auth/verify-otp { email, code }` — backend sets the
///      `rise.sid` session cookie (our cookie jar picks it up) and
///      returns the user. Admin accounts use `/api/auth/admin-login`
///      with password instead — we don't expose that on mobile.
///   3. `GET /api/me` — refresh user profile at cold start.
///   4. `POST /api/auth/logout` — clears the server-side session.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<void> requestOtp(String email) async {
    try {
      final res = await _api.dio.post(
        '/api/auth/request-otp',
        data: {'email': email.trim().toLowerCase()},
      );
      if (res.statusCode != 200) {
        throw _errFromResponse(res, fallback: 'Не удалось отправить код');
      }
    } on DioException catch (e) {
      throw _networkErr(e);
    }
  }

  /// Self-registration for a free-tier student account.
  ///
  /// Mirrors the web app's `/api/register` endpoint:
  ///   { name, email, phone?, privacyAccepted, marketingAccepted }
  /// 201 on success, 400 on validation, 409 on email already in use.
  ///
  /// The server does NOT set a session cookie here — the user still
  /// has to go through the OTP flow to log in. That's on purpose so
  /// we verify the email belongs to the person who typed it.
  Future<void> register({
    required String name,
    required String email,
    String? phone,
    required bool privacyAccepted,
    bool marketingAccepted = false,
  }) async {
    try {
      final res = await _api.dio.post(
        '/api/register',
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          'privacyAccepted': privacyAccepted,
          'marketingAccepted': marketingAccepted,
        },
      );
      if (res.statusCode == 201 || res.statusCode == 200) return;
      throw _errFromResponse(res, fallback: 'Не удалось зарегистрироваться');
    } on DioException catch (e) {
      throw _networkErr(e);
    }
  }

  /// Verifies the OTP. On success the session cookie is already
  /// in our jar — caller just needs to query [currentUser] or use
  /// the returned user object directly.
  Future<CurrentUser> verifyOtp({
    required String email,
    required String code,
  }) async {
    try {
      final res = await _api.dio.post(
        '/api/auth/verify-otp',
        data: {'email': email.trim().toLowerCase(), 'code': code.trim()},
      );
      if (res.statusCode != 200) {
        throw _errFromResponse(res, fallback: 'Неверный код');
      }
      return CurrentUser.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _networkErr(e);
    }
  }

  /// Returns the current user if a valid session cookie is present,
  /// null if 401. Any other error re-throws so the UI doesn't silently
  /// treat a 500 as "logged out".
  Future<CurrentUser?> currentUser() async {
    try {
      final res = await _api.dio.get('/api/me');
      if (res.statusCode == 200) {
        return CurrentUser.fromJson(res.data as Map<String, dynamic>);
      }
      if (res.statusCode == 401) return null;
      throw _errFromResponse(res, fallback: 'Не удалось получить профиль');
    } on DioException catch (e) {
      throw _networkErr(e);
    }
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/api/auth/logout');
    } on DioException {
      // Network flake on logout shouldn't trap the user in the app —
      // we'll still clear the local cookie jar below.
    }
    await _api.clearCookies();
  }

  Exception _errFromResponse(Response<dynamic> r, {required String fallback}) {
    final data = r.data;
    if (data is Map<String, dynamic> && data['error'] is String) {
      return Exception(data['error'] as String);
    }
    return Exception('$fallback (HTTP ${r.statusCode})');
  }

  /// Network-level failures (DNS, timeout, TLS, server 5xx with the
  /// default Dio validateStatus) don't carry a parsed body — surface
  /// a clean Russian message and the root cause for the console.
  Exception _networkErr(DioException e) {
    // If the server did reply with a body (rare with validateStatus
    // accepting <500 as ok, but possible on 5xx), prefer the parsed
    // error — it's more specific than "connection failed".
    final resp = e.response;
    if (resp != null && resp.data is Map<String, dynamic>) {
      final msg = (resp.data as Map<String, dynamic>)['error'];
      if (msg is String) return Exception(msg);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return Exception('Сервер не отвечает. Проверьте интернет и попробуйте снова.');
      case DioExceptionType.connectionError:
        return Exception('Нет связи с сервером. Проверьте интернет.');
      case DioExceptionType.badCertificate:
        return Exception('Ошибка сертификата сервера.');
      case DioExceptionType.cancel:
        return Exception('Запрос отменён.');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return Exception(
          'Ошибка сети: ${e.message ?? e.type.name} '
          '(HTTP ${e.response?.statusCode ?? "—"})',
        );
    }
  }
}

/// Provider wiring. `apiClientProvider` resolves first, then we hand
/// it to the repo. Unwrapping the FutureProvider is centralised here
/// so no feature consumer has to deal with `AsyncValue<AuthRepository>`.
final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return AuthRepository(api);
});
