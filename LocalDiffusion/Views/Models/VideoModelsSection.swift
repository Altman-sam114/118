import SwiftUI

struct VideoModelsSection: View {
    let models: [VideoModel]
    let isImporting: Bool
    let onImport: () -> Void
    let onCheck: (VideoModel) -> Void
    let onDelete: (VideoModel) -> Void

    var body: some View {
        Section {
            if models.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("No deployed video packages", systemImage: "film.stack")
                        .font(.headline)
                        .foregroundStyle(SciFiTheme.primaryText)
                    Text("Import an explicit .ldvideo package to check its files and keep it separate from image models.")
                        .font(.subheadline)
                        .foregroundStyle(SciFiTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onImport) {
                        Label("Import Video Package", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.cyan))
                    .disabled(isImporting)
                    .accessibilityValue(isImporting ? "Importing" : "Ready")
                    .accessibilityHint("Copies and validates an explicit .ldvideo package. It does not generate video.")
                }
                .padding(.vertical, 8)
            } else {
                ForEach(models) { model in
                    VideoModelRow(model: model, onCheck: { onCheck(model) }, onDelete: { onDelete(model) })
                }
            }
        } header: {
            Text("Video Models")
        } footer: {
            Text("Video packages use separate storage. Deployed means the package is complete; video inference is unavailable in this build.")
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct VideoModelRow: View {
    let model: VideoModel
    let onCheck: () -> Void
    let onDelete: () -> Void
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                header(horizontal: true)
                header(horizontal: false)
            }

            ViewThatFits(in: .horizontal) {
                statusRow(horizontal: true)
                statusRow(horizontal: false)
            }

            HStack(spacing: 10) {
                Button(action: onCheck) {
                    Label("Check Deployment", systemImage: "checkmark.shield")
                }
                .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.cyan))
                .accessibilityLabel("Check deployment for \(model.name)")
                .accessibilityHint("Rechecks the package manifest, required files, size, and integrity.")

                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(SciFiTheme.amber)
                .accessibilityLabel("Remove deployed video package \(model.name)")
                .accessibilityHint("Removes this video package and its deployment record. It does not affect image models.")
            }
        }
        .padding(.vertical, 8)
        .sciFiPanel(isHighlighted: model.deploymentStatus == .ready)
        .accessibilityElement(children: .contain)
        .confirmationDialog("Remove video package?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Remove Package", role: .destructive, action: onDelete)
                .accessibilityLabel("Remove deployed video package \(model.name)")
                .accessibilityValue(model.name)
                .accessibilityHint("Removes the validated package from VideoModels. Image models are unchanged.")
            Button("Cancel", role: .cancel) { }
                .accessibilityLabel("Cancel removing video package \(model.name)")
                .accessibilityValue(model.name)
        } message: {
            Text("This removes \(model.name) from the dedicated video-model directory.")
        }
    }

    private func header(horizontal: Bool) -> some View {
        Group {
            if horizontal {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    identity
                    Spacer(minLength: 8)
                    deploymentBadge
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    identity
                    deploymentBadge
                }
            }
        }
    }

    private func statusRow(horizontal: Bool) -> some View {
        Group {
            if horizontal {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(model.packageType.title)
                    Text(model.sizeDescription)
                    Text(model.inferenceAvailability.title)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.packageType.title)
                    Text(model.sizeDescription)
                    Text(model.inferenceAvailability.title)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(SciFiTheme.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.name)
                .font(.headline)
                .foregroundStyle(SciFiTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(model.sourceLabel) · v\(model.sourceVersion)")
                .font(.caption)
                .foregroundStyle(SciFiTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var deploymentBadge: some View {
        Label(model.deploymentStatus.title, systemImage: deploymentSystemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(deploymentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .overlay {
                Capsule()
                    .stroke(deploymentColor.opacity(0.45), lineWidth: 1)
            }
            .accessibilityLabel("Deployment status")
            .accessibilityValue(model.deploymentStatus.title)
    }

    private var deploymentSystemImage: String {
        switch model.deploymentStatus {
        case .ready: "checkmark.circle"
        case .unsupported: "questionmark.circle"
        case .failed: "xmark.octagon"
        case .queued, .downloading, .paused: "arrow.down.circle"
        case .unavailable: "minus.circle"
        }
    }

    private var deploymentColor: Color {
        switch model.deploymentStatus {
        case .ready: SciFiTheme.mint
        case .unsupported, .failed: SciFiTheme.amber
        case .queued, .downloading, .paused: SciFiTheme.cyan
        case .unavailable: SciFiTheme.secondaryText
        }
    }
}
