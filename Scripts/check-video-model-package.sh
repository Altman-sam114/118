#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swiftc_bin="${developer_dir}/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
macos_sdk="${developer_dir}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
probe_root="$(mktemp -d /private/tmp/localdiffusion-video-package-check.XXXXXX)"
probe_source="${probe_root}/VideoPackageProbe.swift"
probe_binary="${probe_root}/VideoPackageProbe"
trap 'rm -rf "${probe_root}"' EXIT

cat > "${probe_source}" <<'SWIFT'
import CryptoKit
import Foundation

enum VideoModelPackageType: String {
    case localDiffusionVideoV1 = "localdiffusion.video-model.v1"
}

@main
struct VideoPackageProbe {
    static func main() throws {
        let fileManager = FileManager.default
        let fixtureRoot = URL(fileURLWithPath: "/private/tmp/localdiffusion-video-package-fixture")
        try? fileManager.removeItem(at: fixtureRoot)
        defer { try? fileManager.removeItem(at: fixtureRoot) }
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)

        let validSource = try makePackage(at: fixtureRoot.appendingPathComponent("Example.ldvideo"))
        let store = AppFileStore(rootURL: fixtureRoot.appendingPathComponent("store"))
        let firstImport = try store.importVideoModelPackage(from: validSource)
        let secondImport = try store.importVideoModelPackage(from: validSource)
        let packageNames = try store.videoModelPackageDirectoryNames()
        guard firstImport.directoryName == "Example.ldvideo",
              secondImport.directoryName == "Example-2.ldvideo",
              packageNames == ["Example.ldvideo", "Example-2.ldvideo"] else {
            fatalError("duplicate destination handling failed")
        }

        guard (try? store.videoModelPackageURL(for: "../escape.ldvideo")) == nil else {
            fatalError("path escape was accepted")
        }

        let empty = fixtureRoot.appendingPathComponent("Empty.ldvideo")
        _ = try makePackage(at: empty, data: Data())
        expectReject(empty)
        let missing = fixtureRoot.appendingPathComponent("Missing.ldvideo")
        _ = try makePackage(at: missing, data: nil)
        expectReject(missing)
        let unsafe = fixtureRoot.appendingPathComponent("Unsafe.ldvideo")
        _ = try makePackage(at: unsafe, manifestPath: "../outside.bin")
        expectReject(unsafe)
        let unknown = fixtureRoot.appendingPathComponent("Unknown.txt")
        try fileManager.createDirectory(at: unknown, withIntermediateDirectories: true)
        expectReject(unknown)
    }

    static func makePackage(
        at url: URL,
        data: Data? = Data("small-weight".utf8),
        manifestPath: String = "weights/model.bin"
    ) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: url.appendingPathComponent("weights"), withIntermediateDirectories: true)
        if let data, manifestPath == "weights/model.bin" {
            try data.write(to: url.appendingPathComponent(manifestPath))
        }
        let digest = SHA256.hash(data: data ?? Data()).map { byte in
            let hex = String(byte, radix: 16)
            return hex.count == 1 ? "0\(hex)" : hex
        }.joined()
        let manifest: [String: Any] = [
            "format": "localdiffusion.video-model",
            "schemaVersion": 1,
            "modelType": "video-diffusion",
            "displayName": url.deletingPathExtension().lastPathComponent,
            "version": "1",
            "capabilities": ["video-generation"],
            "weights": [["path": manifestPath, "size": data?.count ?? 1, "sha256": digest]]
        ]
        let manifestData = try JSONSerialization.data(withJSONObject: manifest)
        try manifestData.write(to: url.appendingPathComponent("manifest.json"))
        return url
    }

    static func expectReject(_ url: URL) {
        do {
            _ = try VideoModelPackageInspector.inspect(at: url)
            fatalError("invalid fixture was accepted: \(url.lastPathComponent)")
        } catch {
        }
    }
}
SWIFT

"${swiftc_bin}" \
    -target arm64-apple-macosx26.0 \
    -sdk "${macos_sdk}" \
    "${repo_root}/LocalDiffusion/Services/VideoModelPackageService.swift" \
    "${repo_root}/LocalDiffusion/Services/AppFileStore.swift" \
    "${probe_source}" \
    -o "${probe_binary}"
"${probe_binary}"
