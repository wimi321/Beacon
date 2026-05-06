# DFlash Research Note

Beacon should not adopt `z-lab/dflash` in the mobile production path for v0.2.17.

## Finding

DFlash is a speculative-decoding research/runtime stack for accelerating large language model inference through Python-oriented ecosystems such as Transformers, SGLang, vLLM, and MLX. It is useful to watch, but it is not a drop-in replacement for Beacon's Android/iOS LiteRT-LM local runtime.

## Decision

- Do not add DFlash dependencies to the APK or native mobile builds.
- Do not change the Gemma 4 E2B/E4B model download flow for this release.
- Keep Beacon's production path on the current real local LiteRT-LM bridge.
- Revisit only if an official mobile runtime path supports a comparable draft-model acceleration strategy for the Gemma mobile artifacts Beacon ships.

## Rationale

- Beacon's release target is offline mobile use, especially Android APK distribution and iOS LiteRT-LM compatibility.
- DFlash currently adds a different runtime and model-management surface, which would increase package complexity and memory risk.
- The war-crisis feature needs knowledge grounding and simple user access, not a new inference backend.
