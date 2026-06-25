import SwiftData
import SwiftUI
import UIKit

enum GallerySort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case oldest = "Oldest"
    case model = "Model"

    var id: String { rawValue }
}

enum GalleryFilter: Hashable {
    case all
    case folder(UUID)
    case tag(String)
}

struct GalleryView: View {
    let fileStore: AppFileStore
    @Binding var focusedImageID: UUID?
    let onReuse: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var generation: GenerationViewModel
    @Query(sort: \GeneratedImage.createdAt, order: .reverse) private var images: [GeneratedImage]
    @Query(sort: \GalleryFolder.name) private var folders: [GalleryFolder]
    @Query(sort: \LocalModel.name) private var models: [LocalModel]

    @State private var filter: GalleryFilter = .all
    @State private var sort: GallerySort = .newest
    @State private var showingAddFolder = false
    @State private var editingFolder: FolderEditorState?
    @State private var pendingFolderDeletion: FolderEditorState?
    @State private var detailPath: [UUID] = []

    private var allTags: [String] {
        images.flatMap(\.tags).normalizedTags()
    }

    private var visibleImages: [GeneratedImage] {
        let filtered = images.filter { image in
            switch filter {
            case .all:
                return true
            case .folder(let id):
                return image.folderID == id
            case .tag(let tag):
                return image.tags.contains(tag)
            }
        }

        switch sort {
        case .newest:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return filtered.sorted { $0.createdAt < $1.createdAt }
        case .model:
            return filtered.sorted {
                if $0.modelName == $1.modelName {
                    return $0.createdAt > $1.createdAt
                }
                return $0.modelName < $1.modelName
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: filterBinding) {
                Label("All Images", systemImage: "square.grid.2x2")
                    .tag(GalleryFilter.all)
                    .sciFiListRow()

                Section("Folders") {
                    ForEach(folders) { folder in
                        Label(folder.name, systemImage: "folder")
                            .tag(GalleryFilter.folder(folder.id))
                            .sciFiListRow()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingFolderDeletion = FolderEditorState(folder: folder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    editingFolder = FolderEditorState(folder: folder)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .contextMenu {
                                Button {
                                    editingFolder = FolderEditorState(folder: folder)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    pendingFolderDeletion = FolderEditorState(folder: folder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }

                Section("Tags") {
                    ForEach(allTags, id: \.self) { tag in
                        Label(tag, systemImage: "tag")
                            .tag(GalleryFilter.tag(tag))
                            .sciFiListRow()
                    }
                }
            }
            .navigationTitle("Gallery")
            .sciFiScreen()
            .bottomTabBarClearance()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddFolder = true
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFolder) {
                FolderNameEditor(title: "New Folder", initialName: "") { folderName in
                    modelContext.insert(GalleryFolder(name: folderName))
                    try? modelContext.save()
                }
            }
            .sheet(item: $editingFolder) { folderState in
                FolderNameEditor(title: "Rename Folder", initialName: folderState.name) { newName in
                    renameFolder(id: folderState.id, name: newName)
                    editingFolder = nil
                }
            }
            .confirmationDialog("Delete folder?", isPresented: folderDeleteBinding) {
                Button("Delete Folder", role: .destructive) {
                    if let pendingFolderDeletion {
                        deleteFolder(id: pendingFolderDeletion.id)
                    }
                    pendingFolderDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingFolderDeletion = nil
                }
            } message: {
                Text("Images in this folder will remain in the gallery and move back to All Images.")
            }
        } detail: {
            NavigationStack(path: $detailPath) {
                Group {
                    if visibleImages.isEmpty {
                        EmptyStateView(
                            systemImage: "photo.on.rectangle",
                            title: "No images",
                            message: "Generated images will appear here."
                        )
                        .padding()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                                ForEach(visibleImages) { image in
                                    NavigationLink(value: image.id) {
                                        ImageTile(image: image, fileStore: fileStore)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                            .padding(.bottom, 20)
                        }
                    }
                }
                .navigationTitle("Images")
                .sciFiScreen()
                .bottomTabBarClearance()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            reconcileImageFiles()
                        } label: {
                            Label("Refresh Gallery", systemImage: "arrow.clockwise")
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Picker("Sort", selection: $sort) {
                            ForEach(GallerySort.allCases) { sort in
                                Text(sort.rawValue).tag(sort)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .onAppear {
                    reconcileImageFiles()
                    openFocusedImageIfAvailable()
                }
                .onChange(of: focusedImageID) {
                    openFocusedImageIfAvailable()
                }
                .onChange(of: images.map(\.id)) {
                    openFocusedImageIfAvailable()
                }
                .navigationDestination(for: UUID.self) { imageID in
                    if let image = images.first(where: { $0.id == imageID }) {
                        ImageDetailView(
                            image: image,
                            folders: folders,
                            fileStore: fileStore
                        ) {
                            generation.load(image: image)
                            onReuse()
                        } onRegenerate: {
                            generation.load(image: image)
                            let readyModels = models.filter(\.isReady)
                            let model = readyModels.first(where: { $0.id == image.modelID }) ?? readyModels.first
                            generation.selectedModelID = model?.id
                            generation.generate(using: model, modelContext: modelContext)
                            onReuse()
                        } onDelete: {
                            deleteImage(image)
                        }
                    } else {
                        EmptyStateView(
                            systemImage: "photo.badge.exclamationmark",
                            title: "Image unavailable",
                            message: "This generated image is no longer in the gallery."
                        )
                    }
                }
            }
        }
    }

    private func openFocusedImageIfAvailable() {
        guard let focusedImageID,
              images.contains(where: { $0.id == focusedImageID }) else {
            return
        }

        filter = .all
        detailPath = [focusedImageID]
        self.focusedImageID = nil
    }

    private func renameFolder(id: UUID, name: String) {
        guard let folder = folders.first(where: { $0.id == id }) else { return }
        folder.name = name
        try? modelContext.save()
    }

    private func deleteFolder(id: UUID) {
        guard let folder = folders.first(where: { $0.id == id }) else { return }
        for image in images where image.folderID == id {
            image.folderID = nil
        }
        modelContext.delete(folder)
        if filter == .folder(id) {
            filter = .all
        }
        try? modelContext.save()
    }

    private func deleteImage(_ image: GeneratedImage) {
        try? fileStore.removeImageFile(named: image.imageFilename)
        modelContext.delete(image)
        if focusedImageID == image.id {
            focusedImageID = nil
        }
        detailPath.removeAll { $0 == image.id }
        try? modelContext.save()
    }

    private func reconcileImageFiles() {
        var changed = false
        var referencedFilenames = Set<String>()

        for image in images {
            let imageURL = fileStore.imageURL(for: image.imageFilename)
            let fileExists = fileStore.fileExists(at: imageURL)
            referencedFilenames.insert(image.imageFilename)

            guard fileExists, fileStore.fileSize(at: imageURL) > 0 else {
                if fileExists {
                    try? fileStore.removeImageFile(named: image.imageFilename)
                }
                modelContext.delete(image)
                changed = true
                continue
            }
        }

        if let storedFilenames = try? fileStore.generatedImageFilenames() {
            for filename in storedFilenames where !referencedFilenames.contains(filename) {
                try? fileStore.removeImageFile(named: filename)
            }
        }

        if changed {
            try? modelContext.save()
        }
    }

    private var folderDeleteBinding: Binding<Bool> {
        Binding(
            get: { pendingFolderDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingFolderDeletion = nil
                }
            }
        )
    }

    private var filterBinding: Binding<GalleryFilter?> {
        Binding(
            get: { filter },
            set: { filter = $0 ?? .all }
        )
    }
}

private struct ImageTile: View {
    let image: GeneratedImage
    let fileStore: AppFileStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let uiImage = UIImage(contentsOfFile: fileStore.imageURL(for: image.imageFilename).path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        Text("\(image.resolvedOutputWidth)x\(image.resolvedOutputHeight)")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(SciFiTheme.cyan)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(8)
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(SciFiTheme.panelSoft)
                    .frame(height: 150)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(SciFiTheme.secondaryText)
                    }
            }

            Text(image.prompt)
                .font(.caption.weight(.medium))
                .foregroundStyle(SciFiTheme.primaryText)
                .lineLimit(2)
            HStack {
                Text(image.createdAt, style: .date)
                Spacer()
                Text(image.modelName)
                    .lineLimit(1)
            }
            .font(.caption2)
            .foregroundStyle(SciFiTheme.secondaryText)
        }
        .padding(10)
        .sciFiPanel()
    }
}

private struct ImageDetailView: View {
    let image: GeneratedImage
    let folders: [GalleryFolder]
    let fileStore: AppFileStore
    let onReuse: () -> Void
    let onRegenerate: () -> Void
    let onDelete: () -> Void

    @State private var tagText: String
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    init(
        image: GeneratedImage,
        folders: [GalleryFolder],
        fileStore: AppFileStore,
        onReuse: @escaping () -> Void,
        onRegenerate: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.image = image
        self.folders = folders
        self.fileStore = fileStore
        self.onReuse = onReuse
        self.onRegenerate = onRegenerate
        self.onDelete = onDelete
        _tagText = State(initialValue: image.tags.joined(separator: ", "))
    }

    var body: some View {
        let imageURL = fileStore.imageURL(for: image.imageFilename)

        Form {
            if let uiImage = UIImage(contentsOfFile: imageURL.path) {
                Section {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(SciFiTheme.cyan.opacity(0.26), lineWidth: 1)
                        }
                }
                .listRowBackground(SciFiTheme.panel)
            }

            Section("Parameters") {
                LabeledContent("Model", value: image.modelName)
                LabeledContent("Prompt", value: image.prompt)
                LabeledContent("Negative", value: image.negativePrompt.isEmpty ? "None" : image.negativePrompt)
                LabeledContent("Steps", value: "\(image.steps)")
                LabeledContent("CFG", value: image.cfgScale.formatted(.number.precision(.fractionLength(1))))
                LabeledContent("Seed", value: "\(image.seed)")
                LabeledContent("Requested Size", value: "\(image.width) x \(image.height)")
                LabeledContent("Output Size", value: "\(image.resolvedOutputWidth) x \(image.resolvedOutputHeight)")
                LabeledContent("Sampler", value: image.samplerRawValue)
                Button {
                    onReuse()
                } label: {
                    Label("Reuse Parameters", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(SciFiSecondaryButtonStyle())

                Button {
                    onRegenerate()
                } label: {
                    Label("Reuse and Generate", systemImage: "play.fill")
                }
                .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.mint))

                if fileStore.fileExists(at: imageURL), fileStore.fileSize(at: imageURL) > 0 {
                    ShareLink(item: imageURL) {
                        Label("Share PNG", systemImage: "square.and.arrow.up")
                    }
                    .foregroundStyle(SciFiTheme.cyan)
                }
            }
            .listRowBackground(SciFiTheme.panel)

            Section("Organization") {
                Picker("Folder", selection: folderBinding) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(folders) { folder in
                        Text(folder.name).tag(Optional(folder.id))
                    }
                }

                TextField("Tags, comma separated", text: $tagText, axis: .vertical)
                Button {
                    image.tags = tagText.tagsFromCSV()
                    try? modelContext.save()
                } label: {
                    Label("Save Tags", systemImage: "tag")
                }
                .buttonStyle(SciFiSecondaryButtonStyle())
            }
            .listRowBackground(SciFiTheme.panel)
        }
        .navigationTitle("Image Detail")
        .sciFiScreen()
        .bottomTabBarClearance()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Image", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete this generated image?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Image", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The image file and its saved generation metadata will be removed.")
        }
    }

    private var folderBinding: Binding<UUID?> {
        Binding(
            get: { image.folderID },
            set: { newValue in
                image.folderID = newValue
                try? modelContext.save()
            }
        )
    }
}

private struct FolderEditorState: Identifiable {
    let id: UUID
    let name: String

    init(folder: GalleryFolder) {
        id = folder.id
        name = folder.name
    }
}

private struct FolderNameEditor: View {
    let title: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(title: String, initialName: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Folder") {
                    TextField("Folder name", text: $name)
                }
                .listRowBackground(SciFiTheme.panel)
            }
            .navigationTitle(title)
            .sciFiScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
