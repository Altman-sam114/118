import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ModelLibraryView: View {
    let fileStore: AppFileStore

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var downloads: HuggingFaceDownloadManager
    @Query(sort: \LocalModel.updatedAt, order: .reverse) private var models: [LocalModel]
    @State private var showingAddModel = false
    @State private var modelDirectoryBytes: Int64 = 0
    @State private var showingModelFileImporter = false
    @State private var isImportingModelFile = false
    @State private var pendingModelDeletion: ModelDeletionState?
    @State private var pendingUntrackedModelDeletion: UntrackedModelFile?
    @State private var importingUntrackedModel: UntrackedModelFile?
    @State private var inspectedModel: LocalModel?
    @State private var deleteErrorMessage: String?
    @State private var untrackedModelFiles: [UntrackedModelFile] = []

    private var readyModels: [LocalModel] {
        models.filter(\.isReady)
    }

    private var trackedModelBytes: Int64 {
        readyModels.reduce(0) { $0 + $1.downloadedBytes }
    }

    private var untrackedModelBytes: Int64 {
        untrackedModelFiles.reduce(0) { $0 + $1.bytes }
    }

    var body: some View {
        NavigationStack {
            List {
                if models.isEmpty, untrackedModelFiles.isEmpty {
                    VStack(spacing: 12) {
                        EmptyStateView(
                            systemImage: "shippingbox",
                            title: "No models",
                            message: "Add a Hugging Face GGUF model to begin."
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Model Library empty state")
                        .accessibilityValue("No tracked models or untracked GGUF files.")
                        .accessibilityHint("Use Download from Hugging Face or Import GGUF File to add a local model.")

                        Button {
                            showingAddModel = true
                        } label: {
                            Label("Download from Hugging Face", systemImage: "arrow.down")
                        }
                        .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.mint))
                        .accessibilityHint("Opens the Hugging Face model download form.")

                        Button {
                            showingModelFileImporter = true
                        } label: {
                            Label("Import GGUF File", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(SciFiSecondaryButtonStyle())
                        .accessibilityValue(isImportingModelFile ? "Importing" : "Ready")
                        .accessibilityHint("Opens a file picker for a local GGUF model file.")
                        .disabled(isImportingModelFile)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    storageSections
                }
            }
            .navigationTitle("Models")
            .sciFiScreen()
            .bottomTabBarClearance()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        reconcileModelFiles()
                    } label: {
                        Label("Refresh Storage", systemImage: "arrow.clockwise")
                    }
                    .accessibilityHint("Checks the model directory and refreshes tracked and untracked GGUF file status.")
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddModel = true
                        } label: {
                            Label("Download from Hugging Face", systemImage: "arrow.down")
                        }
                        .accessibilityHint("Opens the Hugging Face GGUF model download form.")

                        Button {
                            showingModelFileImporter = true
                        } label: {
                            Label("Import GGUF File", systemImage: "square.and.arrow.down")
                        }
                        .accessibilityValue(isImportingModelFile ? "Importing" : "Ready")
                        .accessibilityHint("Opens a file picker for a local GGUF model file.")
                        .disabled(isImportingModelFile)
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .accessibilityLabel("Add model options")
                    .accessibilityValue(isImportingModelFile ? "Importing" : "Ready")
                    .accessibilityHint("Opens options to download a Hugging Face GGUF model or import a local GGUF file.")
                }
            }
            .sheet(isPresented: $showingAddModel) {
                AddModelView(fileStore: fileStore, existingModels: models) { model in
                    modelContext.insert(model)
                    try? modelContext.save()
                    downloads.start(model)
                }
            }
            .fileImporter(
                isPresented: $showingModelFileImporter,
                allowedContentTypes: [UTType(filenameExtension: "gguf") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleModelFileImport(result)
            }
            .sheet(item: $importingUntrackedModel) { file in
                UntrackedModelImportEditor(file: file) { name, family in
                    importUntrackedModel(file, name: name, family: family)
                    importingUntrackedModel = nil
                }
            }
            .sheet(item: $inspectedModel) { model in
                ModelDetailView(
                    model: model,
                    progress: downloads.progress(for: model),
                    localURL: fileStore.modelURL(for: model.localFilename),
                    fileExists: fileStore.fileExists(at: fileStore.modelURL(for: model.localFilename)),
                    diskBytes: fileStore.fileSize(at: fileStore.modelURL(for: model.localFilename)),
                    availableModelFilenames: trackedAuxiliaryModelFilenames(for: model)
                ) {
                    startOrResume(model)
                } pause: {
                    downloads.pause(model)
                    try? modelContext.save()
                } cancel: {
                    downloads.cancel(model)
                    try? modelContext.save()
                } delete: {
                    requestDeleteModels([model])
                }
            }
            .onAppear {
                reconcileModelFiles()
            }
            .confirmationDialog("Delete model?", isPresented: modelDeleteBinding, titleVisibility: .visible) {
                Button(modelDeleteButtonTitle, role: .destructive) {
                    performPendingModelDeletion()
                }
                .accessibilityLabel(Text(modelDeleteAccessibilityLabel))
                .accessibilityValue(Text(modelDeleteAccessibilityValue))
                .accessibilityHint(Text(modelDeleteAccessibilityHint))

                Button("Cancel", role: .cancel) {
                    pendingModelDeletion = nil
                }
                .accessibilityLabel(Text(modelDeleteCancelAccessibilityLabel))
                .accessibilityValue(Text(modelDeleteAccessibilityValue))
                .accessibilityHint(Text(modelDeleteCancelAccessibilityHint))
            } message: {
                Text(modelDeleteMessage)
            }
            .confirmationDialog("Delete untracked model file?", isPresented: untrackedModelDeleteBinding, titleVisibility: .visible) {
                Button("Delete File", role: .destructive) {
                    performPendingUntrackedModelDeletion()
                }
                .accessibilityLabel(Text("Delete untracked model file: \(pendingUntrackedModelFilename)"))
                .accessibilityValue(Text(pendingUntrackedModelFilename))
                .accessibilityHint(Text("Removes this untracked GGUF file from Application Support. It is not connected to model metadata."))

                Button("Cancel", role: .cancel) {
                    pendingUntrackedModelDeletion = nil
                }
                .accessibilityLabel(Text("Cancel deleting untracked model file: \(pendingUntrackedModelFilename)"))
                .accessibilityValue(Text(pendingUntrackedModelFilename))
                .accessibilityHint(Text("Keeps this local file and closes the delete confirmation."))
            } message: {
                Text(untrackedModelDeleteMessage)
            }
            .alert("Model Storage", isPresented: deleteErrorBinding) {
                Button("OK", role: .cancel) {
                    deleteErrorMessage = nil
                }
            } message: {
                Text(deleteErrorMessage ?? "")
            }
            .overlay {
                if isImportingModelFile {
                    ProgressView("Importing model file")
                        .padding()
                        .foregroundStyle(SciFiTheme.primaryText)
                        .background(SciFiTheme.panelStrong, in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(SciFiTheme.cyan.opacity(0.35), lineWidth: 1)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var storageSections: some View {
        Section {
            StorageSummaryRow(
                readyCount: readyModels.count,
                totalCount: models.count,
                trackedBytes: trackedModelBytes,
                directoryBytes: modelDirectoryBytes,
                untrackedCount: untrackedModelFiles.count,
                untrackedBytes: untrackedModelBytes
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 8, trailing: 16))
        }

        if !models.isEmpty {
            Section("Downloaded Models") {
                ForEach(models) { model in
                    ModelRow(model: model, progress: downloads.progress(for: model)) {
                        startOrResume(model)
                    } pause: {
                        downloads.pause(model)
                        try? modelContext.save()
                    } cancel: {
                        downloads.cancel(model)
                        try? modelContext.save()
                    } delete: {
                        requestDeleteModels([model])
                    } details: {
                        inspectedModel = model
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .onDelete(perform: deleteModels)
            }
        }

        if !untrackedModelFiles.isEmpty {
            Section("Untracked Files") {
                ForEach(untrackedModelFiles) { file in
                    UntrackedModelFileRow(file: file) {
                        importingUntrackedModel = file
                    } delete: {
                        pendingUntrackedModelDeletion = file
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
    }

    private func startOrResume(_ model: LocalModel) {
        if model.status == .paused {
            downloads.resume(model)
        } else {
            downloads.start(model)
        }
        try? modelContext.save()
    }

    private func deleteModels(at offsets: IndexSet) {
        requestDeleteModels(offsets.map { models[$0] })
    }

    private func requestDeleteModels(_ selectedModels: [LocalModel]) {
        guard !selectedModels.isEmpty else { return }
        pendingModelDeletion = ModelDeletionState(models: selectedModels)
    }

    private func performPendingModelDeletion() {
        guard let deletion = pendingModelDeletion else { return }

        var deletedAnyModel = false
        var failedDeletions: [String] = []

        for modelID in deletion.modelIDs {
            guard let model = models.first(where: { $0.id == modelID }) else { continue }

            do {
                downloads.prepareForDeletion(model)
                try fileStore.removeModelFile(named: model.localFilename)
                try? fileStore.removeResumeData(forModelFilename: model.localFilename)
                modelContext.delete(model)
                deletedAnyModel = true
            } catch {
                let message = "Could not delete local model file: \(error.localizedDescription)"
                downloads.keepAfterFailedDeletion(model, message: message)
                failedDeletions.append("\(model.name): \(message)")
            }
        }

        if deletedAnyModel {
            try? modelContext.save()
            refreshStorageUsage()
            refreshUntrackedModelFiles()
        }

        if failedDeletions.isEmpty {
            self.pendingModelDeletion = nil
        } else {
            self.pendingModelDeletion = nil
            deleteErrorMessage = failedDeletions.joined(separator: "\n")
        }
    }

    private func reconcileModelFiles() {
        var changed = false

        for model in models {
            let url = fileStore.modelURL(for: model.localFilename)
            let size = fileStore.fileSize(at: url)

            if fileStore.fileExists(at: url), size > 0 {
                if model.downloadedBytes != size {
                    model.downloadedBytes = size
                    changed = true
                }
                if model.totalBytes < size {
                    model.totalBytes = size
                    changed = true
                }
                if model.status != .ready {
                    model.status = .ready
                    model.lastError = nil
                    changed = true
                }
            } else if model.status == .ready {
                model.downloadedBytes = 0
                model.status = .failed
                model.lastError = "The model file is missing from Application Support."
                changed = true
            } else if model.status == .downloading, !downloads.hasActiveDownload(for: model) {
                if downloads.hasResumeData(for: model) {
                    model.status = .paused
                    model.lastError = "Download was interrupted. Tap resume to continue."
                } else {
                    model.downloadedBytes = 0
                    model.status = .queued
                    model.lastError = "Download was interrupted. Tap download to restart."
                }
                changed = true
            } else if model.status == .paused, !downloads.hasResumeData(for: model) {
                model.downloadedBytes = 0
                model.status = .queued
                model.lastError = "Resume data is unavailable. Tap download to restart."
                changed = true
            }
        }

        refreshStorageUsage()
        refreshUntrackedModelFiles()

        if changed {
            try? modelContext.save()
        }
    }

    private func refreshStorageUsage() {
        modelDirectoryBytes = fileStore.modelDirectorySize()
    }

    private func refreshUntrackedModelFiles() {
        let trackedFilenames = Set(models.map(\.localFilename))
        guard let filenames = try? fileStore.modelFilenames() else {
            untrackedModelFiles = []
            return
        }

        untrackedModelFiles = filenames
            .filter { !trackedFilenames.contains($0) }
            .map { filename in
                let url = fileStore.modelURL(for: filename)
                return UntrackedModelFile(
                    filename: filename,
                    bytes: fileStore.fileSize(at: url)
                )
            }
            .sorted { $0.filename < $1.filename }
    }

    private func performPendingUntrackedModelDeletion() {
        guard let pendingUntrackedModelDeletion else { return }

        do {
            try fileStore.removeModelFile(named: pendingUntrackedModelDeletion.filename)
            self.pendingUntrackedModelDeletion = nil
            refreshStorageUsage()
            refreshUntrackedModelFiles()
        } catch {
            self.pendingUntrackedModelDeletion = nil
            deleteErrorMessage = "\(pendingUntrackedModelDeletion.filename): Could not delete local model file: \(error.localizedDescription)"
        }
    }

    private func handleModelFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let sourceURL = try result.get().first else { return }
            isImportingModelFile = true
            let fileStore = fileStore

            Task {
                do {
                    let filename = try await Task.detached(priority: .utility) {
                        try fileStore.importModelFile(from: sourceURL)
                    }.value

                    refreshStorageUsage()
                    refreshUntrackedModelFiles()
                    if let importedFile = untrackedModelFiles.first(where: { $0.filename == filename }) {
                        importingUntrackedModel = importedFile
                    }
                } catch {
                    deleteErrorMessage = "Could not import model file: \(error.localizedDescription)"
                }
                isImportingModelFile = false
            }
        } catch {
            deleteErrorMessage = "Could not import model file: \(error.localizedDescription)"
        }
    }

    private func importUntrackedModel(_ file: UntrackedModelFile, name: String, family: ModelFamily) {
        guard !models.contains(where: { $0.localFilename == file.filename }) else {
            deleteErrorMessage = "\(file.filename) is already tracked in the model library."
            refreshUntrackedModelFiles()
            return
        }

        let modelURL = fileStore.modelURL(for: file.filename)
        let size = fileStore.fileSize(at: modelURL)
        guard fileStore.fileExists(at: modelURL), size > 0 else {
            deleteErrorMessage = "\(file.filename) is missing or empty."
            refreshUntrackedModelFiles()
            return
        }

        let model = LocalModel(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            family: family,
            sourceRepository: "Local Import",
            sourceFilename: file.filename,
            sourceRevision: "",
            sourceURLString: modelURL.absoluteString,
            localFilename: file.filename,
            downloadedBytes: size,
            totalBytes: size,
            status: .ready
        )
        modelContext.insert(model)

        do {
            try modelContext.save()
            refreshStorageUsage()
            refreshUntrackedModelFiles()
        } catch {
            modelContext.delete(model)
            try? modelContext.save()
            deleteErrorMessage = "Could not import \(file.filename): \(error.localizedDescription)"
        }
    }

    private func trackedAuxiliaryModelFilenames(for model: LocalModel) -> [String] {
        models
            .filter { $0.id != model.id && $0.status == .ready }
            .map(\.localFilename)
            .sorted()
    }

    private var modelDeleteBinding: Binding<Bool> {
        Binding(
            get: { pendingModelDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingModelDeletion = nil
                }
            }
        )
    }

    private var modelDeleteButtonTitle: String {
        guard let pendingModelDeletion else { return "Delete Model" }
        return pendingModelDeletion.modelIDs.count == 1 ? "Delete Model" : "Delete Models"
    }

    private var modelDeleteMessage: String {
        guard let pendingModelDeletion else {
            return "This removes the model metadata and local file from Application Support."
        }

        if pendingModelDeletion.modelIDs.count == 1 {
            let name = pendingModelDeletion.names.first ?? "this model"
            return "This removes \(name) and its local file from Application Support."
        }

        return "This removes \(pendingModelDeletion.modelIDs.count) models and their local files from Application Support."
    }

    private var modelDeleteAccessibilityLabel: String {
        guard let pendingModelDeletion else { return "Delete model" }
        if pendingModelDeletion.modelIDs.count == 1 {
            return "Delete model: \(pendingModelDeletion.names.first ?? "Unavailable model")"
        }
        return "Delete \(pendingModelDeletion.modelIDs.count) models"
    }

    private var modelDeleteCancelAccessibilityLabel: String {
        guard let pendingModelDeletion else { return "Cancel deleting model" }
        if pendingModelDeletion.modelIDs.count == 1 {
            return "Cancel deleting model: \(pendingModelDeletion.names.first ?? "Unavailable model")"
        }
        return "Cancel deleting \(pendingModelDeletion.modelIDs.count) models"
    }

    private var modelDeleteAccessibilityValue: String {
        guard let pendingModelDeletion else { return "No pending model deletion" }
        if pendingModelDeletion.modelIDs.count == 1 {
            return pendingModelDeletion.names.first ?? "Unavailable model"
        }
        return "\(pendingModelDeletion.modelIDs.count) models: \(pendingModelDeletion.names.joined(separator: ", "))"
    }

    private var modelDeleteAccessibilityHint: String {
        guard let pendingModelDeletion else {
            return "Removes model metadata and the local file from Application Support."
        }
        if pendingModelDeletion.modelIDs.count == 1 {
            return "Removes this model's metadata and local file from Application Support."
        }
        return "Removes the selected model metadata and local files from Application Support."
    }

    private var modelDeleteCancelAccessibilityHint: String {
        guard let pendingModelDeletion else {
            return "Closes the delete confirmation and keeps model metadata and local files."
        }
        if pendingModelDeletion.modelIDs.count == 1 {
            return "Closes the delete confirmation and keeps this model's metadata and local file."
        }
        return "Closes the delete confirmation and keeps the selected model metadata and local files."
    }

    private var deleteErrorBinding: Binding<Bool> {
        Binding(
            get: { deleteErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    deleteErrorMessage = nil
                }
            }
        )
    }

    private var untrackedModelDeleteBinding: Binding<Bool> {
        Binding(
            get: { pendingUntrackedModelDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingUntrackedModelDeletion = nil
                }
            }
        )
    }

    private var untrackedModelDeleteMessage: String {
        guard let pendingUntrackedModelDeletion else {
            return "This removes an app-managed GGUF file that is not connected to model metadata."
        }

        return "This removes \(pendingUntrackedModelDeletion.filename) from Application Support."
    }

    private var pendingUntrackedModelFilename: String {
        pendingUntrackedModelDeletion?.filename ?? "Unavailable file"
    }
}

private struct ModelDeletionState: Identifiable {
    let modelIDs: [UUID]
    let names: [String]

    init(models: [LocalModel]) {
        self.modelIDs = models.map(\.id)
        self.names = models.map(\.name)
    }

    var id: String {
        modelIDs.map(\.uuidString).joined(separator: "-")
    }
}

private struct UntrackedModelFile: Identifiable, Equatable {
    let filename: String
    let bytes: Int64

    var id: String {
        filename
    }
}

private struct StorageSummaryRow: View {
    let readyCount: Int
    let totalCount: Int
    let trackedBytes: Int64
    let directoryBytes: Int64
    let untrackedCount: Int
    let untrackedBytes: Int64

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Tracked")
                    Text(trackedText)
                        .foregroundStyle(SciFiTheme.primaryText)
                }
                GridRow {
                    Text("On Disk")
                    Text(directoryText)
                        .foregroundStyle(SciFiTheme.primaryText)
                }
                GridRow {
                    Text("Untracked")
                    Text(untrackedText)
                        .foregroundStyle(untrackedCount == 0 ? SciFiTheme.secondaryText : SciFiTheme.amber)
                }
            }
            .font(.caption)
            .foregroundStyle(SciFiTheme.secondaryText)
        }
        .padding(14)
        .sciFiPanel(isHighlighted: readyCount > 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Model storage summary")
        .accessibilityValue(accessibilitySummaryValue)
        .accessibilityHint("Summarizes tracked, on-disk, and untracked model storage.")
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                titleBlock
                readyPill
            }
        } else {
            HStack {
                titleBlock
                Spacer(minLength: 12)
                readyPill
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Storage Matrix")
                .font(.headline)
                .foregroundStyle(SciFiTheme.primaryText)
            Text("\(totalCount) tracked models")
                .font(.caption)
                .foregroundStyle(SciFiTheme.secondaryText)
        }
    }

    private var readyPill: some View {
        SciFiStatusPill(
            title: "\(readyCount) ready",
            systemImage: "checkmark.circle",
            color: readyCount == 0 ? SciFiTheme.amber : SciFiTheme.mint
        )
    }

    private var trackedText: String {
        ByteCountFormatter.fileSizeString(trackedBytes)
    }

    private var directoryText: String {
        ByteCountFormatter.fileSizeString(directoryBytes)
    }

    private var untrackedText: String {
        "\(untrackedCount) files, \(ByteCountFormatter.fileSizeString(untrackedBytes))"
    }

    private var accessibilitySummaryValue: String {
        "\(readyCount) of \(totalCount) tracked models ready. Tracked storage \(trackedText). On disk \(directoryText). Untracked \(untrackedText)."
    }
}

private struct UntrackedModelFileRow: View {
    let file: UntrackedModelFile
    let importFile: () -> Void
    let delete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        rowContent
        .padding(12)
        .sciFiPanel()
    }

    @ViewBuilder
    private var rowContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                fileInfo
                actions
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                fileInfo
                Spacer()
                actions
            }
        }
    }

    private var fileInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(file.filename)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SciFiTheme.primaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            Text(fileSizeText)
                .font(.caption)
                .foregroundStyle(SciFiTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Untracked model file")
        .accessibilityValue(fileAccessibilityValue)
        .accessibilityHint("Import this file into the model library or delete it from local storage.")
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: importFile) {
                Label("Import Untracked Model", systemImage: "plus.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.mint))
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(importAccessibilityLabel)
            .accessibilityHint(importAccessibilityHint)

            Button(role: .destructive, action: delete) {
                Label("Delete Untracked Model File", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.danger))
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(deleteAccessibilityLabel)
            .accessibilityHint(deleteAccessibilityHint)
        }
    }

    private var fileSizeText: String {
        ByteCountFormatter.fileSizeString(file.bytes)
    }

    private var fileAccessibilityValue: String {
        "\(file.filename), \(fileSizeText)"
    }

    private var importAccessibilityLabel: String {
        "Import \(file.filename)"
    }

    private var deleteAccessibilityLabel: String {
        "Delete \(file.filename)"
    }

    private var importAccessibilityHint: String {
        "Opens the import form for \(file.filename)."
    }

    private var deleteAccessibilityHint: String {
        "Shows a confirmation before deleting \(file.filename)."
    }
}

private struct UntrackedModelImportEditor: View {
    let file: UntrackedModelFile
    let onImport: (String, ModelFamily) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var family: ModelFamily

    init(file: UntrackedModelFile, onImport: @escaping (String, ModelFamily) -> Void) {
        self.file = file
        self.onImport = onImport
        let defaultName = file.filename.replacingOccurrences(
            of: ".gguf",
            with: "",
            options: [.caseInsensitive]
        )
        _name = State(initialValue: defaultName)
        _family = State(initialValue: ModelFamily.inferred(from: file.filename))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("File") {
                    LabeledContent("Name", value: file.filename)
                    LabeledContent("Size", value: ByteCountFormatter.fileSizeString(file.bytes))
                }
                .listRowBackground(SciFiTheme.panel)

                Section("Model") {
                    TextField("Display name", text: $name)
                        .accessibilityLabel(Text("Imported model display name"))
                        .accessibilityValue(Text(displayNameAccessibilityValue))
                        .accessibilityHint(Text("Required before importing and used as the model name in Models."))
                    Picker("Family", selection: $family) {
                        ForEach(ModelFamily.allCases) { family in
                            Text(family.rawValue).tag(family)
                        }
                    }
                    .accessibilityLabel(Text("Imported model family"))
                    .accessibilityValue(Text(familyAccessibilityValue))
                    .accessibilityHint(Text("Sets the model family metadata for this imported GGUF file."))
                }
                .listRowBackground(SciFiTheme.panel)
            }
            .navigationTitle("Import Model")
            .sciFiScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel(Text("Cancel model import"))
                    .accessibilityValue(Text("No model imported"))
                    .accessibilityHint(Text("Closes the import editor without adding \(file.filename) to the model library."))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport(name, family)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(Text("Import model"))
                    .accessibilityValue(Text(importAccessibilityValue))
                    .accessibilityHint(Text(importAccessibilityHint))
                }
            }
        }
    }

    private var hasDisplayName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayNameAccessibilityValue: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "No display name" : trimmedName
    }

    private var familyAccessibilityValue: String {
        family.rawValue
    }

    private var importAccessibilityValue: String {
        hasDisplayName ? "Ready" : "Display name required"
    }

    private var importAccessibilityHint: String {
        hasDisplayName
        ? "Adds \(file.filename) to the model library using the current display name and family."
        : "Enter a display name before importing \(file.filename)."
    }
}

private struct ModelRow: View {
    let model: LocalModel
    let progress: ModelDownloadProgress
    let startOrResume: () -> Void
    let pause: () -> Void
    let cancel: () -> Void
    let delete: () -> Void
    let details: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ProgressView(value: progress.fraction)
                .tint(statusColor)

            footer

            if let message = progress.message, !message.isEmpty {
                ModelMessageRow(message: message)
            }
        }
        .padding(12)
        .sciFiPanel(isHighlighted: progress.status == .downloading || progress.status == .ready)
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                modelIdentity
                statusPill
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                modelIdentity
                Spacer()
                statusPill
            }
        }
    }

    private var modelIdentity: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.name)
                .font(.headline)
                .foregroundStyle(SciFiTheme.primaryText)
            Text("\(model.family.rawValue) | \(model.sourceFilename)")
                .font(.subheadline)
                .foregroundStyle(SciFiTheme.secondaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
        }
    }

    private var statusPill: some View {
        SciFiStatusPill(title: statusText, systemImage: statusIcon, color: statusColor)
    }

    @ViewBuilder
    private var footer: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                sizeLabel
                controls
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                sizeLabel
                Spacer()
                controls
            }
        }
    }

    private var sizeLabel: some View {
        Text(sizeText)
            .font(.caption)
            .foregroundStyle(SciFiTheme.secondaryText)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            controlButton("Model Details", systemImage: "info.circle", action: details)

            switch progress.status {
            case .ready:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SciFiTheme.mint)
                    .accessibilityLabel("Ready")
                controlButton("Delete Model", systemImage: "trash", color: SciFiTheme.danger, role: .destructive, action: delete)
            case .downloading:
                controlButton("Pause Download", systemImage: "pause.fill", color: SciFiTheme.amber, action: pause)
                controlButton("Cancel Download", systemImage: "xmark", color: SciFiTheme.danger, role: .destructive, action: cancel)
                controlButton("Delete Model", systemImage: "trash", color: SciFiTheme.danger, role: .destructive, action: delete)
            case .paused:
                controlButton("Resume Download", systemImage: "play.fill", color: SciFiTheme.mint, action: startOrResume)
                controlButton("Delete Model", systemImage: "trash", color: SciFiTheme.danger, role: .destructive, action: delete)
            case .queued, .failed:
                controlButton("Download Model", systemImage: "arrow.down", action: startOrResume)
                controlButton("Delete Model", systemImage: "trash", color: SciFiTheme.danger, role: .destructive, action: delete)
            }
        }
    }

    private func controlButton(
        _ title: String,
        systemImage: String,
        color: Color = SciFiTheme.cyan,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(SciFiSecondaryButtonStyle(color: color))
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(Text("\(title): \(model.name)"))
        .accessibilityHint(Text("Applies this action to \(model.name)."))
    }

    private var statusText: String {
        switch progress.status {
        case .queued:
            "Queued"
        case .downloading:
            progress.percentageText
        case .paused:
            "Paused"
        case .ready:
            "Ready"
        case .failed:
            "Failed"
        }
    }

    private var sizeText: String {
        let downloaded = ByteCountFormatter.fileSizeString(progress.downloadedBytes)
        let total = progress.totalBytes > 0 ? ByteCountFormatter.fileSizeString(progress.totalBytes) : "Unknown size"
        return "\(downloaded) / \(total)"
    }

    private var statusColor: Color {
        switch progress.status {
        case .ready:
            SciFiTheme.mint
        case .failed:
            SciFiTheme.danger
        case .paused:
            SciFiTheme.amber
        case .downloading:
            SciFiTheme.cyan
        default:
            SciFiTheme.secondaryText
        }
    }

    private var statusIcon: String {
        switch progress.status {
        case .queued:
            "clock"
        case .downloading:
            "arrow.down.circle"
        case .paused:
            "pause.circle"
        case .ready:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle"
        }
    }
}

private struct ModelMessageRow: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .foregroundStyle(SciFiTheme.amber)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Model status message")
        .accessibilityValue(message)
        .accessibilityHint("Describes this model's download or storage status.")
    }
}

private struct ModelDetailMessageRow: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .foregroundStyle(SciFiTheme.amber)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Model detail status message")
        .accessibilityValue(message)
        .accessibilityHint("Describes this model's download or storage status in the detail view.")
    }
}

private struct ModelDetailView: View {
    let model: LocalModel
    let progress: ModelDownloadProgress
    let localURL: URL
    let fileExists: Bool
    let diskBytes: Int64
    let availableModelFilenames: [String]
    let startOrResume: () -> Void
    let pause: () -> Void
    let cancel: () -> Void
    let delete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    LabeledContent("State", value: statusText)
                    ProgressView(value: progress.fraction)
                        .tint(detailStatusColor)
                    LabeledContent("Downloaded", value: sizeText)

                    if let message = progress.message, !message.isEmpty {
                        ModelDetailMessageRow(message: message)
                    }
                }
                .listRowBackground(SciFiTheme.panel)

                Section("Model") {
                    DetailTextRow(title: "Name", value: model.name)
                    LabeledContent("Family", value: model.family.rawValue)
                    DetailTextRow(title: "Source File", value: model.sourceFilename)
                    LabeledContent("Created", value: model.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Updated", value: model.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
                .listRowBackground(SciFiTheme.panel)

                Section("Native Loading") {
                    Picker("Mode", selection: nativeLoadModeBinding) {
                        ForEach(NativeModelLoadMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .accessibilityLabel(Text("Native loading mode"))
                    .accessibilityValue(Text(model.nativeLoadMode.rawValue))
                    .accessibilityHint(Text("Choose whether \(model.name) loads as a complete model or as standalone diffusion with optional auxiliary files."))

                    DetailTextRow(title: "Mode", value: nativeLoadModeDescription)

                    auxiliaryModelPicker("CLIP-L", selection: auxiliaryFilenameBinding(\.clipLFilename))
                    auxiliaryModelPicker("CLIP-G", selection: auxiliaryFilenameBinding(\.clipGFilename))
                    auxiliaryModelPicker("T5XXL", selection: auxiliaryFilenameBinding(\.t5xxlFilename))
                    auxiliaryModelPicker("VAE", selection: auxiliaryFilenameBinding(\.vaeFilename))
                }
                .listRowBackground(SciFiTheme.panel)

                Section("Source") {
                    DetailTextRow(title: "Repository", value: model.sourceRepository.isEmpty ? "Direct URL" : model.sourceRepository)
                    DetailTextRow(title: "Revision", value: model.sourceRevision.isEmpty ? "None" : model.sourceRevision)
                    DetailTextRow(title: "URL", value: model.sourceURLString)
                }
                .listRowBackground(SciFiTheme.panel)

                Section("Storage") {
                    DetailTextRow(title: "Local File", value: model.localFilename)
                    LabeledContent("File Present", value: fileExists ? "Yes" : "No")
                    LabeledContent("Disk Size", value: ByteCountFormatter.fileSizeString(diskBytes))
                    DetailTextRow(title: "Path", value: localURL.path)
                }
                .listRowBackground(SciFiTheme.panel)

                Section {
                    detailControls
                }
                .listRowBackground(SciFiTheme.panel)
            }
            .textSelection(.enabled)
            .navigationTitle("Model Details")
            .sciFiScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func auxiliaryModelPicker(
        _ title: String,
        selection: Binding<String?>
    ) -> some View {
        Picker(title, selection: selection) {
            Text("None").tag(Optional<String>.none)
            ForEach(availableModelFilenames, id: \.self) { filename in
                Text(filename).tag(Optional(filename))
            }
        }
        .accessibilityLabel(Text("\(title) auxiliary model"))
        .accessibilityValue(Text(selection.wrappedValue ?? "None selected"))
        .accessibilityHint(Text("Select an optional \(title) GGUF file for \(model.name)'s standalone diffusion loading."))
    }

    private var nativeLoadModeBinding: Binding<NativeModelLoadMode> {
        Binding(
            get: { model.nativeLoadMode },
            set: { newValue in
                model.nativeLoadMode = newValue
                try? modelContext.save()
            }
        )
    }

    private func auxiliaryFilenameBinding(
        _ keyPath: ReferenceWritableKeyPath<LocalModel, String?>
    ) -> Binding<String?> {
        Binding(
            get: { model[keyPath: keyPath].flatMap(Self.nonEmptyFilename) },
            set: { filename in
                model[keyPath: keyPath] = Self.nonEmptyFilename(filename)
                try? modelContext.save()
            }
        )
    }

    private static func nonEmptyFilename(_ filename: String?) -> String? {
        let trimmed = filename?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var nativeLoadModeDescription: String {
        switch model.nativeLoadMode {
        case .fullModel:
            return "Use the selected file as a complete stable-diffusion.cpp model."
        case .standaloneDiffusion:
            return "Use the selected file as the diffusion model and load optional CLIP/T5/VAE files below."
        }
    }

    @ViewBuilder
    private var detailControls: some View {
        switch progress.status {
        case .ready:
            detailControlButton(
                "Delete Model",
                systemImage: "trash",
                color: SciFiTheme.danger,
                role: .destructive
            ) {
                dismiss()
                delete()
            }
        case .downloading:
            detailControlButton(
                "Pause Download",
                systemImage: "pause.fill",
                color: SciFiTheme.amber
            ) {
                pause()
            }
            detailControlButton(
                "Cancel Download",
                systemImage: "xmark",
                color: SciFiTheme.danger,
                role: .destructive
            ) {
                cancel()
            }
            detailControlButton(
                "Delete Model",
                systemImage: "trash",
                color: SciFiTheme.danger,
                role: .destructive
            ) {
                dismiss()
                delete()
            }
        case .paused:
            detailControlButton(
                "Resume Download",
                systemImage: "play.fill",
                color: SciFiTheme.mint
            ) {
                startOrResume()
            }
            detailControlButton(
                "Delete Model",
                systemImage: "trash",
                color: SciFiTheme.danger,
                role: .destructive
            ) {
                dismiss()
                delete()
            }
        case .queued, .failed:
            detailControlButton("Download Model", systemImage: "arrow.down") {
                startOrResume()
            }
            detailControlButton(
                "Delete Model",
                systemImage: "trash",
                color: SciFiTheme.danger,
                role: .destructive
            ) {
                dismiss()
                delete()
            }
        }
    }

    private func detailControlButton(
        _ title: String,
        systemImage: String,
        color: Color = SciFiTheme.cyan,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(SciFiSecondaryButtonStyle(color: color))
        .accessibilityLabel(Text("\(title): \(model.name)"))
        .accessibilityHint(Text("Applies this action to \(model.name)."))
    }

    private var statusText: String {
        switch progress.status {
        case .queued:
            "Queued"
        case .downloading:
            "Downloading \(progress.percentageText)"
        case .paused:
            "Paused"
        case .ready:
            "Ready"
        case .failed:
            "Failed"
        }
    }

    private var sizeText: String {
        let downloaded = ByteCountFormatter.fileSizeString(progress.downloadedBytes)
        let total = progress.totalBytes > 0 ? ByteCountFormatter.fileSizeString(progress.totalBytes) : "Unknown size"
        return "\(downloaded) / \(total)"
    }

    private var detailStatusColor: Color {
        switch progress.status {
        case .ready:
            SciFiTheme.mint
        case .downloading:
            SciFiTheme.cyan
        case .paused:
            SciFiTheme.amber
        case .failed:
            SciFiTheme.danger
        case .queued:
            SciFiTheme.secondaryText
        }
    }
}

private struct DetailTextRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(SciFiTheme.secondaryText)
            Text(value.isEmpty ? "None" : value)
                .font(.body)
                .foregroundStyle(SciFiTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

private struct AddModelView: View {
    let fileStore: AppFileStore
    let existingModels: [LocalModel]
    let onAdd: (LocalModel) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var repository = ""
    @State private var filename = ""
    @State private var revision = "main"
    @State private var family: ModelFamily = .sdxl
    @State private var huggingFaceURL = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Paste URL") {
                    TextField("huggingface.co/.../resolve/.../*.gguf", text: $huggingFaceURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit {
                            parseHuggingFaceURLIfReady()
                        }
                    Button {
                        parseHuggingFaceURLIfReady()
                    } label: {
                        Label("Parse Hugging Face URL", systemImage: "link")
                    }
                    .disabled(!hasHuggingFaceURL)
                    .buttonStyle(SciFiSecondaryButtonStyle())
                    .accessibilityValue(parseURLAccessibilityValue)
                    .accessibilityHint("Fills the model fields from a Hugging Face GGUF file URL.")
                }
                .listRowBackground(SciFiTheme.panel)

                Section("Hugging Face") {
                    TextField("Display name", text: $name)
                    TextField("Repository, e.g. owner/repo", text: $repository)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("GGUF file path or direct URL", text: $filename)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit {
                            submitModelIfReady()
                        }
                    TextField("Revision", text: $revision)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit {
                            submitModelIfReady()
                        }
                    Picker("Family", selection: $family) {
                        ForEach(ModelFamily.allCases) { family in
                            Text(family.rawValue).tag(family)
                        }
                    }
                }
                .listRowBackground(SciFiTheme.panel)

                if let errorMessage {
                    Section {
                        AddModelErrorRow(message: errorMessage)
                    }
                    .listRowBackground(SciFiTheme.panel)
                }
            }
            .navigationTitle("Add Model")
            .sciFiScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") {
                        submitModelIfReady()
                    }
                    .disabled(!canSubmit)
                    .accessibilityLabel("Download model")
                    .accessibilityValue(downloadAccessibilityValue)
                    .accessibilityHint("Starts the Hugging Face GGUF model download when required fields are complete.")
                }
            }
        }
    }

    private var hasHuggingFaceURL: Bool {
        !huggingFaceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var parseURLAccessibilityValue: String {
        hasHuggingFaceURL ? "Ready to parse." : "Paste a Hugging Face GGUF URL before parsing."
    }

    private var downloadAccessibilityValue: String {
        canSubmit ? "Ready to download." : "Enter a display name and GGUF file path before downloading."
    }

    private func parseHuggingFaceURLIfReady() {
        guard hasHuggingFaceURL else { return }
        applyHuggingFaceURL()
    }

    private func submitModelIfReady() {
        guard canSubmit else { return }
        addModel()
    }

    private func applyHuggingFaceURL() {
        guard let parsedURL = ParsedHuggingFaceFileURL(string: huggingFaceURL) else {
            errorMessage = "Paste a Hugging Face file URL that contains /resolve/ or /blob/ and ends in .gguf."
            return
        }

        repository = parsedURL.repository
        filename = parsedURL.filename
        revision = parsedURL.revision
        name = parsedURL.displayName
        family = parsedURL.family
        errorMessage = nil
    }

    private func addModel() {
        guard let sourceURL = HuggingFaceURLBuilder.downloadURL(
            repository: repository,
            filename: filename,
            revision: revision
        ) else {
            errorMessage = "Enter a repository and file path, or a direct Hugging Face URL."
            return
        }

        let repositoryPart = repository.isEmpty ? sourceURL.host ?? "model" : repository
        let filenamePart = sourceURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)

        guard filenamePart.lowercased().hasSuffix(".gguf") else {
            errorMessage = "Model source must resolve to a .gguf file."
            return
        }

        let localFilename = fileStore.makeModelFilename(repository: repositoryPart, filename: filenamePart)
        let normalizedSource = sourceURL.absoluteString
        let normalizedLocalFilename = localFilename.lowercased()

        if existingModels.contains(where: { $0.sourceURLString == normalizedSource }) {
            errorMessage = "This source URL is already in your model library."
            return
        }

        if existingModels.contains(where: { $0.localFilename.lowercased() == normalizedLocalFilename }) {
            errorMessage = "A model with the same local filename already exists."
            return
        }

        if fileStore.fileExists(at: fileStore.modelURL(for: localFilename)) {
            errorMessage = "A model file with this name already exists on disk."
            return
        }

        let model = LocalModel(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            family: family,
            sourceRepository: repository.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceFilename: filename.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceRevision: revision.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceURLString: sourceURL.absoluteString,
            localFilename: localFilename
        )

        onAdd(model)
        dismiss()
    }
}

private struct AddModelErrorRow: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .foregroundStyle(SciFiTheme.danger)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Add model error")
        .accessibilityValue(message)
        .accessibilityHint("Fix the model source or file information before downloading.")
    }
}

private struct ParsedHuggingFaceFileURL {
    let repository: String
    let filename: String
    let revision: String
    let displayName: String
    let family: ModelFamily

    init?(string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.host?.lowercased().contains("huggingface.co") == true else {
            return nil
        }

        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 5,
              let markerIndex = components.firstIndex(where: { $0 == "resolve" || $0 == "blob" }),
              markerIndex >= 2,
              markerIndex + 2 < components.count else {
            return nil
        }

        let repositoryParts = components[..<markerIndex]
        let revisionIndex = components.index(after: markerIndex)
        let filenameStartIndex = components.index(after: revisionIndex)
        let filenameParts = components[filenameStartIndex...]

        let path = filenameParts.joined(separator: "/")
        guard path.lowercased().hasSuffix(".gguf") else { return nil }

        self.repository = repositoryParts.joined(separator: "/")
        self.filename = path
        self.revision = components[revisionIndex]
        self.displayName = ParsedHuggingFaceFileURL.makeDisplayName(
            repository: repository,
            filename: path
        )
        self.family = ModelFamily.inferred(from: "\(repository) \(path)")
    }

    private static func makeDisplayName(repository: String, filename: String) -> String {
        let rawName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let fallbackName = repository.split(separator: "/").last.map(String.init) ?? rawName
        return rawName.isEmpty ? fallbackName : rawName
    }

}

private extension ModelFamily {
    static func inferred(from value: String) -> ModelFamily {
        let value = value.lowercased()
        if value.contains("flux") {
            return .flux
        }
        if value.contains("sdxl") || value.contains("xl") {
            return .sdxl
        }
        return .stableDiffusion
    }
}
