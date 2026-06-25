import Foundation
import SwiftData
import UIKit

@MainActor
final class GenerationViewModel: ObservableObject {
    @Published var parameters = GenerationParameters()
    @Published var selectedModelID: UUID?
    @Published private(set) var progress = GenerationProgress(fraction: 0, stage: "Idle")
    @Published private(set) var isGenerating = false
    @Published private(set) var isCancelling = false
    @Published private(set) var generatedImageData: Data?
    @Published private(set) var latestGeneratedImageID: UUID?
    @Published var alertMessage: String?
    let backendStatus: InferenceBackendStatus

    private let fileStore: AppFileStore
    private let backend: any ImageGenerationBackend
    private var generationTask: Task<Void, Never>?

    init(fileStore: AppFileStore, backend: any ImageGenerationBackend) {
        self.fileStore = fileStore
        self.backend = backend
        self.backendStatus = backend.status
    }

    func generate(using model: LocalModel?, modelContext: ModelContext) {
        guard !isGenerating else { return }
        guard let model, model.isReady else {
            alertMessage = "Download a model before generating."
            return
        }

        let modelURL = fileStore.modelURL(for: model.localFilename)
        guard fileStore.fileExists(at: modelURL), fileStore.fileSize(at: modelURL) > 0 else {
            model.downloadedBytes = 0
            model.status = .failed
            model.lastError = "The model file is missing from Application Support."
            try? modelContext.save()
            alertMessage = "The selected model file is missing. Refresh or redownload it from Models."
            return
        }

        let auxiliaryModelURLs = auxiliaryModelURLs(for: model)
        if let missingAuxiliaryModel = firstMissingAuxiliaryModel(in: auxiliaryModelURLs) {
            alertMessage = "\(missingAuxiliaryModel.label) is configured for this model but the file is missing from Application Support."
            return
        }

        let normalizedParameters = parameters.normalizedForGeneration
        parameters = normalizedParameters
        let request = ImageGenerationRequest(
            parameters: normalizedParameters,
            modelName: model.name,
            nativeLoadMode: model.nativeLoadMode,
            clipLURL: auxiliaryModelURLs.clipL,
            clipGURL: auxiliaryModelURLs.clipG,
            t5xxlURL: auxiliaryModelURLs.t5xxl,
            vaeURL: auxiliaryModelURLs.vae
        )
        let fileStore = fileStore
        let backend = backend
        let modelID = model.id
        let modelName = model.name

        generatedImageData = nil
        latestGeneratedImageID = nil
        progress = GenerationProgress(fraction: 0, stage: "Starting")
        isGenerating = true
        isCancelling = false

        generationTask = Task {
            defer {
                generationTask = nil
            }

            do {
                let data = try await backend.generateImage(request: request, modelURL: modelURL) { [weak self] progress in
                    Task { @MainActor in
                        self?.progress = progress
                    }
                }

                try Task.checkCancellation()
                let imageFilename = try fileStore.saveGeneratedImage(data: data)
                let image = GeneratedImage(
                    imageFilename: imageFilename,
                    parameters: request.parameters,
                    modelID: modelID,
                    modelName: modelName,
                    tags: TagExtractor.tags(from: request.parameters.prompt)
                )
                if let decodedImage = UIImage(data: data) {
                    image.updateOutputDimensions(
                        width: Int(decodedImage.size.width * decodedImage.scale),
                        height: Int(decodedImage.size.height * decodedImage.scale)
                    )
                }
                modelContext.insert(image)
                do {
                    try modelContext.save()
                } catch {
                    modelContext.delete(image)
                    try? modelContext.save()
                    try? fileStore.removeImageFile(named: imageFilename)
                    throw error
                }

                generatedImageData = data
                latestGeneratedImageID = image.id
                progress = GenerationProgress(fraction: 1, stage: "Complete")
                isGenerating = false
                isCancelling = false
            } catch is CancellationError {
                progress = GenerationProgress(fraction: 0, stage: "Cancelled")
                isGenerating = false
                isCancelling = false
            } catch {
                alertMessage = error.localizedDescription
                progress = GenerationProgress(fraction: 0, stage: "Failed")
                isGenerating = false
                isCancelling = false
            }
        }
    }

    func cancel() {
        guard isGenerating, !isCancelling else { return }
        isCancelling = true
        progress = GenerationProgress(fraction: progress.fraction, stage: "Cancelling")
        generationTask?.cancel()
    }

    func load(template: PromptTemplate) {
        parameters = template.parameters.normalizedForGeneration
    }

    func load(image: GeneratedImage) {
        parameters = image.parameters.normalizedForGeneration
        selectedModelID = image.modelID
    }

    private func auxiliaryModelURLs(for model: LocalModel) -> AuxiliaryModelURLs {
        AuxiliaryModelURLs(
            clipL: model.clipLFilename.flatMap(modelURLIfConfigured),
            clipG: model.clipGFilename.flatMap(modelURLIfConfigured),
            t5xxl: model.t5xxlFilename.flatMap(modelURLIfConfigured),
            vae: model.vaeFilename.flatMap(modelURLIfConfigured)
        )
    }

    private func modelURLIfConfigured(filename: String) -> URL? {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return fileStore.modelURL(for: trimmed)
    }

    private func firstMissingAuxiliaryModel(in urls: AuxiliaryModelURLs) -> (label: String, url: URL)? {
        let candidates: [(label: String, url: URL?)] = [
            ("CLIP-L", urls.clipL),
            ("CLIP-G", urls.clipG),
            ("T5XXL", urls.t5xxl),
            ("VAE", urls.vae)
        ]

        for candidate in candidates {
            guard let url = candidate.url else { continue }
            if !fileStore.fileExists(at: url) || fileStore.fileSize(at: url) <= 0 {
                return (candidate.label, url)
            }
        }

        return nil
    }
}

private struct AuxiliaryModelURLs {
    var clipL: URL?
    var clipG: URL?
    var t5xxl: URL?
    var vae: URL?
}

enum TagExtractor {
    static func tags(from prompt: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",.;:()[]{}")
            .union(.whitespacesAndNewlines)
        let ignored: Set<String> = [
            "a", "an", "and", "the", "with", "for", "from", "into",
            "high", "quality", "best", "very", "image", "photo"
        ]

        let candidates = prompt
            .lowercased()
            .components(separatedBy: separators)
            .filter { $0.count > 2 && !ignored.contains($0) }

        return Array(candidates.prefix(8)).normalizedTags()
    }
}
