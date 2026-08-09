#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d /private/tmp/localdiffusion-video-native-provenance.XXXXXX)"
trap 'rm -rf "${fixture_root}"' EXIT

cat > "${fixture_root}/symbol-only.json" <<'JSON'
{
  "schema": "localdiffusion.video-native-dependency",
  "schemaVersion": 1,
  "engine": {"name": "unknown", "source": "fixture", "revision": "unknown"},
  "nativeAsset": {"assetName": "fixture"},
  "publicABI": {"videoHeader": {"path": null}, "appBridge": {"path": null}, "signatureEvidence": "missing"},
  "model": {"family": "unknown", "components": [], "version": "unknown", "compatibility": "missing"},
  "license": {"spdx": "unknown", "provenance": "missing", "source": "unknown"},
  "observedSymbols": [{"symbol": "_generate_video", "status": "observed-only"}]
}
JSON
printf '%s\n' '_generate_video' '_sd_ctx_supports_video_generation' 'LTX' 'WAN' > "${fixture_root}/symbols.txt"

set +e
VIDEO_NATIVE_MANIFEST="${fixture_root}/symbol-only.json" \
VIDEO_NATIVE_SYMBOLS_FILE="${fixture_root}/symbols.txt" \
VIDEO_NATIVE_REPORT="${fixture_root}/symbol-only-report.json" \
  "${repo_root}/Scripts/check-video-native-dependency.sh"
symbol_only_status=$?
set -e
[[ "${symbol_only_status}" -eq 1 ]]
python3 - "${fixture_root}/symbol-only-report.json" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["gate"]["status"] == "dependency-blocked"
assert report["observedSymbolsAreABI"] is False
assert "public-abi-evidence-missing" in report["gate"]["reasons"]
assert report["evidence"]["nativeCallsMade"] is False
PY

printf '%s\n' '{"schema":"wrong","schemaVersion":99}' > "${fixture_root}/invalid.json"
set +e
VIDEO_NATIVE_MANIFEST="${fixture_root}/invalid.json" \
VIDEO_NATIVE_REPORT="${fixture_root}/invalid-report.json" \
  "${repo_root}/Scripts/check-video-native-dependency.sh"
invalid_status=$?
set -e
[[ "${invalid_status}" -eq 1 ]]
python3 - "${fixture_root}/invalid-report.json" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["gate"]["status"] == "dependency-blocked"
assert "manifest-invalid" in report["gate"]["reasons"]
PY

echo "Video native provenance probe passed: symbol-only and incomplete manifest gates remain blocked."
