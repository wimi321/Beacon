#!/bin/sh
set -eu

copy_if_needed() {
  src="$1"
  dst="$2"

  src_size=$(stat -f%z "$src")
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
RUNTIME_DST="${RUNTIME_DIR}/libLiteRtMetalAccelerator.dylib"
MODEL_RUNTIME_DST="${MODEL_DIR}/libLiteRtMetalAccelerator.dylib"

mkdir -p "$RUNTIME_DIR"
copy_if_needed "$RUNTIME_SRC" "$RUNTIME_DST"
copy_if_needed "$RUNTIME_SRC" "$MODEL_RUNTIME_DST"

# Older Beacon builds duplicated the same Metal accelerator binary under the
# generic GPU filename as well. On device that causes Objective-C class
# collisions when both dylibs are loaded, so proactively remove the stale alias.
rm -f "${RUNTIME_DIR}/libLiteRtGpuAccelerator.dylib"
rm -f "${MODEL_DIR}/libLiteRtGpuAccelerator.dylib"

if [ "$PLATFORM_NAME" = "iphoneos" ] && [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none "$RUNTIME_DST"
  codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none "$MODEL_RUNTIME_DST"
fi
