#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 /path/to/stable-diffusion.cpp /path/to/output/LocalDiffusionNative.xcframework"
  exit 64
fi

STABLE_DIFFUSION_CPP_DIR="$(cd "$1" && pwd)"
OUTPUT_XCFRAMEWORK="$2"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/NativeBackend/Build"
BRIDGE_SOURCE="${ROOT_DIR}/NativeBackend/StableDiffusionCpp/StableDiffusionCppBridge.mm"
BRIDGE_HEADER="${ROOT_DIR}/LocalDiffusion/Inference/NativeStableDiffusionBridge.h"
IPHONEOS_MIN_VERSION="${IPHONEOS_MIN_VERSION:-17.0}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_JOBS="${BUILD_JOBS:-}"
DEVICE_ARCHITECTURES="${DEVICE_ARCHITECTURES:-arm64}"
SIMULATOR_ARCHITECTURES="${SIMULATOR_ARCHITECTURES:-arm64 x86_64}"

if [[ -z "${DEVELOPER_DIR:-}" ]] && ! xcodebuild -version >/dev/null 2>&1; then
  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  fi
fi

if [[ ! -f "${STABLE_DIFFUSION_CPP_DIR}/include/stable-diffusion.h" ]]; then
  echo "stable-diffusion.h was not found under ${STABLE_DIFFUSION_CPP_DIR}/include"
  exit 66
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake is required to build stable-diffusion.cpp. Install it with Homebrew or your package manager."
  echo "Example: brew install cmake"
  exit 69
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode is required to create the iOS XCFramework."
  echo "Set DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer or switch xcode-select to Xcode.app."
  exit 69
fi

if ! xcrun --find clang++ >/dev/null 2>&1; then
  echo "Xcode command line tools are required"
  exit 69
fi

if [[ -z "${BUILD_JOBS}" ]]; then
  if BUILD_JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null)" && [[ "${BUILD_JOBS}" =~ ^[0-9]+$ ]] && [[ "${BUILD_JOBS}" -gt 0 ]]; then
    :
  else
    BUILD_JOBS=4
  fi
fi

prepare_makefile_output_directories() {
  local cmake_build_dir="$1"

  while IFS= read -r build_make; do
    while IFS= read -r output_path; do
      mkdir -p "${cmake_build_dir}/$(dirname "${output_path}")"
    done < <(
      sed -nE 's/.*[[:space:]]-(o|MF)[[:space:]](CMakeFiles\/[^[:space:]]+).*/\2/p' "${build_make}" | sort -u
    )
  done < <(find "${cmake_build_dir}/CMakeFiles" -name build.make -type f 2>/dev/null)
}

configure_and_build_platform() {
  local sdk_name="$1"
  local architectures="$2"
  local cmake_architectures="$3"
  local platform_build_dir="${BUILD_DIR}/${sdk_name}"
  local library_output="${platform_build_dir}/libLocalDiffusionNative.a"
  local minimum_version_flag="-miphoneos-version-min=${IPHONEOS_MIN_VERSION}"
  local sdk_path
  local cc_path
  local cxx_path
  local ar_path
  local ranlib_path
  sdk_path="$(xcrun --sdk "${sdk_name}" --show-sdk-path)"
  cc_path="$(xcrun --sdk "${sdk_name}" --find clang)"
  cxx_path="$(xcrun --sdk "${sdk_name}" --find clang++)"
  ar_path="$(xcrun --sdk "${sdk_name}" --find ar)"
  ranlib_path="$(xcrun --sdk "${sdk_name}" --find ranlib)"

  if [[ "${sdk_name}" == "iphonesimulator" ]]; then
    minimum_version_flag="-mios-simulator-version-min=${IPHONEOS_MIN_VERSION}"
  fi

  cmake -S "${STABLE_DIFFUSION_CPP_DIR}" -B "${platform_build_dir}/stable-diffusion.cpp" \
    -G "Unix Makefiles" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_C_COMPILER="${cc_path}" \
    -DCMAKE_CXX_COMPILER="${cxx_path}" \
    -DCMAKE_AR="${ar_path}" \
    -DCMAKE_RANLIB="${ranlib_path}" \
    -DCMAKE_OSX_SYSROOT="${sdk_path}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${IPHONEOS_MIN_VERSION}" \
    -DCMAKE_OSX_ARCHITECTURES="${cmake_architectures}" \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DBUILD_SHARED_LIBS=OFF \
    -DSD_BUILD_SHARED_LIBS=OFF \
    -DSD_BUILD_EXAMPLES=OFF \
    -DSD_WEBP=OFF \
    -DSD_WEBM=OFF \
    -DSD_METAL=ON \
    -DGGML_METAL=ON \
    -DGGML_NATIVE=OFF \
    ${EXTRA_CMAKE_FLAGS:-}

  prepare_makefile_output_directories "${platform_build_dir}/stable-diffusion.cpp"
  cmake --build "${platform_build_dir}/stable-diffusion.cpp" --config "${CONFIGURATION}" --parallel "${BUILD_JOBS}"

  local arch_flags=()
  for architecture in ${architectures}; do
    arch_flags+=("-arch" "${architecture}")
  done

  xcrun --sdk "${sdk_name}" clang++ \
    -std=c++17 \
    -fobjc-arc \
    -fmodules \
    -isysroot "${sdk_path}" \
    "${minimum_version_flag}" \
    "${arch_flags[@]}" \
    -I"${STABLE_DIFFUSION_CPP_DIR}/include" \
    -I"${ROOT_DIR}/LocalDiffusion/Inference" \
    -c "${BRIDGE_SOURCE}" \
    -o "${platform_build_dir}/StableDiffusionCppBridge.o"

  local archives=()
  while IFS= read -r archive; do
    archives+=("${archive}")
  done < <(find "${platform_build_dir}/stable-diffusion.cpp" -name '*.a' -type f)

  if [[ ${#archives[@]} -eq 0 ]]; then
    echo "No static libraries were produced for ${sdk_name}"
    exit 70
  fi

  xcrun libtool -static \
    -o "${library_output}" \
    "${platform_build_dir}/StableDiffusionCppBridge.o" \
    "${archives[@]}"

  mkdir -p "${platform_build_dir}/Headers"
  cp "${BRIDGE_HEADER}" "${platform_build_dir}/Headers/NativeStableDiffusionBridge.h"
}

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

configure_and_build_platform "iphoneos" "${DEVICE_ARCHITECTURES}" "${DEVICE_ARCHITECTURES// /;}"
configure_and_build_platform "iphonesimulator" "${SIMULATOR_ARCHITECTURES}" "${SIMULATOR_ARCHITECTURES// /;}"

rm -rf "${OUTPUT_XCFRAMEWORK}"
xcodebuild -create-xcframework \
  -library "${BUILD_DIR}/iphoneos/libLocalDiffusionNative.a" \
  -headers "${BUILD_DIR}/iphoneos/Headers" \
  -library "${BUILD_DIR}/iphonesimulator/libLocalDiffusionNative.a" \
  -headers "${BUILD_DIR}/iphonesimulator/Headers" \
  -output "${OUTPUT_XCFRAMEWORK}"

found_generate_symbol=0
found_free_symbol=0
while IFS= read -r archive; do
  symbol_output="$(mktemp)"
  if xcrun nm -gU "${archive}" >"${symbol_output}" 2>/dev/null && grep -q "_ldi_sd_generate_png" "${symbol_output}"; then
    found_generate_symbol=1
  fi
  if grep -q "_ldi_sd_free_result" "${symbol_output}"; then
    found_free_symbol=1
  fi
  rm -f "${symbol_output}"
done < <(find "${OUTPUT_XCFRAMEWORK}" -name '*.a' -type f)

if [[ "${found_generate_symbol}" != "1" ]] || [[ "${found_free_symbol}" != "1" ]]; then
  echo "Generated XCFramework does not export the expected LocalDiffusion C bridge symbols."
  echo "Expected _ldi_sd_generate_png and _ldi_sd_free_result in at least one static archive."
  exit 70
fi

echo "Created ${OUTPUT_XCFRAMEWORK}"
echo "Run ./Scripts/enable-native-backend.sh, then ./Scripts/check-native-backend.sh."
