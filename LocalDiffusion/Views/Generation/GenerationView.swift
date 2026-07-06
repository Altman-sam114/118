import SwiftData
import SwiftUI
import UIKit

struct GenerationView: View {
    let fileStore: AppFileStore
    let onShowGallery: () -> Void
    let onShowModels: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var viewModel: GenerationViewModel
    @Query(sort: \LocalModel.name) private var models: [LocalModel]
    @State private var showingSaveTemplate = false
    @FocusState private var focusedPrompt: PromptField?

    private var readyModels: [LocalModel] {
        models.filter(\.isReady)
    }

    private var selectedModel: LocalModel? {
        readyModels.first(where: { $0.id == viewModel.selectedModelID }) ?? readyModels.first
    }

    var body: some View {
        NavigationStack {
            generationLayout
            .navigationTitle("Generate")
            .sciFiScreen()
            .bottomTabBarClearance()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSaveTemplate = true
                    } label: {
                        Label("Save Template", systemImage: "bookmark")
                    }
                    .disabled(viewModel.parameters.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityValue(Text(saveTemplateAccessibilityValue))
                    .accessibilityHint(Text(saveTemplateAccessibilityHint))
                }
            }
            .sheet(isPresented: $showingSaveTemplate) {
                PromptTemplateEditor(
                    title: "Save Template",
                    initialName: "",
                    initialCategory: "",
                    initialParameters: viewModel.parameters
                ) { name, category, parameters in
                    modelContext.insert(PromptTemplate(
                        name: name,
                        category: category,
                        parameters: parameters
                    ))
                    try? modelContext.save()
                }
            }
            .alert("Generation", isPresented: alertBinding) {
                Button("OK", role: .cancel) {
                    viewModel.alertMessage = nil
                }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .onAppear {
                if viewModel.selectedModelID == nil {
                    viewModel.selectedModelID = readyModels.first?.id
                }
            }
        }
    }

    @ViewBuilder
    private var generationLayout: some View {
        if horizontalSizeClass == .regular {
            if dynamicTypeSize.isAccessibilitySize {
                singleColumnGenerationLayout
            } else {
                wideGenerationLayout
            }
        } else {
            compactGenerationLayout
        }
    }

    private var compactGenerationLayout: some View {
        singleColumnGenerationLayout
    }

    private var singleColumnGenerationLayout: some View {
        Form {
            consoleSection
            modelSection
            promptsSection
            ParameterEditor(parameters: $viewModel.parameters)
            runSection
            resultSection
        }
    }

    private var wideGenerationLayout: some View {
        HStack(spacing: 0) {
            Form {
                modelSection
                promptsSection
                ParameterEditor(parameters: $viewModel.parameters)
            }
            .scrollContentBackground(.hidden)
            .frame(minWidth: 360, idealWidth: 470, maxWidth: 560)

            Rectangle()
                .fill(SciFiTheme.stroke)
                .frame(width: 1)
                .accessibilityHidden(true)

            Form {
                consoleSection
                runSection
                resultSection
            }
            .scrollContentBackground(.hidden)
            .frame(minWidth: 320, maxWidth: .infinity)
        }
    }

    private var consoleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                consoleOverview
                consoleStatusPills
                consoleMetrics
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
    }

    @ViewBuilder
    private var consoleOverview: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                consoleOverviewIcon
                consoleOverviewCopy
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                consoleOverviewIcon
                consoleOverviewCopy
            }
        }
    }

    private var consoleOverviewIcon: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(SciFiTheme.cyan)
            .frame(width: 54, height: 54)
            .background(SciFiTheme.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(SciFiTheme.cyan.opacity(0.38), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private var consoleOverviewCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Local Render Console")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SciFiTheme.primaryText)
            Text("GGUF model loaded locally. Tune prompts and fire the native backend from this device.")
                .font(.subheadline)
                .foregroundStyle(SciFiTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var consoleStatusPills: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                backendStatusPill
                modelStatusPill
            }
        } else {
            HStack {
                backendStatusPill
                modelStatusPill
            }
        }
    }

    private var backendStatusPill: some View {
        SciFiStatusPill(
            title: viewModel.backendStatus.isReady ? "Backend Online" : "Backend Offline",
            systemImage: viewModel.backendStatus.isReady ? "cpu" : "exclamationmark.triangle",
            color: viewModel.backendStatus.isReady ? SciFiTheme.mint : SciFiTheme.amber
        )
    }

    private var modelStatusPill: some View {
        SciFiStatusPill(
            title: selectedModel?.family.rawValue ?? "No Model",
            systemImage: "shippingbox",
            color: selectedModel == nil ? SciFiTheme.amber : SciFiTheme.cyan
        )
    }

    private var consoleMetrics: some View {
        LazyVGrid(columns: consoleMetricColumns, spacing: 10) {
            SciFiMetric(title: "Steps", value: "\(viewModel.parameters.steps)", systemImage: "number")
            SciFiMetric(
                title: "Canvas",
                value: "\(viewModel.parameters.width)x\(viewModel.parameters.height)",
                systemImage: "aspectratio",
                color: SciFiTheme.magenta
            )
        }
    }

    private var consoleMetricColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }

        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var modelSection: some View {
        Section("Model") {
            if readyModels.isEmpty {
                VStack(spacing: 12) {
                    EmptyStateView(
                        systemImage: "shippingbox",
                        title: "No local model",
                        message: "Download or import a GGUF model before starting generation."
                    )

                    Button {
                        onShowModels()
                    } label: {
                        Label("Open Models", systemImage: "shippingbox")
                    }
                    .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.mint))
                }
            } else {
                Picker("Model", selection: selectedModelBinding) {
                    ForEach(readyModels) { model in
                        Text(model.name).tag(Optional(model.id))
                    }
                }
            }
        }
        .listRowBackground(SciFiTheme.panel)
    }

    private var promptsSection: some View {
        Section("Prompts") {
            promptEditor(
                title: "Positive Signal",
                placeholder: "Describe the image to synthesize",
                text: $viewModel.parameters.prompt,
                field: .positive,
                minHeight: horizontalSizeClass == .regular ? 150 : 112,
                accent: SciFiTheme.cyan
            )

            promptEditor(
                title: "Negative Mask",
                placeholder: "Artifacts, style, or details to avoid",
                text: $viewModel.parameters.negativePrompt,
                field: .negative,
                minHeight: horizontalSizeClass == .regular ? 104 : 84,
                accent: SciFiTheme.magenta
            )
        }
        .listRowBackground(SciFiTheme.panel)
    }

    private var runSection: some View {
        Section("Run") {
            let gate = generationGate
            GenerationGatePanel(gate: gate)

            if viewModel.isGenerating {
                ProgressView(value: viewModel.progress.fraction) {
                    Text(viewModel.progress.stage)
                        .foregroundStyle(SciFiTheme.primaryText)
                }
                .tint(SciFiTheme.cyan)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Generation progress"))
                .accessibilityValue(Text(generationProgressAccessibilityValue))
                .accessibilityHint(Text("Shows the current local render stage and percentage."))
                Button(role: .destructive) {
                    viewModel.cancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.danger))
                .disabled(viewModel.isCancelling)
                .accessibilityLabel(Text("Cancel generation"))
                .accessibilityValue(Text(viewModel.isCancelling ? "Cancelling" : "Active"))
                .accessibilityHint(Text("Stops the current local render task before it saves a result."))
            } else {
                Button {
                    viewModel.generate(using: selectedModel, modelContext: modelContext)
                } label: {
                    Label(gate.primaryActionTitle, systemImage: gate.primaryActionImage)
                }
                .buttonStyle(SciFiPrimaryButtonStyle())
                .disabled(!canGenerate)
                .accessibilityLabel(Text("Generate image"))
                .accessibilityValue(Text(primaryGenerateAccessibilityValue(for: gate)))
                .accessibilityHint(Text(primaryGenerateAccessibilityHint(for: gate)))

                switch gate.secondaryAction {
                case .openModels:
                    Button {
                        onShowModels()
                    } label: {
                        Label("Open Models", systemImage: "shippingbox")
                    }
                    .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.mint))
                    .accessibilityValue(Text("Model required"))
                    .accessibilityHint(Text("Opens Models to download or import a ready GGUF model before generation."))
                case .focusPrompt:
                    Button {
                        focusedPrompt = .positive
                    } label: {
                        Label("Edit Prompt", systemImage: "text.cursor")
                    }
                    .buttonStyle(SciFiSecondaryButtonStyle())
                    .accessibilityValue(Text("Positive prompt required"))
                    .accessibilityHint(Text("Moves focus to Positive Signal so you can enter the prompt used for generation."))
                case .none:
                    EmptyView()
                }
            }
        }
        .listRowBackground(SciFiTheme.panel)
    }

    @ViewBuilder
    private var resultSection: some View {
        if let imageData = viewModel.generatedImageData,
           let image = UIImage(data: imageData) {
            Section("Result") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(SciFiTheme.cyan.opacity(0.28), lineWidth: 1)
                    }
                    .accessibilityLabel(Text("Generated image preview"))
                    .accessibilityValue(Text(resultImageAccessibilityValue(for: image)))
                    .accessibilityHint(Text("Use View in Gallery to inspect, tag, share, or reuse the saved result."))

                Button {
                    onShowGallery()
                } label: {
                    Label("View in Gallery", systemImage: "square.grid.2x2")
                }
                .buttonStyle(SciFiSecondaryButtonStyle())
                .disabled(viewModel.latestGeneratedImageID == nil)
                .accessibilityValue(Text(viewModel.latestGeneratedImageID == nil ? "Unavailable" : "Ready"))
                .accessibilityHint(Text("Opens the saved generated image in Gallery."))
            }
            .listRowBackground(SciFiTheme.panel)
        }
    }

    private func promptEditor(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: PromptField,
        minHeight: CGFloat,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            promptEditorHeader(title: title, text: text, accent: accent)

            TextEditor(text: text)
                .focused($focusedPrompt, equals: field)
                .scrollContentBackground(.hidden)
                .foregroundStyle(SciFiTheme.primaryText)
                .frame(minHeight: promptEditorMinHeight(minHeight))
                .padding(8)
                .background(SciFiTheme.panelSoft, in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.body)
                            .foregroundStyle(SciFiTheme.secondaryText.opacity(0.72))
                            .padding(.top, 16)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accent.opacity(0.26), lineWidth: 1)
                }
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text(text.wrappedValue.isEmpty ? "Empty prompt" : text.wrappedValue))
                .accessibilityHint(Text(accessibilityHint(for: field)))
        }
    }

    @ViewBuilder
    private func promptEditorHeader(
        title: String,
        text: Binding<String>,
        accent: Color
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                promptEditorTitle(title, accent: accent)
                promptEditorMetadata(text: text, title: title)
            }
        } else {
            HStack {
                promptEditorTitle(title, accent: accent)
                Spacer()
                promptEditorMetadata(text: text, title: title)
            }
        }
    }

    private func promptEditorTitle(_ title: String, accent: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent)
    }

    @ViewBuilder
    private func promptEditorMetadata(text: Binding<String>, title: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                promptCharacterCount(text)
                clearPromptButton(text: text, title: title)
            }
        } else {
            HStack(spacing: 8) {
                promptCharacterCount(text)
                clearPromptButton(text: text, title: title)
            }
        }
    }

    private func promptCharacterCount(_ text: Binding<String>) -> some View {
        Text("\(text.wrappedValue.count) chars")
            .font(.caption.monospacedDigit())
            .foregroundStyle(SciFiTheme.secondaryText)
    }

    @ViewBuilder
    private func clearPromptButton(text: Binding<String>, title: String) -> some View {
        if !text.wrappedValue.isEmpty {
            if dynamicTypeSize.isAccessibilitySize {
                clearPromptButtonContent(text: text, title: title)
            } else {
                clearPromptButtonContent(text: text, title: title)
                    .labelStyle(.iconOnly)
            }
        }
    }

    private func clearPromptButtonContent(text: Binding<String>, title: String) -> some View {
        Button {
            text.wrappedValue = ""
        } label: {
            Label("Clear \(title)", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(SciFiTheme.secondaryText)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityHint("Clears only this prompt field.")
    }

    private func promptEditorMinHeight(_ minHeight: CGFloat) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? minHeight + 48 : minHeight
    }

    private func accessibilityHint(for field: PromptField) -> String {
        switch field {
        case .positive:
            return "Edits the positive prompt used for image generation."
        case .negative:
            return "Edits the negative prompt used to avoid unwanted details."
        }
    }

    private var selectedModelBinding: Binding<UUID?> {
        Binding(
            get: { selectedModel?.id },
            set: { viewModel.selectedModelID = $0 }
        )
    }

    private var canGenerate: Bool {
        selectedModel != nil &&
        viewModel.backendStatus.isReady &&
        !viewModel.parameters.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSaveTemplate: Bool {
        !viewModel.parameters.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var saveTemplateAccessibilityValue: String {
        canSaveTemplate ? "Ready" : "Positive prompt required"
    }

    private var saveTemplateAccessibilityHint: String {
        canSaveTemplate
        ? "Saves the current prompts and generation parameters as a Prompt Library template."
        : "Enter a positive prompt before saving a template."
    }

    private func primaryGenerateAccessibilityValue(for gate: GenerationGate) -> String {
        canGenerate ? "Ready" : "Unavailable. \(gate.title). \(gate.message)"
    }

    private func primaryGenerateAccessibilityHint(for gate: GenerationGate) -> String {
        canGenerate
        ? "Starts local image generation with the selected model and current prompts."
        : gate.accessibilityHint
    }

    private var generationGate: GenerationGate {
        if !viewModel.backendStatus.isReady {
            return GenerationGate(
                title: "Backend Offline",
                message: viewModel.backendStatus.message,
                systemImage: "exclamationmark.triangle",
                color: SciFiTheme.amber,
                primaryActionTitle: "Generate",
                primaryActionImage: "play.slash",
                secondaryAction: .none,
                accessibilityHint: "Generation cannot start until the local inference backend is available."
            )
        }

        if selectedModel == nil {
            return GenerationGate(
                title: "Model Required",
                message: "No ready model is selected.",
                systemImage: "shippingbox",
                color: SciFiTheme.amber,
                primaryActionTitle: "Select Model First",
                primaryActionImage: "play.slash",
                secondaryAction: .openModels,
                accessibilityHint: "Open Models to download or import a ready GGUF model."
            )
        }

        if viewModel.parameters.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return GenerationGate(
                title: "Prompt Required",
                message: "Positive prompt is empty.",
                systemImage: "text.cursor",
                color: SciFiTheme.amber,
                primaryActionTitle: "Add Prompt First",
                primaryActionImage: "play.slash",
                secondaryAction: .focusPrompt,
                accessibilityHint: "Edit the positive prompt before starting generation."
            )
        }

        let title = viewModel.backendStatus.title == "Debug Mock Inference" ? "Mock Backend Ready" : "Ready to Render"
        return GenerationGate(
            title: title,
            message: "\(selectedModel?.name ?? "Model") is ready.",
            systemImage: "checkmark.seal",
            color: SciFiTheme.mint,
            primaryActionTitle: "Generate",
            primaryActionImage: "play.fill",
            secondaryAction: .none,
            accessibilityHint: "Ready to start local image generation."
        )
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.alertMessage = nil
                }
            }
        )
    }

    private var generationProgressAccessibilityValue: String {
        "\(viewModel.progress.stage), \(progressPercentText)."
    }

    private var progressPercentText: String {
        let clampedFraction = min(max(viewModel.progress.fraction, 0), 1)
        return "\(Int((clampedFraction * 100).rounded())) percent"
    }

    private func resultImageAccessibilityValue(for image: UIImage) -> String {
        let pixelWidth = Int((image.size.width * image.scale).rounded())
        let pixelHeight = Int((image.size.height * image.scale).rounded())
        let galleryState = viewModel.latestGeneratedImageID == nil ? "Gallery record unavailable" : "Saved to Gallery"
        return "\(pixelWidth) by \(pixelHeight) pixels. \(galleryState)."
    }
}

private enum PromptField: Hashable {
    case positive
    case negative
}

private enum GenerationGateSecondaryAction {
    case none
    case openModels
    case focusPrompt
}

private struct GenerationGate {
    let title: String
    let message: String
    let systemImage: String
    let color: Color
    let primaryActionTitle: String
    let primaryActionImage: String
    let secondaryAction: GenerationGateSecondaryAction
    let accessibilityHint: String
}

private struct GenerationGatePanel: View {
    let gate: GenerationGate

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: gate.systemImage)
                .font(.headline)
                .foregroundStyle(gate.color)
                .frame(width: 32, height: 32)
                .background(gate.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(gate.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SciFiTheme.primaryText)
                Text(gate.message)
                    .font(.caption)
                    .foregroundStyle(SciFiTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(SciFiTheme.panelSoft, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(gate.color.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Generation status"))
        .accessibilityValue(Text("\(gate.title). \(gate.message)"))
        .accessibilityHint(Text(gate.accessibilityHint))
    }
}
