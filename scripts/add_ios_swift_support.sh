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
APP_BUNDLE_DIR="${ARCHIVE_PATH}/Products/Applications/App.app"
SWIFT_SOURCE_DIR="${SWIFT_SOURCE_DIR:-${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.0/iphoneos}"

if [ ! -d "$APP_FRAMEWORKS_DIR" ]; then
  echo "error: App Frameworks directory not found: $APP_FRAMEWORKS_DIR" >&2
  exit 1
fi

if [ ! -f "$APP_EXECUTABLE" ]; then
  echo "error: App executable not found: $APP_EXECUTABLE" >&2
  exit 1
fi

rm -rf "${ARCHIVE_PATH}/SwiftSupport"

if [ ! -d "$SWIFT_SOURCE_DIR" ]; then
  SWIFT_SOURCE_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos"
fi

if [ ! -d "$SWIFT_SOURCE_DIR" ]; then
  echo "error: Swift standard library source directory not found." >&2
  exit 1
fi

TMP_REQUIRED="$(mktemp)"
TMP_ENTITLEMENTS="$(mktemp)"
trap 'rm -f "$TMP_REQUIRED" "$TMP_ENTITLEMENTS"' EXIT

find "$APP_BUNDLE_DIR" -type f | while IFS= read -r file_path; do
  if file "$file_path" | grep -q 'Mach-O'; then
    otool -L "$file_path" 2>/dev/null \
      | sed -n 's#.*\/usr\/lib\/swift\/\(libswift[^[:space:]]*\.dylib\).*#\1#p'
  fi
done | sort -u > "$TMP_REQUIRED"

if ! grep -q '^libswift' "$TMP_REQUIRED"; then
  echo "No Swift standard library references found; SwiftSupport is intentionally omitted."
  exit 0
fi

rm -f "$APP_FRAMEWORKS_DIR"/libswift*.dylib
mkdir -p "$SWIFT_SUPPORT_DIR"
count=0
while IFS= read -r swift_lib; do
  if [ -f "$SWIFT_SOURCE_DIR/$swift_lib" ]; then
    cp -f "$SWIFT_SOURCE_DIR/$swift_lib" "$APP_FRAMEWORKS_DIR/$swift_lib"
    cp -f "$SWIFT_SOURCE_DIR/$swift_lib" "$SWIFT_SUPPORT_DIR/$swift_lib"
    chmod 755 "$APP_FRAMEWORKS_DIR/$swift_lib"
    chmod 644 "$SWIFT_SUPPORT_DIR/$swift_lib"
    count=$((count + 1))
  fi
done < "$TMP_REQUIRED"

count=$(find "$SWIFT_SUPPORT_DIR" -maxdepth 1 -name 'libswift*.dylib' -type f | wc -l | tr -d ' ')
if [ "$count" = "0" ]; then
  echo "error: SwiftSupport was created but contains no Swift dylibs." >&2
  exit 1
fi

if [ "${CODE_SIGNING_ALLOWED:-YES}" = "YES" ]; then
  CODE_SIGN_IDENTITY_TO_USE="${EXPANDED_CODE_SIGN_IDENTITY_NAME:-}"
  if [ -z "$CODE_SIGN_IDENTITY_TO_USE" ]; then
    CODE_SIGN_IDENTITY_TO_USE="$(codesign -dv --verbose=4 "$APP_BUNDLE_DIR" 2>&1 | awk -F= '/^Authority=/ { print $2; exit }')"
  fi

  if [ -n "$CODE_SIGN_IDENTITY_TO_USE" ]; then
    for swift_lib_path in "$APP_FRAMEWORKS_DIR"/libswift*.dylib; do
      codesign --force --sign "$CODE_SIGN_IDENTITY_TO_USE" --timestamp=none "$swift_lib_path"
    done

    if codesign -d --entitlements :- "$APP_BUNDLE_DIR" > "$TMP_ENTITLEMENTS" 2>/dev/null \
      && grep -q '<plist' "$TMP_ENTITLEMENTS"; then
      codesign --force --sign "$CODE_SIGN_IDENTITY_TO_USE" --entitlements "$TMP_ENTITLEMENTS" --timestamp=none "$APP_BUNDLE_DIR"
    else
      codesign --force --sign "$CODE_SIGN_IDENTITY_TO_USE" --timestamp=none "$APP_BUNDLE_DIR"
    fi
  else
    echo "warning: Could not determine a signing identity for embedded Swift dylibs." >&2
  fi
fi

echo "Added $count Swift dylibs to App.app/Frameworks and SwiftSupport/iphoneos"
