# Gemma 4 Good Hackathon Submission Pack

This directory turns Beacon from a strong mobile prototype into a competition-ready, judge-verifiable submission for [The Gemma 4 Good Hackathon](https://www.kaggle.com/competitions/gemma-4-good-hackathon).

## Competition Fit

Beacon is a strong fit because the product is built around the exact failure mode the hackathon rewards: people need useful AI when connectivity, cloud APIs, and normal support systems are unavailable.

Recommended tracks:

| Track | Fit | Why Beacon qualifies |
| --- | --- | --- |
| Main Track | High | A complete, installable mobile app with a clear public-good story. |
| Global Resilience | Very high | Offline, edge-based disaster and wilderness response is Beacon's core use case. |
| Safety & Trust | High | Local retrieval, source attribution, no fake AI fallback, and clear safety disclaimers. |
| Digital Equity & Inclusivity | High | 20-language UI, Arabic RTL support, low-friction mobile UX, and no cloud dependency. |
| LiteRT Special Technology | High if verified | Android uses Google AI Edge LiteRT-LM artifacts and runtime dependency. Final submission should include logs proving the active runtime. |
| Cactus Special Technology | Not current target | Beacon routes E2B/E4B and power modes, but it does not currently use the Cactus framework. Do not claim this track unless implemented. |

## Official Requirements Snapshot

Current verified competition deadline: **2026-05-18 23:59 UTC**.

The public Kaggle submission needs:

- Kaggle Writeup, maximum 1,500 words.
- Public video, 3 minutes or less, viewable without login.
- Public code repository.
- Live demo URL or downloadable demo files.
- Media gallery with cover image.
- Track selection.

## Recommended Submission Positioning

Project title:

> Beacon: Offline Gemma 4 Survival Intelligence for When the Network Is Gone

One-line pitch:

> Beacon turns an Android phone into an offline emergency survival assistant powered by Gemma 4, helping people make safer decisions during medical, disaster, and wilderness emergencies when connectivity is unavailable.

Primary story:

1. A person is lost, injured, or trapped with no network.
2. Beacon runs Gemma 4 locally on the phone.
3. The app retrieves authoritative offline survival and first-aid knowledge.
4. Gemma 4 turns that context into simple, actionable next steps.
5. The user keeps control of the device, data, language, and model.

## Files In This Pack

- [WRITEUP_DRAFT.md](./WRITEUP_DRAFT.md) - 1,500-word Kaggle writeup draft.
- [VIDEO_SCRIPT.md](./VIDEO_SCRIPT.md) - 3-minute video structure, shots, and voiceover.
- [ARCHITECTURE.md](./ARCHITECTURE.md) - technical architecture and judge-verification points.
- [VALIDATION.md](./VALIDATION.md) - real-device validation plan and release evidence.
- [DATA_LICENSES.md](./DATA_LICENSES.md) - data source license audit and competition-safe data strategy.
- [SUBMISSION_CHECKLIST.md](./SUBMISSION_CHECKLIST.md) - final pre-submit checklist.

## Current Readiness

| Area | Status | Notes |
| --- | --- | --- |
| Android installable APK | Ready for validation | Publish the latest arm64 release APK as demo file. |
| Gemma 4 on-device path | Implemented | Android depends on `com.google.ai.edge.litertlm:litertlm-android`. Include runtime diagnostics in final video/writeup. |
| Model download | Implemented | E2B/E4B download in-app with ordered mirrors. |
| Offline knowledge | Implemented | 6,332 source records and 14,406 entries in the current bundle. |
| Multilingual UI | Implemented | 20 UI languages, with README demos in 10 locales. |
| Visual help | Implemented | Camera/photo intake exists; final submission needs a clean recorded proof. |
| Data licensing | Needs cleanup before final submission | Some medical sources require review or removal from the competition build. See [DATA_LICENSES.md](./DATA_LICENSES.md). |
| Video | Not done | Highest scoring artifact. See [VIDEO_SCRIPT.md](./VIDEO_SCRIPT.md). |
| Kaggle writeup | Drafted | See [WRITEUP_DRAFT.md](./WRITEUP_DRAFT.md). |

## Final Submission Strategy

1. Ship a clean Android-first public demo.
2. Record proof that the phone can answer offline after model download.
3. Show the LiteRT-LM runtime and Gemma 4 model in diagnostics.
4. Use a competition-safe knowledge profile or document explicit source permissions.
5. Keep the video simple: one person, one no-signal crisis, one working app.

## Verification Command

Run the local readiness audit:

```bash
npm run competition:audit
npm run competition:knowledge:safe
```

Use the output as the first draft of the final validation appendix.
