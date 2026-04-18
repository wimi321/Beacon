# Contributing to Beacon

Thanks for helping improve Beacon.

## Before you open a PR

- Search existing issues first to avoid duplicate work.
- Prefer small, focused pull requests over broad refactors.
- Include screenshots or screen recordings for UI changes.
- Include device model, OS version, and reproduction steps for runtime bugs.

## Local setup

```bash
npm install
npm test
dart test
```

If you are working on the mobile shells:

```bash
npm run mobile:build
```

## Pull request checklist

- Keep emergency behavior changes easy to review.
- Do not introduce fake AI fallback behavior.
- Preserve offline-first behavior when the network is unavailable.
- Add or update tests when changing prompt composition, session memory, retrieval, or UI flow.
- Keep user-facing language simple and panic-proof.

## Knowledge base contributions

- Prefer authoritative medical, survival, weather, and public safety sources.
- Respect licensing and redistribution terms for every source.
- Add new sources through the manifest and build scripts rather than hand-editing generated bundles.

## Security-sensitive changes

If your change touches signing, model packaging, native bridges, or safety-critical guidance, open the PR with extra detail so it can be reviewed carefully.
