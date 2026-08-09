import CryptoKit
import Foundation

struct VideoModelPackageFile: Codable, Sendable {
    let path: String
    let size: Int64
    let sha256: String
}

struct VideoModelPackageManifest: Codable, Sendable {
    let format: String
    let schemaVersion: Int
    let modelType: String
    let displayName: String
    let version: String
    let capabilities: [String]
    let weights: [VideoModelPackageFile]
}

struct VideoModelPackageInspection: Sendable {
    let manifest: VideoModelPackageManifest
    let packageType: VideoModelPackageType
    let totalBytes: Int64
}

struct VideoModelPackageImport: Sendable {
    let directoryName: String
    let inspection: VideoModelPackageInspection
}

enum VideoModelPackageError: LocalizedError {
    case packageIsNotDirectory
    case unsupportedPackageExtension
    case missingManifest
    case invalidManifest(String)
    case unsafeRelativePath(String)
    case requiredFileMissing(String)
    case requiredFileEmpty(String)
    case requiredFileSizeMismatch(String)
    case requiredFileHashMismatch(String)

    var errorDescription: String? {
        switch self {
        case .packageIsNotDirectory:
            "Video model imports must be a .ldvideo directory package."
        case .unsupportedPackageExtension:
            "Only the explicit .ldvideo video model package type is supported."
        case .missingManifest:
            "The video model package must contain manifest.json."
        case .invalidManifest(let reason):
            "The video model manifest is unsupported: \(reason)"
        case .unsafeRelativePath(let path):
            "The video model package contains an unsafe file path: \(path)"
        case .requiredFileMissing(let path):
            "The required video model file is missing: \(path)"
        case .requiredFileEmpty(let path):
            "The required video model file is empty: \(path)"
        case .requiredFileSizeMismatch(let path):
            "The required video model file size does not match its manifest: \(path)"
        case .requiredFileHashMismatch(let path):
            "The required video model file integrity check failed: \(path)"
        }
    }

    var isUnsupported: Bool {
        switch self {
        case .packageIsNotDirectory, .unsupportedPackageExtension, .missingManifest, .invalidManifest:
            true
        case .unsafeRelativePath, .requiredFileMissing, .requiredFileEmpty, .requiredFileSizeMismatch, .requiredFileHashMismatch:
            false
        }
    }
}

enum VideoModelPackageInspector {
    static let manifestFilename = "manifest.json"
    static let supportedFormat = "localdiffusion.video-model"
    static let supportedModelType = "video-diffusion"
    static let supportedSchemaVersion = 1
    static let requiredCapability = "video-generation"

    static func inspect(at packageURL: URL) throws -> VideoModelPackageInspection {
        let packageValues = try packageURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard packageValues.isDirectory == true, packageValues.isSymbolicLink != true else {
            throw VideoModelPackageError.packageIsNotDirectory
        }
        guard packageURL.pathExtension.lowercased() == "ldvideo" else {
            throw VideoModelPackageError.unsupportedPackageExtension
        }

        let resolvedRoot = packageURL.standardizedFileURL.resolvingSymlinksInPath()
        let manifestURL = packageURL.appendingPathComponent(manifestFilename, isDirectory: false)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw VideoModelPackageError.missingManifest
        }
        guard isSafeFileURL(manifestURL, inside: resolvedRoot) else {
            throw VideoModelPackageError.unsafeRelativePath(manifestFilename)
        }

        let manifest: VideoModelPackageManifest
        do {
            let data = try Data(contentsOf: manifestURL)
            manifest = try JSONDecoder().decode(VideoModelPackageManifest.self, from: data)
        } catch {
            throw VideoModelPackageError.invalidManifest(error.localizedDescription)
        }

        let normalizedCapabilities = normalizedTags(manifest.capabilities)
        guard manifest.format == supportedFormat else {
            throw VideoModelPackageError.invalidManifest("format is not \(supportedFormat)")
        }
        guard manifest.schemaVersion == supportedSchemaVersion else {
            throw VideoModelPackageError.invalidManifest("schema version is not supported")
        }
        guard manifest.modelType == supportedModelType else {
            throw VideoModelPackageError.invalidManifest("model type is not \(supportedModelType)")
        }
        guard !manifest.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VideoModelPackageError.invalidManifest("display name is empty")
        }
        guard !manifest.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VideoModelPackageError.invalidManifest("version is empty")
        }
        guard normalizedCapabilities.contains(requiredCapability) else {
            throw VideoModelPackageError.invalidManifest("video-generation capability is not declared")
        }
        guard !manifest.weights.isEmpty else {
            throw VideoModelPackageError.invalidManifest("no required weight files are declared")
        }

        var totalBytes: Int64 = 0
        for requiredFile in manifest.weights {
            let fileURL = try validatedRelativeFileURL(requiredFile.path, packageURL: packageURL, resolvedRoot: resolvedRoot)
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw VideoModelPackageError.requiredFileMissing(requiredFile.path)
            }
            guard requiredFile.size > 0, (values.fileSize ?? 0) > 0 else {
                throw VideoModelPackageError.requiredFileEmpty(requiredFile.path)
            }
            guard Int64(values.fileSize ?? 0) == requiredFile.size else {
                throw VideoModelPackageError.requiredFileSizeMismatch(requiredFile.path)
            }
            guard try sha256(for: fileURL).caseInsensitiveCompare(requiredFile.sha256) == .orderedSame else {
                throw VideoModelPackageError.requiredFileHashMismatch(requiredFile.path)
            }
            totalBytes += requiredFile.size
        }

        return VideoModelPackageInspection(
            manifest: manifest,
            packageType: .localDiffusionVideoV1,
            totalBytes: totalBytes
        )
    }

    private static func validatedRelativeFileURL(
        _ path: String,
        packageURL: URL,
        resolvedRoot: URL
    ) throws -> URL {
        let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\\"),
              !components.contains("."),
              !components.contains(".."),
              !components.contains(where: \.isEmpty) else {
            throw VideoModelPackageError.unsafeRelativePath(path)
        }

        let fileURL = packageURL.appendingPathComponent(path, isDirectory: false)
        guard isSafeFileURL(fileURL, inside: resolvedRoot) else {
            throw VideoModelPackageError.unsafeRelativePath(path)
        }
        return fileURL
    }

    private static func isSafeFileURL(_ fileURL: URL, inside resolvedRoot: URL) -> Bool {
        let resolvedFile = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        let rootComponents = resolvedRoot.pathComponents
        let fileComponents = resolvedFile.pathComponents
        return fileComponents.count > rootComponents.count
            && fileComponents.prefix(rootComponents.count).elementsEqual(rootComponents)
    }

    private static func normalizedTags(_ values: [String]) -> [String] {
        var result: [String] = []
        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !result.contains(normalized) else { continue }
            result.append(normalized)
        }
        return result
    }

    private static func sha256(for fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { byte in
            let hex = String(byte, radix: 16)
            return hex.count == 1 ? "0\(hex)" : hex
        }.joined()
    }
}
