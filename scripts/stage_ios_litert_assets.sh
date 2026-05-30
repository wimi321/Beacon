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

ensure_beacon_native_plugin_registration() {
  config_path="$1"
  if [ ! -f "$config_path" ]; then
    echo "warning: capacitor.config.json not found at $config_path; BeaconNative registration not patched" >&2
    return 0
  fi

  CONFIG_PATH="$config_path" python3 - <<'PY'
import json
import os
from pathlib import Path

config_path = Path(os.environ["CONFIG_PATH"])
config = json.loads(config_path.read_text())
package_classes = list(config.get("packageClassList") or [])
changed = False

for plugin_class in ("BeaconNativePlugin", "App.BeaconNativePlugin"):
    if plugin_class not in package_classes:
        package_classes.append(plugin_class)
        changed = True

if changed:
    config["packageClassList"] = package_classes
    config_path.write_text(json.dumps(config, indent="\t", ensure_ascii=False) + "\n")
    print(f"note: Patched BeaconNative plugin registration in {config_path}")
else:
    print(f"note: BeaconNative plugin registration already present in {config_path}")
PY
}

PROJECT_DIR="${PROJECT_DIR:?PROJECT_DIR is required}"
TARGET_BUILD_DIR="${TARGET_BUILD_DIR:?TARGET_BUILD_DIR is required}"
UNLOCALIZED_RESOURCES_FOLDER_PATH="${UNLOCALIZED_RESOURCES_FOLDER_PATH:?UNLOCALIZED_RESOURCES_FOLDER_PATH is required}"
FRAMEWORKS_FOLDER_PATH="${FRAMEWORKS_FOLDER_PATH:-Frameworks}"
PLATFORM_NAME="${PLATFORM_NAME:-iphoneos}"

MODEL_SRC_DEFAULT="${PROJECT_DIR}/../../.artifacts/gemma-4-E2B-it.litertlm"
MODEL_SRC_ORCA2520="${PROJECT_DIR}/../../.artifacts/models/gemma-4-E2B-it-orca2520.litertlm"
MODEL_SRC="${BEACON_IOS_GEMMA_MODEL_SRC:-}"
if [ -z "$MODEL_SRC" ]; then
  if [ -f "$MODEL_SRC_DEFAULT" ]; then
    MODEL_SRC="$MODEL_SRC_DEFAULT"
    echo "note: Using official Gemma 4 E2B LiteRT-LM artifact for iOS: $MODEL_SRC"
  elif [ -f "$MODEL_SRC_ORCA2520" ]; then
    MODEL_SRC="$MODEL_SRC_ORCA2520"
    echo "note: Official Gemma 4 E2B artifact not found; using ORCA-style vision_2520 artifact: $MODEL_SRC"
  fi
fi
MODEL_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/models"
MODEL_DST="${MODEL_DIR}/gemma-4-E2B-it.litertlm"

if [ ! -f "$MODEL_SRC" ]; then
  echo "error: Missing bundled Gemma 4 E2B artifact at $MODEL_SRC" >&2
  exit 1
fi

mkdir -p "$MODEL_DIR"
copy_if_needed "$MODEL_SRC" "$MODEL_DST"

# `npx cap sync ios` regenerates capacitor.config.json and can drop local,
# app-owned plugins that are not installed as npm Capacitor packages. Patch the
# already-copied resource inside the app bundle on every Xcode build so the
# JavaScript bridge always sees the real iOS BeaconNative implementation.
ensure_beacon_native_plugin_registration "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/capacitor.config.json"

RUNTIME_VARIANT="ios-arm64"
if [ "$PLATFORM_NAME" = "iphonesimulator" ]; then
  RUNTIME_VARIANT="ios-arm64-simulator"
fi

RUNTIME_SRC="${PROJECT_DIR}/Vendor/LiteRtRuntime/${RUNTIME_VARIANT}/libLiteRtMetalAccelerator.dylib"
if [ ! -f "$RUNTIME_SRC" ]; then
  echo "error: Missing LiteRT Metal accelerator runtime at $RUNTIME_SRC" >&2
  exit 1
fi
GEMMA_CONSTRAINT_PROVIDER_SRC="${PROJECT_DIR}/Vendor/LiteRtRuntime/${RUNTIME_VARIANT}/libGemmaModelConstraintProvider.dylib"
if [ ! -f "$GEMMA_CONSTRAINT_PROVIDER_SRC" ]; then
  echo "error: Missing Gemma model constraint provider runtime at $GEMMA_CONSTRAINT_PROVIDER_SRC" >&2
  exit 1
fi

RUNTIME_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_NAME="GemmaModelConstraintProvider.framework"
GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_EXECUTABLE="GemmaModelConstraintProvider"
GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_DIR="${RUNTIME_DIR}/${GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_NAME}"
GEMMA_CONSTRAINT_PROVIDER_DST="${GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_DIR}/${GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_EXECUTABLE}"
GEMMA_CONSTRAINT_PROVIDER_LEGACY_DST="${RUNTIME_DIR}/libGemmaModelConstraintProvider.dylib"
RUNTIME_FRAMEWORK_NAME="LiteRtMetalAccelerator.framework"
RUNTIME_FRAMEWORK_EXECUTABLE="LiteRtMetalAccelerator"
RUNTIME_FRAMEWORK_DIR="${RUNTIME_DIR}/${RUNTIME_FRAMEWORK_NAME}"
RUNTIME_DST="${RUNTIME_FRAMEWORK_DIR}/${RUNTIME_FRAMEWORK_EXECUTABLE}"
RUNTIME_LEGACY_DST="${RUNTIME_DIR}/libLiteRtMetalAccelerator.dylib"

mkdir -p "$RUNTIME_DIR"
rm -rf "$GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_DIR"
mkdir -p "$GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_DIR"
cp -f "$GEMMA_CONSTRAINT_PROVIDER_SRC" "$GEMMA_CONSTRAINT_PROVIDER_DST"
chmod 755 "$GEMMA_CONSTRAINT_PROVIDER_DST"
install_name_tool -id "@rpath/${GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_NAME}/${GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_EXECUTABLE}" "$GEMMA_CONSTRAINT_PROVIDER_DST"
cat > "${GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_EXECUTABLE}</string>
  <key>CFBundleIdentifier</key>
  <string>app.beacon.gemma-model-constraint-provider</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>GemmaModelConstraintProvider</string>
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
install_name_tool \
  -change "@rpath/libGemmaModelConstraintProvider.dylib" \
  "@rpath/${GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_NAME}/${GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_EXECUTABLE}" \
  "${CLITERT_DST}/CLiteRTLM"

# Older Beacon builds copied the Metal accelerator as a loose dylib. App Store
# validation only accepts non-system dynamic libraries inside framework bundles,
# so keep the accelerator in LiteRtMetalAccelerator.framework and remove stale
# loose dylibs from the app bundle and resources.
rm -f "$GEMMA_CONSTRAINT_PROVIDER_LEGACY_DST"
rm -f "$RUNTIME_LEGACY_DST"
rm -f "${RUNTIME_DIR}/libLiteRtGpuAccelerator.dylib"
rm -f "${MODEL_DIR}/libLiteRtGpuAccelerator.dylib"
rm -f "${MODEL_DIR}/libLiteRtMetalAccelerator.dylib"

if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ]; then
  CODE_SIGN_IDENTITY_TO_USE="${EXPANDED_CODE_SIGN_IDENTITY:--}"
  codesign --force --sign "$CODE_SIGN_IDENTITY_TO_USE" --timestamp=none "$GEMMA_CONSTRAINT_PROVIDER_FRAMEWORK_DIR"
  codesign --force --sign "$CODE_SIGN_IDENTITY_TO_USE" --timestamp=none "$RUNTIME_FRAMEWORK_DIR"
  codesign --force --sign "$CODE_SIGN_IDENTITY_TO_USE" --timestamp=none "$CLITERT_DST"
fi
