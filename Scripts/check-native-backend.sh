#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCFRAMEWORK="${1:-${ROOT_DIR}/LocalDiffusion/Frameworks/LocalDiffusionNative.xcframework}"
PROJECT_FILE="${ROOT_DIR}/LocalDiffusion.xcodeproj/project.pbxproj"
NATIVE_XCCONFIG="${ROOT_DIR}/LocalDiffusion/Config/NativeBackend.xcconfig"
BRIDGING_HEADER="${ROOT_DIR}/LocalDiffusion/App/LocalDiffusion-Bridging-Header.h"
SWIFT_BACKEND="${ROOT_DIR}/LocalDiffusion/Inference/ImageGenerationBackend.swift"

failures=0

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

if [[ -d "${XCFRAMEWORK}" ]]; then
  pass "XCFramework exists at ${XCFRAMEWORK}"
else
  fail "XCFramework is missing at ${XCFRAMEWORK}"
fi

if [[ -f "${XCFRAMEWORK}/Info.plist" ]]; then
  pass "XCFramework Info.plist exists"
else
  fail "XCFramework Info.plist is missing"
fi

header_count="$(find "${XCFRAMEWORK}" -name NativeStableDiffusionBridge.h -type f 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${header_count}" != "0" ]]; then
  pass "NativeStableDiffusionBridge.h is packaged in the XCFramework"
else
  fail "NativeStableDiffusionBridge.h is not packaged in the XCFramework"
fi

if [[ -f "${BRIDGING_HEADER}" ]] && grep -q "NativeStableDiffusionBridge.h" "${BRIDGING_HEADER}"; then
  pass "App bridging header imports NativeStableDiffusionBridge.h"
else
  fail "App bridging header does not import NativeStableDiffusionBridge.h"
fi

if [[ -f "${SWIFT_BACKEND}" ]] && grep -q "USE_STABLE_DIFFUSION_CPP" "${SWIFT_BACKEND}"; then
  pass "Swift backend has a USE_STABLE_DIFFUSION_CPP native path"
else
  fail "Swift backend does not expose a USE_STABLE_DIFFUSION_CPP native path"
fi

native_xcconfig_enabled=0
if [[ -f "${PROJECT_FILE}" ]] && grep -q "baseConfigurationReference = .*NativeBackend.xcconfig" "${PROJECT_FILE}"; then
  native_xcconfig_enabled=1
fi

native_xcframework_linked=0
if [[ -f "${PROJECT_FILE}" ]] && grep -q "LocalDiffusionNative.xcframework in Frameworks" "${PROJECT_FILE}"; then
  native_xcframework_linked=1
fi

if [[ "${native_xcframework_linked}" == "1" ]]; then
  pass "Xcode target links LocalDiffusionNative.xcframework in the Frameworks build phase"
else
  fail "Xcode target does not link LocalDiffusionNative.xcframework; run ./Scripts/enable-native-backend.sh"
fi

if [[ -f "${PROJECT_FILE}" ]] && grep -q "USE_STABLE_DIFFUSION_CPP" "${PROJECT_FILE}"; then
  pass "Xcode project defines USE_STABLE_DIFFUSION_CPP"
elif [[ "${native_xcconfig_enabled}" == "1" ]] && [[ -f "${NATIVE_XCCONFIG}" ]] && grep -q "USE_STABLE_DIFFUSION_CPP" "${NATIVE_XCCONFIG}"; then
  pass "Xcode project build configurations include native xcconfig with USE_STABLE_DIFFUSION_CPP"
else
  fail "Xcode project build configurations do not include USE_STABLE_DIFFUSION_CPP; run ./Scripts/enable-native-backend.sh"
fi

if command -v xcrun >/dev/null 2>&1; then
  found_generate_symbol=0
  found_free_symbol=0
  simulator_has_arm64=0
  simulator_has_x86_64=0

  while IFS= read -r archive; do
    symbol_output="$(mktemp)"
    if xcrun nm -gU "${archive}" >"${symbol_output}" 2>/dev/null && grep -q "_ldi_sd_generate_png" "${symbol_output}"; then
      found_generate_symbol=1
    fi
    if grep -q "_ldi_sd_free_result" "${symbol_output}"; then
      found_free_symbol=1
    fi
    rm -f "${symbol_output}"

    if [[ "${archive}" == *simulator* ]]; then
      lipo_output="$(xcrun lipo -info "${archive}" 2>/dev/null || true)"
      if [[ "${lipo_output}" == *"arm64"* ]]; then
        simulator_has_arm64=1
      fi
      if [[ "${lipo_output}" == *"x86_64"* ]]; then
        simulator_has_x86_64=1
      fi
    fi
  done < <(find "${XCFRAMEWORK}" -name '*.a' -type f 2>/dev/null)

  if [[ "${found_generate_symbol}" == "1" ]]; then
    pass "Native archive exports ldi_sd_generate_png"
  else
    fail "Native archive does not export ldi_sd_generate_png"
  fi

  if [[ "${found_free_symbol}" == "1" ]]; then
    pass "Native archive exports ldi_sd_free_result"
  else
    fail "Native archive does not export ldi_sd_free_result"
  fi

  if [[ "${simulator_has_arm64}" == "1" ]] && [[ "${simulator_has_x86_64}" == "1" ]]; then
    pass "Simulator native archive includes arm64 and x86_64"
  else
    fail "Simulator native archive must include both arm64 and x86_64"
  fi
else
  fail "xcrun is unavailable, so native archive symbols could not be checked"
fi

if [[ "${failures}" == "0" ]]; then
  echo "Native backend preflight passed."
  exit 0
fi

echo "Native backend preflight failed with ${failures} issue(s)."
echo "Install or refresh the native backend with:"
echo "  ./Scripts/install-native-backend.sh /path/to/stable-diffusion.cpp"
exit 1
