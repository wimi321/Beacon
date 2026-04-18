# Changelog

All notable changes to Beacon will be documented in this file.

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

### Release and docs

- Added APK-first download guidance to both English and Chinese READMEs
- Synced repository package and app version metadata to `0.1.1`

### Verification

- `npm test`
- `npm run build`

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
