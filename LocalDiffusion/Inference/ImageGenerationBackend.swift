import Foundation
import UIKit

struct ImageGenerationRequest: Sendable {
    var parameters: GenerationParameters
    var modelName: String
    var nativeLoadMode: NativeModelLoadMode
    var clipLURL: URL?
    var clipGURL: URL?
    var t5xxlURL: URL?
    var vaeURL: URL?

    var usesStandaloneDiffusionModel: Bool {
        nativeLoadMode == .standaloneDiffusion
    }
}

struct GenerationProgress: Sendable, Equatable {
    var fraction: Double
    var stage: String
}

enum InferenceBackendError: LocalizedError {
    case backendNotLinked
    case invalidImageData
    case nativeFailure(String)

    var errorDescription: String? {
        switch self {
        case .backendNotLinked:
            "The stable-diffusion.cpp XCFramework has not been linked yet."
        case .invalidImageData:
            "The inference backend returned invalid image data."
        case .nativeFailure(let message):
            message
        }
    }
}

protocol ImageGenerationBackend: Sendable {
    var status: InferenceBackendStatus { get }

    func generateImage(
        request: ImageGenerationRequest,
        modelURL: URL,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> Data
}

struct InferenceBackendStatus: Sendable, Equatable {
    var isReady: Bool
    var title: String
    var message: String
}

enum InferenceBackendFactory {
    static func makeDefaultBackend() -> any ImageGenerationBackend {
        #if USE_STABLE_DIFFUSION_CPP
        StableDiffusionCPPInferenceBackend()
        #elseif DEBUG_MOCK_INFERENCE
        MockLocalInferenceBackend()
        #else
        UnavailableInferenceBackend()
        #endif
    }
}

actor UnavailableInferenceBackend: ImageGenerationBackend {
    nonisolated var status: InferenceBackendStatus {
        InferenceBackendStatus(
            isReady: false,
            title: "Native Backend Missing",
            message: "Install and link LocalDiffusionNative.xcframework, then enable USE_STABLE_DIFFUSION_CPP."
        )
    }

    func generateImage(
        request: ImageGenerationRequest,
        modelURL: URL,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> Data {
        progress(GenerationProgress(fraction: 0, stage: "Native backend unavailable"))
        throw InferenceBackendError.backendNotLinked
    }
}

actor MockLocalInferenceBackend: ImageGenerationBackend {
    nonisolated var status: InferenceBackendStatus {
        InferenceBackendStatus(
            isReady: true,
            title: "Debug Mock Inference",
            message: "Using placeholder image generation for UI development."
        )
    }

    func generateImage(
        request: ImageGenerationRequest,
        modelURL: URL,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> Data {
        let steps = max(request.parameters.steps, 1)
        for step in 1...steps {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 55_000_000)
            progress(GenerationProgress(
                fraction: Double(step) / Double(steps),
                stage: "Step \(step) of \(steps)"
            ))
        }

        try Task.checkCancellation()
        guard let data = renderPlaceholderImage(for: request) else {
            throw InferenceBackendError.invalidImageData
        }
        return data
    }

    private func renderPlaceholderImage(for request: ImageGenerationRequest) -> Data? {
        let width = max(min(request.parameters.width, 1024), 256)
        let height = max(min(request.parameters.height, 1024), 256)
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            let seed = CGFloat(abs(request.parameters.seed % 360)) / 360.0
            let start = UIColor(hue: seed, saturation: 0.42, brightness: 0.88, alpha: 1).cgColor
            let end = UIColor(hue: fmod(seed + 0.31, 1), saturation: 0.62, brightness: 0.55, alpha: 1).cgColor
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: [start, end] as CFArray, locations: [0, 1])

            if let gradient {
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            UIColor.white.withAlphaComponent(0.18).setFill()
            for index in 0..<9 {
                let inset = CGFloat(index) * min(size.width, size.height) * 0.035
                let rect = CGRect(
                    x: inset,
                    y: inset,
                    width: size.width - inset * 2,
                    height: size.height - inset * 2
                )
                cgContext.fillEllipse(in: rect)
            }

            let title = request.parameters.prompt.isEmpty ? "Local generation" : request.parameters.prompt
            let subtitle = "\(request.modelName) | \(request.parameters.samplerRawValue) | seed \(request.parameters.seed)"
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byTruncatingTail

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.86),
                .paragraphStyle: paragraph
            ]

            let maxTextWidth = size.width * 0.78
            NSString(string: title).draw(
                with: CGRect(x: (size.width - maxTextWidth) / 2, y: size.height * 0.42, width: maxTextWidth, height: 72),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: titleAttributes,
                context: nil
            )
            NSString(string: subtitle).draw(
                with: CGRect(x: (size.width - maxTextWidth) / 2, y: size.height * 0.56, width: maxTextWidth, height: 28),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: subtitleAttributes,
                context: nil
            )
        }

        return image.pngData()
    }
}

struct StableDiffusionCPPInferenceBackend: ImageGenerationBackend {
    var status: InferenceBackendStatus {
        InferenceBackendStatus(
            isReady: true,
            title: "Native Inference Ready",
            message: "Using the linked stable-diffusion.cpp backend."
        )
    }

    func generateImage(
        request: ImageGenerationRequest,
        modelURL: URL,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> Data {
        #if USE_STABLE_DIFFUSION_CPP
        let cancellationToken = NativeCancellationToken()
        let nativeTask = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()

            let progressBox = NativeProgressBox(
                progress: progress,
                cancellationToken: cancellationToken
            )
            let progressContext = Unmanaged.passUnretained(progressBox).toOpaque()

            var result = LDIImageResult()
            defer {
                ldi_sd_free_result(&result)
            }

            let status = modelURL.path.withCString { modelPath in
                request.parameters.prompt.withCString { prompt in
                    request.parameters.negativePrompt.withCString { negativePrompt in
                        request.parameters.samplerRawValue.withCString { sampler in
                            return request.withNativeAuxiliaryModelPaths { paths in
                                var input = LDIImageGenerationInput(
                                    model_path: request.usesStandaloneDiffusionModel ? nil : modelPath,
                                    diffusion_model_path: request.usesStandaloneDiffusionModel ? modelPath : nil,
                                    clip_l_path: paths.clipL,
                                    clip_g_path: paths.clipG,
                                    t5xxl_path: paths.t5xxl,
                                    vae_path: paths.vae,
                                    prompt: prompt,
                                    negative_prompt: negativePrompt,
                                    steps: Int32(request.parameters.steps),
                                    cfg_scale: Float(request.parameters.cfgScale),
                                    seed: Int64(request.parameters.seed),
                                    width: Int32(request.parameters.width),
                                    height: Int32(request.parameters.height),
                                    sampler: sampler
                                )

                                return ldi_sd_generate_png(&input, nativeProgressCallback, progressContext, &result)
                            }
                        }
                    }
                }
            }

            try Task.checkCancellation()
            if cancellationToken.isCancelled {
                throw CancellationError()
            }

            guard status == 0 else {
                if Task.isCancelled || cancellationToken.isCancelled {
                    throw CancellationError()
                }
                let message = result.error_message.map { String(cString: $0) } ?? "Native inference failed."
                throw InferenceBackendError.nativeFailure(message)
            }

            guard let bytes = result.bytes, result.count > 0 else {
                throw InferenceBackendError.invalidImageData
            }

            return Data(bytes: bytes, count: Int(result.count))
        }

        return try await withTaskCancellationHandler {
            try await nativeTask.value
        } onCancel: {
            cancellationToken.cancel()
            nativeTask.cancel()
        }
        #else
        progress(GenerationProgress(fraction: 0, stage: "Loading native backend"))
        throw InferenceBackendError.backendNotLinked
        #endif
    }
}

#if USE_STABLE_DIFFUSION_CPP
private struct NativeAuxiliaryModelPaths {
    var clipL: UnsafePointer<CChar>?
    var clipG: UnsafePointer<CChar>?
    var t5xxl: UnsafePointer<CChar>?
    var vae: UnsafePointer<CChar>?
}

private extension ImageGenerationRequest {
    func withNativeAuxiliaryModelPaths<Result>(
        _ body: (NativeAuxiliaryModelPaths) -> Result
    ) -> Result {
        withOptionalCString(clipLURL?.path) { clipL in
            withOptionalCString(clipGURL?.path) { clipG in
                withOptionalCString(t5xxlURL?.path) { t5xxl in
                    withOptionalCString(vaeURL?.path) { vae in
                        body(NativeAuxiliaryModelPaths(
                            clipL: clipL,
                            clipG: clipG,
                            t5xxl: t5xxl,
                            vae: vae
                        ))
                    }
                }
            }
        }
    }
}

private func withOptionalCString<Result>(
    _ value: String?,
    _ body: (UnsafePointer<CChar>?) -> Result
) -> Result {
    guard let value, !value.isEmpty else {
        return body(nil)
    }
    return value.withCString(body)
}

private final class NativeProgressBox: @unchecked Sendable {
    let progress: @Sendable (GenerationProgress) -> Void
    let cancellationToken: NativeCancellationToken

    init(
        progress: @escaping @Sendable (GenerationProgress) -> Void,
        cancellationToken: NativeCancellationToken
    ) {
        self.progress = progress
        self.cancellationToken = cancellationToken
    }
}

private final class NativeCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

private let nativeProgressCallback: LDIProgressCallback = { fraction, stagePointer, context in
    guard let context else { return true }
    let box = Unmanaged<NativeProgressBox>.fromOpaque(context).takeUnretainedValue()
    let stage = stagePointer.map { String(cString: $0) } ?? "Generating"
    box.progress(GenerationProgress(fraction: Double(fraction), stage: stage))
    return !box.cancellationToken.isCancelled
}
#endif
