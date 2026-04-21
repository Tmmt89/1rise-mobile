/// Build-time configuration. Single source of truth for every endpoint,
/// room URL, and feature flag the app reads.
///
/// Overridable via `--dart-define` at `flutter run` / `flutter build`:
///
///   flutter run --dart-define=API_BASE_URL=https://staging.1rise.ru
///
/// Production defaults point at the live clone. Changing the default
/// requires a code change + CI build — we do NOT read from env at
/// runtime, because that would require another round-trip on every
/// cold start.
class AppConfig {
  const AppConfig._();

  /// Base URL for all `/api/*` calls. Must NOT have a trailing slash —
  /// consumers concatenate `'/api/whatever'`.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://1rise.ru',
  );

  /// LiveKit server URL. The backend also returns this in the
  /// `/api/video/room/:id/join` response body, so the client can
  /// ignore this constant — but we keep it here as a fallback for
  /// the (unusual) case where the server omits it.
  static const defaultLivekitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://meet.1rise.ru',
  );

  /// When true, the API client dumps request/response headers + bodies
  /// to the log. Ship release builds with this off.
  static const bool httpLogging = bool.fromEnvironment(
    'HTTP_LOGGING',
    defaultValue: false,
  );
}
