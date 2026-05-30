#!/bin/sh
set -eu

ARCHIVE_PATH="${1:-}"
if [ -z "$ARCHIVE_PATH" ]; then
  echo "usage: $0 /path/to/App.xcarchive" >&2
  exit 64
fi

APP_FRAMEWORKS_DIR="${ARCHIVE_PATH}/Products/Applications/App.app/Frameworks"
SWIFT_SUPPORT_DIR="${ARCHIVE_PATH}/SwiftSupport/iphoneos"
APP_EXECUTABLE="${ARCHIVE_PATH}/Products/Applications/App.app/App"

if [ ! -d "$APP_FRAMEWORKS_DIR" ]; then
  echo "error: App Frameworks directory not found: $APP_FRAMEWORKS_DIR" >&2
  exit 1
fi

if [ ! -f "$APP_EXECUTABLE" ]; then
  echo "error: App executable not found: $APP_EXECUTABLE" >&2
  exit 1
fi

rm -rf "${ARCHIVE_PATH}/SwiftSupport"

if ! find "$APP_FRAMEWORKS_DIR" -maxdepth 1 -name 'libswift*.dylib' -type f | grep -q .; then
  echo "No embedded Swift standard libraries found; SwiftSupport is intentionally omitted."
  exit 0
fi

TMP_SWIFT_SUPPORT="$(mktemp -d)"
trap 'rm -rf "$TMP_SWIFT_SUPPORT"' EXIT

# Let Apple's stdlib tool decide the exact Swift runtime set. Hand-copying
# every libswift*.dylib is fragile and can fail App Store processing when the
# SwiftSupport folder no longer matches the app bundle after export signing.
xcrun swift-stdlib-tool \
  --copy \
  --platform iphoneos \
  --scan-executable "$APP_EXECUTABLE" \
  --scan-folder "$APP_FRAMEWORKS_DIR" \
  --destination "$TMP_SWIFT_SUPPORT" \
  --strip-bitcode \
  --strip-bitcode-tool "${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}/Toolchains/XcodeDefault.xctoolchain/usr/bin/bitcode_strip" >/dev/null

if ! find "$TMP_SWIFT_SUPPORT" -maxdepth 1 -name 'libswift*.dylib' -type f | grep -q .; then
  echo "Swift stdlib tool selected no support libraries; SwiftSupport is intentionally omitted."
  exit 0
fi

mkdir -p "$SWIFT_SUPPORT_DIR"
cp -f "$TMP_SWIFT_SUPPORT"/libswift*.dylib "$SWIFT_SUPPORT_DIR/"
count=$(find "$SWIFT_SUPPORT_DIR" -maxdepth 1 -name 'libswift*.dylib' -type f | wc -l | tr -d ' ')
if [ "$count" = "0" ]; then
  echo "error: SwiftSupport was created but contains no Swift dylibs." >&2
  exit 1
fi

echo "Added $count SwiftSupport dylibs to $SWIFT_SUPPORT_DIR"
