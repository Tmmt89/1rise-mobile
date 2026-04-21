# Build plan

Three tiers, shippable at every boundary. Timeline assumes AI-assisted
pair programming. Solo unassisted would be 2–3× these.

## T1 — usable MVP (~5–7 days)

Student can log in, see the schedule, book, and join a lesson. Teacher
can do the same plus land in the video room as moderator (basic
controls only: mic, cam, leave).

- [ ] Flutter project scaffold (android + ios targets)
- [ ] `pubspec.yaml` deps: `dio`, `dio_cookie_manager`, `flutter_riverpod`,
      `go_router`, `livekit_client`, `permission_handler`,
      `shared_preferences`
- [ ] `lib/core/config.dart` — base URL, LiveKit URL
- [ ] `lib/core/api_client.dart` — dio instance w/ cookie jar persisted
      to `shared_preferences`
- [ ] `lib/features/auth/` — email → OTP → verify flow, mirrors
      `/api/auth/request-otp` + `/api/auth/verify-otp`
- [ ] `lib/features/schedule/` — list upcoming sessions from
      `/api/sessions/upcoming`, filter by level/gender/free
- [ ] `lib/features/booking/` — `POST /api/sessions/:id/book`,
      `/api/me/active-booking`
- [ ] `lib/features/room/` — `/api/video/room/:id/join` → LiveKit
      `Room.connect(wsUrl, token)`, publish mic+camera, basic toolbar
- [ ] `lib/features/profile/` — `/api/me`, logout, archive view
- [ ] `lib/router.dart` — go_router with auth guard + deep links

**Ship gate:** teacher + student pair can do a 10-min test lesson end
to end on real devices.

## T2 — student polish (~+5–7 days)

Everything a student would actually want for daily use.

- [ ] Breakout move/return UX — listen to LiveKit `DataReceived`,
      parse `breakout:move` / `breakout:return`, disconnect +
      reconnect with preserved mic/cam state, full-screen overlay
      ("Переводим вас в мини-группу…")
- [ ] Participants list drawer (read-only for attendee, mod actions
      for teacher — T3)
- [ ] Push notifications — Firebase Cloud Messaging. Reminder 15 min
      before lesson start; arrival ping when teacher opens the room.
      Backend already has `notification_outbox`; wire a new channel
      type `MOBILE_PUSH` via FCM.
- [ ] Network reconnect UX — LiveKit auto-reconnects, but the UI
      should not look broken during the gap.
- [ ] Waiting-for-teacher state — poll `/api/video/room/:id/join`
      every 5s when 202 (same UX contract as the web app).
- [ ] Session kick-ban surface — if join returns 403 BANNED, show the
      "Повторное подключение возможно через N мин" screen.
- [ ] Russian locale throughout (no i18n layer; strings inlined).

**Ship gate:** bookable beta via Google Play Internal Testing + TestFlight.

## T3 — teacher controls (~+3–5 days)

Moderator-only features to match what the web client has.

- [ ] Hover-equivalent on mobile: long-press a participant tile →
      bottom sheet with Mute mic / Mute cam / Kick buttons.
- [ ] Kick bottom-sheet with 20-min ban confirmation.
- [ ] "Создать breakouts" sheet — per-participant group select + start.
- [ ] Countdown bar during active breakout + "Вернуть всех" button.
- [ ] Screen-share — moderator-only (student button hidden).

**Ship gate:** a teacher can run a full lesson with breakouts from the
phone, no web client needed.

## Store submission (~+3–5 days)

- [ ] App icon (adapt from web favicon or commission new)
- [ ] Splash screen (`flutter_native_splash`)
- [ ] Store listings: title, subtitle, description, keywords,
      screenshots (in Russian).
- [ ] Privacy policy — link to existing one at 1rise.ru/privacy
- [ ] **Android: Google Play Internal → Open Testing → Production.**
      ~2 business days review per stage.
- [ ] **Android: RuStore submission in parallel** — RF-friendly,
      mandatory per 2022 legislation for user-facing RF services.
- [ ] **iOS: TestFlight first.** App Store public release is a
      separate conversation — Russian payment services have been
      getting rejected; TestFlight beta to a small invite list works
      without review.
- [ ] iOS PWA fallback for users who can't install from App Store —
      the existing web app already works as PWA candidate, just needs
      a proper `manifest.json` + installability check.

## Not in scope for v1

- Admin surface (stays on web)
- Recording playback (admin-only per spec 0001 phase 5.6)
- Breakout drag-and-drop (select-per-row on mobile too)
- Dark mode (maybe v1.1)
- Real-time chat inside the room (maybe later spec)
- Offline mode / data caching beyond auth state

## Branch + PR convention

Mirrors the backend repo:

- `spec-0003/...` feature branches for mobile-only work
- Every phase a separate PR with its own acceptance criteria
- `main` is always deployable to Internal Testing
