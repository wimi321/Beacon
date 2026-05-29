# App Store Status

Beacon's first iOS App Store submission was rejected and the project is being prepared for resubmission.

| Item | Status |
| --- | --- |
| App Store name | Beacon Survival SOS |
| Bundle ID | `com.beacon.sos` |
| Rejected version | `0.2.17` |
| Rejected build | `18` |
| Review date | 2026-05-26 |
| Resubmission candidate | `0.2.20` build `27` |
| Release mode | Manual release after Apple approval |
| Price | Free |
| Privacy label | No data collected |

## Apple Review Issues

- Guideline 4 - Design: the app UI was crowded/cut off on iPad Air 11-inch (M3), with bottom controls not visible.
- Guideline 1.4.1 - Safety / Physical Harm: medical guidance did not expose citations that were easy for users to find.

## Resubmission Fixes

- iOS is now configured as an iPhone-only app (`UIDeviceFamily = [1]`) while still keeping the iPad compatibility presentation usable if Apple opens it on iPad.
- The home screen bottom input and primary controls are visible in iPhone and iPad compatibility screenshots.
- AI medical/safety answers now show a visible "Sources and citations" panel with source titles and URLs below the response.
- If retrieved evidence is missing but the answer contains likely medical guidance, Beacon shows conservative fallback citations from MedlinePlus, MSD Manual, and WHO.
- The removed SOS UI no longer requests location permission. The iOS build no longer includes `NSLocationWhenInUseUsageDescription`, and the Capacitor Geolocation plugin has been removed.
- The iOS build no longer registers the Capacitor Network plugin, so Beacon does not proactively query wireless/cellular network state on launch.
- Permission text is bilingual and scoped to camera/photo-library use for local visual help.

## Validation

- `npm test -- --run`: 11 files, 101 tests passed.
- `npm run build`: passed.
- `npm run mobile:build`: passed; iOS/Android Capacitor sync now includes 6 plugins.
- iOS generic Release build passed with Xcode store validation.
- Built app contains bundled `gemma-4-E2B-it.litertlm` and `libLiteRtMetalAccelerator.dylib`.
- iPhone 17 Pro simulator screenshot: `.artifacts/ios-review/iphone17pro-v020-current.png`.
- iPad Air 11-inch compatibility screenshot: `.artifacts/ios-review/ipad-air-11-v020-compat.png`.
- Modern iPhone true-device smoke is still blocked locally because the connected iPhone 15 Pro is visible to Xcode but marked unavailable.

## Notes

- The iOS build includes the local Gemma E2B profile and bundled public-safety knowledge used for App Store review.
- Camera and photo-library permissions are used only for Visual Help, and images are processed locally on device.
- Beacon does not require login, does not use cloud inference, and does not include ads or tracking.
- Android distribution continues through GitHub Releases. The current Android release track may move faster than the App Store review track while Apple review is pending.

## Suggested App Review Notes

Beacon Survival SOS is an offline emergency guidance app. It does not require login, cloud inference, ads, or tracking. The iOS build bundles Gemma E2B and the offline public-safety knowledge base.

Changes since the rejected 0.2.17 build:

- Fixed iPad compatibility layout so bottom controls remain visible.
- Set the iOS target family to iPhone only.
- Added visible citations below medical and safety answers.
- Removed the unused SOS/location feature and removed location permission.
- Kept camera/photo access limited to user-initiated Visual Help, with image processing on device.
