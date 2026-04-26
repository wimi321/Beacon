# Final Submission Checklist

Deadline: **2026-05-18 23:59 UTC**.

## Kaggle Artifacts

- [ ] Kaggle team created and identity verification complete.
- [ ] Track selection confirmed.
- [ ] Kaggle Writeup under 1,500 words.
- [ ] Public YouTube video, 3 minutes or less.
- [ ] Public GitHub repository link.
- [ ] Public demo link or downloadable APK files.
- [ ] Media gallery cover image.
- [ ] Final submission, not draft.

## Repository

- [ ] README explains the problem, install flow, architecture, model path, and safety limits.
- [ ] `docs/competition` is linked from README.
- [ ] License file is present.
- [ ] Data license document is present and honest.
- [ ] No private keys, certificates, signing secrets, personal photos, or device identifiers.
- [ ] GitHub Actions pass on `main`.
- [ ] Latest APK release matches the latest commit used in the Kaggle writeup.

## APK Demo

- [ ] Fresh install succeeds.
- [ ] Portrait-only behavior confirmed.
- [ ] Model download progress is visible.
- [ ] China-friendly mirror fallback works or has a documented fallback.
- [ ] Gemma 4 E2B loads successfully.
- [ ] Airplane-mode local text answer works.
- [ ] Camera and photo picker work.
- [ ] Image appears in chat.
- [ ] Multi-turn memory works for 8-10 turns.
- [ ] Language switching works for English, Chinese, Spanish, Japanese, and Arabic.
- [ ] App does not generate fake emergency guidance when model is missing.

## Competition-Safe Data

- [ ] High-risk third-party full-text sources removed or permission documented.
- [ ] Safe source manifest generated.
- [ ] Knowledge count updated in README and writeup.
- [ ] Evidence/source cards still show authoritative provenance.

## Video

- [ ] Shows real phone, not only emulator.
- [ ] Shows airplane mode or no-network proof.
- [ ] Shows Gemma 4 model ready.
- [ ] Shows one strong disaster/wilderness scenario.
- [ ] Shows one visual help scenario.
- [ ] Shows multilingual accessibility.
- [ ] Shows architecture/running diagnostics briefly.
- [ ] Ends with one memorable impact sentence.

## Submission Claim Discipline

- [ ] Do not claim iPhone release support unless a supported iPhone passed the matrix.
- [ ] Do not claim Cactus unless Beacon actually uses Cactus.
- [ ] Do not claim medical diagnosis.
- [ ] Do not claim all knowledge sources are open unless license audit is complete.
- [ ] Do not claim bundled model weights in the public APK if the app downloads them in-app.
