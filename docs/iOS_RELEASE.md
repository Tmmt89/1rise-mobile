# iOS release runbook

## Prereq — Apple Developer account

Building to your own phone via Xcode works with a free Apple ID
(provisioning expires every 7 days — not ok for end users but fine
for dogfooding). Anything past that needs a paid account:

- **Apple Developer Program individual** — $99/year. Sufficient for
  TestFlight + public App Store release. Register at
  https://developer.apple.com/programs/.
- **Apple Developer Program organization** — $99/year, requires a
  D-U-N-S number + legal entity. Use this if you want the store
  listing to show as "Rise Speaking Club LLC" instead of a person.

**Known risk for Russian services** — App Store reviewers have
rejected apps for Russian payment services several times since
early 2022. Mitigations:

1. TestFlight first — a beta with 10k external testers doesn't
   require App Store review and won't get caught in the political
   filter. Good enough for initial user validation.
2. Public release: position the app as "online English classes,"
   not "Russian service." Keep copy neutral. No payment happens
   inside the mobile app (bookings use existing web payment flow).

## Build + sign

```bash
# One-time: open the Xcode project once so Xcode registers
# bundle ID ru.onerise.onerise_mobile to your team
open ios/Runner.xcworkspace

# In Xcode: Runner target → Signing & Capabilities →
#   Team: pick your Apple Dev account
#   Automatically manage signing: ✅

# CLI build for testflight
flutter build ipa --export-method app-store
# Output: build/ios/ipa/onerise_mobile.ipa
```

## TestFlight submission

1. Upload the .ipa via **Transporter.app** (free from Mac App Store).
2. In App Store Connect → Apps → TestFlight tab, pick the build.
3. Fill out the compliance screen (we use HTTPS + standard WebRTC,
   no restricted crypto — answer "No" to the "uses non-exempt
   encryption" question with the WebRTC exemption citation).
4. Add internal testers (up to 100, instant access).
5. For external testers (up to 10k): submit for Beta App Review,
   typically 24-48h turnaround.

## App Store public release

The same build goes through App Store Review. Expect **at least
one reject cycle** — Apple's reasons usually include:

- "Your app is marketing-only / webview wrapper" — mitigation: show
  distinct native value (the LiveKit room UI, push notifications,
  offline-able schedule cache).
- "Privacy policy doesn't describe all collected data" — we collect
  email, name, microphone + camera, session booking data.
  Privacy policy lives at `1rise.ru/privacy`.
- "App crashes on our device" — test on older iPhones (min target
  is iOS 14, so anything iPhone 6s+).

## Deployment target

`ios/Runner.xcodeproj` is set to **iOS 14.0+**. Reason: `livekit_client`
requires iOS 13, but we bump to 14 to drop the last of the
`UIApplicationDelegate`-only paths and match what Apple's own
templates default to. Covers 98%+ of active iPhones in Russia.

## Info.plist permissions (already wired)

```
NSCameraUsageDescription      — student camera during lesson
NSMicrophoneUsageDescription  — student mic during lesson
NSLocalNetworkUsageDescription — LiveKit LAN fallback
UIBackgroundModes: audio, voip — keep mic alive when phone locked
```

The copy for each is in Russian. Store reviewers read these — we
keep the wording explicit about the **why**.

## Universal Links (deep linking — T2)

For the push-notif → tap-notif → open-room flow to land on
`/room/:id` cleanly (instead of a browser tab), we need Apple
Associated Domains + an `apple-app-site-association` file served
from `1rise.ru/.well-known/`:

```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "TEAMID.ru.onerise.onerise_mobile",
      "paths": ["/room/*"]
    }]
  }
}
```

Not wired yet. Land with T2 push notifications so the whole
notification → room flow works end-to-end.
