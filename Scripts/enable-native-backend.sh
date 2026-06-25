#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="${PROJECT_FILE:-${ROOT_DIR}/LocalDiffusion.xcodeproj/project.pbxproj}"
NATIVE_XCCONFIG_PATH="LocalDiffusion/Config/NativeBackend.xcconfig"
NATIVE_XCCONFIG_ABSOLUTE="${ROOT_DIR}/${NATIVE_XCCONFIG_PATH}"
NATIVE_XCCONFIG_ID="9B0000010000000000000015"
NATIVE_XCFRAMEWORK_PATH="LocalDiffusion/Frameworks/LocalDiffusionNative.xcframework"
NATIVE_XCFRAMEWORK_ABSOLUTE="${ROOT_DIR}/${NATIVE_XCFRAMEWORK_PATH}"
NATIVE_XCFRAMEWORK_ID="9B000001000000000000001D"
NATIVE_XCFRAMEWORK_BUILD_ID="9B0000010000000000000113"

if [[ ! -f "${PROJECT_FILE}" ]]; then
  echo "Project file not found at ${PROJECT_FILE}"
  exit 66
fi

if [[ ! -f "${NATIVE_XCCONFIG_ABSOLUTE}" ]]; then
  echo "Native backend xcconfig not found at ${NATIVE_XCCONFIG_ABSOLUTE}"
  exit 66
fi

if [[ ! -d "${NATIVE_XCFRAMEWORK_ABSOLUTE}" ]]; then
  echo "Native backend XCFramework not found at ${NATIVE_XCFRAMEWORK_ABSOLUTE}"
  echo "Run ./Scripts/install-native-backend.sh /path/to/stable-diffusion.cpp first."
  exit 66
fi

if ! grep -q "NativeBackend.xcconfig" "${PROJECT_FILE}"; then
  perl -0pi -e 's!(\t\t9B0000010000000000000014 /\* NativeStableDiffusionBridge.h \*/ = \{[^\n]+\};\n)!$1\t\t9B0000010000000000000015 /* NativeBackend.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Config/NativeBackend.xcconfig; sourceTree = "<group>"; };\n!' "${PROJECT_FILE}"
  perl -0pi -e 's!(\t\t9B0000010000000000000410 /\* LocalDiffusion \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)!$1\t\t\t\t9B0000010000000000000015 /* NativeBackend.xcconfig */,\n!' "${PROJECT_FILE}"
fi

if ! grep -q "LocalDiffusionNative.xcframework" "${PROJECT_FILE}"; then
  perl -0pi -e 's!(\t\t9B0000010000000000000112 /\* PromptLibraryView.swift in Sources \*/ = \{[^\n]+\};\n)!$1\t\t9B0000010000000000000113 /* LocalDiffusionNative.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = 9B000001000000000000001D /* LocalDiffusionNative.xcframework */; };\n!' "${PROJECT_FILE}"
  perl -0pi -e 's!(\t\t9B0000010000000000000016 /\* \.gitkeep \*/ = \{[^\n]+\};\n)!$1\t\t9B000001000000000000001D /* LocalDiffusionNative.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = LocalDiffusionNative.xcframework; sourceTree = "<group>"; };\n!' "${PROJECT_FILE}"
  perl -0pi -e 's!(\t\t9B0000010000000000000300 /\* Frameworks \*/ = \{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = \(\n)!$1\t\t\t\t9B0000010000000000000113 /* LocalDiffusionNative.xcframework in Frameworks */,\n!' "${PROJECT_FILE}"
  perl -0pi -e 's!(\t\t9B0000010000000000000422 /\* Frameworks \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n\t\t\t\t9B0000010000000000000016 /\* \.gitkeep \*/,\n)!$1\t\t\t\t9B000001000000000000001D /* LocalDiffusionNative.xcframework */,\n!' "${PROJECT_FILE}"
fi

if grep -q "LocalDiffusionNative.xcframework" "${PROJECT_FILE}" && ! grep -q "LocalDiffusionNative.xcframework in Frameworks" "${PROJECT_FILE}"; then
  perl -0pi -e 's!(\t\t9B0000010000000000000112 /\* PromptLibraryView.swift in Sources \*/ = \{[^\n]+\};\n)!$1\t\t9B0000010000000000000113 /* LocalDiffusionNative.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = 9B000001000000000000001D /* LocalDiffusionNative.xcframework */; };\n!' "${PROJECT_FILE}"
  perl -0pi -e 's!(\t\t9B0000010000000000000300 /\* Frameworks \*/ = \{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = \(\n)!$1\t\t\t\t9B0000010000000000000113 /* LocalDiffusionNative.xcframework in Frameworks */,\n!' "${PROJECT_FILE}"
fi

if ! grep -A3 "9B0000010000000000000901 /\* Debug \*/" "${PROJECT_FILE}" | grep -q "baseConfigurationReference"; then
  perl -0pi -e 's!(\t\t9B0000010000000000000901 /\* Debug \*/ = \{\n\t\t\tisa = XCBuildConfiguration;\n)!$1\t\t\tbaseConfigurationReference = 9B0000010000000000000015 /* NativeBackend.xcconfig */;\n!' "${PROJECT_FILE}"
fi

if ! grep -A3 "9B0000010000000000000902 /\* Release \*/" "${PROJECT_FILE}" | grep -q "baseConfigurationReference"; then
  perl -0pi -e 's!(\t\t9B0000010000000000000902 /\* Release \*/ = \{\n\t\t\tisa = XCBuildConfiguration;\n)!$1\t\t\tbaseConfigurationReference = 9B0000010000000000000015 /* NativeBackend.xcconfig */;\n!' "${PROJECT_FILE}"
fi

if ! plutil -lint "${PROJECT_FILE}" >/dev/null; then
  echo "Project file was modified but is not a valid plist."
  exit 70
fi

echo "Enabled native backend xcconfig and XCFramework linkage for the LocalDiffusion target."
echo "Run ./Scripts/check-native-backend.sh after installing LocalDiffusionNative.xcframework."
