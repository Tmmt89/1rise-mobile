# 1rise-mobile

Flutter mobile app for [1rise.ru](https://1rise.ru) — Russian speaking club with live
LiveKit video rooms, moderator controls, and breakout groups.

Android + iOS. Points at the existing backend — no server code lives here.

## What this app does

For **students**: browse the lesson schedule, book a slot, get a push
reminder, tap in when it's time and join the video room. Built-in
breakout support — when the teacher starts groups, the client migrates
rooms transparently.

For **teachers**: the above plus moderator controls (kick, force-mute,
breakouts) on top of each participant's tile.

For **admins**: managed via the web app at 1rise.ru/admin. Not in the
mobile surface (intentional — audit-sensitive stuff stays on the laptop).

## Architecture — in one paragraph

Talks to `https://1rise.ru/api/*` for everything except video. Session
auth via cookies (same as the web app). Video plane connects directly
to LiveKit via `livekit_client` — native WebRTC, not a webview. JWT
tokens minted by our backend per-join.

```
┌─────────────────────┐         ┌─────────────────────┐
│   Flutter client    │         │    1rise.ru API     │
│                     │  ──────▶│ /api/auth/*         │
│   dio + cookie jar  │         │ /api/sessions/*     │
│   riverpod state    │         │ /api/video/room/*   │
│   go_router         │         └─────────────────────┘
│                     │         ┌─────────────────────┐
│   livekit_client  ──┼────────▶│   meet.1rise.ru     │
│                     │  WSS    │   (LiveKit server)  │
└─────────────────────┘         └─────────────────────┘
```

## Status

Pre-alpha. Start of the project (see `docs/PLAN.md`).

## Development

```bash
# Requires Flutter 3.x
flutter pub get
flutter run             # picks up connected Android/iOS device
```

Backend: no setup — the app points at prod (`1rise.ru`). To point at
a local/staging backend, change the base URL in `lib/core/config.dart`.
