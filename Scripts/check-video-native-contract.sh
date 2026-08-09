#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
swiftc_bin="${developer_dir}/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
macos_sdk="${developer_dir}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
probe_root="$(mktemp -d /private/tmp/localdiffusion-video-contract.XXXXXX)"
probe_source="${probe_root}/VideoContractProbe.swift"
probe_binary="${probe_root}/VideoContractProbe"
trap 'rm -rf "${probe_root}"' EXIT

cat > "${probe_source}" <<'SWIFT'
import Foundation

final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [VideoGenerationProgress] = []

    func append(_ value: VideoGenerationProgress) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [VideoGenerationProgress] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

@main
struct VideoContractProbe {
    static func main() async throws {
        let backend = UnavailableVideoGenerationBackend()
        let request = VideoGenerationRequest(
            modelIdentifier: "fixture",
            modelURL: URL(fileURLWithPath: "/private/tmp/fixture.ldvideo"),
            prompt: "fixture"
        )

        guard backend.status.state == .unavailable else {
            fatalError("unavailable backend state changed")
        }

        let progress = ProgressRecorder()
        do {
            try await backend.generate(request: request) { progress.append($0) }
            fatalError("unavailable backend returned successfully")
        } catch let error as VideoGenerationBackendError {
            guard error == .dependencyBlocked(.publicABIEvidenceMissing) else {
                fatalError("unexpected unavailable error: \(error.code)")
            }
        }

        guard progress.snapshot() == [VideoGenerationProgress(
            stage: .unavailable,
            message: "Video backend unavailable; no native call or output was produced."
        )] else {
            fatalError("unexpected progress output")
        }

        let cancellationTask = Task {
            try await backend.generate(request: request) { _ in
                fatalError("cancelled request reported progress")
            }
        }
        cancellationTask.cancel()
        do {
            try await cancellationTask.value
            fatalError("cancelled request returned successfully")
        } catch let error as VideoGenerationBackendError {
            guard error == .cancellation else {
                fatalError("unexpected cancellation error: \(error.code)")
            }
        }
    }
}
SWIFT

"${swiftc_bin}" \
  -target arm64-apple-macosx26.0 \
  -sdk "${macos_sdk}" \
  "${repo_root}/LocalDiffusion/Inference/VideoGenerationBackend.swift" \
  "${probe_source}" \
  -o "${probe_binary}"
"${probe_binary}"

cat <<'SUMMARY'
CONTRACT_STATUS=unavailable
ERROR_CODE=video-dependency-blocked
CANCELLATION_CODE=video-cancellation
NATIVE_CALLS=none
OUTPUTS=none
SUMMARY
