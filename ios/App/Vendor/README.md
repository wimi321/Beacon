# iOS Vendor Assets

This directory intentionally does **not** store the full patched LiteRT iOS engine archives in git.

Why:

- GitHub rejects regular git objects larger than `100 MB`
- the local Beacon iOS runtime currently depends on several generated static archives that are much larger than that limit

What is omitted from version control:

- `BeaconLiteRtLm.xcframework/`
- `litert_patch/`
- `litert_support_build/`

What can remain local:

- `LiteRtRuntime/` dynamic runtime support files

How these assets are expected to be prepared locally:

1. Stage the base LiteRT iOS runtime artifacts under `ios/App/Vendor/`
2. Rebuild the patched support archives with:

```bash
scripts/build_ios_litert_support.sh
```

3. Stage runtime assets into the app bundle during iOS build with:

```bash
scripts/stage_ios_litert_assets.sh
```

Related note:

- the bundled model file is expected at `.artifacts/gemma-4-E2B-it.litertlm`

If you are publishing a public version of Beacon, consider moving the oversized iOS vendor binaries to release assets or another reproducible fetch path before promising one-command iOS builds from a clean clone.
