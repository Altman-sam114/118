import Foundation

enum AppFileStoreError: LocalizedError {
    case unsupportedModelFile
    case emptyModelFile
    case invalidImageFilename(String)
    case invalidImageDeletionToken
    case deletionDestinationExists
    case deletionRestoreConflict
    case deletionPayloadMissing
    case deletionFileOperation(operation: String, underlying: Error)
    case deletionStageLocationUncertain(token: ImageDeletionToken, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedModelFile:
            "Model imports must be .gguf files."
        case .emptyModelFile:
            "The selected model file is empty."
        case .invalidImageFilename(let filename):
            "The image filename is outside the generated-images boundary: \(filename)"
        case .invalidImageDeletionToken:
            "The image deletion token does not match the generated-images staging boundary."
        case .deletionDestinationExists:
            "The image deletion staging destination already exists."
        case .deletionRestoreConflict:
            "The original and staged image paths conflict. No file was overwritten or removed."
        case .deletionPayloadMissing:
            "The staged image payload and original image file are both missing."
        case .deletionFileOperation(let operation, let underlying):
            "The image deletion \(operation) operation failed: \(underlying.localizedDescription)"
        case .deletionStageLocationUncertain(_, let underlying):
            "Staging reported an error after the image moved. Restore the staged image before retrying: \(underlying.localizedDescription)"
        }
    }
}

struct ImageDeletionToken: Sendable {
    enum Payload: Sendable, Equatable {
        case staged
        case sourceMissing
    }

    let id: UUID
    let originalURL: URL
    let stagedURL: URL
    let payload: Payload
}

enum ImageDeletionRestoreResult {
    case restored
    case alreadyRestored
    case noPayload
}

enum ImageDeletionFinalizeResult {
    case finalized
    case alreadyFinalized
    case noPayload
}

struct ImageDeletionFileOperations {
    var moveItem: (URL, URL) throws -> Void
    var removeItem: (URL) throws -> Void

    static func live(fileManager: FileManager) -> Self {
        Self(
            moveItem: { source, destination in
                try fileManager.moveItem(at: source, to: destination)
            },
            removeItem: { url in
                try fileManager.removeItem(at: url)
            }
        )
    }
}

final class AppFileStore: @unchecked Sendable {
    static let shared = AppFileStore()

    let rootURL: URL
    let modelsURL: URL
    let imagesURL: URL
    let temporaryDownloadsURL: URL

    private let fileManager: FileManager
    private let imageDeletionFileOperations: ImageDeletionFileOperations
    private var imageDeletionStagingURL: URL {
        imagesURL.appendingPathComponent(".DeletionStaging", isDirectory: true)
    }

    init(
        rootURL injectedRootURL: URL? = nil,
        fileManager: FileManager = .default,
        imageDeletionFileOperations: ImageDeletionFileOperations? = nil
    ) {
        self.fileManager = fileManager
        self.imageDeletionFileOperations = imageDeletionFileOperations ?? .live(fileManager: fileManager)

        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        rootURL = injectedRootURL ?? applicationSupport.appendingPathComponent("LocalDiffusion", isDirectory: true)
        modelsURL = rootURL.appendingPathComponent("Models", isDirectory: true)
        imagesURL = rootURL.appendingPathComponent("GeneratedImages", isDirectory: true)
        temporaryDownloadsURL = rootURL.appendingPathComponent("Downloads", isDirectory: true)

        do {
            try prepareDirectory(rootURL)
            try prepareDirectory(modelsURL)
            try prepareDirectory(imagesURL)
            try prepareDirectory(temporaryDownloadsURL)
        } catch {
            assertionFailure("Unable to prepare file store: \(error)")
        }
    }

    func modelURL(for filename: String) -> URL {
        modelsURL.appendingPathComponent(filename, isDirectory: false)
    }

    func imageURL(for filename: String) -> URL {
        imagesURL.appendingPathComponent(filename, isDirectory: false)
    }

    func resumeDataURL(forModelFilename filename: String) -> URL {
        temporaryDownloadsURL.appendingPathComponent("\(filename).resumeData", isDirectory: false)
    }

    func makeModelFilename(repository: String, filename: String) -> String {
        let source = "\(repository)-\(filename)"
        let sanitized = source
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return sanitized.hasSuffix(".gguf") ? sanitized : "\(sanitized).gguf"
    }

    func saveGeneratedImage(data: Data) throws -> String {
        let filename = "\(UUID().uuidString).png"
        let url = imageURL(for: filename)
        try data.write(to: url, options: [.atomic])
        try excludeFromBackup(url)
        return filename
    }

    func saveResumeData(_ data: Data, forModelFilename filename: String) throws {
        let url = resumeDataURL(forModelFilename: filename)
        try data.write(to: url, options: [.atomic])
        try excludeFromBackup(url)
    }

    func resumeData(forModelFilename filename: String) -> Data? {
        try? Data(contentsOf: resumeDataURL(forModelFilename: filename))
    }

    func removeResumeData(forModelFilename filename: String) throws {
        try removeFileIfPresent(at: resumeDataURL(forModelFilename: filename))
    }

    func removeModelFile(named filename: String) throws {
        try removeFileIfPresent(at: modelURL(for: filename))
    }

    func importModelFile(from sourceURL: URL) throws -> String {
        guard sourceURL.pathExtension.lowercased() == "gguf" else {
            throw AppFileStoreError.unsupportedModelFile
        }

        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let importedFilename = availableModelFilename(for: sourceURL.lastPathComponent)
        let destinationURL = modelURL(for: importedFilename)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        guard fileSize(at: destinationURL) > 0 else {
            try? removeFileIfPresent(at: destinationURL)
            throw AppFileStoreError.emptyModelFile
        }

        try excludeFromBackup(destinationURL)
        return importedFilename
    }

    func modelFilenames() throws -> Set<String> {
        let urls = try fileManager.contentsOfDirectory(
            at: modelsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return Set(urls.compactMap { url in
            guard url.pathExtension.lowercased() == "gguf" else { return nil }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { return nil }
            return url.lastPathComponent
        })
    }

    func removeImageFile(named filename: String) throws {
        try removeFileIfPresent(at: imageURL(for: filename))
    }

    func stageImageDeletion(named filename: String) throws -> ImageDeletionToken {
        let originalURL = try validatedImageURL(for: filename)
        try prepareDirectory(imageDeletionStagingURL)

        let tokenID = UUID()
        let stagedURL = imageDeletionStagingURL
            .appendingPathComponent("\(tokenID.uuidString).png", isDirectory: false)
        guard !fileManager.fileExists(atPath: stagedURL.path) else {
            throw AppFileStoreError.deletionDestinationExists
        }

        guard fileManager.fileExists(atPath: originalURL.path) else {
            return ImageDeletionToken(
                id: tokenID,
                originalURL: originalURL,
                stagedURL: stagedURL,
                payload: .sourceMissing
            )
        }

        let token = ImageDeletionToken(
            id: tokenID,
            originalURL: originalURL,
            stagedURL: stagedURL,
            payload: .staged
        )
        do {
            try imageDeletionFileOperations.moveItem(originalURL, stagedURL)
        } catch {
            let stagedExists = fileManager.fileExists(atPath: stagedURL.path)
            if stagedExists {
                throw AppFileStoreError.deletionStageLocationUncertain(token: token, underlying: error)
            }
            throw AppFileStoreError.deletionFileOperation(operation: "stage", underlying: error)
        }

        guard !fileManager.fileExists(atPath: originalURL.path),
              fileManager.fileExists(atPath: stagedURL.path) else {
            throw AppFileStoreError.deletionStageLocationUncertain(
                token: token,
                underlying: CocoaError(.fileWriteUnknown)
            )
        }
        return token
    }

    func restoreImageDeletion(_ token: ImageDeletionToken) throws -> ImageDeletionRestoreResult {
        try validateImageDeletionToken(token)
        guard token.payload == .staged else { return .noPayload }

        let originalExists = fileManager.fileExists(atPath: token.originalURL.path)
        let stagedExists = fileManager.fileExists(atPath: token.stagedURL.path)
        switch (originalExists, stagedExists) {
        case (true, false):
            return .alreadyRestored
        case (true, true):
            throw AppFileStoreError.deletionRestoreConflict
        case (false, false):
            throw AppFileStoreError.deletionPayloadMissing
        case (false, true):
            do {
                try imageDeletionFileOperations.moveItem(token.stagedURL, token.originalURL)
            } catch {
                throw AppFileStoreError.deletionFileOperation(operation: "restore", underlying: error)
            }
            guard fileManager.fileExists(atPath: token.originalURL.path),
                  !fileManager.fileExists(atPath: token.stagedURL.path) else {
                throw AppFileStoreError.deletionFileOperation(
                    operation: "restore",
                    underlying: CocoaError(.fileWriteUnknown)
                )
            }
            return .restored
        }
    }

    func finalizeImageDeletion(_ token: ImageDeletionToken) throws -> ImageDeletionFinalizeResult {
        try validateImageDeletionToken(token)
        guard token.payload == .staged else { return .noPayload }

        let originalExists = fileManager.fileExists(atPath: token.originalURL.path)
        let stagedExists = fileManager.fileExists(atPath: token.stagedURL.path)
        guard !originalExists else {
            throw AppFileStoreError.deletionRestoreConflict
        }
        guard stagedExists else { return .alreadyFinalized }

        do {
            try imageDeletionFileOperations.removeItem(token.stagedURL)
        } catch {
            throw AppFileStoreError.deletionFileOperation(operation: "finalize", underlying: error)
        }
        guard !fileManager.fileExists(atPath: token.stagedURL.path) else {
            throw AppFileStoreError.deletionFileOperation(
                operation: "finalize",
                underlying: CocoaError(.fileWriteUnknown)
            )
        }
        return .finalized
    }

    func generatedImageFilenames() throws -> Set<String> {
        let urls = try fileManager.contentsOfDirectory(
            at: imagesURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return Set(urls.compactMap { url in
            guard url.pathExtension.lowercased() == "png" else { return nil }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { return nil }
            return url.lastPathComponent
        })
    }

    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func fileSize(at url: URL) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return 0
        }
        return size.int64Value
    }

    func modelDirectorySize() -> Int64 {
        directorySize(at: modelsURL)
    }

    func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private func prepareDirectory(_ url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try excludeFromBackup(url)
    }

    private func removeFileIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func validatedImageURL(for filename: String) throws -> URL {
        let trimmedFilename = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFilename.isEmpty,
              trimmedFilename == filename,
              filename != ".",
              filename != "..",
              !filename.hasPrefix("/"),
              !filename.contains("/"),
              !filename.contains("\\"),
              (filename as NSString).pathExtension.lowercased() == "png" else {
            throw AppFileStoreError.invalidImageFilename(filename)
        }

        let url = imagesURL.appendingPathComponent(filename, isDirectory: false)
        guard url.deletingLastPathComponent().path == imagesURL.path else {
            throw AppFileStoreError.invalidImageFilename(filename)
        }
        return url
    }

    private func validateImageDeletionToken(_ token: ImageDeletionToken) throws {
        let originalURL = token.originalURL
        let stagedURL = token.stagedURL
        let expectedStagedURL = imageDeletionStagingURL
            .appendingPathComponent("\(token.id.uuidString).png", isDirectory: false)
        guard originalURL.deletingLastPathComponent().path == imagesURL.path,
              originalURL.pathExtension.lowercased() == "png",
              stagedURL.path == expectedStagedURL.path,
              stagedURL.deletingLastPathComponent().path == imageDeletionStagingURL.path else {
            throw AppFileStoreError.invalidImageDeletionToken
        }
    }

    private func availableModelFilename(for filename: String) -> String {
        let fallbackFilename = "Imported-\(UUID().uuidString).gguf"
        let sanitized = filename
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let baseFilename = sanitized.isEmpty ? fallbackFilename : sanitized
        let ext = (baseFilename as NSString).pathExtension
        let stem = (baseFilename as NSString).deletingPathExtension
        let normalizedFilename = ext.lowercased() == "gguf" ? baseFilename : "\(baseFilename).gguf"

        guard fileManager.fileExists(atPath: modelURL(for: normalizedFilename).path) else {
            return normalizedFilename
        }

        let normalizedStem = stem.isEmpty ? "Imported" : stem
        var index = 2
        while true {
            let candidate = "\(normalizedStem)-\(index).gguf"
            if !fileManager.fileExists(atPath: modelURL(for: candidate).path) {
                return candidate
            }
            index += 1
        }
    }

    private func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }
}
