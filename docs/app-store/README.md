# App Store Localization Package

Beacon supports region-specific App Store listings. This package keeps App Store Connect copy and screenshot generation reproducible instead of relying on manual copy/paste.

## Locales

| Apple Locale | Store Language | App Locale |
| --- | --- | --- |
| `en-US` | English (U.S.) | `en` |
| `zh-Hans` | 简体中文 | `zh-CN` |
| `zh-Hant` | 繁體中文 | `zh-TW` |
| `ja` | 日本語 | `ja` |
| `ko` | 한국어 | `ko` |
| `es-ES` | Español | `es` |
| `fr-FR` | Français | `fr` |
| `de-DE` | Deutsch | `de` |
| `pt-BR` | Português (Brasil) | `pt` |
| `ru` | Русский | `ru` |
| `ar-SA` | العربية | `ar` |
| `hi` | हिन्दी | `hi` |
| `id` | Bahasa Indonesia | `id` |
| `it` | Italiano | `it` |
| `tr` | Türkçe | `tr` |
| `vi` | Tiếng Việt | `vi` |
| `th` | ไทย | `th` |
| `nl-NL` | Nederlands | `nl` |
| `pl` | Polski | `pl` |
| `uk` | Українська | `uk` |

## Generate Metadata

```bash
python3 scripts/generate_app_store_localizations.py --metadata --version 0.2.28
```

Generated metadata is written to:

- `docs/app-store/localizations/app-store-localizations.json`
- `docs/app-store/localizations/<apple-locale>/metadata.md`
- `.artifacts/app-store-localization-package/metadata/app-store-localizations.json`

## Generate Localized Screenshots

Install Python screenshot dependencies once, then render localized screenshots:

```bash
python3 -m pip install pillow playwright
python3 -m playwright install chromium
python3 scripts/generate_app_store_localizations.py --metadata --screenshots --version 0.2.28
```

Upload-ready screenshots are written to:

```text
.artifacts/app-store-localization-package/screenshots/<apple-locale>/iphone-6.3/
```

Each locale gets four device-faithful iPhone screenshots:

1. `01-home.png` — panic-first home screen
2. `02-chat.png` — offline guidance with citations
3. `03-visual.png` — camera/photo visual help picker
4. `04-language.png` — manual language switcher

## Validate

```bash
python3 scripts/validate_app_store_localizations.py
python3 scripts/validate_app_store_localizations.py --screenshots
```

The validator checks App Store field length limits and screenshot dimensions.

## App Store Connect Workflow

1. Open App Store Connect → Beacon Survival SOS → version metadata.
2. Add each localization listed above.
3. Copy fields from `metadata.md` or the combined JSON.
4. Upload the matching screenshots from `.artifacts/app-store-localization-package/screenshots/<apple-locale>/iphone-6.3/`.
5. Save and submit the metadata update.

Notes:

- China mainland should use `zh-Hans` metadata and Chinese screenshots.
- Taiwan/Hong Kong/Macau should use `zh-Hant`.
- U.S. should use `en-US`.
- The description intentionally mentions citations and professional-care limitations to satisfy medical-information review expectations.
