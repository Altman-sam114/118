import SwiftData
import SwiftUI

@main
struct LocalDiffusionApp: App {
    private let fileStore: AppFileStore
    private let modelContainer: ModelContainer?
    private let startupErrorMessage: String?

    @StateObject private var downloadManager: HuggingFaceDownloadManager

    init() {
        let fileStore = AppFileStore.shared
        let containerResult = Self.makeModelContainer()
        self.fileStore = fileStore
        self.modelContainer = containerResult.container
        self.startupErrorMessage = containerResult.errorMessage
        _downloadManager = StateObject(wrappedValue: HuggingFaceDownloadManager(fileStore: fileStore))
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                RootContentView(fileStore: fileStore)
                    .environmentObject(downloadManager)
                    .modelContainer(modelContainer)
            } else {
                StartupFailureView(message: startupErrorMessage ?? "SwiftData storage could not be opened.")
            }
        }
    }

    private static func makeModelContainer() -> (container: ModelContainer?, errorMessage: String?) {
        let schema = Schema([
            LocalModel.self,
            GeneratedImage.self,
            GalleryFolder.self,
            PromptTemplate.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return (try ModelContainer(for: schema, configurations: [configuration]), nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }
}

private struct StartupFailureView: View {
    let message: String

    var body: some View {
        ZStack {
            SciFiBackground()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(SciFiTheme.amber)
                    .frame(width: 76, height: 76)
                    .background(SciFiTheme.panelStrong, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(SciFiTheme.amber.opacity(0.38), lineWidth: 1)
                    }

                VStack(spacing: 8) {
                    Text("Storage Offline")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(SciFiTheme.primaryText)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(SciFiTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Close and reopen after the storage issue is resolved.")
                    .font(.caption)
                    .foregroundStyle(SciFiTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: 420)
            .sciFiPanel(isHighlighted: true)
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}
