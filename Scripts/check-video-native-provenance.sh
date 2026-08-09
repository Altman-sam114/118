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

cat > "${fixture_root}/absolute-evidence.json" <<'JSON'
{
  "schema": "localdiffusion.video-native-dependency",
  "schemaVersion": 1,
  "engine": {"name": "fixture", "source": "fixture", "revision": "fixture", "sourceEvidencePath": "/tmp/source", "revisionEvidencePath": "/tmp/revision"},
  "nativeAsset": {"identityEvidence": "/tmp/asset"},
  "publicABI": {"videoHeader": {"path": "/tmp/header"}, "appBridge": {"path": "/tmp/bridge"}, "swiftContract": {"path": "/tmp/contract"}, "signatureEvidence": {"path": "/tmp/signature", "status": "verified"}},
  "model": {"family": "fixture", "components": ["component"], "version": "1", "compatibilityManifest": {"path": "/tmp/compat"}, "compatibility": "verified", "provenanceEvidencePath": "/tmp/model"},
  "license": {"spdx": "MIT", "provenance": "fixture", "source": "fixture", "provenanceEvidencePath": "/tmp/license", "sourceEvidencePath": "/tmp/license-source"},
  "observedSymbols": []
}
JSON

cat > "${fixture_root}/escape-evidence.json" <<'JSON'
{
  "schema": "localdiffusion.video-native-dependency",
  "schemaVersion": 1,
  "engine": {"name": "fixture", "source": "fixture", "revision": "fixture", "sourceEvidencePath": "../source", "revisionEvidencePath": "evidence/../../revision"},
  "nativeAsset": {"identityEvidence": "asset/../identity"},
  "publicABI": {"videoHeader": {"path": "../header"}, "appBridge": {"path": "bridge/../../bridge"}, "swiftContract": {"path": "contract/../contract"}, "signatureEvidence": {"path": "signature/../signature", "status": "verified"}},
  "model": {"family": "fixture", "components": ["component"], "version": "1", "compatibilityManifest": {"path": "model/../compat"}, "compatibility": "verified", "provenanceEvidencePath": "model/../../provenance"},
  "license": {"spdx": "MIT", "provenance": "fixture", "source": "fixture", "provenanceEvidencePath": "license/../license", "sourceEvidencePath": "license/../../source"},
  "observedSymbols": []
}
JSON

cat > "${fixture_root}/fake-evidence.json" <<'JSON'
{
  "schema": "localdiffusion.video-native-dependency",
  "schemaVersion": 1,
  "engine": {"name": "fixture", "source": "made-up", "revision": "made-up", "sourceEvidencePath": "missing/source.txt", "revisionEvidencePath": "missing/revision.txt"},
  "nativeAsset": {"identityEvidence": "missing/asset.txt"},
  "publicABI": {"videoHeader": {"path": "missing/header.h"}, "appBridge": {"path": "missing/bridge.h"}, "swiftContract": {"path": "missing/contract.swift"}, "signatureEvidence": {"path": "missing/signature.json", "status": "verified"}},
  "model": {"family": "made-up", "components": ["made-up"], "version": "made-up", "compatibilityManifest": {"path": "missing/compat.json"}, "compatibility": "made-up", "provenanceEvidencePath": "missing/model.json"},
  "license": {"spdx": "MIT", "provenance": "made-up", "source": "made-up", "provenanceEvidencePath": "missing/license.json", "sourceEvidencePath": "missing/license-source.json"},
  "observedSymbols": []
}
JSON

for fixture_name in absolute-evidence escape-evidence fake-evidence; do
  fixture_report="${fixture_root}/${fixture_name}-report.json"
  set +e
  VIDEO_NATIVE_MANIFEST="${fixture_root}/${fixture_name}.json" \
  VIDEO_NATIVE_SYMBOLS_FILE="${fixture_root}/symbols.txt" \
  VIDEO_NATIVE_REPORT="${fixture_report}" \
    "${repo_root}/Scripts/check-video-native-dependency.sh"
  fixture_status=$?
  set -e
  [[ "${fixture_status}" -eq 1 ]]
  python3 - "${fixture_report}" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["gate"]["status"] == "dependency-blocked"
assert report["gate"]["videoInference"] == "unavailable"
assert report["observedSymbolsAreABI"] is False
assert report["evidence"]["nativeCallsMade"] is False
assert report["gate"]["reasons"]
PY
done

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
