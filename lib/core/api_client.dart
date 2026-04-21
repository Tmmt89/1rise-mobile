import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:onerise_mobile/core/config.dart';

/// Singleton Dio instance plus a cookie jar that persists across app
/// restarts.
///
/// The backend at 1rise.ru authenticates via a `rise.sid` session
/// cookie (connect-pg-simple + express-session — see
/// `server/index.ts` in the backend repo). Since every
/// authenticated call depends on that cookie surviving background
/// → foreground transitions and full restarts, we back the cookie
/// jar with `PersistCookieJar` writing to the app documents dir.
///
/// Every consumer pulls the instance via Riverpod (`apiClientProvider`)
/// rather than reaching through a global, so tests can override with
/// a mock Dio without touching this file.
class ApiClient {
  ApiClient._(this.dio);

  final Dio dio;

  /// Builds a fresh client. Not a singleton — Riverpod owns the
  /// lifetime via the provider below.
  static Future<ApiClient> create() async {
    final documentsDir = await path_provider.getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(
      storage: FileStorage('${documentsDir.path}/.cookies/'),
      ignoreExpires: false,
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        // JSON everywhere. The single raw-body endpoint
        // (`/api/livekit/webhook`) is server-to-server, the app
        // never calls it.
        headers: {'Accept': 'application/json'},
        // Never follow redirects into HTML pages — if the backend
        // wedges and serves the SPA catch-all by mistake, we want to
        // notice as a decode error, not silently swallow a 200-OK
        // HTML document.
        responseType: ResponseType.json,
        validateStatus: (s) => s != null && s >= 200 && s < 500,
      ),
    );

    dio.interceptors.add(CookieManager(cookieJar));

    if (AppConfig.httpLogging) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        // ignore: avoid_print
        logPrint: (o) => print(o),
      ));
    }

    return ApiClient._(dio);
  }

  /// Wipe the cookie jar. Called by the auth repo on logout so a
  /// fresh login starts clean.
  Future<void> clearCookies() async {
    final jar = (dio.interceptors
            .firstWhere((i) => i is CookieManager) as CookieManager)
        .cookieJar;
    await jar.deleteAll();
  }
}

/// Riverpod async provider. Every feature repo depends on this one.
final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  return ApiClient.create();
});

/// Convenience provider for the small amount of state we cache locally
/// (auth status, last-seen user id). Kept separate from the cookie jar
/// because SharedPreferences is easier to reset + simpler to test.
final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});
