# Competition Validation Plan

This file defines the evidence Beacon should produce before the Kaggle submission is finalized.

## Release Candidate

| Field | Current value |
| --- | --- |
| App version | `0.2.14` |
| Android versionCode | `17` |
| Default public APK mode | User downloads Gemma 4 in-app |
| Main demo platform | Android arm64 |
| Knowledge records | 6,302 sources / 14,229 entries |

## Automated Checks

Run before every release candidate:

```bash
npm test
npm run build
npm run competition:audit
npm run mobile:android:release:github
```

Recommended native checks:

```bash
cd android
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH \
./gradlew testDebugUnitTest lintDebug assembleRelease -PbeaconBundleGemmaInApk=false -PbeaconArm64Only=true
```

## Real-Device Smoke Matrix

| Scenario | Expected result | Evidence to save |
| --- | --- | --- |
| Fresh install | App opens to home screen, portrait only. | Screenshot + device model. |
| No model loaded | App clearly asks user to download a model. | Screenshot. |
| Download E2B | Button becomes progress, resume works after interruption. | Screen recording. |
| Load model | `Gemma 4 E2B` becomes ready, diagnostics reflect local model. | Diagnostics text. |
| Airplane-mode text answer | Real local answer streams, no template fallback. | Screen recording. |
| Multi-turn memory | Follow-up remembers earlier details in same session. | Transcript. |
| Return home | New session starts cleanly, model remains warm. | Screen recording. |
| Photo/camera help | Image appears in chat and answer references the visual context. | Screen recording. |
| Album upload | User can select local photo without separate confusing entry. | Screen recording. |
| Language switch | UI and answer language follow selected locale. | Screenshots for English and Chinese. |
| Long session | No one-word collapse such as `help`, `1`, or `laptop`. | 8-10 turn transcript. |

## Core Demo Prompts

Use these prompts in the video and validation transcript:

1. `I am lost in a forest, it is getting dark, I have no signal and only half a bottle of water. What should I do first?`
2. `I have a deep cut on my arm and the bleeding is not stopping.`
3. `There is thunder and I am on a ridge. What should I avoid?`
4. `I took a photo of this injury. What looks dangerous and what should I do next?`
5. `Remember that I am still in the forest. Should I keep walking or build shelter?`

Chinese validation prompts:

1. `我在森林里迷路了，天快黑了，没有信号，只有半瓶水，先做什么？`
2. `手臂有很深的伤口，一直流血，压不住怎么办？`
3. `我在山脊上，正在打雷，哪些事情不能做？`

## Pass/Fail Criteria

Release-blocking failures:

- App cannot install or launch.
- Model cannot be downloaded from any configured mirror.
- App generates emergency guidance without a loaded local model.
- App loses all answer quality after several turns.
- Visual help cannot enter camera/photo flow.
- Image is not visible in the chat after capture/upload.
- Language switch leaves major UI text hard-coded in another language.
- Safety disclaimer or professional escalation is absent from high-risk flows.
- Runtime diagnostics contradict the claimed model/runtime.

## Evidence Folder Convention

Save final artifacts under:

```text
docs/competition/evidence/YYYY-MM-DD/
```

Suggested files:

- `device.md`
- `apk-sha256.txt`
- `runtime-diagnostics.txt`
- `offline-text-demo.mp4`
- `visual-help-demo.mp4`
- `multilingual-demo.mp4`
- `long-session-transcript.md`

Do not commit private device identifiers, personal photos, GPS coordinates, or keystore files.
