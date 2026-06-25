#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${ROOT_DIR}/LocalDiffusion.xcodeproj"
SCHEME="${SCHEME:-LocalDiffusion}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-${ROOT_DIR}/DerivedData/SimulatorSmoke}"
DEVICE_NAME="${DEVICE_NAME:-iPhone 17}"
BUNDLE_ID="${BUNDLE_ID:-com.example.LocalDiffusion}"
SCREENSHOT_PATH="${SCREENSHOT_PATH:-${ROOT_DIR}/DerivedData/localdiffusion-smoke.png}"

if [[ -z "${DEVELOPER_DIR:-}" ]] && [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode is required. Set DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer."
  exit 69
fi

if ! xcrun simctl list devices available >/dev/null 2>&1; then
  echo "simctl could not access CoreSimulator. Make sure Simulator services are available."
  exit 69
fi

device_id="${DEVICE_ID:-}"
if [[ -z "${device_id}" ]]; then
  device_id="$(
    xcrun simctl list devices available |
      awk -v name="${DEVICE_NAME}" '$0 ~ name && $0 ~ /\([0-9A-F-]{36}\)/ {
        match($0, /\([0-9A-F-]{36}\)/)
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
      }'
  )"
fi

if [[ -z "${device_id}" ]]; then
  echo "No available simulator matched DEVICE_NAME='${DEVICE_NAME}'."
  echo "Set DEVICE_ID to a simulator UUID or DEVICE_NAME to another available device."
  exit 66
fi

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

app_path="${DERIVED_DATA}/Build/Products/${CONFIGURATION}-iphonesimulator/${SCHEME}.app"
if [[ ! -d "${app_path}" ]]; then
  echo "Built app was not found at ${app_path}"
  exit 70
fi

xcrun simctl boot "${device_id}" 2>/dev/null || true
xcrun simctl bootstatus "${device_id}" -b
xcrun simctl install "${device_id}" "${app_path}"
xcrun simctl launch "${device_id}" "${BUNDLE_ID}"
mkdir -p "$(dirname "${SCREENSHOT_PATH}")"
xcrun simctl io "${device_id}" screenshot "${SCREENSHOT_PATH}"

echo "Simulator smoke test launched ${BUNDLE_ID} on ${device_id}."
echo "Screenshot: ${SCREENSHOT_PATH}"
