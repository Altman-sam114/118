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
                    .frame(minHeight: 44)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

            if let lastError = model.lastError, !lastError.isEmpty {
                Text("Error: \(lastError)")
                    .font(.caption)
                    .foregroundStyle(SciFiTheme.amber)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Deployment error")
                    .accessibilityValue(lastError)
                    .accessibilityHint("Check deployment to validate this package again.")
            }

            if dynamicTypeSize.isAccessibilitySize {
                actionButtons(vertical: true)
            } else {
                ViewThatFits(in: .horizontal) {
                    actionButtons(vertical: false)
                    actionButtons(vertical: true)
                }
            }
        }
        .padding(.vertical, 8)
        .sciFiPanel(isHighlighted: model.deploymentStatus == .ready)
        .accessibilityElement(children: .contain)
        .confirmationDialog("Remove video package?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Remove Package", role: .destructive, action: onDelete)
                .accessibilityLabel(removeActionAccessibilityLabel)
                .accessibilityValue(model.name)
                .accessibilityHint("Removes the validated package from VideoModels. Image models are unchanged.")
            Button("Cancel", role: .cancel) { }
                .accessibilityLabel("Cancel removing video package \(model.name)")
                .accessibilityValue(model.name)
        } message: {
            Text("This removes \(model.name) from the dedicated video-model directory.")
        }
    }

    @ViewBuilder
    private func actionButtons(vertical: Bool) -> some View {
        if vertical {
            VStack(alignment: .leading, spacing: 8) {
                checkButton
                deleteButton
            }
        } else {
            HStack(spacing: 10) {
                checkButton
                deleteButton
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var checkButton: some View {
        Button(action: onCheck) {
            Label("Check Deployment", systemImage: "checkmark.shield")
        }
        .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.cyan))
        .frame(minHeight: 44)
        .accessibilityLabel("Check deployment for \(model.name)")
        .accessibilityHint("Rechecks the package manifest, required files, size, and integrity.")
    }

    private var deleteButton: some View {
        Button {
            showingDeleteConfirmation = true
        } label: {
            Image(systemName: "trash")
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(SciFiTheme.amber)
        .accessibilityLabel(removeActionAccessibilityLabel)
        .accessibilityHint("Removes this video package and its deployment record. It does not affect image models.")
    }

    private var removeActionAccessibilityLabel: String {
        if model.deploymentStatus == .ready {
            "Remove deployed video package \(model.name)"
        } else {
            "Remove video package \(model.name)"
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
                    packageTypeStatus
                    sizeStatus
                    inferenceStatus
                }
                .fixedSize(horizontal: true, vertical: false)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    packageTypeStatus
                    sizeStatus
                    inferenceStatus
                }
            }
        }
        .font(.caption)
        .foregroundStyle(SciFiTheme.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var packageTypeStatus: some View {
        Text(model.packageType.title)
            .accessibilityLabel("Package type")
            .accessibilityValue(model.packageType.title)
    }

    private var sizeStatus: some View {
        Text(model.sizeDescription)
            .accessibilityLabel("Package size")
            .accessibilityValue(model.sizeDescription)
    }

    private var inferenceStatus: some View {
        Label(model.inferenceAvailability.title, systemImage: "nosign")
            .foregroundStyle(SciFiTheme.amber)
            .accessibilityLabel("Video inference availability")
            .accessibilityValue(model.inferenceAvailability.title)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Video model \(model.name)")
        .accessibilityValue("\(model.sourceLabel), version \(model.sourceVersion)")
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
