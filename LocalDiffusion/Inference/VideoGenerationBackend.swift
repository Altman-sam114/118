import Foundation

struct VideoGenerationRequest: Sendable, Equatable {
    let modelIdentifier: String
    let modelURL: URL
    let prompt: String

    init(modelIdentifier: String, modelURL: URL, prompt: String) {
        self.modelIdentifier = modelIdentifier
        self.modelURL = modelURL
        self.prompt = prompt
    }
}

enum VideoGenerationBackendState: String, Sendable, Equatable {
    case unavailable
    case dependencyBlocked = "dependency-blocked"
    case ready
}

enum VideoGenerationProgressStage: String, Sendable, Equatable {
    case unavailable
    case dependencyBlocked = "dependency-blocked"
}

struct VideoGenerationProgress: Sendable, Equatable {
    let stage: VideoGenerationProgressStage
    let message: String
}

enum VideoDependencyBlocker: String, Sendable, Equatable {
    case manifestInvalid = "manifest-invalid"
    case publicABIEvidenceMissing = "public-abi-evidence-missing"
    case modelCompatibilityEvidenceMissing = "model-compatibility-evidence-missing"
    case licenseProvenanceMissing = "license-provenance-missing"
    case engineRevisionMissing = "engine-revision-missing"
}

struct VideoGenerationBackendStatus: Sendable, Equatable {
    let state: VideoGenerationBackendState
    let code: String
    let title: String
    let message: String
    let blockers: [VideoDependencyBlocker]
}

enum VideoGenerationBackendError: LocalizedError, Sendable, Equatable {
    case contractUnavailable
    case dependencyBlocked(VideoDependencyBlocker)
    case manifestInvalid(String)
    case publicABIEvidenceMissing
    case modelCompatibilityEvidenceMissing
    case licenseProvenanceMissing
    case cancellation

    var code: String {
        switch self {
        case .contractUnavailable: "video-contract-unavailable"
        case .dependencyBlocked: "video-dependency-blocked"
        case .manifestInvalid: "video-manifest-invalid"
        case .publicABIEvidenceMissing: "video-public-abi-evidence-missing"
        case .modelCompatibilityEvidenceMissing: "video-model-compatibility-evidence-missing"
        case .licenseProvenanceMissing: "video-license-provenance-missing"
        case .cancellation: "video-cancellation"
        }
    }

    var errorDescription: String? {
        switch self {
        case .contractUnavailable:
            "Video generation is unavailable because no video backend contract is enabled."
        case .dependencyBlocked(let blocker):
            "Video generation is dependency-blocked: \(blocker.rawValue)."
        case .manifestInvalid(let reason):
            "The video native dependency manifest is invalid: \(reason)"
        case .publicABIEvidenceMissing:
            "A public video header and stable ABI signature have not been provided."
        case .modelCompatibilityEvidenceMissing:
            "Video model components and compatibility evidence have not been provided."
        case .licenseProvenanceMissing:
            "Video engine and model license provenance has not been provided."
        case .cancellation:
            "Video generation was cancelled."
        }
    }
}

protocol VideoGenerationBackend: Sendable {
    var status: VideoGenerationBackendStatus { get }

    func generate(
        request: VideoGenerationRequest,
        progress: @escaping @Sendable (VideoGenerationProgress) -> Void
    ) async throws
}

actor UnavailableVideoGenerationBackend: VideoGenerationBackend {
    nonisolated let status = VideoGenerationBackendStatus(
        state: .unavailable,
        code: "video-backend-unavailable",
        title: "Video Inference Unavailable",
        message: "Video deployment is separate, but this build has no supported video native engine contract.",
        blockers: [
            .publicABIEvidenceMissing,
            .modelCompatibilityEvidenceMissing,
            .licenseProvenanceMissing,
        ]
    )

    func generate(
        request: VideoGenerationRequest,
        progress: @escaping @Sendable (VideoGenerationProgress) -> Void
    ) async throws {
        do {
            try Task.checkCancellation()
        } catch {
            throw VideoGenerationBackendError.cancellation
        }

        progress(VideoGenerationProgress(
            stage: .unavailable,
            message: "Video backend unavailable; no native call or output was produced."
        ))

        do {
            try Task.checkCancellation()
        } catch {
            throw VideoGenerationBackendError.cancellation
        }

        _ = request
        throw VideoGenerationBackendError.dependencyBlocked(.publicABIEvidenceMissing)
    }
}
