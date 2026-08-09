#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${ROOT_DIR}/LocalDiffusion.xcodeproj"
SCHEME="${SCHEME:-LocalDiffusion}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-${ROOT_DIR}/DerivedData/SimulatorSmoke}"
DEVICE_ID="${DEVICE_ID:-}"
DEVICE_NAME="${DEVICE_NAME:-}"
BUNDLE_ID="${BUNDLE_ID:-com.example.LocalDiffusion}"
SCREENSHOT_PATH="${SCREENSHOT_PATH:-${ROOT_DIR}/DerivedData/localdiffusion-smoke.png}"

if [[ -z "${DEVELOPER_DIR:-}" ]] && [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

current_stage="environment"
failure_stage="none"
device_selection="auto"
device_id=""
device_name=""
app_path=""
build_status="NOT_RUN"
build_command_status="NOT_RUN"
app_status="NOT_RUN"
install_status="NOT_RUN"
install_command_status="NOT_RUN"
boot_status="NOT_RUN"
boot_command_status="NOT_RUN"
bootstatus_command_status="NOT_RUN"
launch_status="NOT_RUN"
launch_command_status="NOT_RUN"
screenshot_status="NOT_RUN"
screenshot_command_status="NOT_RUN"
screenshot_file_status="NOT_RUN"
png_readable_status="NOT_RUN"
screenshot_summary_status="NOT_RUN"
screenshot_format="unknown"
screenshot_bytes="unknown"
screenshot_width="unknown"
screenshot_height="unknown"

emit_summary() {
  local final_status="$1"
  local result="PASS"
  if [[ "${final_status}" -ne 0 ]]; then
    result="FAIL"
    if [[ "${failure_stage}" == "none" ]]; then
      failure_stage="${current_stage}"
    fi
  fi

  cat <<EOF
SMOKE_RESULT=${result}
SMOKE_FAILURE_STAGE=${failure_stage}
SMOKE_EXIT_CODE=${final_status}
SMOKE_DEVICE_SELECTION=${device_selection}
SMOKE_DEVICE_NAME=${device_name}
SMOKE_DEVICE_ID=${device_id}
SMOKE_BUNDLE_ID=${BUNDLE_ID}
SMOKE_APP_PATH=${app_path}
SMOKE_BUILD=${build_status}
SMOKE_BUILD_COMMAND_EXIT=${build_command_status}
SMOKE_APP_PRESENT=${app_status}
SMOKE_INSTALL=${install_status}
SMOKE_INSTALL_COMMAND_EXIT=${install_command_status}
SMOKE_BOOT=${boot_status}
SMOKE_BOOT_COMMAND_EXIT=${boot_command_status}
SMOKE_BOOTSTATUS_COMMAND_EXIT=${bootstatus_command_status}
SMOKE_LAUNCH=${launch_status}
SMOKE_LAUNCH_COMMAND_EXIT=${launch_command_status}
SMOKE_SCREENSHOT=${screenshot_status}
SMOKE_SCREENSHOT_COMMAND_EXIT=${screenshot_command_status}
SMOKE_SCREENSHOT_FILE=${screenshot_file_status}
SMOKE_PNG_READABLE=${png_readable_status}
SMOKE_SCREENSHOT_SUMMARY=${screenshot_summary_status}
SMOKE_SCREENSHOT_PATH=${SCREENSHOT_PATH}
SMOKE_SCREENSHOT_FORMAT=${screenshot_format}
SMOKE_SCREENSHOT_BYTES=${screenshot_bytes}
SMOKE_SCREENSHOT_WIDTH=${screenshot_width}
SMOKE_SCREENSHOT_HEIGHT=${screenshot_height}
SMOKE_EVIDENCE=simulator build/install/launch/screenshot plus PNG readability, file-size, and dimension checks only
EOF
}

fail_stage() {
  failure_stage="$1"
  local exit_code="$2"
  shift 2
  printf 'FAIL stage=%s exit=%s: %s\n' "${failure_stage}" "${exit_code}" "$*" >&2
  exit "${exit_code}"
}

trap 'status=$?; emit_summary "${status}"' EXIT

if ! command -v xcodebuild >/dev/null 2>&1; then
  fail_stage "environment-xcode" 69 "Full Xcode is required. Set DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer."
fi

set +e
xcode_version_output="$(xcodebuild -version 2>&1)"
xcode_version_status=$?
set -e
printf '%s\n' "${xcode_version_output}"
if [[ "${xcode_version_status}" -ne 0 ]]; then
  fail_stage "environment-xcode" 69 "xcodebuild -version failed with exit ${xcode_version_status}."
fi

current_stage="environment-coresimulator"
set +e
available_devices="$(xcrun simctl list devices available 2>&1)"
simctl_list_status=$?
set -e
printf '%s\n' "${available_devices}"
if [[ "${simctl_list_status}" -ne 0 ]]; then
  fail_stage "environment-coresimulator" 69 "simctl could not access CoreSimulator; command exit ${simctl_list_status}."
fi

current_stage="device-selection"
if [[ -n "${DEVICE_ID}" ]]; then
  device_selection="DEVICE_ID"
elif [[ -n "${DEVICE_NAME}" ]]; then
  device_selection="DEVICE_NAME"
fi

selected_device="$(
  printf '%s\n' "${available_devices}" |
    awk -v mode="${device_selection}" -v selector_id="${DEVICE_ID}" -v selector_name="${DEVICE_NAME}" '
      function trim(value) {
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        return value
      }
      {
        line = $0
        lower_line = tolower(line)
        if (index(lower_line, "ipad") == 0) {
          next
        }
        if (mode == "DEVICE_ID" && index(line, "(" selector_id ")") == 0) {
          next
        }
        if (mode == "DEVICE_NAME" && index(line, selector_name) == 0) {
          next
        }
        if (match(line, /\([[:xdigit:]-]{36}\)/) == 0) {
          next
        }
        uuid = substr(line, RSTART + 1, RLENGTH - 2)
        name = trim(substr(line, 1, RSTART - 1))
        print uuid "\t" name
        exit
      }
    '
)"

if [[ -z "${selected_device}" ]]; then
  if [[ "${device_selection}" == "DEVICE_ID" ]]; then
    fail_stage "device-selection" 66 "DEVICE_ID='${DEVICE_ID}' did not identify an available iPad simulator."
  elif [[ "${device_selection}" == "DEVICE_NAME" ]]; then
    fail_stage "device-selection" 66 "DEVICE_NAME='${DEVICE_NAME}' did not identify an available iPad simulator."
  else
    fail_stage "device-selection" 66 "No available iPad simulator was found; the smoke test will not fall back to iPhone."
  fi
fi

IFS=$'\t' read -r device_id device_name <<< "${selected_device}"
printf 'Selected iPad simulator: name=%s id=%s selection=%s\n' "${device_name}" "${device_id}" "${device_selection}"

app_path="${DERIVED_DATA}/Build/Products/${CONFIGURATION}-iphonesimulator/${SCHEME}.app"
current_stage="simulator-build"
set +e
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "${DERIVED_DATA}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY= \
  build
build_command_status=$?
set -e
if [[ "${build_command_status}" -ne 0 ]]; then
  build_status="FAIL"
  fail_stage "simulator-build" 70 "xcodebuild simulator build failed with exit ${build_command_status}."
fi
build_status="PASS"

current_stage="app-artifact"
if [[ ! -d "${app_path}" ]]; then
  app_status="FAIL"
  fail_stage "app-artifact" 71 "Built app was not found at ${app_path}."
fi
app_status="PASS"

current_stage="boot"
set +e
boot_output="$(xcrun simctl boot "${device_id}" 2>&1)"
boot_command_status=$?
set -e
printf '%s\n' "${boot_output}"

set +e
bootstatus_output="$(xcrun simctl bootstatus "${device_id}" -b 2>&1)"
bootstatus_command_status=$?
set -e
printf '%s\n' "${bootstatus_output}"
if [[ "${bootstatus_command_status}" -ne 0 ]]; then
  boot_status="FAIL"
  fail_stage "boot" 73 "simctl boot/bootstatus failed; boot exit ${boot_command_status}, bootstatus exit ${bootstatus_command_status}."
fi
boot_status="PASS"

current_stage="install"
set +e
xcrun simctl install "${device_id}" "${app_path}"
install_command_status=$?
set -e
if [[ "${install_command_status}" -ne 0 ]]; then
  install_status="FAIL"
  fail_stage "install" 72 "simctl install failed with exit ${install_command_status}."
fi
install_status="PASS"

current_stage="launch"
set +e
launch_output="$(xcrun simctl launch "${device_id}" "${BUNDLE_ID}" 2>&1)"
launch_command_status=$?
set -e
printf '%s\n' "${launch_output}"
if [[ "${launch_command_status}" -ne 0 ]]; then
  launch_status="FAIL"
  fail_stage "launch" 74 "simctl launch failed with exit ${launch_command_status}."
fi
launch_status="PASS"

current_stage="screenshot"
if ! mkdir -p "$(dirname "${SCREENSHOT_PATH}")"; then
  screenshot_status="FAIL"
  fail_stage "screenshot" 75 "Could not create screenshot directory for ${SCREENSHOT_PATH}."
fi
set +e
xcrun simctl io "${device_id}" screenshot "${SCREENSHOT_PATH}"
screenshot_command_status=$?
set -e
if [[ "${screenshot_command_status}" -ne 0 ]]; then
  screenshot_status="FAIL"
  fail_stage "screenshot" 75 "simctl screenshot failed with exit ${screenshot_command_status}."
fi
screenshot_status="PASS"

current_stage="screenshot-file"
if [[ ! -f "${SCREENSHOT_PATH}" ]]; then
  screenshot_file_status="FAIL"
  fail_stage "screenshot-file" 76 "Screenshot file was not created at ${SCREENSHOT_PATH}."
fi
screenshot_bytes="$(wc -c < "${SCREENSHOT_PATH}" | tr -d '[:space:]')"
if [[ ! "${screenshot_bytes}" =~ ^[1-9][0-9]*$ ]]; then
  screenshot_file_status="FAIL"
  fail_stage "screenshot-file" 76 "Screenshot file is empty or has an invalid byte count: ${screenshot_bytes}."
fi
screenshot_file_status="PASS"

current_stage="screenshot-summary"
set +e
screenshot_metadata="$(sips -g format -g pixelWidth -g pixelHeight "${SCREENSHOT_PATH}" 2>&1)"
sips_status=$?
set -e
printf '%s\n' "${screenshot_metadata}"
if [[ "${sips_status}" -ne 0 ]]; then
  png_readable_status="FAIL"
  fail_stage "screenshot-summary" 77 "sips could not read the screenshot as an image; exit ${sips_status}."
fi

screenshot_format="$(printf '%s\n' "${screenshot_metadata}" | awk -F': *' '$1 ~ /^[[:space:]]*format[[:space:]]*$/ {print tolower($2); exit}')"
screenshot_width="$(printf '%s\n' "${screenshot_metadata}" | awk -F': *' '$1 ~ /^[[:space:]]*pixelWidth[[:space:]]*$/ {print $2; exit}')"
screenshot_height="$(printf '%s\n' "${screenshot_metadata}" | awk -F': *' '$1 ~ /^[[:space:]]*pixelHeight[[:space:]]*$/ {print $2; exit}')"
if [[ "${screenshot_format}" != "png" || ! "${screenshot_width}" =~ ^[1-9][0-9]*$ || ! "${screenshot_height}" =~ ^[1-9][0-9]*$ ]]; then
  png_readable_status="FAIL"
  fail_stage "screenshot-summary" 77 "PNG metadata is invalid: format=${screenshot_format}, width=${screenshot_width}, height=${screenshot_height}."
fi
png_readable_status="PASS"
screenshot_summary_status="PASS"

printf 'Simulator smoke completed for iPad %s (%s), bundle=%s, screenshot=%s, bytes=%s, size=%sx%s.\n' \
  "${device_name}" "${device_id}" "${BUNDLE_ID}" "${SCREENSHOT_PATH}" "${screenshot_bytes}" "${screenshot_width}" "${screenshot_height}"
