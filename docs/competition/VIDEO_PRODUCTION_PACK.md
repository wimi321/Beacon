# Beacon 3-Minute Competition Video Production Pack

Purpose: create a judge-ready, public-good video for Gemma 4 Good Hackathon. The video should feel like a real offline survival product, not a generic app promo.

Target length: 2:55-3:00.

Core promise:

> When the network is gone, Beacon turns a phone into an offline Gemma 4 survival assistant.

## Creative Direction

- Visual tone: cinematic, grounded, calm under pressure.
- Color: cold blue-gray crisis environments contrasted with Beacon's warm cyan/green survival glow.
- Camera language: close, handheld, human; no superhero framing, no disaster spectacle.
- Product proof: use real Android screen recordings for model download, airplane mode, streaming answer, visual help, language switching, and diagnostics.
- Safety tone: Beacon gives guidance and next steps; it does not claim to diagnose, rescue, or guarantee survival.
- No fake AI: if UI is shown, it must be the real app or clearly treated as conceptual B-roll.

## 3-Minute Voiceover Script

In an emergency, the cloud is often the first thing you lose.

A storm knocks out towers. A hiking trail has no signal. A city block loses power. In those moments, the phone in your hand may still have battery, but ordinary apps stop being useful.

Beacon is built for that gap.

It turns an Android phone into an offline emergency survival assistant powered by Gemma 4 running on-device. The user installs the app, downloads Gemma 4 E2B or E4B inside the app, and carries an offline emergency knowledge base with thousands of curated entries.

No server. No API key. No network required after setup.

Imagine someone is lost in a forest near sunset. They type what they know: they are alone, there is no signal, and it is getting cold.

Beacon retrieves local survival guidance, then Gemma turns it into simple actions: stop wandering, stay warm, mark the location, conserve battery, prepare visible signals, and decide when it is safer to stay put.

The user can ask follow-up questions in the same situation. Beacon keeps the current emergency context, so the answer does not reset into a generic checklist.

If words are not enough, the user can send a photo. An injury, an unknown plant, a damaged room, smoke, water, or a hazard can be added to the conversation. The image stays on the device.

Beacon is designed for ordinary people under stress. The interface is simple, touch targets are large, and the app supports 20 UI languages, including right-to-left Arabic.

Under the hood, Beacon combines React, Capacitor, Kotlin, Google AI Edge LiteRT-LM, Gemma 4, and a bundled offline emergency knowledge base. The public APK stays lightweight, while the model is downloaded inside the app.

This is not a cloud chatbot wearing an emergency skin. It is local survival intelligence for the moments when connection fails first.

Beacon: when the network is gone, your phone still has a guide.

## Shot List With Storyboards And Image-To-Video Prompts

| # | Time | Duration | Role | Visual / Action | Voiceover Cue | Seed Image Prompt | Seedance 2.0 Image-To-Video Prompt | Negative Prompt |
| --- | --- | ---: | --- | --- | --- | --- | --- | --- |
| 01 | 0:00-0:12 | 12s | AI cinematic opener | A lone hand holds a phone in a dark forest. No signal. Distant storm light. | In an emergency, the cloud is often the first thing you lose. | Cinematic 16:9 close-up of a realistic hand holding a modern Android phone in a dark forest at dusk, no signal icon implied without readable UI text, rain mist, cold blue-gray atmosphere, subtle cyan glow from the phone, grounded documentary realism, shallow depth of field, no logos, no watermark, no readable text. | Slow handheld push-in toward the phone, tiny raindrops moving, distant lightning softly illuminating tree silhouettes, phone glow reflecting on fingers, tense but calm mood, cinematic realism, 24fps, no text overlays. | fake UI text, brand logos, gore, panic expression, overdramatic lightning, cyberpunk neon, unreadable clutter |
| 02 | 0:12-0:24 | 12s | AI crisis montage | Split-second glimpses: storm street, power outage, trail marker. | A storm knocks out towers. A hiking trail has no signal. A city block loses power. | Cinematic triptych-style disaster resilience frame, left: dark city street during power outage, center: remote hiking trail marker at sunset, right: storm clouds over cell tower silhouette, cohesive blue-gray palette with a subtle warm Beacon glow, realistic documentary look, no text, no logos. | Gentle parallax across the three panels, rain and wind moving, lights flicker out in city panel, trail leaves move, storm clouds roll, smooth premium documentary motion. | destruction spectacle, explosions, people harmed, text, logos, comic style, oversaturated neon |
| 03 | 0:24-0:38 | Real phone proof | Real recording | Phone home screen opens Beacon. Big simple emergency actions. | Beacon is built for that gap. | Use real app recording. If a generated placeholder is needed: clean premium mobile app hero shot on a phone, emergency assistant interface with large simple cards, high contrast, no readable fake text except Beacon logo if accurate. | Use real phone screen recording. Slow natural hand motion, tap Beacon icon, app opens to home screen, keep status bar visible enough to prove mobile, no fake overlays. | fake app UI, tiny controls, crowded dashboard, unreadable text, desktop mockup |
| 04 | 0:38-0:55 | Real phone proof | Model manager + airplane mode | Show Gemma 4 E2B/E4B ready, then airplane mode/no network. | The user installs the app, downloads Gemma 4 E2B or E4B inside the app... | Use real app recording. Optional cover frame: close-up Android settings and Beacon model screen, model ready state, airplane mode proof, clean documentary product shot. | Real screen capture or over-shoulder phone footage, tap Settings & Models, show model ready/downloaded, enable airplane mode, return to Beacon, smooth confident motion. | fake download UI, cloud icons implying server, unreadable diagnostics, shaky unusable footage |
| 05 | 0:55-1:15 | Real phone proof | Offline forest prompt | User enters: “I’m lost in a forest, no signal, it’s getting cold.” | Imagine someone is lost in a forest near sunset. | Use real app recording. Optional generated B-roll: phone on a backpack beside a forest trail at twilight, Beacon chat open, no readable fake text, soft cyan UI glow. | Real phone recording: type the scenario, send it, show immediate transition into chat, keep the keyboard interaction simple and human. | fake template answer, text hallucination, unreadable keyboard, over-stylized UI |
| 06 | 1:15-1:38 | Real phone proof | Streaming answer | Answer streams with actionable steps. | Beacon retrieves local survival guidance, then Gemma turns it into simple actions. | Use real app recording. Optional generated cutaway: close-up of streaming answer lines reflected on the user's face, no readable fake text, urgent but calm. | Capture actual app streaming output; crop so words are readable; show the answer forming over time, not appearing instantly; light phone movement only. | instant full answer, stock chatbot look, tiny unreadable text, exaggerated AI particles |
| 07 | 1:38-1:55 | Real phone proof | Follow-up memory | User asks: “Should I keep walking?” Beacon remembers forest/cold context. | The user can ask follow-up questions in the same situation. | Use real app recording. Optional generated B-roll: two-message conversation on phone, user in dark forest background, no readable fake text. | Real screen capture: send a follow-up, show response grounded in previous context, subtle scroll, no scene reset. | generic answer, lost context, fake UI, frantic movement |
| 08 | 1:55-2:12 | Real phone proof + photo | Tap visual help, choose camera/gallery, image appears in chat. | If words are not enough, the user can send a photo. | Use real app recording. Optional generated frame: phone camera/gallery picker beside emergency kit, photo preview visible in chat, polished mobile UX, no private details. | Real phone recording: tap visual help, choose photo or camera, send image, show image bubble inside chat before analysis, smooth touch flow. | no image bubble, privacy leak, fake gallery, tiny buttons, confusing modal |
| 09 | 2:12-2:27 | Real phone proof | Visual answer | Beacon references visual context and gives next steps. | An injury, an unknown plant, a damaged room, smoke, water, or a hazard can be added. | Use real app recording. Optional generated cutaway: close-up of phone analyzing a safe staged outdoor hazard photo, calm cyan focus ring, no medical gore. | Real app recording: visual answer streams after image appears; keep camera steady; show that the response is tied to the image. | gore, diagnosis claims, fake confidence badge, unreadable source block |
| 10 | 2:27-2:42 | Real phone proof | Language switch | Switch to English/Chinese/Arabic RTL; UI remains simple. | Beacon is designed for ordinary people under stress. | Use real app recording. Optional generated frame: elegant language picker floating over Beacon interface, multilingual labels, premium mobile design, no visual clutter. | Real screen recording: open language picker, switch language, show home UI update; include Arabic RTL only if layout is stable and readable. | cluttered list, broken RTL, overlapping status bar, tiny touch targets |
| 11 | 2:42-2:52 | Technical proof | Diagnostics + architecture overlay | Show runtime diagnostics and simple architecture line. | Under the hood, Beacon combines React, Capacitor, Kotlin, LiteRT-LM, Gemma 4... | Clean technical architecture visual, Android phone in center, small connected nodes labeled React, Capacitor, Kotlin, LiteRT-LM, Gemma 4, Offline Knowledge, dark premium background, readable minimal typography, no extra claims. | Slow orbit/parallax around phone and architecture nodes, soft connection lines pulse once, premium keynote style, restrained motion. | dense diagram, unreadable labels, stock circuit board, excessive neon, fake Google branding |
| 12 | 2:52-3:00 | AI closing hero | Beacon logo + phone glow in darkness. | Beacon: when the network is gone, your phone still has a guide. | Cinematic closing frame, Beacon app icon glowing softly on a phone lying on an emergency blanket, dark environment, subtle dawn light on horizon, premium Apple-style product cinematography, no extra text, no watermark. | Slow pull-back from phone and emergency blanket, dawn light grows slightly, calm resolution, logo glow remains subtle, end on still frame for title/card overlay in editor. | cheesy lens flare, excessive glow, cluttered survival gear, text artifacts, watermark |

## Editing Timeline

| Time | Track | Notes |
| --- | --- | --- |
| 0:00-0:24 | Cinematic B-roll | Build emotional stakes before showing product. Keep cuts slow and grounded. |
| 0:24-0:55 | Product setup proof | Real app, model ready, airplane mode. This is the credibility anchor. |
| 0:55-1:55 | Core offline AI proof | Forest prompt, streaming answer, follow-up memory. Do not overcut; judges need to see it works. |
| 1:55-2:27 | Multimodal proof | Photo enters chat, answer uses visual context. Use safe staged image. |
| 2:27-2:42 | Accessibility/global proof | Language switch, large simple UI, stress-friendly design. |
| 2:42-3:00 | Architecture + final promise | Keep technical overlay clean, then emotional closing frame. |

## On-Screen Text Cards

Use no more than five text cards:

1. `No signal. Still useful.`
2. `Gemma 4 runs on-device.`
3. `Offline knowledge: 6,332 sources / 14,406 entries.`
4. `20 UI languages.`
5. `Beacon: survival intelligence when the network is gone.`

## Recording Checklist

- Use real Android device recording for shots 03-10.
- Start with model already downloaded for the main demo, but include a short model-ready proof shot.
- Enable airplane mode before the main prompt.
- Use a staged, non-graphic image for visual help.
- Keep the screen readable: 1080p minimum, avoid glare, slow taps.
- Blur device identifiers, personal photos, location, and notifications.
- Do not show API keys, keystore paths, signing details, private URLs, or model tokens.
- Do not claim diagnosis, guaranteed rescue, or medical certainty.

## Export Spec

- Aspect ratio: 16:9 primary for Kaggle/YouTube.
- Resolution: 1920x1080 or 4K if source allows.
- Frame rate: 24fps for cinematic B-roll, 30fps for phone capture is acceptable.
- Captions: burn-in English captions recommended; optional multilingual subtitle files later.
- Audio: calm documentary voice, light low-frequency pulse, no alarm fatigue.

## Deliverables

- Storyboard frames: `docs/assets/competition-video/storyboards/shot-01.png` through `shot-12.png`.
- Contact sheet: `docs/assets/competition-video/storyboards/contact-sheet.png`.
- This production pack: `docs/competition/VIDEO_PRODUCTION_PACK.md`.
