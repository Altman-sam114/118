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

enum GalleryLayoutMode {
    case standalone
    case embeddedWide
}

private func galleryImageCountText(_ count: Int) -> String {
    count == 1 ? "1 image" : "\(count) images"
}

struct GalleryView: View {
    let fileStore: AppFileStore
    @Binding var focusedImageID: UUID?
    let layoutMode: GalleryLayoutMode
    let onReuse: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

    init(
        fileStore: AppFileStore,
        focusedImageID: Binding<UUID?>,
        layoutMode: GalleryLayoutMode = .standalone,
        onReuse: @escaping () -> Void
    ) {
        self.fileStore = fileStore
        _focusedImageID = focusedImageID
        self.layoutMode = layoutMode
        self.onReuse = onReuse
    }

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
        Group {
            switch layoutMode {
            case .standalone:
                standaloneLayout
            case .embeddedWide:
                embeddedWideLayout
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
    }

    private var standaloneLayout: some View {
        NavigationSplitView {
            filterList
            .navigationTitle("Gallery")
            .sciFiScreen()
            .bottomTabBarClearance()
            .toolbar {
                newFolderToolbarItem
            }
        } detail: {
            NavigationStack(path: $detailPath) {
                galleryNavigationBehavior(
                    imageGrid
                        .navigationTitle("Images")
                        .sciFiScreen()
                        .bottomTabBarClearance()
                        .toolbar {
                            imageGridToolbar()
                        }
                )
            }
        }
    }

    private var embeddedWideLayout: some View {
        NavigationStack(path: $detailPath) {
            galleryNavigationBehavior(
                HStack(spacing: 0) {
                    filterList
                        .scrollContentBackground(.hidden)
                        .background(SciFiTheme.panelSoft)
                        .frame(width: filterRailWidth)

                    Rectangle()
                        .fill(SciFiTheme.stroke)
                        .frame(width: 1)
                        .accessibilityHidden(true)

                    imageGrid
                }
                .navigationTitle("Gallery")
                .sciFiScreen()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        selectedFilterLabel
                    }
                    imageGridToolbar(refreshPlacement: .primaryAction)
                    newFolderToolbarItem
                }
            )
        }
    }

    private var filterList: some View {
        List(selection: filterBinding) {
            GalleryFilterRow(
                title: "All Images",
                systemImage: "square.grid.2x2",
                kind: .allImages,
                imageCount: images.count
            )
                .tag(GalleryFilter.all)
                .sciFiListRow()

            Section("Folders") {
                ForEach(folders) { folder in
                    GalleryFilterRow(
                        title: folder.name,
                        systemImage: "folder",
                        kind: .folder,
                        imageCount: imageCount(inFolder: folder.id)
                    )
                        .tag(GalleryFilter.folder(folder.id))
                        .sciFiListRow()
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingFolderDeletion = FolderEditorState(folder: folder)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .accessibilityLabel(Text("Delete folder: \(folder.name)"))
                            .accessibilityHint(Text("Shows a confirmation before deleting \(folder.name)."))

                            Button {
                                editingFolder = FolderEditorState(folder: folder)
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)
                            .accessibilityLabel(Text("Rename folder: \(folder.name)"))
                            .accessibilityHint(Text("Opens \(folder.name) for renaming."))
                        }
                        .contextMenu {
                            Button {
                                editingFolder = FolderEditorState(folder: folder)
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .accessibilityLabel(Text("Rename folder: \(folder.name)"))
                            .accessibilityHint(Text("Opens \(folder.name) for renaming."))

                            Button(role: .destructive) {
                                pendingFolderDeletion = FolderEditorState(folder: folder)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .accessibilityLabel(Text("Delete folder: \(folder.name)"))
                            .accessibilityHint(Text("Shows a confirmation before deleting \(folder.name)."))
                        }
                }
            }

            Section("Tags") {
                ForEach(allTags, id: \.self) { tag in
                    GalleryFilterRow(
                        title: tag,
                        systemImage: "tag",
                        kind: .tag,
                        imageCount: imageCount(withTag: tag)
                    )
                        .tag(GalleryFilter.tag(tag))
                        .sciFiListRow()
                }
            }
        }
    }

    private var imageGrid: some View {
        Group {
            if visibleImages.isEmpty {
                EmptyStateView(
                    systemImage: "photo.on.rectangle",
                    title: "No images",
                    message: "Generated images will appear here."
                )
                .padding()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Gallery empty state")
                .accessibilityValue(galleryEmptyAccessibilityValue)
                .accessibilityHint(galleryEmptyAccessibilityHint)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: imageGridMinimumWidth), spacing: 12)], spacing: 12) {
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
    }

    private var imageGridMinimumWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 220 : 150
    }

    private var filterRailWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 320 : 280
    }

    private var selectedFilterLabel: some View {
        Label(selectedFilterTitle, systemImage: selectedFilterSystemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SciFiTheme.cyan)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Selected gallery filter")
            .accessibilityValue("\(selectedFilterTitle), \(galleryImageCountText(visibleImages.count))")
    }

    private var selectedFilterTitle: String {
        switch filter {
        case .all:
            return "All Images"
        case .folder(let id):
            return folders.first(where: { $0.id == id })?.name ?? "Folder"
        case .tag(let tag):
            return tag
        }
    }

    private var galleryEmptyAccessibilityValue: String {
        "\(selectedFilterTitle), \(galleryImageCountText(visibleImages.count))"
    }

    private var galleryEmptyAccessibilityHint: String {
        "Generate an image or choose a different gallery filter."
    }

    private var selectedFilterSystemImage: String {
        switch filter {
        case .all:
            return "square.grid.2x2"
        case .folder:
            return "folder"
        case .tag:
            return "tag"
        }
    }

    private var sortAccessibilityValue: String {
        switch sort {
        case .newest:
            return "Newest images first"
        case .oldest:
            return "Oldest images first"
        case .model:
            return "Grouped by model name"
        }
    }

    @ToolbarContentBuilder
    private func imageGridToolbar(refreshPlacement: ToolbarItemPlacement = .topBarLeading) -> some ToolbarContent {
        ToolbarItem(placement: refreshPlacement) {
            Button {
                reconcileImageFiles()
            } label: {
                Label("Refresh Gallery", systemImage: "arrow.clockwise")
            }
            .accessibilityHint("Checks generated image files and removes missing or orphaned gallery entries.")
        }

        ToolbarItem(placement: .primaryAction) {
            Picker("Sort", selection: $sort) {
                ForEach(GallerySort.allCases) { sort in
                    Text(sort.rawValue).tag(sort)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Gallery sort order")
            .accessibilityValue(sortAccessibilityValue)
            .accessibilityHint("Changes the order of visible gallery images.")
        }
    }

    @ToolbarContentBuilder
    private var newFolderToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddFolder = true
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            .accessibilityHint("Creates a folder for organizing gallery images.")
        }
    }

    @ViewBuilder
    private func imageDetail(for imageID: UUID) -> some View {
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

    private func galleryNavigationBehavior<V: View>(_ view: V) -> some View {
        view
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
                imageDetail(for: imageID)
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

    private func imageCount(inFolder folderID: UUID) -> Int {
        images.filter { $0.folderID == folderID }.count
    }

    private func imageCount(withTag tag: String) -> Int {
        images.filter { $0.tags.contains(tag) }.count
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

private enum GalleryFilterRowKind {
    case allImages
    case folder
    case tag

    var accessibilityLabel: String {
        switch self {
        case .allImages:
            return "All Images filter"
        case .folder:
            return "Folder filter"
        case .tag:
            return "Tag filter"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .allImages:
            return "Shows every generated image in the gallery."
        case .folder:
            return "Filters the gallery images by this folder."
        case .tag:
            return "Filters the gallery images by this tag."
        }
    }
}

private struct GalleryFilterRow: View {
    let title: String
    let systemImage: String
    let kind: GalleryFilterRowKind
    let imageCount: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(SciFiTheme.primaryText)
                    .lineLimit(titleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)

                Text(galleryImageCountText(imageCount))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(SciFiTheme.secondaryText)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(SciFiTheme.cyan)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .hoverEffect(.highlight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.accessibilityLabel)
        .accessibilityValue("\(title), \(galleryImageCountText(imageCount))")
        .accessibilityHint(kind.accessibilityHint)
    }

    private var titleLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
    }
}

private struct ImageTile: View {
    let image: GeneratedImage
    let fileStore: AppFileStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                            .font(.caption.monospacedDigit())
                            .bold()
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
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)

            metadataView
                .font(.caption)
                .foregroundStyle(SciFiTheme.secondaryText)
        }
        .padding(10)
        .sciFiPanel()
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .hoverEffect(.highlight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabelText))
        .accessibilityValue(Text(accessibilityValueText))
        .accessibilityHint("Opens image detail")
    }

    @ViewBuilder
    private var metadataView: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 3) {
                Text(image.createdAt, style: .date)
                Text(image.modelName)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text(image.createdAt, style: .date)
                Spacer(minLength: 8)
                Text(image.modelName)
                    .lineLimit(1)
            }
        }
    }

    private var accessibilityLabelText: String {
        "Generated image: \(image.prompt)"
    }

    private var accessibilityValueText: String {
        let date = image.createdAt.formatted(date: .abbreviated, time: .omitted)
        return "Model \(image.modelName). Created \(date). Output \(image.resolvedOutputWidth) by \(image.resolvedOutputHeight)."
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                        .accessibilityLabel("Generated image preview")
                        .accessibilityValue(imagePreviewAccessibilityValue)
                }
                .listRowBackground(SciFiTheme.panel)
            }

            Section("Parameters") {
                GalleryDetailParameterRow(title: "Model", value: image.modelName)
                GalleryDetailParameterRow(title: "Prompt", value: image.prompt, isLongForm: true)
                GalleryDetailParameterRow(
                    title: "Negative",
                    value: image.negativePrompt.isEmpty ? "None" : image.negativePrompt,
                    isLongForm: !image.negativePrompt.isEmpty
                )
                GalleryDetailParameterRow(title: "Steps", value: "\(image.steps)")
                GalleryDetailParameterRow(
                    title: "CFG",
                    value: image.cfgScale.formatted(.number.precision(.fractionLength(1)))
                )
                GalleryDetailParameterRow(title: "Seed", value: "\(image.seed)")
                GalleryDetailParameterRow(title: "Requested Size", value: "\(image.width) x \(image.height)")
                GalleryDetailParameterRow(
                    title: "Output Size",
                    value: "\(image.resolvedOutputWidth) x \(image.resolvedOutputHeight)"
                )
                GalleryDetailParameterRow(title: "Sampler", value: image.samplerRawValue)
                Button {
                    onReuse()
                } label: {
                    Label("Reuse Parameters", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(SciFiSecondaryButtonStyle())
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityLabel(Text("Reuse image parameters"))
                .accessibilityValue(Text(imageActionAccessibilityValue))
                .accessibilityHint(Text("Loads this image's generation parameters back into Generate."))

                Button {
                    onRegenerate()
                } label: {
                    Label("Reuse and Generate", systemImage: "play.fill")
                }
                .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.mint))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityLabel(Text("Reuse and generate image"))
                .accessibilityValue(Text(imageActionAccessibilityValue))
                .accessibilityHint(Text("Loads this image's parameters and starts a new local generation."))

                if fileStore.fileExists(at: imageURL), fileStore.fileSize(at: imageURL) > 0 {
                    ShareLink(item: imageURL) {
                        Label("Share PNG", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SciFiSecondaryButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityLabel(Text("Share generated PNG"))
                    .accessibilityValue(Text(imageActionAccessibilityValue))
                    .accessibilityHint(Text("Shares this generated PNG file."))
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
                .accessibilityLabel(Text("Image folder"))
                .accessibilityValue(Text(currentFolderAccessibilityValue))
                .accessibilityHint("Changes this image's folder and saves the selection immediately.")

                TextField("Tags, comma separated", text: $tagText, axis: .vertical)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3...6 : 1...3)
                    .accessibilityLabel(Text("Image tags"))
                    .accessibilityValue(Text(tagTextAccessibilityValue))
                    .accessibilityHint(Text("Separate tags with commas, then use Save Tags to store them."))
                Button {
                    image.tags = tagText.tagsFromCSV()
                    try? modelContext.save()
                } label: {
                    Label("Save Tags", systemImage: "tag")
                }
                .buttonStyle(SciFiSecondaryButtonStyle())
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityLabel(Text("Save image tags"))
                .accessibilityValue(Text(saveTagsAccessibilityValue))
                .accessibilityHint("Saves the current comma-separated tags for this image.")
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
                .accessibilityLabel(Text("Delete generated image"))
                .accessibilityValue(Text(imageActionAccessibilityValue))
                .accessibilityHint(Text("Shows a confirmation before deleting this image file and metadata."))
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

    private var imagePreviewAccessibilityValue: String {
        "Prompt \(image.prompt). Model \(image.modelName). Output \(image.resolvedOutputWidth) by \(image.resolvedOutputHeight)."
    }

    private var imageActionAccessibilityValue: String {
        "Model \(image.modelName). Seed \(image.seed). Requested \(image.width) by \(image.height) pixels. Output \(image.resolvedOutputWidth) by \(image.resolvedOutputHeight) pixels."
    }

    private var currentFolderAccessibilityValue: String {
        guard let folderID = image.folderID else {
            return "No folder"
        }

        return folders.first(where: { $0.id == folderID })?.name ?? "Folder unavailable"
    }

    private var tagTextAccessibilityValue: String {
        tagsAccessibilityDescription(draftTags)
    }

    private var savedTags: [String] {
        image.tags
    }

    private var draftTags: [String] {
        tagText.tagsFromCSV()
    }

    private var hasUnsavedTagChanges: Bool {
        draftTags != savedTags
    }

    private var saveTagsAccessibilityValue: String {
        let changeState = hasUnsavedTagChanges ? "Unsaved changes" : "No changes"
        return "\(changeState). Draft tags: \(tagsAccessibilityDescription(draftTags)). Saved tags: \(tagsAccessibilityDescription(savedTags))."
    }

    private func tagsAccessibilityDescription(_ tags: [String]) -> String {
        tags.isEmpty ? "No tags" : tags.joined(separator: ", ")
    }
}

private struct GalleryDetailParameterRow: View {
    let title: String
    let value: String
    var isLongForm = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if shouldStack {
                VStack(alignment: .leading, spacing: 4) {
                    titleText
                    valueText
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    titleText
                    Spacer(minLength: 12)
                    valueText
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private var shouldStack: Bool {
        dynamicTypeSize.isAccessibilitySize || isLongForm
    }

    private var titleText: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SciFiTheme.cyan)
    }

    private var valueText: some View {
        Text(value)
            .font(.body)
            .foregroundStyle(SciFiTheme.primaryText)
            .lineLimit(valueLineLimit)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var valueLineLimit: Int? {
        shouldStack ? nil : 2
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
                    .accessibilityLabel(Text("Cancel folder editing"))
                    .accessibilityValue(Text("No changes saved"))
                    .accessibilityHint(Text("Closes the folder editor without saving the current folder name."))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(Text("Save folder name"))
                    .accessibilityValue(Text(folderSaveAccessibilityValue))
                    .accessibilityHint(Text(folderSaveAccessibilityHint))
                }
            }
        }
    }

    private var hasFolderName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var folderSaveAccessibilityValue: String {
        hasFolderName ? "Ready" : "Folder name required"
    }

    private var folderSaveAccessibilityHint: String {
        hasFolderName
        ? "Saves the current folder name."
        : "Enter a folder name before saving."
    }
}
