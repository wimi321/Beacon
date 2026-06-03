# Fastlane App Store Connect Upload

Beacon uses `fastlane deliver` for bulk App Store Connect metadata and screenshot updates. This avoids browser file-picker limitations and makes multi-language releases reproducible.

## Installed Tool

```bash
fastlane --version
# fastlane 2.235.0
```

## Generate The Upload Package

```bash
npm run appstore:screenshots
npm run appstore:fastlane
npm run appstore:fastlane:validate
```

Generated local-only upload package:

```text
.artifacts/fastlane-deliver/metadata/<locale>/*.txt
.artifacts/fastlane-deliver/screenshots/<locale>/*.png
.artifacts/fastlane-deliver/manifest.json
```

The package currently targets `0.2.28`, `com.beacon.sos`, Apple App ID `6772494235`, and Team ID `CX8YS634JU`.

## Authentication

Preferred authentication is an App Store Connect API Key. Create it once in App Store Connect:

1. App Store Connect → Users and Access → Integrations → App Store Connect API.
2. Create a key with permission to manage apps and upload metadata/screenshots.
3. Download the `.p8` file immediately. Apple only allows downloading it once.
4. Keep the key outside the repo, for example:

```text
~/Developer/AppStoreKeys/AuthKey_<KEY_ID>.p8
~/Developer/AppStoreKeys/AuthKey_BEACON.json
```

Fastlane expects a JSON file like this:

```json
{
  "key_id": "YOUR_KEY_ID",
  "issuer_id": "YOUR_ISSUER_ID",
  "key": "<P8_PRIVATE_KEY_CONTENT>",
  "duration": 1200,
  "in_house": false
}
```

Never commit `.p8` or API key JSON files.

## Upload Metadata And Screenshots

```bash
FASTLANE_APP_STORE_CONNECT_API_KEY_PATH=$HOME/Developer/AppStoreKeys/AuthKey_BEACON.json \
  npm run appstore:upload
```

This uploads localized metadata and screenshots only. It does not upload a binary and does not submit for review.

## Submit A Prepared Build

After a valid build has already been uploaded and selected in App Store Connect, submit with:

```bash
FASTLANE_APP_STORE_CONNECT_API_KEY_PATH=$HOME/Developer/AppStoreKeys/AuthKey_BEACON.json \
  fastlane ios submit_appstore_version version:0.2.28 build_number:40
```

The submit lane skips binary, metadata, and screenshot upload. It only asks App Store Connect to submit the prepared version/build for review.

## Safety Notes

- The repository only stores scripts and fastlane lanes, not credentials.
- `.artifacts/` stays ignored by git, so generated screenshots are local-only.
- `overwrite_screenshots: true` intentionally replaces old screenshot sets for the editable version.
- If a web session has unsaved screenshot edits, prefer discarding/reloading the App Store Connect page before using fastlane.
