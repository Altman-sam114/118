import Foundation

struct ImageDeletionToken: Sendable {
    fileprivate enum Payload: Sendable, Equatable {
        case staged
        case sourceMissing
    }

    let id: UUID
    let hasStagedPayload: Bool
    let sourceWasMissing: Bool

    fileprivate let issuerID: UUID
    fileprivate let originalURL: URL
    fileprivate let stagedURL: URL

    fileprivate init(
        id: UUID,
        issuerID: UUID,
        originalURL: URL,
        stagedURL: URL,
        payload: Payload
    ) {
        self.id = id
        self.issuerID = issuerID
        self.originalURL = originalURL
        self.stagedURL = stagedURL
        hasStagedPayload = payload == .staged
        sourceWasMissing = payload == .sourceMissing
    }
}

enum AppFileStoreError: LocalizedError {
    case unsupportedModelFile
    case emptyModelFile
    case invalidVideoModelPackageDirectoryName(String)
    case videoModelPackageDestinationExists
    case invalidImageFilename(String)
    case invalidImageDeletionToken
    case deletionDestinationExists
    case deletionRestoreConflict
    case deletionPayloadMissing
    case unsafeDeletionStaging(String)
    case deletionVolumeIdentityUnavailable
    case deletionVolumeMismatch
    case deletionFileOperation(operation: String, underlying: Error)
    case deletionStageLocationUncertain(token: ImageDeletionToken, underlying: Error)
    case deletionStagePayloadLocationUnknown(token: ImageDeletionToken, underlying: Error)
    case deletionStageConflict(token: ImageDeletionToken, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedModelFile:
            "Model imports must be .gguf files."
        case .emptyModelFile:
            "The selected model file is empty."
        case .invalidVideoModelPackageDirectoryName(let name):
            "The video model package directory is outside the dedicated video-model boundary: \(name)"
        case .videoModelPackageDestinationExists:
            "A video model package with this destination already exists."
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
        case .unsafeDeletionStaging(let reason):
            "The image deletion staging boundary is unsafe: \(reason)"
        case .deletionVolumeIdentityUnavailable:
            "The image and deletion staging volume identities could not be verified."
        case .deletionVolumeMismatch:
            "The image and deletion staging directory are not on the same volume."
        case .deletionFileOperation(let operation, let underlying):
            "The image deletion \(operation) operation failed: \(underlying.localizedDescription)"
        case .deletionStageLocationUncertain(_, let underlying):
            "Staging reported an error after the original image disappeared. Recovery is required before retrying: \(underlying.localizedDescription)"
        case .deletionStagePayloadLocationUnknown(_, let underlying):
            "Staging failed and the image is visible at neither the original nor staged location. Recovery is required; do not start another deletion: \(underlying.localizedDescription)"
        case .deletionStageConflict(_, let underlying):
            "Staging failed with files at both the original and staged locations. Neither file was removed: \(underlying.localizedDescription)"
        }
    }
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
    var volumeIdentifier: (URL) throws -> NSObject?

    static func live(fileManager: FileManager) -> Self {
        Self(
            moveItem: { source, destination in
                try fileManager.moveItem(at: source, to: destination)
            },
            removeItem: { url in
                try fileManager.removeItem(at: url)
            },
            volumeIdentifier: { url in
                try url.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier as? NSObject
            }
        )
    }
}

final class AppFileStore: @unchecked Sendable {
    static let shared = AppFileStore()

    let rootURL: URL
    let modelsURL: URL
    let videoModelsURL: URL
    let imagesURL: URL
    let temporaryDownloadsURL: URL

    private let fileManager: FileManager
    private let imageDeletionFileOperations: ImageDeletionFileOperations
    private let imageDeletionIssuerID = UUID()
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
        videoModelsURL = rootURL.appendingPathComponent("VideoModels", isDirectory: true)
        imagesURL = rootURL.appendingPathComponent("GeneratedImages", isDirectory: true)
        temporaryDownloadsURL = rootURL.appendingPathComponent("Downloads", isDirectory: true)

        do {
            try prepareDirectory(rootURL)
            try prepareDirectory(modelsURL)
            try prepareDirectory(videoModelsURL)
            try prepareDirectory(imagesURL)
            try prepareDirectory(temporaryDownloadsURL)
        } catch {
            assertionFailure("Unable to prepare file store: \(error)")
        }
    }

    func modelURL(for filename: String) -> URL {
        modelsURL.appendingPathComponent(filename, isDirectory: false)
    }

    func videoModelPackageURL(for directoryName: String) throws -> URL {
        try validatedVideoModelPackageURL(for: directoryName)
    }

    func importVideoModelPackage(from sourceURL: URL) throws -> VideoModelPackageImport {
        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        _ = try VideoModelPackageInspector.inspect(at: sourceURL)
        let directoryName = availableVideoModelPackageDirectoryName(for: sourceURL.lastPathComponent)
        let destinationURL = try validatedVideoModelPackageURL(for: directoryName)
        let stagingURL = videoModelsURL.appendingPathComponent(".importing-\(UUID().uuidString).ldvideo", isDirectory: true)

        do {
            try fileManager.copyItem(at: sourceURL, to: stagingURL)
            let copiedInspection = try VideoModelPackageInspector.inspect(at: stagingURL)
            guard !fileManager.fileExists(atPath: destinationURL.path) else {
                throw AppFileStoreError.videoModelPackageDestinationExists
            }
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
            try excludeFromBackup(destinationURL)
            return VideoModelPackageImport(directoryName: directoryName, inspection: copiedInspection)
        } catch {
            try? removeFileIfPresent(at: stagingURL)
            throw error
        }
    }

    func inspectVideoModelPackage(named directoryName: String) throws -> VideoModelPackageInspection {
        try VideoModelPackageInspector.inspect(at: try validatedVideoModelPackageURL(for: directoryName))
    }

    func removeVideoModelPackage(named directoryName: String) throws {
        try removeFileIfPresent(at: try validatedVideoModelPackageURL(for: directoryName))
    }

    func videoModelPackageDirectoryNames() throws -> Set<String> {
        let urls = try fileManager.contentsOfDirectory(
            at: videoModelsURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        return Set(urls.compactMap { url in
            guard url.pathExtension.lowercased() == "ldvideo" else { return nil }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values?.isDirectory == true, values?.isSymbolicLink != true else { return nil }
            return url.lastPathComponent
        })
    }

    func videoModelDirectorySize() -> Int64 {
        directorySize(at: videoModelsURL)
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
        let stagingURL = try validatedImageDeletionStagingURL()

        let tokenID = UUID()
        let stagedURL = stagingURL
            .appendingPathComponent("\(tokenID.uuidString).png", isDirectory: false)
        try validateResolvedDeletionPaths(originalURL: originalURL, stagedURL: stagedURL, stagingURL: stagingURL)
        guard !fileManager.fileExists(atPath: stagedURL.path) else {
            throw AppFileStoreError.deletionDestinationExists
        }
        try validateSameVolume(imagesURL, stagingURL)

        guard fileManager.fileExists(atPath: originalURL.path) else {
            return ImageDeletionToken(
                id: tokenID,
                issuerID: imageDeletionIssuerID,
                originalURL: originalURL,
                stagedURL: stagedURL,
                payload: .sourceMissing
            )
        }
        try validateDeletionPayloadVolumes(
            originalURL: originalURL,
            stagedURL: stagedURL,
            stagingURL: stagingURL,
            originalExists: true,
            stagedExists: false
        )

        let token = ImageDeletionToken(
            id: tokenID,
            issuerID: imageDeletionIssuerID,
            originalURL: originalURL,
            stagedURL: stagedURL,
            payload: .staged
        )
        do {
            try imageDeletionFileOperations.moveItem(originalURL, stagedURL)
        } catch {
            let originalExists = fileManager.fileExists(atPath: originalURL.path)
            let stagedExists = fileManager.fileExists(atPath: stagedURL.path)
            switch (originalExists, stagedExists) {
            case (true, false):
                throw AppFileStoreError.deletionFileOperation(operation: "stage", underlying: error)
            case (false, true):
                throw AppFileStoreError.deletionStageLocationUncertain(token: token, underlying: error)
            case (false, false):
                throw AppFileStoreError.deletionStagePayloadLocationUnknown(token: token, underlying: error)
            case (true, true):
                throw AppFileStoreError.deletionStageConflict(token: token, underlying: error)
            }
        }

        guard !fileManager.fileExists(atPath: originalURL.path),
              fileManager.fileExists(atPath: stagedURL.path) else {
            throw AppFileStoreError.deletionStageLocationUncertain(
                token: token,
                underlying: CocoaError(.fileWriteUnknown)
            )
        }
        do {
            try validateDeletionPayloadVolumes(
                originalURL: originalURL,
                stagedURL: stagedURL,
                stagingURL: stagingURL,
                originalExists: false,
                stagedExists: true
            )
        } catch {
            throw AppFileStoreError.deletionStageLocationUncertain(token: token, underlying: error)
        }
        return token
    }

    func restoreImageDeletion(_ token: ImageDeletionToken) throws -> ImageDeletionRestoreResult {
        try validateImageDeletionToken(token)
        guard token.hasStagedPayload else { return .noPayload }

        let originalExists = fileManager.fileExists(atPath: token.originalURL.path)
        let stagedExists = fileManager.fileExists(atPath: token.stagedURL.path)
        try validateDeletionPayloadVolumes(
            originalURL: token.originalURL,
            stagedURL: token.stagedURL,
            stagingURL: token.stagedURL.deletingLastPathComponent(),
            originalExists: originalExists,
            stagedExists: stagedExists
        )
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
        guard token.hasStagedPayload else { return .noPayload }

        let originalExists = fileManager.fileExists(atPath: token.originalURL.path)
        let stagedExists = fileManager.fileExists(atPath: token.stagedURL.path)
        try validateDeletionPayloadVolumes(
            originalURL: token.originalURL,
            stagedURL: token.stagedURL,
            stagingURL: token.stagedURL.deletingLastPathComponent(),
            originalExists: originalExists,
            stagedExists: stagedExists
        )
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
        guard token.issuerID == imageDeletionIssuerID else {
            throw AppFileStoreError.invalidImageDeletionToken
        }

        let stagingURL = try validatedImageDeletionStagingURL()
        let expectedStagedURL = stagingURL
            .appendingPathComponent("\(token.id.uuidString).png", isDirectory: false)
        guard originalURL.deletingLastPathComponent().path == imagesURL.path,
              originalURL.pathExtension.lowercased() == "png" else {
            throw AppFileStoreError.invalidImageDeletionToken
        }
        guard stagedURL.path == expectedStagedURL.path else {
            throw AppFileStoreError.unsafeDeletionStaging("the token staged destination does not match its identity")
        }
        guard stagedURL.deletingLastPathComponent().path == stagingURL.path else {
            throw AppFileStoreError.unsafeDeletionStaging("the token staged destination is outside the staging directory")
        }
        try validateResolvedDeletionPaths(originalURL: originalURL, stagedURL: stagedURL, stagingURL: stagingURL)
        try validateSameVolume(imagesURL, stagingURL)
    }

    private func validatedImageDeletionStagingURL() throws -> URL {
        let stagingURL = imageDeletionStagingURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: stagingURL.path, isDirectory: &isDirectory) {
            let values = try stagingURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw AppFileStoreError.unsafeDeletionStaging("the staging directory is a symbolic link")
            }
            guard isDirectory.boolValue, values.isDirectory == true else {
                throw AppFileStoreError.unsafeDeletionStaging("the staging path is not a directory")
            }
        } else {
            try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: false)
            try excludeFromBackup(stagingURL)
        }

        let values = try stagingURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw AppFileStoreError.unsafeDeletionStaging("the staging path did not resolve to a real directory")
        }

        let resolvedImagesURL = imagesURL.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedStagingURL = stagingURL.resolvingSymlinksInPath()
        guard isStrictDescendant(resolvedStagingURL, of: resolvedImagesURL),
              resolvedStagingURL.deletingLastPathComponent().path == resolvedImagesURL.path else {
            throw AppFileStoreError.unsafeDeletionStaging("the resolved staging directory is outside the generated-images root")
        }
        return resolvedStagingURL
    }

    private func validateResolvedDeletionPaths(
        originalURL: URL,
        stagedURL: URL,
        stagingURL: URL
    ) throws {
        let resolvedImagesURL = imagesURL.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedStagingURL = stagingURL.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedOriginalURL = resolvedURLPreservingMissingLeaf(originalURL)
        let resolvedStagedURL = resolvedURLPreservingMissingLeaf(stagedURL)
        guard resolvedOriginalURL.deletingLastPathComponent().path == resolvedImagesURL.path else {
            throw AppFileStoreError.unsafeDeletionStaging("the resolved original image is outside the generated-images root")
        }
        guard resolvedStagedURL.deletingLastPathComponent().path == resolvedStagingURL.path else {
            throw AppFileStoreError.unsafeDeletionStaging("the resolved staged destination is outside the staging directory")
        }
        guard isStrictDescendant(resolvedStagedURL, of: resolvedImagesURL) else {
            throw AppFileStoreError.unsafeDeletionStaging("the resolved staged destination is outside the generated-images root")
        }
    }

    private func validateSameVolume(_ firstURL: URL, _ secondURL: URL) throws {
        let firstIdentifier = try imageDeletionFileOperations.volumeIdentifier(firstURL)
        let secondIdentifier = try imageDeletionFileOperations.volumeIdentifier(secondURL)
        guard let firstIdentifier, let secondIdentifier else {
            throw AppFileStoreError.deletionVolumeIdentityUnavailable
        }
        guard firstIdentifier.isEqual(secondIdentifier) else {
            throw AppFileStoreError.deletionVolumeMismatch
        }
    }

    private func validateDeletionPayloadVolumes(
        originalURL: URL,
        stagedURL: URL,
        stagingURL: URL,
        originalExists: Bool,
        stagedExists: Bool
    ) throws {
        switch (originalExists, stagedExists) {
        case (true, true):
            try validateSameVolume(originalURL, imagesURL)
            try validateSameVolume(stagedURL, stagingURL)
            try validateSameVolume(originalURL, stagedURL)
        case (true, false):
            try validateSameVolume(originalURL, imagesURL)
            try validateSameVolume(originalURL, stagingURL)
        case (false, true):
            try validateSameVolume(stagedURL, stagingURL)
            try validateSameVolume(stagedURL, imagesURL)
        case (false, false):
            try validateSameVolume(imagesURL, stagingURL)
        }
    }

    private func isStrictDescendant(_ candidate: URL, of directory: URL) -> Bool {
        let directoryComponents = directory.standardizedFileURL.pathComponents
        let candidateComponents = candidate.standardizedFileURL.pathComponents
        guard candidateComponents.count > directoryComponents.count else { return false }
        return candidateComponents.prefix(directoryComponents.count).elementsEqual(directoryComponents)
    }

    private func resolvedURLPreservingMissingLeaf(_ url: URL) -> URL {
        let standardizedURL = url.standardizedFileURL
        if fileManager.fileExists(atPath: standardizedURL.path) {
            return standardizedURL.resolvingSymlinksInPath()
        }
        return standardizedURL.deletingLastPathComponent()
            .resolvingSymlinksInPath()
            .appendingPathComponent(standardizedURL.lastPathComponent, isDirectory: false)
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

    private func validatedVideoModelPackageURL(for directoryName: String) throws -> URL {
        let trimmedName = directoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              trimmedName == directoryName,
              directoryName != ".",
              directoryName != "..",
              !directoryName.hasPrefix("/"),
              !directoryName.contains("/"),
              !directoryName.contains("\\"),
              (directoryName as NSString).pathExtension.lowercased() == "ldvideo" else {
            throw AppFileStoreError.invalidVideoModelPackageDirectoryName(directoryName)
        }

        let url = videoModelsURL.appendingPathComponent(directoryName, isDirectory: true)
        guard url.deletingLastPathComponent().path == videoModelsURL.path else {
            throw AppFileStoreError.invalidVideoModelPackageDirectoryName(directoryName)
        }
        return url
    }

    private func availableVideoModelPackageDirectoryName(for sourceName: String) -> String {
        let sanitized = sourceName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let baseName = sanitized.hasSuffix(".ldvideo") ? sanitized : "Imported-\(UUID().uuidString).ldvideo"
        let stem = (baseName as NSString).deletingPathExtension
        let initialName = "\(stem).ldvideo"

        if !fileManager.fileExists(atPath: videoModelsURL.appendingPathComponent(initialName).path) {
            return initialName
        }

        var index = 2
        while true {
            let candidate = "\(stem)-\(index).ldvideo"
            if !fileManager.fileExists(atPath: videoModelsURL.appendingPathComponent(candidate).path) {
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
