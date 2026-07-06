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
        case .plan: "checklist"
        }
    }

    var sidebarAccessibilityHint: String {
        switch self {
        case .generate: "Opens the generation workspace."
        case .models: "Opens model download and storage management."
        case .gallery: "Opens generated image browsing and reuse."
        case .prompts: "Opens saved prompt templates."
        case .plan: "Opens local plan, planning-only paid capability status, and platform readiness."
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
                SidebarSectionRow(section: section, isSelected: selection == section)
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

private struct SidebarSectionRow: View {
    let section: AppSection
    let isSelected: Bool

    var body: some View {
        Label {
            Text(section.title)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: section.systemImage)
        }
        .frame(minHeight: 44, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .hoverEffect(.highlight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(section.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(section.sidebarAccessibilityHint)
    }
}

private struct PlanStatusToken {
    let title: String
    let systemImage: String
    let color: Color
}

private enum PlanCapabilityStatus {
    case available
    case planned
    case requiresConfiguration

    var title: String {
        switch self {
        case .available: "Available"
        case .planned: "Planning only"
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

    var token: PlanStatusToken {
        PlanStatusToken(title: title, systemImage: systemImage, color: color)
    }
}

private struct PlanCapabilityItem: Identifiable {
    let title: String
    let detail: String
    let status: PlanCapabilityStatus
    let systemImage: String
    let accessibilityHint: String

    var id: String { title }
}

private enum PlanEntitlementRuleStatus {
    case protected
    case candidate
    case requiresConfiguration
    case notImplemented

    var title: String {
        switch self {
        case .protected: "Protected"
        case .candidate: "Planning only"
        case .requiresConfiguration: "Requires configuration"
        case .notImplemented: "Not implemented"
        }
    }

    var systemImage: String {
        switch self {
        case .protected: "lock.open"
        case .candidate: "sparkles"
        case .requiresConfiguration: "wrench.and.screwdriver"
        case .notImplemented: "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .protected: SciFiTheme.mint
        case .candidate: SciFiTheme.cyan
        case .requiresConfiguration: SciFiTheme.amber
        case .notImplemented: SciFiTheme.magenta
        }
    }

    var token: PlanStatusToken {
        PlanStatusToken(title: title, systemImage: systemImage, color: color)
    }
}

private struct PlanEntitlementRuleItem: Identifiable {
    let title: String
    let detail: String
    let status: PlanEntitlementRuleStatus
    let systemImage: String
    let accessibilityHint: String

    var id: String { title }
}

private struct PlanAvailabilityItem: Identifiable {
    let title: String
    let detail: String
    let status: PlanStatusToken
    let systemImage: String
    let accessibilityHint: String

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
        case .planned: "Needs QA"
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

    var token: PlanStatusToken {
        PlanStatusToken(title: title, systemImage: systemImage, color: color)
    }
}

private struct MacReadinessItem: Identifiable {
    let title: String
    let detail: String
    let status: MacReadinessStatus
    let systemImage: String
    let accessibilityHint: String

    var id: String { title }
}

private struct PlanView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let capabilityItems = [
        PlanCapabilityItem(
            title: "Local generation workspace",
            detail: "Prompt, parameter, run, cancel, and result handoff.",
            status: .available,
            systemImage: "sparkles",
            accessibilityHint: "Confirms this generation workspace is available in the current Local plan."
        ),
        PlanCapabilityItem(
            title: "Model and storage management",
            detail: "Download, import, resume, reconcile, and delete GGUF files.",
            status: .available,
            systemImage: "shippingbox",
            accessibilityHint: "Confirms model and storage management are available in the current Local plan."
        ),
        PlanCapabilityItem(
            title: "Gallery and prompt reuse",
            detail: "Folders, tags, templates, reuse, and regeneration.",
            status: .available,
            systemImage: "square.grid.2x2",
            accessibilityHint: "Confirms gallery organization and prompt reuse are available in the current Local plan."
        ),
        PlanCapabilityItem(
            title: "Batch queue controls",
            detail: "Planning-only paid candidate for higher-throughput local generation; not sold or unlocked in this build.",
            status: .planned,
            systemImage: "list.bullet.rectangle",
            accessibilityHint: "Clarifies batch queue controls are planning-only paid candidates and are not sold or unlocked in this build."
        ),
        PlanCapabilityItem(
            title: "Curated prompt packs",
            detail: "Planning-only paid candidate for reusable style systems; not sold or unlocked in this build.",
            status: .planned,
            systemImage: "text.book.closed",
            accessibilityHint: "Clarifies curated prompt packs are planning-only paid candidates and are not sold or unlocked in this build."
        ),
        PlanCapabilityItem(
            title: "Workflow export",
            detail: "Planning-only paid candidate for portable generation recipes and production handoff; not sold or unlocked in this build.",
            status: .planned,
            systemImage: "square.and.arrow.up",
            accessibilityHint: "Clarifies workflow export is a planning-only paid candidate and is not sold or unlocked in this build."
        ),
        PlanCapabilityItem(
            title: "StoreKit purchases",
            detail: "StoreKit purchase capability is not enabled in this build; planning-only paid candidates are not sold, purchased, or unlocked until product IDs, entitlement mapping, and App Store Connect are configured.",
            status: .requiresConfiguration,
            systemImage: "cart",
            accessibilityHint: "Clarifies this build has no active StoreKit purchase capability, so planning-only paid candidates cannot be bought or unlocked."
        )
    ]

    private let entitlementRuleItems = [
        PlanEntitlementRuleItem(
            title: "Core local tools",
            detail: "Generate, Models, Gallery, and Prompts stay available in the current Local plan.",
            status: .protected,
            systemImage: "lock.open",
            accessibilityHint: "Confirms core local tools stay available in the current Local plan."
        ),
        PlanEntitlementRuleItem(
            title: "Paid candidates",
            detail: "Batch queue, curated prompt packs, and workflow export are planning-only until product decisions exist.",
            status: .candidate,
            systemImage: "sparkles",
            accessibilityHint: "Clarifies paid candidates are planning only and do not grant active entitlements in this build."
        ),
        PlanEntitlementRuleItem(
            title: "StoreKit purchase gate",
            detail: "No App Store product is requested until product IDs, entitlement mapping, restore flow, receipts, and App Store Connect are configured.",
            status: .requiresConfiguration,
            systemImage: "cart",
            accessibilityHint: "Clarifies this build does not request an App Store product or show a real purchase flow until StoreKit prerequisites exist."
        ),
        PlanEntitlementRuleItem(
            title: "Entitlement persistence",
            detail: "No purchase state is stored, no entitlement is granted, and no App Store product is requested.",
            status: .notImplemented,
            systemImage: "xmark.seal",
            accessibilityHint: "Clarifies this build stores no purchase state, grants no entitlement, and requests no App Store product."
        )
    ]

    private let availabilityItems = [
        PlanAvailabilityItem(
            title: "Core local tools",
            detail: "Generate, Models, Gallery, and Prompts remain available in the Local plan.",
            status: PlanStatusToken(title: "Available", systemImage: "checkmark.circle", color: SciFiTheme.mint),
            systemImage: "lock.open",
            accessibilityHint: "Confirms the core local tools are available in the current Local plan."
        ),
        PlanAvailabilityItem(
            title: "Paid candidates",
            detail: "Batch queue, curated prompt packs, and workflow export are not sold or unlocked in this build; they still need product decisions, StoreKit products, and entitlement mapping.",
            status: PlanStatusToken(title: "Planning only", systemImage: "clock", color: SciFiTheme.cyan),
            systemImage: "sparkles",
            accessibilityHint: "Clarifies these paid candidates are planning only and are not sold or unlocked in this build."
        ),
        PlanAvailabilityItem(
            title: "Purchase UI",
            detail: "Purchase UI remains hidden until StoreKit products and entitlement mapping exist.",
            status: PlanStatusToken(title: "Requires configuration", systemImage: "wrench.and.screwdriver", color: SciFiTheme.amber),
            systemImage: "cart",
            accessibilityHint: "Clarifies purchase UI requires StoreKit products and entitlement mapping before it can be added."
        ),
        PlanAvailabilityItem(
            title: "Mac app",
            detail: "The iPhone and iPad app is available in this build; a Mac/Catalyst app is not enabled.",
            status: PlanStatusToken(title: "Not enabled", systemImage: "xmark.circle", color: SciFiTheme.amber),
            systemImage: "desktopcomputer",
            accessibilityHint: "Clarifies Mac support is separate from the current iPhone and iPad app and still requires platform settings, a native Mac/Catalyst backend slice, signing decisions, and dedicated UI validation."
        )
    ]

    private let macReadinessItems = [
        MacReadinessItem(
            title: "Apple platform support",
            detail: "This build is still configured for the iPhone and iPad app target only.",
            status: .requiresConfiguration,
            systemImage: "desktopcomputer",
            accessibilityHint: "Clarifies Mac support requires enabling a Mac or Catalyst target platform configuration."
        ),
        MacReadinessItem(
            title: "Native backend slice",
            detail: "The native inference framework still needs a Mac or Catalyst slice before Mac builds can run.",
            status: .requiresNativeBuild,
            systemImage: "cpu",
            accessibilityHint: "Clarifies a Mac or Catalyst native backend slice must exist before Mac builds can run."
        ),
        MacReadinessItem(
            title: "Window and sidebar QA",
            detail: "Mac window sizing, sidebar behavior, keyboard, and pointer states need dedicated QA beyond the current iPad layout.",
            status: .planned,
            systemImage: "rectangle.split.2x1",
            accessibilityHint: "Clarifies iPad regular layout and pointer affordance do not replace dedicated Mac or Catalyst window, sidebar, keyboard, and pointer validation."
        ),
        MacReadinessItem(
            title: "Distribution and signing",
            detail: "Mac release channel, signing, sandboxing, and notarization still need a product decision.",
            status: .requiresDecision,
            systemImage: "person.badge.key",
            accessibilityHint: "Clarifies the Mac signing and distribution path needs a product decision."
        )
    ]

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    regularLayout
                } else {
                    compactLayout
                }
            }
            .navigationTitle("Plan")
            .sciFiScreen()
            .bottomTabBarClearance()
        }
    }

    private var compactLayout: some View {
        Form {
            Section {
                planOverview
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            currentBuildSection
            platformStatusSection
            macReadinessSection
            capabilityMatrixSection
            entitlementRulesSection
            availabilitySection
        }
    }

    private var regularLayout: some View {
        ScrollView {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    regularStackLayout
                } else {
                    ViewThatFits(in: .horizontal) {
                        regularColumnLayout
                        regularStackLayout
                    }
                }
            }
            .frame(maxWidth: 1180)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
    }

    private var regularColumnLayout: some View {
        HStack(alignment: .top, spacing: 16) {
            regularPrimaryColumn
                .frame(minWidth: 320, maxWidth: .infinity, alignment: .topLeading)
            regularDetailColumn
                .frame(minWidth: 320, maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var regularStackLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            regularPrimaryColumn
            regularDetailColumn
        }
    }

    private var regularPrimaryColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            planOverview

            PlanPanel("Current Build") {
                currentBuildContent
            }

            PlanPanel("Platform Status") {
                platformStatusContent
            }
        }
    }

    private var regularDetailColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            PlanPanel("Mac Readiness", footer: "These are blockers for a future Mac build. The current iPhone and iPad app is available; a Mac/Catalyst app is not enabled.") {
                macReadinessContent
            }

            PlanPanel("Capability Matrix", footer: "Available items are part of the current Local plan. Planning-only and configuration-gated items are not purchases or active entitlements.") {
                capabilityMatrixContent
            }

            PlanPanel("Entitlement Rules", footer: "These rules are a planning baseline only. This build does not enforce paid access.") {
                entitlementRulesContent
            }

            PlanPanel("Availability", footer: "Availability separates current Local tools from planning-only paid candidates, Purchase UI prerequisites, and Mac app status.") {
                availabilityContent
            }
        }
    }

    private var currentBuildSection: some View {
        Section("Current Build") {
            currentBuildContent
        }
    }

    private var platformStatusSection: some View {
        Section("Platform Status") {
            platformStatusContent
        }
    }

    private var macReadinessSection: some View {
        Section {
            macReadinessContent
        } header: {
            Text("Mac Readiness")
        } footer: {
            compactSectionFooter(
                "Mac Readiness",
                "These are blockers for a future Mac build. The current iPhone and iPad app is available; a Mac/Catalyst app is not enabled."
            )
        }
    }

    private var capabilityMatrixSection: some View {
        Section {
            capabilityMatrixContent
        } header: {
            Text("Capability Matrix")
        } footer: {
            compactSectionFooter(
                "Capability Matrix",
                "Available items are part of the current Local plan. Planning-only and configuration-gated items are not purchases or active entitlements."
            )
        }
    }

    private var entitlementRulesSection: some View {
        Section {
            entitlementRulesContent
        } header: {
            Text("Entitlement Rules")
        } footer: {
            compactSectionFooter(
                "Entitlement Rules",
                "These rules are a planning baseline only. This build does not enforce paid access."
            )
        }
    }

    private var availabilitySection: some View {
        Section {
            availabilityContent
        } header: {
            Text("Availability")
        } footer: {
            compactSectionFooter(
                "Availability",
                "Availability separates current Local tools from planning-only paid candidates, Purchase UI prerequisites, and Mac app status."
            )
        }
    }

    @ViewBuilder
    private var currentBuildContent: some View {
        PlanStatusSummaryRow(
            title: "Plan",
            systemImage: "internaldrive",
            status: PlanStatusToken(title: "Local", systemImage: "checkmark.circle", color: SciFiTheme.mint),
            accessibilityHint: "Confirms this build uses the Local plan."
        )

        PlanStatusSummaryRow(
            title: "StoreKit products",
            systemImage: "cart",
            status: PlanStatusToken(title: "Not configured", systemImage: "wrench.and.screwdriver", color: SciFiTheme.amber),
            accessibilityHint: "Clarifies StoreKit products and purchase flows are not configured in this build."
        )

        PlanNoteRow(
            text: "Purchases, restore, receipts, subscriptions, and entitlements are not enabled in this build; paid candidates on this screen are planning only.",
            systemImage: "exclamationmark.triangle",
            iconColor: SciFiTheme.amber,
            accessibilityLabel: "StoreKit purchase status",
            accessibilityHint: "This build does not include purchase, restore, receipt, subscription, or entitlement flows, and paid candidates cannot be bought or unlocked here."
        )
    }

    @ViewBuilder
    private var platformStatusContent: some View {
        PlanStatusSummaryRow(
            title: "iPhone / iPad",
            systemImage: "iphone",
            status: PlanStatusToken(title: "Available", systemImage: "checkmark.circle", color: SciFiTheme.mint),
            accessibilityHint: "Confirms the current iPhone and iPad target is available."
        )

        PlanStatusSummaryRow(
            title: "Mac Catalyst",
            systemImage: "desktopcomputer",
            status: PlanStatusToken(title: "Not enabled", systemImage: "xmark.circle", color: SciFiTheme.amber),
            accessibilityHint: "Clarifies this build does not enable Mac Catalyst or ship a Mac app."
        )

        PlanNoteRow(
            text: "Mac support remains planned. The iPhone and iPad app is available in this build; a Mac/Catalyst app is not enabled until platform support, a native backend Mac/Catalyst slice, signing decisions, and dedicated UI validation are ready.",
            systemImage: "checklist",
            iconColor: SciFiTheme.cyan,
            accessibilityLabel: "Mac support status",
            accessibilityHint: "Clarifies that the current build provides the iPhone and iPad app while Mac/Catalyst support remains planned and not enabled."
        )
    }

    @ViewBuilder
    private var macReadinessContent: some View {
        ForEach(macReadinessItems) { item in
            MacReadinessRow(item: item)
        }
    }

    @ViewBuilder
    private var capabilityMatrixContent: some View {
        ForEach(capabilityItems) { item in
            CapabilityRow(item: item)
        }
    }

    @ViewBuilder
    private var entitlementRulesContent: some View {
        ForEach(entitlementRuleItems) { item in
            EntitlementRuleRow(item: item)
        }
    }

    @ViewBuilder
    private var availabilityContent: some View {
        ForEach(availabilityItems) { item in
            AvailabilityRow(item: item)
        }
    }

    private var planOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    planOverviewIcon
                    planOverviewCopy
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    planOverviewIcon
                    planOverviewCopy
                }
            }

            Divider()
                .overlay(SciFiTheme.stroke)

            Text("No purchase state is stored, no entitlement is granted, no App Store product is requested from this screen, and paid candidates cannot be bought or unlocked here.")
                .font(.callout)
                .foregroundStyle(SciFiTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .sciFiPanel(isHighlighted: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Local Plan")
        .accessibilityValue(planOverviewAccessibilityValue)
        .accessibilityHint("Summarizes the current Local plan, planning-only paid candidates, and purchase boundary.")
    }

    private var planOverviewIcon: some View {
        Image(systemName: "checklist")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(SciFiTheme.cyan)
            .frame(width: 52, height: 52)
            .background(SciFiTheme.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(SciFiTheme.cyan.opacity(0.38), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private var planOverviewCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Local Plan")
                .font(.headline)
                .foregroundStyle(SciFiTheme.primaryText)

            Text("This build is a local-first image generation app. Paid capability planning is visible here, but StoreKit is not configured.")
                .font(.body)
                .foregroundStyle(SciFiTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var planOverviewAccessibilityValue: String {
        "Local-first image generation app. Paid capability planning is visible, but StoreKit is not configured. No purchase state is stored, no entitlement is granted, no App Store product is requested from this screen, and paid candidates cannot be bought or unlocked here."
    }

    private func compactSectionFooter(_ title: String, _ text: String) -> some View {
        Text(text)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title) note")
            .accessibilityValue(text)
    }
}

private struct PlanPanel<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content

    init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(SciFiTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(title)

            VStack(alignment: .leading, spacing: 10) {
                content
            }

            if let footer {
                Text(footer)
                    .font(.callout)
                    .foregroundStyle(SciFiTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(title) note")
                    .accessibilityValue(footer)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .sciFiPanel()
    }
}

private struct PlanStatusBadge: View {
    let status: PlanStatusToken

    var body: some View {
        Label {
            Text(status.title)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: status.systemImage)
        }
        .font(.callout)
        .foregroundStyle(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(status.color.opacity(0.35), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct PlanStatusSummaryRow: View {
    let title: String
    let systemImage: String
    let status: PlanStatusToken
    let accessibilityHint: String?

    init(
        title: String,
        systemImage: String,
        status: PlanStatusToken,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.status = status
        self.accessibilityHint = accessibilityHint
    }

    var body: some View {
        let row = VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(title)
                    .foregroundStyle(SciFiTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(SciFiTheme.cyan)
            }

            PlanStatusBadge(status: status)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(status.title)

        if let accessibilityHint {
            row.accessibilityHint(accessibilityHint)
        } else {
            row
        }
    }
}

private struct PlanNoteRow: View {
    let text: String
    let systemImage: String
    let iconColor: Color
    let accessibilityLabel: String
    let accessibilityHint: String

    var body: some View {
        Label {
            Text(text)
                .font(.callout)
                .foregroundStyle(SciFiTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(iconColor)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(text)
        .accessibilityHint(accessibilityHint)
    }
}

private struct PlanStatusRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let status: PlanStatusToken

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(title)
                    .foregroundStyle(SciFiTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(SciFiTheme.cyan)
            }

            Text(detail)
                .font(.callout)
                .foregroundStyle(SciFiTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            PlanStatusBadge(status: status)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityValue(status.title)
    }
}

private struct MacReadinessRow: View {
    let item: MacReadinessItem

    var body: some View {
        PlanStatusRow(
            title: item.title,
            detail: item.detail,
            systemImage: item.systemImage,
            status: item.status.token
        )
        .accessibilityHint(item.accessibilityHint)
    }
}

private struct CapabilityRow: View {
    let item: PlanCapabilityItem

    var body: some View {
        PlanStatusRow(
            title: item.title,
            detail: item.detail,
            systemImage: item.systemImage,
            status: item.status.token
        )
        .accessibilityHint(item.accessibilityHint)
    }
}

private struct EntitlementRuleRow: View {
    let item: PlanEntitlementRuleItem

    var body: some View {
        PlanStatusRow(
            title: item.title,
            detail: item.detail,
            systemImage: item.systemImage,
            status: item.status.token
        )
        .accessibilityHint(item.accessibilityHint)
    }
}

private struct AvailabilityRow: View {
    let item: PlanAvailabilityItem

    var body: some View {
        PlanStatusRow(
            title: item.title,
            detail: item.detail,
            systemImage: item.systemImage,
            status: item.status
        )
        .accessibilityHint(item.accessibilityHint)
    }
}
