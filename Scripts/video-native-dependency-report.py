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

    repo_root = repo_root.resolve()

    def safe_repo_file(relative_path: object) -> pathlib.Path | None:
        if not isinstance(relative_path, str) or not relative_path:
            return None
        if "\\" in relative_path or pathlib.PurePosixPath(relative_path).is_absolute():
            return None
        raw_parts = relative_path.split("/")
        if any(part == ".." for part in raw_parts):
            return None
        candidate = (repo_root / relative_path).resolve()
        try:
            candidate.relative_to(repo_root)
        except ValueError:
            return None
        return candidate

    def require_path(name: str, relative_path: object) -> bool:
        candidate = safe_repo_file(relative_path)
        exists = candidate is not None and candidate.is_file()
        checks[name] = "observed" if exists else "missing"
        if not exists:
            reasons.append(name)
        return exists

    def require_evidence_path(name: str, container: object, key: str) -> bool:
        if not isinstance(container, dict):
            reasons.append(name)
            checks[name] = "missing"
            return False
        return require_path(name, container.get(key))

    schema_ok = manifest.get("schema") == "localdiffusion.video-native-dependency" and manifest.get("schemaVersion") == 1
    checks["manifestSchema"] = "pass" if schema_ok else "missing"
    if not schema_ok:
        reasons.append("manifest-invalid")

    engine_revision = manifest.get("engine", {}).get("revision")
    engine_source_evidence = require_evidence_path(
        "engineSourceEvidence", manifest.get("engine", {}), "sourceEvidencePath"
    )
    checks["engineSource"] = "pass" if engine_source_evidence and manifest.get("engine", {}).get("source") not in (None, "", "unknown") else "missing"
    if checks["engineSource"] == "missing":
        reasons.append("engine-source-missing")

    engine_revision_evidence = require_evidence_path(
        "engineRevisionEvidence", manifest.get("engine", {}), "revisionEvidencePath"
    )
    checks["engineRevision"] = "pass" if engine_revision_evidence and engine_revision not in (None, "", "unknown") else "missing"
    if checks["engineRevision"] == "missing":
        reasons.append("engine-revision-missing")

    native_asset = manifest.get("nativeAsset", {})
    require_evidence_path("nativeAssetIdentity", native_asset, "identityEvidence")
    public_abi = manifest.get("publicABI", {})
    require_path("swiftContract", public_abi.get("swiftContract", {}).get("path"))
    require_path("publicHeader", public_abi.get("videoHeader", {}).get("path"))
    require_path("appBridge", public_abi.get("appBridge", {}).get("path"))
    signature_evidence = public_abi.get("signatureEvidence", {})
    signature_ok = (
        isinstance(signature_evidence, dict)
        and signature_evidence.get("status") not in (None, "", "missing", "unknown")
        and require_path("signatureEvidence", signature_evidence.get("path"))
    )
    checks["signatureABI"] = "pass" if signature_ok else "missing"
    if not signature_ok:
        reasons.append("public-abi-evidence-missing")

    model = manifest.get("model", {})
    compatibility_ok = (
        model.get("family") not in (None, "", "unknown")
        and model.get("version") not in (None, "", "unknown")
        and model.get("components")
        and require_path("modelCompatibilityEvidence", model.get("compatibilityManifest", {}).get("path"))
        and model.get("compatibility") not in (None, "", "missing", "unknown")
        and require_path("modelProvenanceEvidence", model.get("provenanceEvidencePath"))
    )
    checks["modelCompatibility"] = "pass" if compatibility_ok else "missing"
    if not compatibility_ok:
        reasons.append("model-compatibility-evidence-missing")

    license_info = manifest.get("license", {})
    license_ok = (
        license_info.get("spdx") not in (None, "", "unknown")
        and require_path("licenseProvenanceEvidence", license_info.get("provenanceEvidencePath"))
        and require_path("licenseSourceEvidence", license_info.get("sourceEvidencePath"))
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
