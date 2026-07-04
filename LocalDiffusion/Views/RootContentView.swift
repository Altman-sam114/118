import SwiftData
import SwiftUI

enum AppSection: Hashable {
    case generate
    case models
    case gallery
    case prompts
    case plan

    var title: String {
        switch self {
        case .generate: "Generate"
        case .models: "Models"
        case .gallery: "Gallery"
        case .prompts: "Prompts"
        case .plan: "Plan"
        }
    }

    var systemImage: String {
        switch self {
        case .generate: "sparkles"
        case .models: "shippingbox"
        case .gallery: "square.grid.2x2"
        case .prompts: "text.book.closed"
        case .plan: "creditcard"
        }
    }
}

struct RootContentView: View {
    private let sections: [AppSection] = [.generate, .models, .gallery, .prompts, .plan]
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

            sectionContent(.plan)
                .tabItem { Label(AppSection.plan.title, systemImage: AppSection.plan.systemImage) }
                .tag(AppSection.plan)
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
        case .plan:
            PlanView()
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

private struct PlanView: View {
    private let futureCapabilities = [
        "Higher-throughput local queues",
        "Advanced batch generation controls",
        "Expanded pro prompt presets",
        "Optional workflow export tools"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    planOverview
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section("Current Build") {
                    LabeledContent {
                        Text("Local")
                            .foregroundStyle(SciFiTheme.mint)
                    } label: {
                        Label("Plan", systemImage: "internaldrive")
                    }

                    LabeledContent {
                        Text("Not configured")
                            .foregroundStyle(SciFiTheme.amber)
                    } label: {
                        Label("StoreKit products", systemImage: "cart")
                    }

                    Label("Purchases, restore, receipts, subscriptions, and entitlements are not enabled in this build.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(SciFiTheme.secondaryText)
                }

                Section {
                    ForEach(futureCapabilities, id: \.self) { capability in
                        Label(capability, systemImage: "sparkles")
                    }
                } header: {
                    Text("Future Paid Capabilities")
                } footer: {
                    Text("These are planning candidates only. No feature is locked, purchased, or activated by this screen.")
                }

                Section("Availability") {
                    Label("Generate, Models, Gallery, and Prompts remain available in the Local plan.", systemImage: "lock.open")
                    Label("StoreKit integration requires product IDs, entitlement rules, and App Store Connect configuration before any purchase UI is added.", systemImage: "wrench.and.screwdriver")
                }
            }
            .navigationTitle("Plan")
            .sciFiScreen()
            .bottomTabBarClearance()
        }
    }

    private var planOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "creditcard")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(SciFiTheme.cyan)
                    .frame(width: 52, height: 52)
                    .background(SciFiTheme.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(SciFiTheme.cyan.opacity(0.38), lineWidth: 1)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Local Plan")
                        .font(.headline)
                        .foregroundStyle(SciFiTheme.primaryText)

                    Text("This build is a local-first image generation app. Paid capability planning is visible here, but StoreKit is not configured.")
                        .font(.body)
                        .foregroundStyle(SciFiTheme.secondaryText)
                }
            }

            Divider()
                .overlay(SciFiTheme.stroke)

            Text("No purchase state is stored, no entitlement is granted, and no App Store product is requested from this screen.")
                .font(.callout)
                .foregroundStyle(SciFiTheme.secondaryText)
        }
        .padding(14)
        .sciFiPanel(isHighlighted: true)
    }
}
