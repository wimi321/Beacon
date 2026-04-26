# Kaggle Writeup Draft

Title: Beacon: Offline Gemma 4 Survival Intelligence for When the Network Is Gone

Subtitle: A phone-first emergency assistant that runs Gemma 4 locally, retrieves offline safety knowledge, and helps people act when networks, cloud APIs, and normal support systems fail.

## Problem

Emergencies often break the systems people depend on. After earthquakes, floods, wildfires, or wilderness accidents, a person may have a charged phone but no connectivity, no doctor, no search engine, and no time to read a manual. The most vulnerable moment is also the moment when cloud AI is least reliable: the network is gone.

Beacon addresses that gap. It turns an Android phone into an offline emergency survival assistant powered by Gemma 4. The goal is not to replace emergency services or clinicians. The goal is to provide last-mile guidance when the user has no better option and needs simple, immediate actions.

## Solution

Beacon combines three local capabilities:

1. Gemma 4 on-device inference.
2. Offline retrieval from emergency, medical, disaster, and survival guidance.
3. A panic-proof mobile interface designed for high-stress situations.

The user can ask directly, tap a crisis preset, take a photo, or select an image from the device. Beacon retrieves relevant local knowledge, builds a compact prompt, and sends it to the native Gemma 4 runtime. The answer is generated locally on the phone. No API key is required and no private emergency details leave the device.

The app supports Gemma 4 E2B for fast setup and Gemma 4 E4B for higher-accuracy devices. Models are downloaded in-app using an ordered mirror list, with China-friendly mirrors first and official sources as fallback. The default public APK does not bundle model weights, keeping the app distributable while still making the local model path reproducible.

## Why Gemma 4

Beacon needs a model that is useful at the edge. Gemma 4 E2B and E4B are a natural fit because the product depends on mobile inference, multilingual responses, long-enough context for retrieved knowledge, and visual emergency workflows. Beacon uses Gemma 4 to transform raw retrieved guidance into direct, situation-specific steps such as "stop bleeding first," "do not move the neck," or "leave the ridge before lightning gets closer."

Gemma 4 is not used as a decorative chatbot. It is the core reasoning layer that adapts authoritative local material to the user's exact question, language, device state, and current session history.

## Technical Architecture

Beacon is built with React, TypeScript, Capacitor, Kotlin, and Google AI Edge LiteRT-LM on Android. The frontend owns the simple emergency UI. The native bridge owns model download, model loading, streaming inference, runtime diagnostics, and camera/photo intake. A local retrieval engine searches the bundled knowledge base before each answer.

The prompt structure is deliberately simple:

- Current language.
- Recent conversation memory.
- Optional visual context.
- User input.
- Retrieved knowledge base content.

The system prompt stays minimal: Beacon should answer directly according to the user input, use retrieved knowledge as reference, and still answer when retrieval is incomplete. There is no template fallback. If the native local model is unavailable, the app surfaces that state instead of pretending to answer.

## Impact

Beacon targets three public-good scenarios:

- Medical first aid when professional help is delayed.
- Disaster survival when infrastructure is disrupted.
- Wilderness safety when the user is offline and isolated.

The interface is intentionally simple: large crisis cards, direct text input, camera/photo help, model status, and language switching. Beacon supports 20 UI languages, including Arabic right-to-left layout, because crisis tools should not assume English fluency.

This makes Beacon especially relevant for Global Resilience, Safety & Trust, and Digital Equity. It is local-first, privacy-preserving, multilingual, and designed for low-connectivity environments.

## Current Demo

The public demo is an Android APK distributed through GitHub Releases. A first-time user installs the APK, opens Settings & Models, downloads Gemma 4 E2B, and then can use Beacon offline. The demo flow shows:

1. First launch and model download.
2. Airplane-mode text triage.
3. Wilderness survival guidance grounded in the offline knowledge base.
4. Photo-based visual help.
5. Language switching.
6. Runtime diagnostics proving local Gemma 4 execution.

## Safety and Limitations

Beacon is not a medical device and is not a replacement for emergency services. It gives emergency support for disrupted environments and tells users to contact professional rescue as soon as communication is available.

For competition release, Beacon also needs strict source-license hygiene. The current development knowledge bundle contains a mix of government, public, and third-party medical references. Before final submission, the competition build should either use only license-cleared sources or include documented permissions for any restricted third-party content.

## Future Work

The next steps are iPhone release-device validation, peer-to-peer SOS relay, stronger quantitative evaluation, and a competition-safe knowledge profile. The long-term vision is a trusted offline survival layer that lives on ordinary phones before the emergency happens.
