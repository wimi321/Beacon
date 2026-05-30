# App Store Distribution

Beacon Survival SOS has been approved for Apple App Store distribution.

| Item | Status |
| --- | --- |
| App Store name | Beacon Survival SOS |
| App Apple ID | `6772494235` |
| App Store URL | <https://apps.apple.com/us/app/beacon-survival-sos/id6772494235> |
| Bundle ID | `com.beacon.sos` |
| Distribution status | Approved for App Store distribution |
| Release mode | Manual release / regional rollout through App Store Connect |
| Price | Free |
| Privacy label | No data collected |
| Device family | iPhone |
| iOS model policy | Bundled Gemma 4 E2B; no in-app model picker required for normal users |

> Apple search, App Store lookup APIs, and some regional storefronts can take up
> to 24 hours to refresh after approval or manual release. If search does not
> show the app yet, use the direct App Store URL above.

## Review Fixes Included

The accepted App Store build includes the fixes prepared after Apple's initial review feedback:

- iPhone-first layout with iPad compatibility no longer exposing clipped bottom controls.
- Visible citations below medical, safety, and emergency guidance where retrieval sources are available.
- Camera and photo-library access limited to user-initiated Visual Help.
- Removed the old SOS/location feature and the unused location permission.
- Removed proactive network-state probing on launch.
- Store-safe permission text for camera and photo-library access.
- Bundled offline public-safety knowledge and on-device Gemma 4 E2B runtime for the iOS path.

## User-Facing Positioning

Beacon Survival SOS is an offline emergency guidance app. It does not require login, cloud inference, ads, or tracking. The iOS build bundles Gemma 4 E2B and the offline public-safety knowledge base so a user can install from the App Store and use the core emergency flow without downloading model weights separately.

Android distribution continues through GitHub Releases. The Android APK remains lightweight and lets users download Gemma 4 E2B or E4B in-app with resumable mirror fallback.

## Validation Record

The App Store release line was prepared with the following gates during the v0.2.x submission cycle:

- Web test suite and production build.
- Capacitor sync for Android and iOS shells.
- iOS archive and App Store export/upload validation.
- App Store Connect processing fixes for Swift support and embedded LiteRT runtime frameworks.
- iPhone real-device smoke testing for launch, text chat, photo intake, citations, and navigation.

The latest repository release notes are tracked in [`docs/releases`](./releases/README.md).

## Maintenance Notes

- Keep this page aligned with the App Store listing after each approved build.
- Keep README download badges pointed at the stable App Store URL, not search results.
- If Apple changes availability by region, document the affected storefronts here.
- If the iOS model policy changes from bundled E2B to downloadable models, update the README install table and App Review notes together.
