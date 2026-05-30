#!/bin/sh
set -eu

ARCHIVE_PATH="${1:-}"
if [ -z "$ARCHIVE_PATH" ]; then
  echo "usage: $0 /path/to/App.xcarchive" >&2
  exit 64
fi

APP_FRAMEWORKS_DIR="${ARCHIVE_PATH}/Products/Applications/App.app/Frameworks"
SWIFT_SUPPORT_DIR="${ARCHIVE_PATH}/SwiftSupport/iphoneos"
SWIFT_STDLIB_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.0/iphoneos"

if [ ! -d "$APP_FRAMEWORKS_DIR" ]; then
  echo "error: App Frameworks directory not found: $APP_FRAMEWORKS_DIR" >&2
  exit 1
fi

if ! find "$APP_FRAMEWORKS_DIR" -maxdepth 1 -name 'libswift*.dylib' -type f | grep -q .; then
  echo "error: No embedded Swift standard libraries found in $APP_FRAMEWORKS_DIR" >&2
  exit 1
fi

if [ ! -d "$SWIFT_STDLIB_DIR" ]; then
  echo "error: Xcode Swift stdlib directory not found: $SWIFT_STDLIB_DIR" >&2
  exit 1
fi

rm -rf "${ARCHIVE_PATH}/SwiftSupport"
mkdir -p "$SWIFT_SUPPORT_DIR"

# App Store processing validates SwiftSupport against Apple's original runtime
# signatures. The app bundle copies are re-signed during archive/export; the
# SwiftSupport copies must come from Xcode's toolchain and keep Apple's
# Software Signing identity intact.
find "$APP_FRAMEWORKS_DIR" -maxdepth 1 -name 'libswift*.dylib' -type f | while IFS= read -r embedded_lib; do
  name=$(basename "$embedded_lib")
  source_lib="$SWIFT_STDLIB_DIR/$name"
  if [ ! -f "$source_lib" ]; then
    echo "error: Swift stdlib not found in Xcode toolchain: $source_lib" >&2
    exit 1
  fi
  cp -f "$source_lib" "$SWIFT_SUPPORT_DIR/"
done

count=$(find "$SWIFT_SUPPORT_DIR" -maxdepth 1 -name 'libswift*.dylib' -type f | wc -l | tr -d ' ')
if [ "$count" = "0" ]; then
  echo "error: SwiftSupport was created but contains no Swift dylibs." >&2
  exit 1
fi

echo "Added $count SwiftSupport dylibs to $SWIFT_SUPPORT_DIR"
