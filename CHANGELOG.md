# Changelog

All notable changes to Beacon will be documented in this file.

## v0.2.14 - 2026-04-25

Portrait-only mobile shell release focused on panic-proof ergonomics.

### Highlights

- Locks the Android app to portrait orientation so gravity sensor changes no longer rotate the rescue UI into landscape
- Restricts iPhone and iPad supported orientations to portrait only
- Enables iPad full-screen mode so portrait-only orientation behaves consistently with native iOS rules
- Bumps Android to `versionCode 17` / `versionName 0.2.14`

### Verification

- Validated Android manifest contains `android:screenOrientation="portrait"`
- Validated iOS `Info.plist` only declares `UIInterfaceOrientationPortrait` for iPhone and iPad
- Installed on Android real device and forced system rotation to landscape; Beacon remained portrait at `1080 x 2400`
- `npm test -- --run`
- `npm run build`
- `npm run mobile:android:release:github`
- `plutil -lint ios/App/App/Info.plist`

## v0.2.13 - 2026-04-25

Model setup reliability release focused on interrupted large-weight downloads.

### Highlights

- Lets users resume a partially downloaded Gemma 4 model instead of leaving the model card locked at `下载中 0%`
- Keeps actively downloading models protected from double taps while treating interrupted partial files as resumable
- Preserves the lightweight APK path: model weights are still downloaded in-app with mirror fallback and resume support
- Bumps Android to `versionCode 16` / `versionName 0.2.13`

### Verification

- Real-device Android E4B download smoke test confirmed visible progress, resume from a partial file, completion, and automatic model switch
- Real-device interrupted-download state reproduced after force stop and fixed for resume
- Real-device camera and album visual-help flows verified that submitted images appear in chat before local analysis
- Added regression coverage for partially downloaded model resume
- `npm test -- --run`
- `npm run build`

## v0.2.12 - 2026-04-25

Visual rescue polish release focused on making photo-based help feel trustworthy and chat-native.

### Highlights

- Shows captured camera photos directly inside the chat as a user message before local visual analysis starts
- Shows imported album photos the same way, so users can confirm the exact image they submitted
- Adds a rounded, constrained image preview style that fits mobile chat without pushing the whole UI around
- Keeps the real native multimodal request path unchanged: the same image payload is still sent to local Gemma 4
- Bumps Android to `versionCode 15` / `versionName 0.2.12`

### Verification

- Added regression coverage for camera photo preview in chat
- Added regression coverage for album photo preview in chat
- `npm test -- --run`
- `npm run build`
- `npm run mobile:android:release:github`

## v0.2.11 - 2026-04-25

Download resilience release focused on making the in-app Gemma 4 model setup usable in mainland China without bundling multi-GB weights into the APK.

### Highlights

- Adds ModelScope CDN mirrors as the first download source for both `Gemma 4 E2B` and `Gemma 4 E4B`
- Keeps `hf-mirror.com` and the official Hugging Face URLs as ordered fallbacks
- Updates the legacy `downloadUrl` field so older allowlist readers also use the China-friendly source first
- Keeps the APK lightweight: users still download model weights in-app, with resumable progress and mirror failover
- Bumps Android to `versionCode 14` / `versionName 0.2.11`

### Verification

- Verified ModelScope E2B and E4B URLs with per-command proxy bypass; system proxy was not changed
- Confirmed both ModelScope files support byte ranges, resume chunks, and expected file sizes
- Confirmed first 1 MiB SHA256 matches the existing Hugging Face mirror for both E2B and E4B
- `npm test -- --run`
- `npm run build`
- `cd android && ./gradlew testReleaseUnitTest`
- `npm run mobile:android:release:github`

## v0.2.10 - 2026-04-25

Mobile release focused on real-device usability, visual rescue entry reliability, and cleaner model output.

### Highlights

- Replaces the hard-to-read native camera source prompt with a clear in-app visual picker for `拍摄 / 从相册导入`
- Keeps the native camera and Android photo picker flows intact while making the first visual-help step obvious
- Centers the language menu inside the model/settings sheet so it no longer clips against the screen edge
- Cleans display-only markdown emphasis leftovers from local model responses while preserving paragraphs, bullets, and numbered steps
- Bumps Android to `versionCode 13` / `versionName 0.2.10`

### Verification

- Real-device Android install and smoke test on `25019PNF3C` / Android 16
- Cold launch with downloaded Gemma 4 E2B showing `离线就绪`
- Visual Help picker, native camera permission/capture flow, and native album picker flow
- Local model text generation with offline NPS survival evidence
- Returning home while the model is still generating
- `npm test -- --run`
- `cd android && ./gradlew testReleaseUnitTest`
- `npm run mobile:android:release:github`

## v0.2.3 - 2026-04-24

Brand polish release focused on making Beacon feel consistent and release-grade from install to splash to GitHub.

### Highlights

- Replaces the old white-background flame icon with a generated dark Beacon rescue-lantern app icon
- Adds generated brand masters for the app icon and transparent emblem, plus a reproducible brand asset pipeline
- Regenerates iOS AppIcon, Android launcher icons, adaptive foreground icons, Web/PWA icons, favicon, and apple-touch-icon
- Rebuilds iOS and Android splash screens with the same dark Beacon visual language
- Updates web metadata, PWA theme colors, and a premium GitHub/social preview image

### Verification

- `npm test`
- `npm run build`
- `git diff --check`
- `dart analyze --fatal-infos`
- `dart test`
- `cd android && ./gradlew testDebugUnitTest`
- `npm run mobile:android:release:github`

## v0.2.2 - 2026-04-24

Visual polish release focused on making the first screen feel calmer, clearer, and more premium without adding friction to emergency use.

### Highlights

- Adds a generated Beacon-style visual direction to the app UI: warm rescue glow, subtle map-line atmosphere, and stronger emergency hierarchy
- Refreshes the home screen hero with a compact signal aura while preserving one-screen panic actions
- Restyles panic cards, visual-help entry, chat input, SOS control, model sheet, and status badges for better touch confidence
- Regenerates README hero media and the English, Simplified Chinese, and Arabic screenshots from the updated interface
- Keeps RTL layout and multilingual home screen behavior intact while improving visual consistency

### Verification

- `npm test`
- `npm run build`
- `git diff --check`
- `dart analyze --fatal-infos`
- `dart test`
- `cd android && ./gradlew testDebugUnitTest`
- `npm run mobile:android:release:github`

## v0.2.1 - 2026-04-24

Release polish for the Android APK, mobile interaction flow, and GitHub delivery.

### Highlights

- Keeps the chat input editable while the local model is generating, so users can prepare the next follow-up without waiting
- Simplifies the first-launch model sheet by removing duplicate model cards while the download guide is shown
- Ships the latest AI response cleanup so structural prompt markers are not shown in chat
- Corrects README model download sizes to match the current Gemma 4 E2B / E4B allowlist

### Verification

- `npm test`
- `npm run build`
- `dart analyze --fatal-infos`
- `dart test`
- `cd android && ./gradlew testDebugUnitTest`

## v0.1.1 - 2026-04-18

Focused release for install flow, first-launch model onboarding, and GitHub delivery polish.

### Highlights

- Added a first-launch `Settings & Models` onboarding card with direct `Gemma 4 E2B / E4B` download actions
- Switched GitHub delivery to a lightweight Android ARM64 APK plus in-app model download flow
- Added a dedicated `mobile:android:release:github` build command for publishable release artifacts

### Product and UX

- Auto-opens the model sheet when no local model is available
- Makes `Gemma 4 E2B` the obvious one-tap recommended starting point
- Simplifies model cards so they show user-facing model state instead of raw local file paths
- Fixes the cold-start home-state bug where system-only warnings could incorrectly push the app into chat view
- Preserves the emergency home screen when the app boots with a low-battery warning only

### Release and docs

- Added APK-first download guidance to both English and Chinese READMEs
- Added Android and iOS release-hardening notes for `v0.1.1`
- Added a release-notes index plus a Simplified Chinese `v0.1.1` release note
- Added a user-perspective acceptance checklist update with this round's validation evidence
- Synced repository package and app version metadata to `0.1.1`

### Verification

- `npm test`
- `npm run build`
- `npm run mobile:build`
- `dart analyze`
- `dart test`
- `cd android && ./gradlew :app:testDebugUnitTest :app:testReleaseUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease :app:bundleRelease`
- `xcodebuild -project ios/App/App.xcodeproj -scheme App -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project ios/App/App.xcodeproj -scheme App -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`

## v0.1.0 - 2026-04-18

First public GitHub release of Beacon.

### Highlights

- Published the project as a public open-source repository
- Added a polished multilingual GitHub landing page and collaboration docs
- Added a README hero demo GIF and short video asset
- Enabled GitHub Discussions and expanded community templates

### Product and runtime

- Real on-device Gemma 4 emergency guidance path
- Offline-first knowledge grounding bundle included in the repository
- Session memory sidecar for continuous emergency conversations
- Android and iOS native shells included
- Camera and local photo intake flow included
- 20-language UI support with manual switching and Arabic RTL support

### Repository and community

- Added Apache-2.0 licensing
- Added English and Simplified Chinese repository docs
- Added CI, issue forms, PR template, and release metadata
- Added i18n documentation and community conduct guidance

### Verification

- `npm test`
- `npm run build`
- `dart test`
- GitHub Actions CI passing

### Known limitations

- iOS release-device validation is still being broadened across more hardware
- Oversized local iOS vendor archives remain intentionally excluded from git
- The public repository is source-first and pre-release, not yet a final store distribution package
