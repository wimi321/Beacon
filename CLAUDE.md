# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Beacon

Beacon is an offline-first emergency response app that runs on-device AI (Gemma 4 via LiteRT) to provide survival guidance without network connectivity. It spans three codebases: a React+TypeScript frontend, a Dart backend for offline business logic, and native Android (Kotlin) / iOS (Swift/Obj-C++) shells connected through Capacitor.

## Commands

### Development
```bash
npm install          # install frontend dependencies
npm run dev          # start Vite dev server
npm run build        # typecheck + production build (output: dist/)
npm test             # run frontend tests (Vitest)
```

### Dart backend
```bash
dart pub get         # install Dart dependencies
dart test            # run all Dart tests
dart test test/path_test.dart   # run a single Dart test file
```

### Mobile
```bash
npm run mobile:build                    # build web → sync Capacitor → validate native projects
npm run mobile:android                  # build + open Android Studio
npm run mobile:ios                      # build + open Xcode
npm run mobile:android:release          # full release APK + AAB
npm run mobile:android:release:github   # lightweight ARM64-only APK (no bundled model)
```

### Android native tests
```bash
cd android && ./gradlew testDebugUnitTest assembleDebug
```

### CI
GitHub Actions runs `npm test`, `npm run build`, `dart pub get`, and `dart test` on push to main and on PRs.

## Architecture

### Data flow
```
User input/photo → React UI → BeaconEngine (retrieval + prompt composition)
  → Capacitor bridge → Native plugin (Android/iOS) → LiteRT local inference
  → Response with evidence grounding → React UI
```

### Frontend (`src/`)
- `App.tsx` — root component, manages chat state and model lifecycle
- `src/lib/beaconEngine.ts` — core engine: knowledge retrieval, evidence bundling, semantic query matching, prompt composition
- `src/lib/capacitorBridge.ts` — Capacitor JSBridge abstraction for native communication
- `src/lib/session.ts` — conversation session state and memory management
- `src/lib/knowledgeBase.ts` — offline knowledge card indexing and search
- `src/lib/scenarioHints.ts` — scenario categorization (20+ emergency patterns)
- `src/lib/types.ts` — shared TypeScript types (messages, model responses, configs)
- `src/i18n/` — 20-language support; `messages.ts` is the main catalog (~100K lines), `languages.ts` is the language registry

### Dart backend (`lib/`)
Contract-based architecture with dependency injection (no singletons):
- `lib/src/contracts/` — interfaces: `ModelRuntime`, `KnowledgeStore`, `MeshTransport`, `ModelDownloader`
- `lib/src/services/` — `TriageService`, `ModelManagerService`, `PowerModeService`, `SosService`
- `lib/src/rag/` — offline retrieval pipeline for evidence grounding
- `lib/src/models/` — domain objects (emergency, evidence, knowledge, SOS)
- `lib/src/mesh/` — peer-to-peer SOS broadcast

### Android native (`android/app/.../com/beacon/sos/`)
- `BeaconNativePlugin.kt` — Capacitor plugin exposing LiteRT inference to JS
- `BeaconPromptComposer.kt` — multilingual prompt generation
- `BeaconSessionMemoryManager.kt` — native-side context persistence
- `BeaconModelFiles.kt` — model asset staging and validation

### iOS native (`ios/App/App/`)
- `BeaconNativePlugin.m` — Obj-C++ LiteRT bridge
- `BeaconLiteRtSafeBridge.mm` — Metal GPU acceleration safety wrapper

## Key Constraints

- **Offline-first**: all core functionality must work without network. Never introduce cloud-only fallbacks for emergency guidance.
- **No fake AI fallback**: do not generate canned or fake model responses when the model is unavailable.
- **Panic-proof UI**: user-facing language must be simple, clear, and calming. High-contrast OLED-friendly palette (#000000 background).
- **RTL support**: Arabic locale requires right-to-left layout handling.
- **Knowledge base changes**: add new sources through `scripts/build_offline_knowledge.mjs` and the manifest — never hand-edit `generatedKnowledge.ts`.
- **Model artifacts**: Android stages LiteRT model files (Gemma 4 E2B/E4B) via Gradle tasks; iOS uses a dynamic xcframework with optional Metal GPU.
- **Concurrent inference**: `runTriage`, `handleQuickAction`, and `handleVisualAnalysis` all guard against overlapping streaming sessions. Panic and camera buttons are disabled while streaming.
- **Model sync retry cap**: the native model sync loop has a 20-retry (30s) ceiling to prevent infinite polling. After timeout the model manager opens with an explicit error.
- **Accessibility**: all interactive elements have `:focus-visible` outlines, `aria-label` attributes, and `prefers-reduced-motion` support. Chat input placeholder meets WCAG AA 4.5:1 contrast.
- **i18n quality**: French and German translations must use proper diacritics (é, è, ê, ü, ö, ß). Add all new i18n keys to every language in `messages.ts`.
