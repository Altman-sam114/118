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

private enum PlanCapabilityStatus {
    case available
    case planned
    case requiresConfiguration

    var title: String {
        switch self {
        case .available: "Available"
        case .planned: "Planned"
        case .requiresConfiguration: "Requires configuration"
        }
    }

    var systemImage: String {
        switch self {
        case .available: "checkmark.circle"
        case .planned: "clock"
        case .requiresConfiguration: "wrench.and.screwdriver"
        }
    }

    var color: Color {
        switch self {
        case .available: SciFiTheme.mint
        case .planned: SciFiTheme.cyan
        case .requiresConfiguration: SciFiTheme.amber
        }
    }
}

private struct PlanCapabilityItem: Identifiable {
    let title: String
    let detail: String
    let status: PlanCapabilityStatus
    let systemImage: String

    var id: String { title }
}

private enum MacReadinessStatus {
    case requiresConfiguration
    case requiresNativeBuild
    case planned
    case requiresDecision

    var title: String {
        switch self {
        case .requiresConfiguration: "Requires configuration"
        case .requiresNativeBuild: "Requires native build"
        case .planned: "Planned"
        case .requiresDecision: "Requires decision"
        }
    }

    var systemImage: String {
        switch self {
        case .requiresConfiguration: "wrench.and.screwdriver"
        case .requiresNativeBuild: "cpu"
        case .planned: "clock"
        case .requiresDecision: "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .requiresConfiguration, .requiresDecision: SciFiTheme.amber
        case .requiresNativeBuild: SciFiTheme.magenta
        case .planned: SciFiTheme.cyan
        }
    }
}

private struct MacReadinessItem: Identifiable {
    let title: String
    let detail: String
    let status: MacReadinessStatus
    let systemImage: String

    var id: String { title }
}

private struct PlanView: View {
    private let capabilityItems = [
        PlanCapabilityItem(
            title: "Local generation workspace",
            detail: "Prompt, parameter, run, cancel, and result handoff.",
            status: .available,
            systemImage: "sparkles"
        ),
        PlanCapabilityItem(
            title: "Model and storage management",
            detail: "Download, import, resume, reconcile, and delete GGUF files.",
            status: .available,
            systemImage: "shippingbox"
        ),
        PlanCapabilityItem(
            title: "Gallery and prompt reuse",
            detail: "Folders, tags, templates, reuse, and regeneration.",
            status: .available,
            systemImage: "square.grid.2x2"
        ),
        PlanCapabilityItem(
            title: "Batch queue controls",
            detail: "Higher-throughput local generation planning.",
            status: .planned,
            systemImage: "list.bullet.rectangle"
        ),
        PlanCapabilityItem(
            title: "Pro prompt packs",
            detail: "Curated prompt presets and reusable style systems.",
            status: .planned,
            systemImage: "text.book.closed"
        ),
        PlanCapabilityItem(
            title: "Workflow export",
            detail: "Portable generation recipes and production handoff.",
            status: .planned,
            systemImage: "square.and.arrow.up"
        ),
        PlanCapabilityItem(
            title: "StoreKit purchases",
            detail: "Requires product IDs, entitlement rules, and App Store Connect.",
            status: .requiresConfiguration,
            systemImage: "cart"
        )
    ]

    private let macReadinessItems = [
        MacReadinessItem(
            title: "Xcode target platform",
            detail: "Project still targets iPhoneOS and iPhone Simulator only.",
            status: .requiresConfiguration,
            systemImage: "desktopcomputer"
        ),
        MacReadinessItem(
            title: "Native backend slice",
            detail: "XCFramework needs a Mac or Catalyst library before Mac builds.",
            status: .requiresNativeBuild,
            systemImage: "cpu"
        ),
        MacReadinessItem(
            title: "Window and sidebar QA",
            detail: "Mac window sizing, sidebar behavior, keyboard, and pointer states need smoke coverage.",
            status: .planned,
            systemImage: "rectangle.split.2x1"
        ),
        MacReadinessItem(
            title: "Distribution and signing",
            detail: "Developer ID, sandboxing, notarization, and App Store path require a product decision.",
            status: .requiresDecision,
            systemImage: "person.badge.key"
        )
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

                Section("Platform Status") {
                    LabeledContent {
                        Text("Available")
                            .foregroundStyle(SciFiTheme.mint)
                    } label: {
                        Label("iPhone / iPad", systemImage: "iphone")
                    }

                    LabeledContent {
                        Text("Not enabled")
                            .foregroundStyle(SciFiTheme.amber)
                    } label: {
                        Label("Mac Catalyst", systemImage: "desktopcomputer")
                    }

                    Label("Mac support requires Xcode platform changes, a native backend Mac/Catalyst slice, signing decisions, and dedicated UI validation.", systemImage: "checklist")
                        .foregroundStyle(SciFiTheme.secondaryText)
                }

                Section {
                    ForEach(macReadinessItems) { item in
                        MacReadinessRow(item: item)
                    }
                } header: {
                    Text("Mac Readiness")
                } footer: {
                    Text("These are blockers for a future Mac build. This iOS target does not currently ship a Mac or Catalyst app.")
                }

                Section {
                    ForEach(capabilityItems) { item in
                        CapabilityRow(item: item)
                    }
                } header: {
                    Text("Capability Matrix")
                } footer: {
                    Text("Available items are part of the current Local plan. Planned and configuration-gated items are not purchases or active entitlements.")
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

private struct MacReadinessRow: View {
    let item: MacReadinessItem

    var body: some View {
        LabeledContent {
            Label(item.status.title, systemImage: item.status.systemImage)
                .foregroundStyle(item.status.color)
                .font(.callout)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.trailing)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .foregroundStyle(SciFiTheme.primaryText)
                    Text(item.detail)
                        .font(.callout)
                        .foregroundStyle(SciFiTheme.secondaryText)
                }
            } icon: {
                Image(systemName: item.systemImage)
                    .foregroundStyle(SciFiTheme.cyan)
            }
        }
    }
}

private struct CapabilityRow: View {
    let item: PlanCapabilityItem

    var body: some View {
        LabeledContent {
            Label(item.status.title, systemImage: item.status.systemImage)
                .foregroundStyle(item.status.color)
                .font(.callout)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.trailing)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .foregroundStyle(SciFiTheme.primaryText)
                    Text(item.detail)
                        .font(.callout)
                        .foregroundStyle(SciFiTheme.secondaryText)
                }
            } icon: {
                Image(systemName: item.systemImage)
                    .foregroundStyle(SciFiTheme.cyan)
            }
        }
    }
}
