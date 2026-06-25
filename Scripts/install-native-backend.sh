#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/stable-diffusion.cpp [LocalDiffusion/Frameworks/LocalDiffusionNative.xcframework]"
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STABLE_DIFFUSION_CPP_DIR="$1"
OUTPUT_XCFRAMEWORK="${2:-${ROOT_DIR}/LocalDiffusion/Frameworks/LocalDiffusionNative.xcframework}"
EXPECTED_XCFRAMEWORK="${ROOT_DIR}/LocalDiffusion/Frameworks/LocalDiffusionNative.xcframework"
BUILD_SCRIPT="${ROOT_DIR}/Scripts/build-stable-diffusion-xcframework.sh"
ENABLE_SCRIPT="${ROOT_DIR}/Scripts/enable-native-backend.sh"
BRIDGE_HEADER="${ROOT_DIR}/LocalDiffusion/Inference/NativeStableDiffusionBridge.h"

"${BUILD_SCRIPT}" "${STABLE_DIFFUSION_CPP_DIR}" "${OUTPUT_XCFRAMEWORK}"

if [[ ! -d "${OUTPUT_XCFRAMEWORK}" ]]; then
  echo "Expected XCFramework was not created at ${OUTPUT_XCFRAMEWORK}"
  exit 70
fi

if ! find "${OUTPUT_XCFRAMEWORK}" -name NativeStableDiffusionBridge.h -type f | grep -q .; then
  echo "NativeStableDiffusionBridge.h is missing from ${OUTPUT_XCFRAMEWORK}"
  exit 70
fi

if ! grep -q "ldi_sd_generate_png" "${BRIDGE_HEADER}" || ! grep -q "ldi_sd_free_result" "${BRIDGE_HEADER}"; then
  echo "Bridge header does not expose the expected native generation symbols"
  exit 70
fi

canonical_path() {
  local path="$1"
  local dir
  dir="$(cd "$(dirname "${path}")" && pwd -P)"
  printf "%s/%s\n" "${dir}" "$(basename "${path}")"
}

if [[ "$(canonical_path "${OUTPUT_XCFRAMEWORK}")" == "$(canonical_path "${EXPECTED_XCFRAMEWORK}")" ]]; then
  "${ENABLE_SCRIPT}"
  cat <<EOF
Installed and enabled native backend:
  ${OUTPUT_XCFRAMEWORK}

Next steps:
  1. Run ./Scripts/check-native-backend.sh.
  2. Build a device target and run generation with a local GGUF model.
EOF
else
cat <<EOF
Installed native backend:
  ${OUTPUT_XCFRAMEWORK}

Custom output path was used. To enable the app target, install the XCFramework at:
  ${EXPECTED_XCFRAMEWORK}

Then run:
  ./Scripts/enable-native-backend.sh
  ./Scripts/check-native-backend.sh
EOF
fi
