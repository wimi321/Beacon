#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR
DEVICETCL_BIN="${DEVELOPER_DIR}/usr/bin/devicectl"
XCDEVICE_BIN="${DEVELOPER_DIR}/usr/bin/xcdevice"

APP_BUNDLE_ID="com.beacon.sos"
DEVICE_ID="${1:-${BEACON_IOS_DEVICE_ID:-}}"
BUILD_DIR="$ROOT/ios/build-device-smoke"
APP_PATH="$BUILD_DIR/Build/Products/Debug-iphoneos/App.app"
RESULT_DIR="$ROOT/.artifacts/runtime-smoke"
RESULT_PATH="$RESULT_DIR/beacon-native-smoke-results.json"
REQUEST_PATH="$RESULT_DIR/beacon-native-smoke-request.json"
LIVE_PROGRESS_PATH="$RESULT_DIR/beacon-native-smoke-progress.json"
ENGINE_PROGRESS_PATH="$RESULT_DIR/beacon-litert-engine-progress.txt"
ENGINE_ERROR_PATH="$RESULT_DIR/beacon-litert-engine-error.txt"
CONVERSATION_ERROR_PATH="$RESULT_DIR/beacon-litert-conversation-error.txt"
COMPILED_MODEL_ERROR_PATH="$RESULT_DIR/beacon-litert-compiled-model-create-error.txt"
STATIC_INIT_PATH="$RESULT_DIR/beacon-litert-static-init.txt"
PREFILL_RUN_ERROR_PATH="$RESULT_DIR/beacon-litert-prefill-run-error.txt"
DECODE_RUN_ERROR_PATH="$RESULT_DIR/beacon-litert-decode-run-error.txt"
APPDELEGATE_AUDIT_PATH="$RESULT_DIR/beacon-appdelegate-smoke-audit.json"
TRACE_TOKEN="beacon-smoke-$(date -u +%Y%m%dT%H%M%SZ)"
SMOKE_QUERY="TRACE_TOKEN=${TRACE_TOKEN}. I am trapped in a building fire with thick smoke and limited visibility. What should I do first?"
RUNTIME_DISPATCH_MODE="${BEACON_LITERT_RUNTIME_DISPATCH_MODE:-preload-only}"
CACHE_MODE="${BEACON_LITERT_CACHE_MODE:-default}"
EXPECT_OK="${BEACON_SMOKE_EXPECT_OK:-1}"
EXPECT_ACTIVE_BACKEND="${BEACON_SMOKE_EXPECT_ACTIVE_BACKEND:-}"
EXPECT_CAPABILITY_CLASS="${BEACON_SMOKE_EXPECT_CAPABILITY_CLASS:-}"
ENV_JSON="$(
  TRACE_TOKEN="$TRACE_TOKEN" SMOKE_QUERY="$SMOKE_QUERY" RUNTIME_DISPATCH_MODE="$RUNTIME_DISPATCH_MODE" CACHE_MODE="$CACHE_MODE" BEACON_LITERT_CPU_OUT_OF_PLACE_KV_CACHE="${BEACON_LITERT_CPU_OUT_OF_PLACE_KV_CACHE:-}" BEACON_LITERT_GPU_ONLY="${BEACON_LITERT_GPU_ONLY:-}" BEACON_LITERT_ALLOW_UNSAFE_GPU_ONLY="${BEACON_LITERT_ALLOW_UNSAFE_GPU_ONLY:-}" BEACON_LITERT_SKIP_GPU="${BEACON_LITERT_SKIP_GPU:-}" BEACON_LITERT_GPU_EXTERNAL_WEIGHT_SECTION_MAP="${BEACON_LITERT_GPU_EXTERNAL_WEIGHT_SECTION_MAP:-}" BEACON_LITERT_MAX_TOKENS="${BEACON_LITERT_MAX_TOKENS:-}" BEACON_LITERT_PREFILL_CHUNK_SIZE="${BEACON_LITERT_PREFILL_CHUNK_SIZE:-}" BEACON_LITERT_SESSION_MAX_OUTPUT_TOKENS="${BEACON_LITERT_SESSION_MAX_OUTPUT_TOKENS:-}" BEACON_LITERT_ACTIVATION_DATA_TYPE="${BEACON_LITERT_ACTIVATION_DATA_TYPE:-}" BEACON_LITERT_SAMPLER_BACKEND="${BEACON_LITERT_SAMPLER_BACKEND:-}" BEACON_LITERT_PARALLEL_FILE_LOADING="${BEACON_LITERT_PARALLEL_FILE_LOADING:-}" BEACON_LITERT_INJECT_DISPATCH_LIBRARY_DIR="${BEACON_LITERT_INJECT_DISPATCH_LIBRARY_DIR:-}" BEACON_LITERT_GPU_EXTERNAL_TENSOR_MODE="${BEACON_LITERT_GPU_EXTERNAL_TENSOR_MODE:-}" BEACON_LITERT_GPU_SHARE_CONSTANT_TENSORS="${BEACON_LITERT_GPU_SHARE_CONSTANT_TENSORS:-}" BEACON_LITERT_GPU_OPTIMIZE_SHADER_COMPILATION="${BEACON_LITERT_GPU_OPTIMIZE_SHADER_COMPILATION:-}" BEACON_LITERT_GPU_CONVERT_WEIGHTS_ON_GPU="${BEACON_LITERT_GPU_CONVERT_WEIGHTS_ON_GPU:-}" BEACON_LITERT_GPU_CACHE_COMPILED_SHADERS_ONLY="${BEACON_LITERT_GPU_CACHE_COMPILED_SHADERS_ONLY:-}" BEACON_LITERT_GPU_ALLOW_SRC_QUANTIZED_FC_CONV_OPS="${BEACON_LITERT_GPU_ALLOW_SRC_QUANTIZED_FC_CONV_OPS:-}" BEACON_LITERT_GPU_NUM_THREADS_TO_UPLOAD="${BEACON_LITERT_GPU_NUM_THREADS_TO_UPLOAD:-}" BEACON_LITERT_GPU_NUM_THREADS_TO_COMPILE="${BEACON_LITERT_GPU_NUM_THREADS_TO_COMPILE:-}" BEACON_LITERT_PREFER_TEXTURE_WEIGHTS="${BEACON_LITERT_PREFER_TEXTURE_WEIGHTS:-}" BEACON_LITERT_USE_METAL_ARGUMENT_BUFFERS="${BEACON_LITERT_USE_METAL_ARGUMENT_BUFFERS:-}" BEACON_LITERT_GPU_FULLY_DELEGATED_SINGLE_DELEGATE="${BEACON_LITERT_GPU_FULLY_DELEGATED_SINGLE_DELEGATE:-}" BEACON_LITERT_GPU_COMMAND_BUFFER_PREPARATIONS="${BEACON_LITERT_GPU_COMMAND_BUFFER_PREPARATIONS:-}" python3 - <<'PY'
import json
import os

payload = {
    "BEACON_SMOKE_TEST": "1",
    "BEACON_SMOKE_QUERY": os.environ["SMOKE_QUERY"],
    "BEACON_LITERT_RUNTIME_DISPATCH_MODE": os.environ["RUNTIME_DISPATCH_MODE"],
    "BEACON_LITERT_CACHE_MODE": os.environ["CACHE_MODE"],
}

cpu_kv_mode = os.environ.get("BEACON_LITERT_CPU_OUT_OF_PLACE_KV_CACHE", "")
if cpu_kv_mode:
    payload["BEACON_LITERT_CPU_OUT_OF_PLACE_KV_CACHE"] = cpu_kv_mode

gpu_only = os.environ.get("BEACON_LITERT_GPU_ONLY", "")
if gpu_only:
    payload["BEACON_LITERT_GPU_ONLY"] = gpu_only

allow_unsafe_gpu_only = os.environ.get("BEACON_LITERT_ALLOW_UNSAFE_GPU_ONLY", "")
if allow_unsafe_gpu_only:
    payload["BEACON_LITERT_ALLOW_UNSAFE_GPU_ONLY"] = allow_unsafe_gpu_only

skip_gpu = os.environ.get("BEACON_LITERT_SKIP_GPU", "")
if skip_gpu:
    payload["BEACON_LITERT_SKIP_GPU"] = skip_gpu

gpu_external_weight_section_map = os.environ.get("BEACON_LITERT_GPU_EXTERNAL_WEIGHT_SECTION_MAP", "")
if gpu_external_weight_section_map:
    payload["BEACON_LITERT_GPU_EXTERNAL_WEIGHT_SECTION_MAP"] = gpu_external_weight_section_map

for key in (
    "BEACON_LITERT_MAX_TOKENS",
    "BEACON_LITERT_PREFILL_CHUNK_SIZE",
    "BEACON_LITERT_SESSION_MAX_OUTPUT_TOKENS",
    "BEACON_LITERT_ACTIVATION_DATA_TYPE",
    "BEACON_LITERT_SAMPLER_BACKEND",
    "BEACON_LITERT_PARALLEL_FILE_LOADING",
    "BEACON_LITERT_INJECT_DISPATCH_LIBRARY_DIR",
    "BEACON_LITERT_GPU_EXTERNAL_TENSOR_MODE",
    "BEACON_LITERT_GPU_SHARE_CONSTANT_TENSORS",
    "BEACON_LITERT_GPU_OPTIMIZE_SHADER_COMPILATION",
    "BEACON_LITERT_GPU_CONVERT_WEIGHTS_ON_GPU",
    "BEACON_LITERT_GPU_CACHE_COMPILED_SHADERS_ONLY",
    "BEACON_LITERT_GPU_ALLOW_SRC_QUANTIZED_FC_CONV_OPS",
    "BEACON_LITERT_GPU_NUM_THREADS_TO_UPLOAD",
    "BEACON_LITERT_GPU_NUM_THREADS_TO_COMPILE",
    "BEACON_LITERT_PREFER_TEXTURE_WEIGHTS",
    "BEACON_LITERT_USE_METAL_ARGUMENT_BUFFERS",
    "BEACON_LITERT_GPU_FULLY_DELEGATED_SINGLE_DELEGATE",
    "BEACON_LITERT_GPU_COMMAND_BUFFER_PREPARATIONS",
):
    value = os.environ.get(key, "")
    if value:
        payload[key] = value

print(json.dumps(payload))
PY
)"
REQUEST_JSON="$(
  TRACE_TOKEN="$TRACE_TOKEN" SMOKE_QUERY="$SMOKE_QUERY" RUNTIME_DISPATCH_MODE="$RUNTIME_DISPATCH_MODE" CACHE_MODE="$CACHE_MODE" BEACON_LITERT_CPU_OUT_OF_PLACE_KV_CACHE="${BEACON_LITERT_CPU_OUT_OF_PLACE_KV_CACHE:-}" BEACON_LITERT_GPU_ONLY="${BEACON_LITERT_GPU_ONLY:-}" BEACON_LITERT_ALLOW_UNSAFE_GPU_ONLY="${BEACON_LITERT_ALLOW_UNSAFE_GPU_ONLY:-}" BEACON_LITERT_SKIP_GPU="${BEACON_LITERT_SKIP_GPU:-}" BEACON_LITERT_GPU_EXTERNAL_WEIGHT_SECTION_MAP="${BEACON_LITERT_GPU_EXTERNAL_WEIGHT_SECTION_MAP:-}" BEACON_LITERT_MAX_TOKENS="${BEACON_LITERT_MAX_TOKENS:-}" BEACON_LITERT_PREFILL_CHUNK_SIZE="${BEACON_LITERT_PREFILL_CHUNK_SIZE:-}" BEACON_LITERT_SESSION_MAX_OUTPUT_TOKENS="${BEACON_LITERT_SESSION_MAX_OUTPUT_TOKENS:-}" BEACON_LITERT_ACTIVATION_DATA_TYPE="${BEACON_LITERT_ACTIVATION_DATA_TYPE:-}" BEACON_LITERT_SAMPLER_BACKEND="${BEACON_LITERT_SAMPLER_BACKEND:-}" BEACON_LITERT_PARALLEL_FILE_LOADING="${BEACON_LITERT_PARALLEL_FILE_LOADING:-}" BEACON_LITERT_INJECT_DISPATCH_LIBRARY_DIR="${BEACON_LITERT_INJECT_DISPATCH_LIBRARY_DIR:-}" BEACON_LITERT_GPU_EXTERNAL_TENSOR_MODE="${BEACON_LITERT_GPU_EXTERNAL_TENSOR_MODE:-}" BEACON_LITERT_GPU_SHARE_CONSTANT_TENSORS="${BEACON_LITERT_GPU_SHARE_CONSTANT_TENSORS:-}" BEACON_LITERT_GPU_OPTIMIZE_SHADER_COMPILATION="${BEACON_LITERT_GPU_OPTIMIZE_SHADER_COMPILATION:-}" BEACON_LITERT_GPU_CONVERT_WEIGHTS_ON_GPU="${BEACON_LITERT_GPU_CONVERT_WEIGHTS_ON_GPU:-}" BEACON_LITERT_GPU_CACHE_COMPILED_SHADERS_ONLY="${BEACON_LITERT_GPU_CACHE_COMPILED_SHADERS_ONLY:-}" BEACON_LITERT_GPU_ALLOW_SRC_QUANTIZED_FC_CONV_OPS="${BEACON_LITERT_GPU_ALLOW_SRC_QUANTIZED_FC_CONV_OPS:-}" BEACON_LITERT_GPU_NUM_THREADS_TO_UPLOAD="${BEACON_LITERT_GPU_NUM_THREADS_TO_UPLOAD:-}" BEACON_LITERT_GPU_NUM_THREADS_TO_COMPILE="${BEACON_LITERT_GPU_NUM_THREADS_TO_COMPILE:-}" BEACON_LITERT_PREFER_TEXTURE_WEIGHTS="${BEACON_LITERT_PREFER_TEXTURE_WEIGHTS:-}" BEACON_LITERT_USE_METAL_ARGUMENT_BUFFERS="${BEACON_LITERT_USE_METAL_ARGUMENT_BUFFERS:-}" BEACON_LITERT_GPU_FULLY_DELEGATED_SINGLE_DELEGATE="${BEACON_LITERT_GPU_FULLY_DELEGATED_SINGLE_DELEGATE:-}" BEACON_LITERT_GPU_COMMAND_BUFFER_PREPARATIONS="${BEACON_LITERT_GPU_COMMAND_BUFFER_PREPARATIONS:-}" python3 - <<'PY'
import json
import os

payload = {
    "enabled": True,
    "traceToken": os.environ["TRACE_TOKEN"],
    "query": os.environ["SMOKE_QUERY"],
    "runtimeDispatchMode": os.environ["RUNTIME_DISPATCH_MODE"],
    "cacheMode": os.environ["CACHE_MODE"],
}

cpu_kv_mode = os.environ.get("BEACON_LITERT_CPU_OUT_OF_PLACE_KV_CACHE", "")
if cpu_kv_mode:
    payload["cpuOutOfPlaceKvCache"] = cpu_kv_mode

gpu_only = os.environ.get("BEACON_LITERT_GPU_ONLY", "")
if gpu_only:
    payload["gpuOnly"] = gpu_only

allow_unsafe_gpu_only = os.environ.get("BEACON_LITERT_ALLOW_UNSAFE_GPU_ONLY", "")
if allow_unsafe_gpu_only:
    payload["allowUnsafeGpuOnly"] = allow_unsafe_gpu_only

skip_gpu = os.environ.get("BEACON_LITERT_SKIP_GPU", "")
if skip_gpu:
    payload["skipGpu"] = skip_gpu

gpu_external_weight_section_map = os.environ.get("BEACON_LITERT_GPU_EXTERNAL_WEIGHT_SECTION_MAP", "")
if gpu_external_weight_section_map:
    payload["gpuExternalWeightSectionMap"] = gpu_external_weight_section_map

for env_key, request_key in (
    ("BEACON_LITERT_MAX_TOKENS", "maxTokens"),
    ("BEACON_LITERT_PREFILL_CHUNK_SIZE", "prefillChunkSize"),
    ("BEACON_LITERT_SESSION_MAX_OUTPUT_TOKENS", "sessionMaxOutputTokens"),
    ("BEACON_LITERT_ACTIVATION_DATA_TYPE", "activationDataType"),
    ("BEACON_LITERT_SAMPLER_BACKEND", "samplerBackend"),
    ("BEACON_LITERT_PARALLEL_FILE_LOADING", "parallelFileLoading"),
    ("BEACON_LITERT_INJECT_DISPATCH_LIBRARY_DIR", "injectDispatchLibraryDir"),
    ("BEACON_LITERT_GPU_EXTERNAL_TENSOR_MODE", "gpuExternalTensorMode"),
    ("BEACON_LITERT_GPU_SHARE_CONSTANT_TENSORS", "gpuShareConstantTensors"),
    ("BEACON_LITERT_GPU_OPTIMIZE_SHADER_COMPILATION", "gpuOptimizeShaderCompilation"),
    ("BEACON_LITERT_GPU_CONVERT_WEIGHTS_ON_GPU", "gpuConvertWeightsOnGpu"),
    ("BEACON_LITERT_GPU_CACHE_COMPILED_SHADERS_ONLY", "gpuCacheCompiledShadersOnly"),
    ("BEACON_LITERT_GPU_ALLOW_SRC_QUANTIZED_FC_CONV_OPS", "gpuAllowSrcQuantizedFcConvOps"),
    ("BEACON_LITERT_GPU_NUM_THREADS_TO_UPLOAD", "gpuNumThreadsToUpload"),
    ("BEACON_LITERT_GPU_NUM_THREADS_TO_COMPILE", "gpuNumThreadsToCompile"),
    ("BEACON_LITERT_PREFER_TEXTURE_WEIGHTS", "preferTextureWeights"),
    ("BEACON_LITERT_USE_METAL_ARGUMENT_BUFFERS", "useMetalArgumentBuffers"),
    ("BEACON_LITERT_GPU_FULLY_DELEGATED_SINGLE_DELEGATE", "gpuFullyDelegatedSingleDelegate"),
    ("BEACON_LITERT_GPU_COMMAND_BUFFER_PREPARATIONS", "gpuCommandBufferPreparations"),
):
    value = os.environ.get(env_key, "")
    if value:
        payload[request_key] = value

print(json.dumps(payload, indent=2))
PY
)"

if [[ -z "$DEVICE_ID" ]]; then
  if [[ -x "$XCDEVICE_BIN" ]]; then
    DEVICE_ID="$(
      "$XCDEVICE_BIN" list 2>/dev/null | python3 -c '
import json, sys
devices = json.load(sys.stdin)
for device in devices:
    if device.get("platform") == "com.apple.platform.iphoneos" and device.get("available") and not device.get("simulator", False):
        print(device.get("identifier", ""))
        break
' || true
    )"
  fi
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "No paired iOS device is currently available. Connect and unlock an iPhone/iPad first." >&2
  exit 1
fi

TARGET_DEVICE_JSON="$(
  "$XCDEVICE_BIN" list 2>/dev/null | python3 -c '
import json
import sys

device_id = sys.argv[1]
devices = json.load(sys.stdin)
for device in devices:
    if device.get("identifier") == device_id:
        print(json.dumps(device))
        break
' "$DEVICE_ID"
)"

if [[ -z "$TARGET_DEVICE_JSON" ]]; then
  echo "Requested iOS device $DEVICE_ID is not visible to Xcode right now." >&2
  exit 1
fi

TARGET_DEVICE_AVAILABLE="$(
  printf '%s' "$TARGET_DEVICE_JSON" | python3 -c '
import json
import sys

device = json.load(sys.stdin)
print("1" if device.get("available") else "0")
'
)"

if [[ "$TARGET_DEVICE_AVAILABLE" != "1" ]]; then
  echo "Requested iOS device $DEVICE_ID is currently unavailable to Xcode." >&2
  printf '%s\n' "$TARGET_DEVICE_JSON" | python3 -c '
import json
import sys

device = json.load(sys.stdin)
print(json.dumps({
    "identifier": device.get("identifier"),
    "name": device.get("name"),
    "modelName": device.get("modelName"),
    "available": device.get("available"),
    "error": device.get("error"),
}, ensure_ascii=False, indent=2))
' >&2
  exit 1
fi

if [[ ! -x "$DEVICETCL_BIN" ]]; then
  echo "devicectl is unavailable at $DEVICETCL_BIN" >&2
  exit 1
fi

mkdir -p "$RESULT_DIR"
rm -f "$RESULT_PATH"
rm -f "$LIVE_PROGRESS_PATH" "$ENGINE_PROGRESS_PATH" "$ENGINE_ERROR_PATH" "$CONVERSATION_ERROR_PATH" "$COMPILED_MODEL_ERROR_PATH" "$STATIC_INIT_PATH" "$PREFILL_RUN_ERROR_PATH" "$DECODE_RUN_ERROR_PATH" "$APPDELEGATE_AUDIT_PATH"
printf '%s\n' "$REQUEST_JSON" > "$REQUEST_PATH"

copy_smoke_summary() {
  "$DEVICETCL_BIN" device copy from \
    --timeout 60 \
    --device "$DEVICE_ID" \
    --domain-type appDataContainer \
    --domain-identifier "$APP_BUNDLE_ID" \
    --source "tmp/beacon-native-smoke-results.json" \
    --destination "$RESULT_PATH"
}

copy_smoke_request() {
  "$DEVICETCL_BIN" device copy to \
    --timeout 60 \
    --device "$DEVICE_ID" \
    --domain-type appDataContainer \
    --domain-identifier "$APP_BUNDLE_ID" \
    --source "$REQUEST_PATH" \
    --destination "tmp/beacon-native-smoke-request.json"
}

copy_optional_artifact() {
  local source_name="$1"
  local destination_path="$2"
  "$DEVICETCL_BIN" device copy from \
    --timeout 30 \
    --device "$DEVICE_ID" \
    --domain-type appDataContainer \
    --domain-identifier "$APP_BUNDLE_ID" \
    --source "tmp/${source_name}" \
    --destination "$destination_path" >/dev/null 2>&1 || true
}

echo "[ios_metal_smoke] Building Debug app for device $DEVICE_ID (runtime dispatch mode: $RUNTIME_DISPATCH_MODE, cache mode: $CACHE_MODE)"
xcodebuild \
  -project "$ROOT/ios/App/App.xcodeproj" \
  -scheme App \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$BUILD_DIR" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "[ios_metal_smoke] Expected app bundle missing: $APP_PATH" >&2
  exit 1
fi

echo "[ios_metal_smoke] Installing app onto device"
"$DEVICETCL_BIN" device install app \
  --timeout 180 \
  --device "$DEVICE_ID" \
  "$APP_PATH"

echo "[ios_metal_smoke] Uploading smoke request payload"
copy_smoke_request

echo "[ios_metal_smoke] Launching app with smoke env"
if ! launch_output="$(
  "$DEVICETCL_BIN" device process launch \
    --timeout 120 \
    --device "$DEVICE_ID" \
    --terminate-existing \
    --environment-variables "$ENV_JSON" \
    "$APP_BUNDLE_ID" \
    --beacon-smoke-test 2>&1
)"; then
  printf '%s\n' "$launch_output" >&2
  if printf '%s' "$launch_output" | grep -qi 'locked\|could not be unlocked'; then
    echo "[ios_metal_smoke] Device is connected but locked. Unlock the iPhone/iPad and rerun the smoke test." >&2
  fi
  exit 1
fi
printf '%s\n' "$launch_output"

echo "[ios_metal_smoke] Waiting for fresh smoke summary (trace token: $TRACE_TOKEN)"
fresh_summary=""
for _ in $(seq 1 60); do
  if copy_smoke_summary >/dev/null 2>&1; then
    if [[ -f "$RESULT_PATH" ]] \
      && grep -q "\"traceToken\" : \"$TRACE_TOKEN\"" "$RESULT_PATH" \
      && grep -q '"generatedAt"' "$RESULT_PATH"; then
      fresh_summary="yes"
      break
    fi
  fi
  sleep 5
done

if [[ "$fresh_summary" != "yes" ]]; then
  echo "[ios_metal_smoke] Failed to capture a fresh smoke summary. Listing tmp/ for debugging..." >&2
  copy_optional_artifact "beacon-native-smoke-progress.json" "$LIVE_PROGRESS_PATH"
  copy_optional_artifact "beacon-litert-engine-progress.txt" "$ENGINE_PROGRESS_PATH"
  copy_optional_artifact "beacon-litert-engine-error.txt" "$ENGINE_ERROR_PATH"
  copy_optional_artifact "beacon-litert-conversation-error.txt" "$CONVERSATION_ERROR_PATH"
  copy_optional_artifact "beacon-litert-compiled-model-create-error.txt" "$COMPILED_MODEL_ERROR_PATH"
  copy_optional_artifact "beacon-litert-static-init.txt" "$STATIC_INIT_PATH"
  copy_optional_artifact "beacon-litert-prefill-run-error.txt" "$PREFILL_RUN_ERROR_PATH"
  copy_optional_artifact "beacon-litert-decode-run-error.txt" "$DECODE_RUN_ERROR_PATH"
  copy_optional_artifact "beacon-appdelegate-smoke-audit.json" "$APPDELEGATE_AUDIT_PATH"
  "$DEVICETCL_BIN" device info files \
    --timeout 30 \
    --device "$DEVICE_ID" \
    --domain-type appDataContainer \
    --domain-identifier "$APP_BUNDLE_ID" \
    --subdirectory tmp || true
  if [[ -f "$RESULT_PATH" ]]; then
    echo "[ios_metal_smoke] Last copied summary:" >&2
    cat "$RESULT_PATH" >&2
  fi
  exit 1
fi

if [[ ! -f "$RESULT_PATH" ]]; then
  echo "[ios_metal_smoke] Smoke summary file was not created at $RESULT_PATH" >&2
  exit 1
fi

echo "[ios_metal_smoke] Fresh smoke summary saved to $RESULT_PATH"
copy_optional_artifact "beacon-native-smoke-progress.json" "$LIVE_PROGRESS_PATH"
copy_optional_artifact "beacon-litert-engine-progress.txt" "$ENGINE_PROGRESS_PATH"
copy_optional_artifact "beacon-litert-engine-error.txt" "$ENGINE_ERROR_PATH"
copy_optional_artifact "beacon-litert-conversation-error.txt" "$CONVERSATION_ERROR_PATH"
copy_optional_artifact "beacon-litert-compiled-model-create-error.txt" "$COMPILED_MODEL_ERROR_PATH"
copy_optional_artifact "beacon-litert-static-init.txt" "$STATIC_INIT_PATH"
copy_optional_artifact "beacon-litert-prefill-run-error.txt" "$PREFILL_RUN_ERROR_PATH"
copy_optional_artifact "beacon-litert-decode-run-error.txt" "$DECODE_RUN_ERROR_PATH"
copy_optional_artifact "beacon-appdelegate-smoke-audit.json" "$APPDELEGATE_AUDIT_PATH"
cat "$RESULT_PATH"

EXPECT_OK="$EXPECT_OK" \
EXPECT_ACTIVE_BACKEND="$EXPECT_ACTIVE_BACKEND" \
EXPECT_CAPABILITY_CLASS="$EXPECT_CAPABILITY_CLASS" \
python3 - "$RESULT_PATH" <<'PY'
import json
import os
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

ok = payload.get("ok")
runtime = payload.get("runtimeDiagnostics") or {}
trace = payload.get("traceToken") or ""
checks = payload.get("checks") or []
failed_checks = [check.get("name", "unknown") for check in checks if not check.get("ok")]
gpu_failure = runtime.get("gpuFailureDetail") or runtime.get("lastEngineFailure") or ""
expected_ok = os.environ.get("EXPECT_OK", "1").lower() not in {"0", "false", "no"}
actual_ok = ok in (1, True, "1")
expected_backend = os.environ.get("EXPECT_ACTIVE_BACKEND", "").strip()
expected_capability = os.environ.get("EXPECT_CAPABILITY_CLASS", "").strip()
actual_backend = (runtime.get("activeBackend") or "").strip()
actual_capability = (runtime.get("capabilityClass") or "").strip()

mismatches = []
if actual_ok != expected_ok:
    mismatches.append(
        f"expected ok={expected_ok}, got ok={actual_ok}"
    )
if expected_backend and actual_backend != expected_backend:
    mismatches.append(
        f"expected activeBackend={expected_backend}, got {actual_backend or 'empty'}"
    )
if expected_capability and actual_capability != expected_capability:
    mismatches.append(
        f"expected capabilityClass={expected_capability}, got {actual_capability or 'empty'}"
    )

if not mismatches:
    raise SystemExit(0)

summary = "[ios_metal_smoke] Smoke summary reported failure"
if trace:
    summary += f" (trace token: {trace})"
if failed_checks:
    summary += f"; failed checks: {', '.join(failed_checks)}"
if gpu_failure:
    summary += f"; runtime: {gpu_failure}"
if mismatches:
    summary += f"; expectation mismatches: {'; '.join(mismatches)}"

print(summary, file=sys.stderr)
raise SystemExit(1)
PY
