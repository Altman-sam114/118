#!/usr/bin/env python3
import json
import pathlib
import sys


def main() -> int:
    repo_root = pathlib.Path(sys.argv[1])
    manifest_path = pathlib.Path(sys.argv[2])
    observed_symbols = json.loads(sys.argv[3])

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(json.dumps({
            "schema": "localdiffusion.video-native-preflight",
            "schemaVersion": 1,
            "gate": {"status": "dependency-blocked", "reasons": ["manifest-invalid"]},
            "error": str(error),
        }, indent=2))
        return 1

    reasons = []
    checks = {}

    def require_path(name: str, relative_path: object) -> None:
        exists = bool(relative_path) and (repo_root / str(relative_path)).is_file()
        checks[name] = "observed" if exists else "missing"
        if not exists:
            reasons.append(name)

    schema_ok = manifest.get("schema") == "localdiffusion.video-native-dependency" and manifest.get("schemaVersion") == 1
    checks["manifestSchema"] = "pass" if schema_ok else "missing"
    if not schema_ok:
        reasons.append("manifest-invalid")

    engine_revision = manifest.get("engine", {}).get("revision")
    checks["engineRevision"] = "pass" if engine_revision not in (None, "", "unknown") else "missing"
    if checks["engineRevision"] == "missing":
        reasons.append("engine-revision-missing")

    public_abi = manifest.get("publicABI", {})
    require_path("publicHeader", public_abi.get("videoHeader", {}).get("path"))
    require_path("appBridge", public_abi.get("appBridge", {}).get("path"))
    signature_ok = public_abi.get("signatureEvidence") not in (None, "", "missing", "unknown")
    checks["signatureABI"] = "pass" if signature_ok else "missing"
    if not signature_ok:
        reasons.append("public-abi-evidence-missing")

    model = manifest.get("model", {})
    compatibility_ok = (
        model.get("family") not in (None, "", "unknown")
        and model.get("version") not in (None, "", "unknown")
        and model.get("components")
        and model.get("compatibility") not in (None, "", "missing", "unknown")
    )
    checks["modelCompatibility"] = "pass" if compatibility_ok else "missing"
    if not compatibility_ok:
        reasons.append("model-compatibility-evidence-missing")

    license_info = manifest.get("license", {})
    license_ok = (
        license_info.get("spdx") not in (None, "", "unknown")
        and license_info.get("provenance") not in (None, "", "missing", "unknown")
        and license_info.get("source") not in (None, "", "unknown")
    )
    checks["licenseProvenance"] = "pass" if license_ok else "missing"
    if not license_ok:
        reasons.append("license-provenance-missing")

    declared_symbols = manifest.get("observedSymbols", [])
    checks["observedSymbols"] = "observed" if (declared_symbols or observed_symbols) else "none"
    checks["observedSymbolsAreABI"] = False

    reasons = list(dict.fromkeys(reasons))
    try:
        manifest_relative_path = str(manifest_path.relative_to(repo_root))
    except ValueError:
        manifest_relative_path = str(manifest_path)

    report = {
        "schema": "localdiffusion.video-native-preflight",
        "schemaVersion": 1,
        "manifestPath": manifest_relative_path,
        "observedSymbols": observed_symbols,
        "observedSymbolsAreABI": False,
        "checks": checks,
        "gate": {
            "status": "dependency-blocked" if reasons else "ready-not-implemented",
            "reasons": reasons,
            "videoInference": "unavailable",
        },
        "evidence": {
            "scope": "metadata and symbol observation only",
            "abiStatement": "observed symbols do not prove a supported ABI",
            "nativeCallsMade": False,
            "outputsProduced": False,
        },
    }
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 1 if reasons else 0


if __name__ == "__main__":
    raise SystemExit(main())
