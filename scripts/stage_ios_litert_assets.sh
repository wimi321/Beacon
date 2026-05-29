#!/bin/sh
set -eu

copy_if_needed() {
  src="$1"
  dst="$2"

  src_size=$(stat -L -f%z "$src")
  dst_size=0
  if [ -f "$dst" ]; then
    dst_size=$(stat -f%z "$dst")
  fi

  if [ "$src_size" != "$dst_size" ]; then
    rm -f "$dst"
    cp -f "$src" "$dst"
  fi
}

PROJECT_DIR="${PROJECT_DIR:?PROJECT_DIR is required}"
TARGET_BUILD_DIR="${TARGET_BUILD_DIR:?TARGET_BUILD_DIR is required}"
UNLOCALIZED_RESOURCES_FOLDER_PATH="${UNLOCALIZED_RESOURCES_FOLDER_PATH:?UNLOCALIZED_RESOURCES_FOLDER_PATH is required}"
FRAMEWORKS_FOLDER_PATH="${FRAMEWORKS_FOLDER_PATH:-Frameworks}"
PLATFORM_NAME="${PLATFORM_NAME:-iphoneos}"

MODEL_SRC="${PROJECT_DIR}/../../.artifacts/gemma-4-E2B-it.litertlm"
MODEL_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/models"
MODEL_DST="${MODEL_DIR}/gemma-4-E2B-it.litertlm"

if [ ! -f "$MODEL_SRC" ]; then
  echo "error: Missing bundled Gemma 4 E2B artifact at $MODEL_SRC" >&2
  exit 1
fi

mkdir -p "$MODEL_DIR"
copy_if_needed "$MODEL_SRC" "$MODEL_DST"

RUNTIME_VARIANT="ios-arm64"
if [ "$PLATFORM_NAME" = "iphonesimulator" ]; then
  RUNTIME_VARIANT="ios-arm64-simulator"
fi

RUNTIME_SRC="${PROJECT_DIR}/Vendor/LiteRtRuntime/${RUNTIME_VARIANT}/libLiteRtMetalAccelerator.dylib"
if [ ! -f "$RUNTIME_SRC" ]; then
  echo "error: Missing LiteRT Metal accelerator runtime at $RUNTIME_SRC" >&2
  exit 1
fi

RUNTIME_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
RUNTIME_FRAMEWORK_NAME="LiteRtMetalAccelerator.framework"
RUNTIME_FRAMEWORK_EXECUTABLE="LiteRtMetalAccelerator"
RUNTIME_FRAMEWORK_DIR="${RUNTIME_DIR}/${RUNTIME_FRAMEWORK_NAME}"
RUNTIME_DST="${RUNTIME_FRAMEWORK_DIR}/${RUNTIME_FRAMEWORK_EXECUTABLE}"
RUNTIME_LEGACY_DST="${RUNTIME_DIR}/libLiteRtMetalAccelerator.dylib"

mkdir -p "$RUNTIME_DIR"
rm -rf "$RUNTIME_FRAMEWORK_DIR"
mkdir -p "$RUNTIME_FRAMEWORK_DIR"
cp -f "$RUNTIME_SRC" "$RUNTIME_DST"
chmod 755 "$RUNTIME_DST"
install_name_tool -id "@rpath/${RUNTIME_FRAMEWORK_NAME}/${RUNTIME_FRAMEWORK_EXECUTABLE}" "$RUNTIME_DST"
cat > "${RUNTIME_FRAMEWORK_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${RUNTIME_FRAMEWORK_EXECUTABLE}</string>
  <key>CFBundleIdentifier</key>
  <string>app.beacon.litert-metal-accelerator</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>LiteRtMetalAccelerator</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>MinimumOSVersion</key>
  <string>15.0</string>
</dict>
</plist>
EOF

CLITERT_VARIANT="ios-arm64"
if [ "$PLATFORM_NAME" = "iphonesimulator" ]; then
  CLITERT_VARIANT="ios-arm64_x86_64-simulator"
fi

CLITERT_SRC="${PROJECT_DIR}/Vendor/CLiteRTLM.xcframework/${CLITERT_VARIANT}/CLiteRTLM.framework"
CLITERT_DST="${RUNTIME_DIR}/CLiteRTLM.framework"
if [ ! -d "$CLITERT_SRC" ]; then
  echo "error: Missing official LiteRT-LM framework at $CLITERT_SRC" >&2
  exit 1
fi
rsync -a --delete "$CLITERT_SRC/" "$CLITERT_DST/"

# App Store validation expects Swift runtime dylibs referenced by bundled
# Swift-based frameworks to live inside Payload/App.app/Frameworks. Some
# official LiteRT/Capacitor combinations do not trigger Xcode's automatic
# Swift stdlib embedding reliably, so stage the exact runtime set explicitly
# during the normal build phase before the app bundle is sealed.
if [ "$PLATFORM_NAME" = "iphoneos" ]; then
  SWIFT_STDLIB_DIR="${DT_TOOLCHAIN_DIR:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain}/usr/lib/swift-5.0/iphoneos"
  if [ ! -d "$SWIFT_STDLIB_DIR" ]; then
    SWIFT_STDLIB_DIR="${DT_TOOLCHAIN_DIR:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain}/usr/lib/swift/iphoneos"
  fi
  if [ ! -d "$SWIFT_STDLIB_DIR" ]; then
    echo "error: Could not locate iPhoneOS Swift standard libraries under DT_TOOLCHAIN_DIR." >&2
    exit 1
  fi

  SWIFT_DYLIBS="
libswiftDarwin.dylib
libswiftMetal.dylib
libswiftCoreAudio.dylib
libswiftsimd.dylib
libswiftQuartzCore.dylib
libswiftos.dylib
libswiftObjectiveC.dylib
libswiftDispatch.dylib
libswiftCoreLocation.dylib
libswiftCoreGraphics.dylib
libswiftCoreFoundation.dylib
libswiftUIKit.dylib
libswiftCoreMedia.dylib
libswiftAVFoundation.dylib
libswiftCore.dylib
libswiftFoundation.dylib
libswiftCoreImage.dylib
"
  for dylib in $SWIFT_DYLIBS; do
    SWIFT_SRC="${SWIFT_STDLIB_DIR}/${dylib}"
    SWIFT_DST="${RUNTIME_DIR}/${dylib}"
    if [ ! -f "$SWIFT_SRC" ]; then
      echo "error: Missing Swift standard library: $SWIFT_SRC" >&2
      exit 1
    fi
    copy_if_needed "$SWIFT_SRC" "$SWIFT_DST"
  done
fi

# Older Beacon builds copied the Metal accelerator as a loose dylib. App Store
# validation only accepts non-system dynamic libraries inside framework bundles,
# so keep the accelerator in LiteRtMetalAccelerator.framework and remove stale
# loose dylibs from the app bundle and resources.
rm -f "$RUNTIME_LEGACY_DST"
rm -f "${RUNTIME_DIR}/libLiteRtGpuAccelerator.dylib"
rm -f "${MODEL_DIR}/libLiteRtGpuAccelerator.dylib"
rm -f "${MODEL_DIR}/libLiteRtMetalAccelerator.dylib"

if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ]; then
  CODE_SIGN_IDENTITY_TO_USE="${EXPANDED_CODE_SIGN_IDENTITY:--}"
  codesign --force --sign "$CODE_SIGN_IDENTITY_TO_USE" --timestamp=none "$RUNTIME_FRAMEWORK_DIR"
  codesign --force --sign "$CODE_SIGN_IDENTITY_TO_USE" --timestamp=none "$CLITERT_DST"
fi

if [ "$PLATFORM_NAME" = "iphoneos" ] && [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  for dylib in $SWIFT_DYLIBS; do
    codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none "${RUNTIME_DIR}/${dylib}"
  done
fi
