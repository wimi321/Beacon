#!/bin/zsh
set -euo pipefail

export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

ROOT=/Users/haoc/Developer/Beacon
LITERT_REPO=${LITERT_REPO:-/tmp/LiteRT-LM}
XCFRAMEWORK="$ROOT/ios/App/Vendor/BeaconLiteRtLm.xcframework"
AR_BIN=/usr/bin/ar
ENGINE_TARGET=//c:engine
MAGIC_HELPER_TARGET=//runtime/executor:magic_number_configs_helper
LLM_EXECUTOR_SETTINGS_UTILS_TARGET=//runtime/executor:llm_executor_settings_utils
ENGINE_SETTINGS_TARGET=//runtime/engine:engine_settings
ENGINE_IMPL_TARGET=//runtime/core:engine_impl
LLM_LITERT_COMPILED_MODEL_EXECUTOR_TARGET=//runtime/executor:llm_litert_compiled_model_executor
KV_CACHE_TARGET=//runtime/executor/litert:kv_cache

if [[ ! -d "$LITERT_REPO" ]]; then
  echo "LiteRT-LM repo not found: $LITERT_REPO" >&2
  exit 1
fi

if [[ ! -d "$XCFRAMEWORK" ]]; then
  echo "Beacon LiteRT xcframework missing: $XCFRAMEWORK" >&2
  exit 1
fi

if ! command -v bazelisk >/dev/null 2>&1; then
  echo "bazelisk is required to rebuild LiteRT-LM patch objects." >&2
  exit 1
fi

build_patch_objects() {
  local config="$1"
  (
    cd "$LITERT_REPO"
    bazelisk build --config="$config" \
      "$ENGINE_TARGET" \
      "$MAGIC_HELPER_TARGET" \
      "$LLM_EXECUTOR_SETTINGS_UTILS_TARGET" \
      "$ENGINE_SETTINGS_TARGET" \
      "$ENGINE_IMPL_TARGET" \
      "$KV_CACHE_TARGET" \
      "$LLM_LITERT_COMPILED_MODEL_EXECUTOR_TARGET" >/dev/null
  )
}

replace_archive_members() {
  local label="$1"
  local config="$2"
  local base_lib="$XCFRAMEWORK/$label/libengine.a"
  local headers_dir="$XCFRAMEWORK/$label/Headers"
  local engine_obj="$LITERT_REPO/bazel-out/${config}-opt/bin/c/_objs/engine/engine.o"
  local magic_obj="$LITERT_REPO/bazel-out/${config}-opt/bin/runtime/executor/_objs/magic_number_configs_helper/magic_number_configs_helper.o"
  local llm_utils_obj="$LITERT_REPO/bazel-out/${config}-opt/bin/runtime/executor/_objs/llm_executor_settings_utils/llm_executor_settings_utils.o"
  local engine_settings_obj="$LITERT_REPO/bazel-out/${config}-opt/bin/runtime/engine/_objs/engine_settings/engine_settings.o"
  local engine_impl_obj="$LITERT_REPO/bazel-out/${config}-opt/bin/runtime/core/_objs/engine_impl/engine_impl.o"
  local kv_cache_obj="$LITERT_REPO/bazel-out/${config}-opt/bin/runtime/executor/litert/_objs/kv_cache/kv_cache.o"
  local llm_executor_obj="$LITERT_REPO/bazel-out/${config}-opt/bin/runtime/executor/_objs/llm_litert_compiled_model_executor/llm_litert_compiled_model_executor.o"
  local tmp_dir

  if [[ ! -f "$base_lib" ]]; then
    echo "Base archive missing: $base_lib" >&2
    exit 1
  fi
  if [[ ! -f "$engine_obj" ]]; then
    echo "Patched engine object missing: $engine_obj" >&2
    exit 1
  fi
  if [[ ! -f "$magic_obj" ]]; then
    echo "Patched magic helper object missing: $magic_obj" >&2
    exit 1
  fi
  if [[ ! -f "$llm_utils_obj" ]]; then
    echo "Patched llm executor settings utils object missing: $llm_utils_obj" >&2
    exit 1
  fi
  if [[ ! -f "$engine_settings_obj" ]]; then
    echo "Patched engine settings object missing: $engine_settings_obj" >&2
    exit 1
  fi
  if [[ ! -f "$engine_impl_obj" ]]; then
    echo "Patched engine impl object missing: $engine_impl_obj" >&2
    exit 1
  fi
  if [[ ! -f "$kv_cache_obj" ]]; then
    echo "Patched kv cache object missing: $kv_cache_obj" >&2
    exit 1
  fi
  if [[ ! -f "$llm_executor_obj" ]]; then
    echo "Patched llm executor object missing: $llm_executor_obj" >&2
    exit 1
  fi

  cp "$LITERT_REPO/c/engine.h" "$headers_dir/engine.h"
  cp "$LITERT_REPO/c/litert_lm_logging.h" "$headers_dir/litert_lm_logging.h"

  tmp_dir=$(mktemp -d)

  cp "$engine_obj" "$tmp_dir/engine.o"
  cp "$magic_obj" "$tmp_dir/magic_number_configs_helper.o"
  cp "$llm_utils_obj" "$tmp_dir/llm_executor_settings_utils.o"
  cp "$engine_settings_obj" "$tmp_dir/engine_settings.o"
  cp "$engine_impl_obj" "$tmp_dir/engine_impl.o"
  cp "$kv_cache_obj" "$tmp_dir/kv_cache.o"
  cp "$llm_executor_obj" "$tmp_dir/llm_litert_compiled_model_executor.o"

  "$AR_BIN" -d "$base_lib" engine.o magic_number_configs_helper.o llm_executor_settings_utils.o engine_settings.o engine_impl.o kv_cache.o llm_litert_compiled_model_executor.o >/dev/null 2>&1 || true
  (
    cd "$tmp_dir"
    "$AR_BIN" -r "$base_lib" engine.o magic_number_configs_helper.o llm_executor_settings_utils.o engine_settings.o engine_impl.o kv_cache.o llm_litert_compiled_model_executor.o
  )

  rm -rf "$tmp_dir"
  echo "Patched $label archive in place"
}

build_patch_objects ios_arm64
build_patch_objects ios_sim_arm64

replace_archive_members ios-arm64 ios_arm64
replace_archive_members ios-arm64-simulator ios_sim_arm64

echo "Updated $XCFRAMEWORK"
