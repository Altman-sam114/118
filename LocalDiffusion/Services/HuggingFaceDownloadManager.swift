import Foundation

struct ModelDownloadProgress: Equatable {
    var fraction: Double
    var downloadedBytes: Int64
    var totalBytes: Int64
    var status: ModelDownloadStatus
    var message: String?

    var percentageText: String {
        "\(Int((fraction * 100).rounded()))%"
    }
}

struct HuggingFaceURLBuilder {
    static func downloadURL(repository: String, filename: String, revision: String) -> URL? {
        if let directURL = URL(string: filename), directURL.scheme?.hasPrefix("http") == true {
            return normalizedDirectDownloadURL(directURL)
        }

        let repo = repository.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let ref = revision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "main" : revision
        guard !repo.isEmpty, !path.isEmpty else { return nil }

        let escapedPath = path
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")

        return URL(string: "https://huggingface.co/\(repo)/resolve/\(ref)/\(escapedPath)")
    }

    private static func normalizedDirectDownloadURL(_ url: URL) -> URL {
        guard url.host?.lowercased().contains("huggingface.co") == true else {
            return url
        }

        var components = url.pathComponents
        guard let markerIndex = components.firstIndex(of: "blob") else {
            return url
        }

        components[markerIndex] = "resolve"
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.path = components.joined(separator: "/").replacingOccurrences(of: "//", with: "/")
        return urlComponents?.url ?? url
    }
}

private struct DownloadTaskDescriptor: Codable {
    var modelID: UUID
    var destinationPath: String

    init(modelID: UUID, destinationURL: URL) {
        self.modelID = modelID
        self.destinationPath = destinationURL.path
    }

    init?(taskDescription: String?) {
        guard let taskDescription,
              let data = taskDescription.data(using: .utf8),
              let descriptor = try? JSONDecoder().decode(DownloadTaskDescriptor.self, from: data) else {
            return nil
        }
        self = descriptor
    }

    var taskDescription: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}

@MainActor
final class HuggingFaceDownloadManager: NSObject, ObservableObject {
    @Published private(set) var progressByModelID: [UUID: ModelDownloadProgress] = [:]
    var onModelStateChange: (() -> Void)?

    private let fileStore: AppFileStore
    private var tasksByModelID: [UUID: URLSessionDownloadTask] = [:]
    private var resumeDataByModelID: [UUID: Data] = [:]
    private var liveModelsByID: [UUID: LocalModel] = [:]
    private var lastProgressPersistenceByModelID: [UUID: Date] = [:]
    private var removedModelIDs: Set<UUID> = []
    private let progressPersistenceInterval: TimeInterval = 1

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    init(fileStore: AppFileStore) {
        self.fileStore = fileStore
        super.init()
    }

    func progress(for model: LocalModel) -> ModelDownloadProgress {
        progressByModelID[model.id] ?? ModelDownloadProgress(
            fraction: model.totalBytes > 0 ? Double(model.downloadedBytes) / Double(model.totalBytes) : (model.isReady ? 1 : 0),
            downloadedBytes: model.downloadedBytes,
            totalBytes: model.totalBytes,
            status: model.status,
            message: model.lastError
        )
    }

    func hasActiveDownload(for model: LocalModel) -> Bool {
        tasksByModelID[model.id] != nil
    }

    func hasResumeData(for model: LocalModel) -> Bool {
        resumeDataByModelID[model.id] != nil || fileStore.resumeData(forModelFilename: model.localFilename) != nil
    }

    func start(_ model: LocalModel) {
        guard tasksByModelID[model.id] == nil else { return }
        removedModelIDs.remove(model.id)
        liveModelsByID[model.id] = model

        guard let url = URL(string: model.sourceURLString) else {
            resumeDataByModelID[model.id] = nil
            try? fileStore.removeResumeData(forModelFilename: model.localFilename)
            mark(modelID: model.id, as: .failed, message: "Invalid source URL")
            return
        }

        model.status = .downloading
        model.lastError = nil
        notifyModelStateChanged()
        progressByModelID[model.id] = ModelDownloadProgress(
            fraction: 0,
            downloadedBytes: model.downloadedBytes,
            totalBytes: model.totalBytes,
            status: .downloading,
            message: nil
        )

        let destinationURL = fileStore.modelURL(for: model.localFilename)
        let task: URLSessionDownloadTask
        if let resumeData = resumeDataByModelID.removeValue(forKey: model.id) {
            task = session.downloadTask(withResumeData: resumeData)
        } else if let resumeData = fileStore.resumeData(forModelFilename: model.localFilename) {
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            task = session.downloadTask(with: url)
        }
        task.taskDescription = DownloadTaskDescriptor(modelID: model.id, destinationURL: destinationURL).taskDescription
        tasksByModelID[model.id] = task
        lastProgressPersistenceByModelID[model.id] = nil
        task.resume()
    }

    func pause(_ model: LocalModel) {
        let modelID = model.id
        guard let task = tasksByModelID[modelID] else { return }
        task.cancel { [weak self] data in
            Task { @MainActor in
                guard let self else { return }
                guard !self.removedModelIDs.contains(modelID) else {
                    self.tasksByModelID[modelID] = nil
                    self.resumeDataByModelID[modelID] = nil
                    self.lastProgressPersistenceByModelID[modelID] = nil
                    self.progressByModelID[modelID] = nil
                    return
                }

                self.tasksByModelID[modelID] = nil
                self.resumeDataByModelID[modelID] = data
                self.lastProgressPersistenceByModelID[modelID] = nil

                let liveModel = self.liveModelsByID[modelID]
                if let data, let localFilename = liveModel?.localFilename {
                    do {
                        try self.fileStore.saveResumeData(data, forModelFilename: localFilename)
                        liveModel?.lastError = nil
                    } catch {
                        liveModel?.lastError = "Paused, but resume data could not be saved: \(error.localizedDescription)"
                    }
                } else if let localFilename = liveModel?.localFilename {
                    try? self.fileStore.removeResumeData(forModelFilename: localFilename)
                }
                liveModel?.status = .paused
                self.notifyModelStateChanged()

                var progress = liveModel.map { self.progress(for: $0) } ?? self.progressByModelID[modelID] ?? ModelDownloadProgress(
                    fraction: 0,
                    downloadedBytes: 0,
                    totalBytes: 0,
                    status: .paused,
                    message: "Paused"
                )
                progress.status = .paused
                progress.message = liveModel?.lastError ?? "Paused"
                self.progressByModelID[modelID] = progress
            }
        }
    }

    func resume(_ model: LocalModel) {
        start(model)
    }

    func cancel(_ model: LocalModel) {
        tasksByModelID[model.id]?.cancel()
        tasksByModelID[model.id] = nil
        resumeDataByModelID[model.id] = nil
        lastProgressPersistenceByModelID[model.id] = nil
        try? fileStore.removeResumeData(forModelFilename: model.localFilename)
        model.status = .queued
        model.lastError = nil
        progressByModelID[model.id] = nil
        notifyModelStateChanged()
    }

    func prepareForDeletion(_ model: LocalModel) {
        removedModelIDs.insert(model.id)
        tasksByModelID[model.id]?.cancel()
        tasksByModelID[model.id] = nil
        resumeDataByModelID[model.id] = nil
        liveModelsByID[model.id] = nil
        lastProgressPersistenceByModelID[model.id] = nil
        progressByModelID[model.id] = nil
        try? fileStore.removeResumeData(forModelFilename: model.localFilename)
    }

    func keepAfterFailedDeletion(_ model: LocalModel, message: String) {
        removedModelIDs.remove(model.id)
        liveModelsByID[model.id] = model
        model.status = .failed
        model.lastError = message
        notifyModelStateChanged()
    }

    private func handleProgress(modelID: UUID, downloadedBytes: Int64, totalBytes: Int64) {
        guard !removedModelIDs.contains(modelID) else { return }

        let knownTotalBytes = totalBytes > 0
            ? totalBytes
            : max(
                progressByModelID[modelID]?.totalBytes ?? 0,
                liveModelsByID[modelID]?.totalBytes ?? 0
            )
        let fraction = knownTotalBytes > 0 ? min(max(Double(downloadedBytes) / Double(knownTotalBytes), 0), 1) : 0
        progressByModelID[modelID] = ModelDownloadProgress(
            fraction: fraction,
            downloadedBytes: downloadedBytes,
            totalBytes: knownTotalBytes,
            status: .downloading,
            message: nil
        )

        guard let model = liveModelsByID[modelID] else { return }
        model.downloadedBytes = downloadedBytes
        if knownTotalBytes > 0 {
            model.totalBytes = knownTotalBytes
        }
        model.status = .downloading
        persistProgressIfNeeded(modelID: modelID)
    }

    private func finish(modelID: UUID, size: Int64, destinationURL: URL) {
        tasksByModelID[modelID] = nil
        resumeDataByModelID[modelID] = nil
        lastProgressPersistenceByModelID[modelID] = nil

        if removedModelIDs.contains(modelID) {
            try? FileManager.default.removeItem(at: destinationURL)
            return
        }

        if let model = liveModelsByID[modelID] {
            try? fileStore.removeResumeData(forModelFilename: model.localFilename)
            model.downloadedBytes = size
            model.totalBytes = max(model.totalBytes, size)
            model.status = .ready
            model.lastError = nil
        }
        notifyModelStateChanged()

        progressByModelID[modelID] = ModelDownloadProgress(
            fraction: 1,
            downloadedBytes: size,
            totalBytes: size,
            status: .ready,
            message: nil
        )
    }

    private func mark(
        modelID: UUID,
        as status: ModelDownloadStatus,
        message: String?,
        preserveResumeData: Bool = false
    ) {
        guard !removedModelIDs.contains(modelID) else {
            tasksByModelID[modelID] = nil
            if !preserveResumeData {
                resumeDataByModelID[modelID] = nil
            }
            lastProgressPersistenceByModelID[modelID] = nil
            progressByModelID[modelID] = nil
            return
        }

        tasksByModelID[modelID] = nil
        if !preserveResumeData {
            resumeDataByModelID[modelID] = nil
        }
        lastProgressPersistenceByModelID[modelID] = nil
        if let model = liveModelsByID[modelID] {
            model.status = status
            model.lastError = message
        }
        notifyModelStateChanged()
        var progress = progressByModelID[modelID] ?? ModelDownloadProgress(
            fraction: 0,
            downloadedBytes: 0,
            totalBytes: 0,
            status: status,
            message: message
        )
        progress.status = status
        progress.message = message
        progressByModelID[modelID] = progress
    }

    private func notifyModelStateChanged() {
        onModelStateChange?()
    }

    private func persistProgressIfNeeded(modelID: UUID) {
        let now = Date()
        if let lastPersistence = lastProgressPersistenceByModelID[modelID],
           now.timeIntervalSince(lastPersistence) < progressPersistenceInterval {
            return
        }

        lastProgressPersistenceByModelID[modelID] = now
        notifyModelStateChanged()
    }

    private func saveResumeData(_ data: Data, for modelID: UUID) -> String? {
        guard !removedModelIDs.contains(modelID) else { return nil }

        resumeDataByModelID[modelID] = data

        guard let model = liveModelsByID[modelID] else { return nil }
        do {
            try fileStore.saveResumeData(data, forModelFilename: model.localFilename)
            return nil
        } catch {
            return "Resume data could not be saved: \(error.localizedDescription)"
        }
    }
}

extension HuggingFaceDownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let descriptor = DownloadTaskDescriptor(taskDescription: downloadTask.taskDescription) else { return }
        Task { @MainActor in
            self.handleProgress(
                modelID: descriptor.modelID,
                downloadedBytes: totalBytesWritten,
                totalBytes: max(totalBytesExpectedToWrite, 0)
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let descriptor = DownloadTaskDescriptor(taskDescription: downloadTask.taskDescription) else { return }

        let destinationURL = URL(fileURLWithPath: descriptor.destinationPath)
        do {
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableDestination = destinationURL
            try mutableDestination.setResourceValues(resourceValues)
            let size = (try fileManager.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value ?? 0

            Task { @MainActor in
                self.finish(modelID: descriptor.modelID, size: size, destinationURL: destinationURL)
            }
        } catch {
            Task { @MainActor in
                self.mark(modelID: descriptor.modelID, as: .failed, message: error.localizedDescription)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error,
              (error as NSError).code != NSURLErrorCancelled,
              let descriptor = DownloadTaskDescriptor(taskDescription: task.taskDescription) else {
            return
        }

        let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data

        Task { @MainActor in
            var message = error.localizedDescription
            var preserveResumeData = false

            if let resumeData {
                preserveResumeData = true
                if let resumeSaveMessage = self.saveResumeData(resumeData, for: descriptor.modelID) {
                    message = "\(message). \(resumeSaveMessage)"
                }
            }

            self.mark(
                modelID: descriptor.modelID,
                as: .failed,
                message: message,
                preserveResumeData: preserveResumeData
            )
        }
    }
}
