# Changelog

All notable changes to Beacon will be documented in this file.

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
