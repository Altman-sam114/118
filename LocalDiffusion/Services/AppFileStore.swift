import Foundation

enum AppFileStoreError: LocalizedError {
    case unsupportedModelFile
    case emptyModelFile

    var errorDescription: String? {
        switch self {
        case .unsupportedModelFile:
            "Model imports must be .gguf files."
        case .emptyModelFile:
            "The selected model file is empty."
        }
    }
}

final class AppFileStore: @unchecked Sendable {
    static let shared = AppFileStore()

    let rootURL: URL
    let modelsURL: URL
    let imagesURL: URL
    let temporaryDownloadsURL: URL

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        rootURL = applicationSupport.appendingPathComponent("LocalDiffusion", isDirectory: true)
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
