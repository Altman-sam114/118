import SwiftData
import SwiftUI

enum AppSection: Hashable {
    case generate
    case models
    case gallery
    case prompts

    var title: String {
        switch self {
        case .generate: "Generate"
        case .models: "Models"
        case .gallery: "Gallery"
        case .prompts: "Prompts"
        }
    }

    var systemImage: String {
        switch self {
        case .generate: "sparkles"
        case .models: "shippingbox"
        case .gallery: "square.grid.2x2"
        case .prompts: "text.book.closed"
        }
    }
}

struct RootContentView: View {
    private let sections: [AppSection] = [.generate, .models, .gallery, .prompts]
    private let fileStore: AppFileStore

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var downloads: HuggingFaceDownloadManager
    @State private var selection: AppSection = .generate
    @State private var focusedGalleryImageID: UUID?
    @StateObject private var generationViewModel: GenerationViewModel

    init(fileStore: AppFileStore) {
        self.fileStore = fileStore
        _generationViewModel = StateObject(
            wrappedValue: GenerationViewModel(
                fileStore: fileStore,
                backend: InferenceBackendFactory.makeDefaultBackend()
            )
        )
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                sidebarLayout
            } else {
                tabLayout
            }
        }
        .environmentObject(generationViewModel)
        .preferredColorScheme(.dark)
        .tint(SciFiTheme.cyan)
        .background(SciFiBackground().ignoresSafeArea())
        .onAppear {
            configureDownloadPersistence()
        }
    }

    private var tabLayout: some View {
        TabView(selection: $selection) {
            sectionContent(.generate)
                .tabItem { Label(AppSection.generate.title, systemImage: AppSection.generate.systemImage) }
                .tag(AppSection.generate)

            sectionContent(.models)
                .tabItem { Label(AppSection.models.title, systemImage: AppSection.models.systemImage) }
                .tag(AppSection.models)

            sectionContent(.gallery)
                .tabItem { Label(AppSection.gallery.title, systemImage: AppSection.gallery.systemImage) }
                .tag(AppSection.gallery)

            sectionContent(.prompts)
                .tabItem { Label(AppSection.prompts.title, systemImage: AppSection.prompts.systemImage) }
                .tag(AppSection.prompts)
        }
        .toolbarBackground(SciFiTheme.backgroundTop, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }

    private var sidebarLayout: some View {
        NavigationSplitView {
            List(sections, id: \.self, selection: sidebarSelectionBinding) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
                    .sciFiListRow()
            }
            .navigationTitle("Local Diffusion")
            .sciFiScreen()
        } detail: {
            sectionContent(selection)
        }
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .generate:
            GenerationView(fileStore: fileStore) {
                focusedGalleryImageID = generationViewModel.latestGeneratedImageID
                selection = .gallery
            } onShowModels: {
                selection = .models
            }
        case .models:
            ModelLibraryView(fileStore: fileStore)
        case .gallery:
            GalleryView(
                fileStore: fileStore,
                focusedImageID: $focusedGalleryImageID,
                layoutMode: galleryLayoutMode
            ) {
                selection = .generate
            }
        case .prompts:
            PromptLibraryView {
                selection = .generate
            }
        }
    }

    private var sidebarSelectionBinding: Binding<AppSection?> {
        Binding(
            get: { selection },
            set: { selection = $0 ?? .generate }
        )
    }

    private var galleryLayoutMode: GalleryLayoutMode {
        horizontalSizeClass == .regular ? .embeddedWide : .standalone
    }

    private func configureDownloadPersistence() {
        downloads.onModelStateChange = { [modelContext] in
            try? modelContext.save()
        }
    }
}
