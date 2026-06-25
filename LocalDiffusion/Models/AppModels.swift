import Foundation
import SwiftData

enum ModelFamily: String, CaseIterable, Identifiable, Codable, Sendable {
    case stableDiffusion = "Stable Diffusion"
    case sdxl = "SDXL"
    case flux = "FLUX"

    var id: String { rawValue }
}

enum ModelDownloadStatus: String, CaseIterable, Codable, Sendable {
    case queued
    case downloading
    case paused
    case ready
    case failed
}

enum NativeModelLoadMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case fullModel = "Full Model"
    case standaloneDiffusion = "Standalone Diffusion"

    var id: String { rawValue }

    static func defaultMode(for family: ModelFamily) -> NativeModelLoadMode {
        family == .flux ? .standaloneDiffusion : .fullModel
    }
}

enum Sampler: String, CaseIterable, Identifiable, Codable, Sendable {
    case euler = "Euler"
    case eulerA = "Euler a"
    case heun = "Heun"
    case dpm2 = "DPM2"
    case dpmpp2m = "DPM++ 2M"
    case dpmpp2mV2 = "DPM++ 2M v2"
    case dpmpp2sA = "DPM++ 2S a"
    case dpmppSde = "DPM++ SDE"
    case erSde = "ER-SDE"
    case lcm = "LCM"

    var id: String { rawValue }
}

struct GenerationParameters: Codable, Hashable, Sendable {
    static let minimumDimension = 256
    static let maximumDimension = 2048
    static let dimensionStep = 64
    static let minimumSteps = 1
    static let maximumSteps = 100
    static let minimumCFGScale = 1.0
    static let maximumCFGScale = 20.0

    var prompt: String
    var negativePrompt: String
    var steps: Int
    var cfgScale: Double
    var seed: Int
    var width: Int
    var height: Int
    var samplerRawValue: String

    init(
        prompt: String = "",
        negativePrompt: String = "",
        steps: Int = 25,
        cfgScale: Double = 7.0,
        seed: Int = Int.random(in: 0...Int(Int32.max)),
        width: Int = 512,
        height: Int = 512,
        sampler: Sampler = .euler
    ) {
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.steps = steps
        self.cfgScale = cfgScale
        self.seed = seed
        self.width = width
        self.height = height
        self.samplerRawValue = sampler.rawValue
    }

    var sampler: Sampler {
        get { Sampler(rawValue: samplerRawValue) ?? .euler }
        set { samplerRawValue = newValue.rawValue }
    }

    var normalizedForGeneration: GenerationParameters {
        var normalized = self
        normalized.steps = Self.clampedSteps(steps)
        normalized.cfgScale = min(max(cfgScale, Self.minimumCFGScale), Self.maximumCFGScale)
        normalized.width = Self.normalizedDimension(width)
        normalized.height = Self.normalizedDimension(height)
        if Sampler(rawValue: samplerRawValue) == nil {
            normalized.sampler = .euler
        }
        return normalized
    }

    static func clampedSteps(_ value: Int) -> Int {
        min(max(value, minimumSteps), maximumSteps)
    }

    static func normalizedDimension(_ value: Int) -> Int {
        let rounded = ((value + dimensionStep / 2) / dimensionStep) * dimensionStep
        return min(max(rounded, minimumDimension), maximumDimension)
    }
}

@Model
final class LocalModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var familyRawValue: String
    var sourceRepository: String
    var sourceFilename: String
    var sourceRevision: String
    var sourceURLString: String
    var localFilename: String
    var nativeLoadModeRawValue: String?
    var clipLFilename: String?
    var clipGFilename: String?
    var t5xxlFilename: String?
    var vaeFilename: String?
    var downloadedBytes: Int64
    var totalBytes: Int64
    var statusRawValue: String
    var lastError: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        family: ModelFamily,
        sourceRepository: String,
        sourceFilename: String,
        sourceRevision: String,
        sourceURLString: String,
        localFilename: String,
        nativeLoadMode: NativeModelLoadMode? = nil,
        clipLFilename: String? = nil,
        clipGFilename: String? = nil,
        t5xxlFilename: String? = nil,
        vaeFilename: String? = nil,
        downloadedBytes: Int64 = 0,
        totalBytes: Int64 = 0,
        status: ModelDownloadStatus = .queued,
        lastError: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.familyRawValue = family.rawValue
        self.sourceRepository = sourceRepository
        self.sourceFilename = sourceFilename
        self.sourceRevision = sourceRevision
        self.sourceURLString = sourceURLString
        self.localFilename = localFilename
        self.nativeLoadModeRawValue = (nativeLoadMode ?? NativeModelLoadMode.defaultMode(for: family)).rawValue
        self.clipLFilename = clipLFilename
        self.clipGFilename = clipGFilename
        self.t5xxlFilename = t5xxlFilename
        self.vaeFilename = vaeFilename
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.statusRawValue = status.rawValue
        self.lastError = lastError
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var family: ModelFamily {
        get { ModelFamily(rawValue: familyRawValue) ?? .stableDiffusion }
        set { familyRawValue = newValue.rawValue }
    }

    var nativeLoadMode: NativeModelLoadMode {
        get {
            NativeModelLoadMode(rawValue: nativeLoadModeRawValue ?? "") ?? NativeModelLoadMode.defaultMode(for: family)
        }
        set {
            nativeLoadModeRawValue = newValue.rawValue
            updatedAt = .now
        }
    }

    var status: ModelDownloadStatus {
        get { ModelDownloadStatus(rawValue: statusRawValue) ?? .queued }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = .now
        }
    }

    var isReady: Bool {
        status == .ready
    }

    var sizeDescription: String {
        ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)
    }
}

@Model
final class GeneratedImage {
    @Attribute(.unique) var id: UUID
    var imageFilename: String
    var prompt: String
    var negativePrompt: String
    var steps: Int
    var cfgScale: Double
    var seed: Int
    var width: Int
    var height: Int
    var outputWidth: Int?
    var outputHeight: Int?
    var samplerRawValue: String
    var modelID: UUID?
    var modelName: String
    var folderID: UUID?
    var tagString: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        imageFilename: String,
        parameters: GenerationParameters,
        modelID: UUID?,
        modelName: String,
        folderID: UUID? = nil,
        tags: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.imageFilename = imageFilename
        self.prompt = parameters.prompt
        self.negativePrompt = parameters.negativePrompt
        self.steps = parameters.steps
        self.cfgScale = parameters.cfgScale
        self.seed = parameters.seed
        self.width = parameters.width
        self.height = parameters.height
        self.outputWidth = parameters.width
        self.outputHeight = parameters.height
        self.samplerRawValue = parameters.samplerRawValue
        self.modelID = modelID
        self.modelName = modelName
        self.folderID = folderID
        self.tagString = tags.normalizedTags().joined(separator: ",")
        self.createdAt = createdAt
    }

    func updateOutputDimensions(width: Int, height: Int) {
        self.outputWidth = width
        self.outputHeight = height
    }

    var resolvedOutputWidth: Int {
        if let outputWidth, outputWidth > 0 {
            return outputWidth
        }
        return width
    }

    var resolvedOutputHeight: Int {
        if let outputHeight, outputHeight > 0 {
            return outputHeight
        }
        return height
    }

    var parameters: GenerationParameters {
        GenerationParameters(
            prompt: prompt,
            negativePrompt: negativePrompt,
            steps: steps,
            cfgScale: cfgScale,
            seed: seed,
            width: width,
            height: height,
            sampler: sampler
        )
    }

    var sampler: Sampler {
        get { Sampler(rawValue: samplerRawValue) ?? .euler }
        set { samplerRawValue = newValue.rawValue }
    }

    var tags: [String] {
        get { tagString.tagsFromCSV() }
        set { tagString = newValue.normalizedTags().joined(separator: ",") }
    }
}

@Model
final class GalleryFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class PromptTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var prompt: String
    var negativePrompt: String
    var steps: Int
    var cfgScale: Double
    var seed: Int
    var width: Int
    var height: Int
    var samplerRawValue: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        parameters: GenerationParameters,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.prompt = parameters.prompt
        self.negativePrompt = parameters.negativePrompt
        self.steps = parameters.steps
        self.cfgScale = parameters.cfgScale
        self.seed = parameters.seed
        self.width = parameters.width
        self.height = parameters.height
        self.samplerRawValue = parameters.samplerRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var parameters: GenerationParameters {
        get {
            GenerationParameters(
                prompt: prompt,
                negativePrompt: negativePrompt,
                steps: steps,
                cfgScale: cfgScale,
                seed: seed,
                width: width,
                height: height,
                sampler: Sampler(rawValue: samplerRawValue) ?? .euler
            )
        }
        set {
            prompt = newValue.prompt
            negativePrompt = newValue.negativePrompt
            steps = newValue.steps
            cfgScale = newValue.cfgScale
            seed = newValue.seed
            width = newValue.width
            height = newValue.height
            samplerRawValue = newValue.samplerRawValue
            updatedAt = .now
        }
    }
}

extension Array where Element == String {
    func normalizedTags() -> [String] {
        var seen = Set<String>()
        return compactMap { rawValue in
            let tag = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard tag.count >= 2, !seen.contains(tag) else { return nil }
            seen.insert(tag)
            return tag
        }
    }
}

extension String {
    func tagsFromCSV() -> [String] {
        split(separator: ",").map(String.init).normalizedTags()
    }
}
