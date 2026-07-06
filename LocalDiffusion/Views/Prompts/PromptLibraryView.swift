import SwiftData
import SwiftUI

struct PromptLibraryView: View {
    let onLoad: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var generation: GenerationViewModel
    @Query(sort: \PromptTemplate.category) private var templates: [PromptTemplate]
    @State private var showingAddTemplate = false
    @State private var editingTemplate: PromptTemplate?
    @State private var editingCategory: PromptCategoryEditorState?
    @State private var pendingCategoryClear: PromptCategoryEditorState?
    @State private var searchText = ""

    private var groupedTemplates: [PromptCategoryGroup] {
        Dictionary(grouping: filteredTemplates) { template in
            template.category.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .map { category, templates in
            PromptCategoryGroup(
                category: category,
                templates: templates.sorted { $0.name < $1.name }
            )
        }
        .sorted {
            if $0.isUncategorized != $1.isUncategorized {
                return !$0.isUncategorized
            }
            return $0.title < $1.title
        }
    }

    private var filteredTemplates: [PromptTemplate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return templates }
        return templates.filter { $0.matchesSearch(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if templates.isEmpty {
                    EmptyStateView(
                        systemImage: "text.book.closed",
                        title: "No templates",
                        message: "Save prompt templates with reusable defaults."
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Prompt Library empty state"))
                    .accessibilityValue(Text("No saved prompt templates."))
                    .accessibilityHint(Text("Use Add to create a template, or save the current generation settings from Generate."))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if filteredTemplates.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "No matching templates",
                        message: "Try a different template name, category, or prompt term."
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("No matching prompt templates"))
                    .accessibilityValue(Text(emptySearchAccessibilityValue))
                    .accessibilityHint(Text("Adjust the search text or use Add to create a new template."))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(groupedTemplates) { group in
                        Section {
                            ForEach(group.templates) { template in
                                PromptTemplateRow(template: template) {
                                    generation.load(template: template)
                                    onLoad()
                                } onEdit: {
                                    editingTemplate = template
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    modelContext.delete(group.templates[index])
                                }
                                try? modelContext.save()
                            }
                        } header: {
                            PromptCategoryHeader(group: group) {
                                editingCategory = PromptCategoryEditorState(category: group.category)
                            } onClear: {
                                pendingCategoryClear = PromptCategoryEditorState(category: group.category)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Prompts")
            .sciFiScreen()
            .bottomTabBarClearance()
            .searchable(text: $searchText, prompt: "Search templates")
            .submitLabel(.search)
            .accessibilityHint("Searches template names, categories, positive prompts, and negative prompts.")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTemplate = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .accessibilityLabel(Text("Add prompt template"))
                    .accessibilityValue(Text("Ready"))
                    .accessibilityHint(Text("Opens a new prompt template editor using the current generation parameters."))
                }
            }
            .sheet(isPresented: $showingAddTemplate) {
                PromptTemplateEditor(
                    title: "New Template",
                    initialName: "",
                    initialCategory: "",
                    initialParameters: generation.parameters
                ) { name, category, parameters in
                    let template = PromptTemplate(
                        name: name,
                        category: category,
                        parameters: parameters
                    )
                    modelContext.insert(template)
                    try? modelContext.save()
                }
            }
            .sheet(item: $editingTemplate) { template in
                PromptTemplateEditor(
                    title: "Edit Template",
                    initialName: template.name,
                    initialCategory: template.category,
                    initialParameters: template.parameters
                ) { name, category, parameters in
                    template.name = name
                    template.category = category
                    template.parameters = parameters
                    try? modelContext.save()
                    editingTemplate = nil
                }
            }
            .sheet(item: $editingCategory) { categoryState in
                PromptCategoryNameEditor(
                    title: "Rename Category",
                    initialName: categoryState.category
                ) { newName in
                    renameCategory(categoryState.category, to: newName)
                    editingCategory = nil
                }
            }
            .confirmationDialog("Clear category?", isPresented: categoryClearBinding) {
                Button("Clear Category", role: .destructive) {
                    if let pendingCategoryClear {
                        clearCategory(pendingCategoryClear.category)
                    }
                    pendingCategoryClear = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingCategoryClear = nil
                }
            } message: {
                Text("Templates stay in the library and move to Uncategorized.")
            }
        }
    }

    private func renameCategory(_ oldCategory: String, to newCategory: String) {
        let trimmedNewCategory = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldCategory.isEmpty, !trimmedNewCategory.isEmpty else { return }

        for template in templates where template.category.trimmingCharacters(in: .whitespacesAndNewlines) == oldCategory {
            template.category = trimmedNewCategory
            template.updatedAt = .now
        }
        try? modelContext.save()
    }

    private func clearCategory(_ category: String) {
        guard !category.isEmpty else { return }

        for template in templates where template.category.trimmingCharacters(in: .whitespacesAndNewlines) == category {
            template.category = ""
            template.updatedAt = .now
        }
        try? modelContext.save()
    }

    private var categoryClearBinding: Binding<Bool> {
        Binding(
            get: { pendingCategoryClear != nil },
            set: { isPresented in
                if !isPresented {
                    pendingCategoryClear = nil
                }
            }
        )
    }

    private var emptySearchAccessibilityValue: String {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return "No templates match the current search."
        }
        return "No templates match \(query)."
    }
}

private extension PromptTemplate {
    func matchesSearch(_ query: String) -> Bool {
        let normalizedQuery = query.lowercased()
        return name.lowercased().contains(normalizedQuery) ||
        category.lowercased().contains(normalizedQuery) ||
        prompt.lowercased().contains(normalizedQuery) ||
        negativePrompt.lowercased().contains(normalizedQuery)
    }
}

private struct PromptCategoryGroup: Identifiable {
    let category: String
    let templates: [PromptTemplate]

    var id: String {
        category.isEmpty ? "__uncategorized__" : category
    }

    var title: String {
        category.isEmpty ? "Uncategorized" : category
    }

    var isUncategorized: Bool {
        category.isEmpty
    }
}

private struct PromptCategoryEditorState: Identifiable {
    let category: String

    var id: String {
        category
    }
}

private struct PromptCategoryHeader: View {
    let group: PromptCategoryGroup
    let onRename: () -> Void
    let onClear: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        headerContent
    }

    @ViewBuilder
    private var headerContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                title
                if !group.isUncategorized {
                    categoryActions
                }
            }
        } else {
            HStack {
                title
                Spacer()
                if !group.isUncategorized {
                    categoryActions
                }
            }
        }
    }

    private var title: some View {
        Text(group.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SciFiTheme.cyan)
    }

    private var categoryActions: some View {
        Menu {
            Button {
                onRename()
            } label: {
                Label("Rename Category", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onClear()
            } label: {
                Label("Clear Category", systemImage: "folder.badge.minus")
            }
        } label: {
            Label("Category Actions", systemImage: "ellipsis.circle")
        }
        .labelStyle(.iconOnly)
        .foregroundStyle(SciFiTheme.cyan)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .hoverEffect(.highlight)
        .accessibilityLabel(Text("\(group.title) category actions"))
        .accessibilityValue(Text("Menu"))
        .accessibilityHint(Text("Opens rename and clear actions for this category."))
    }
}

private struct PromptTemplateRow: View {
    let template: PromptTemplate
    let onLoad: () -> Void
    let onEdit: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            metricPills
        }
        .padding(12)
        .sciFiPanel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Prompt template: \(template.name)"))
        .accessibilityValue(Text(templateAccessibilityValue))
        .accessibilityHint(Text("Contains summary metrics plus Edit Template and Load Template controls."))
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                templateCopy
                actions
            }
        } else {
            HStack {
                templateCopy
                Spacer()
                actions
            }
        }
    }

    private var templateCopy: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(template.name)
                .font(.headline)
                .foregroundStyle(SciFiTheme.primaryText)
            Text(template.prompt)
                .font(.subheadline)
                .foregroundStyle(SciFiTheme.secondaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: onEdit) {
                Label("Edit Template", systemImage: "pencil")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.amber))
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(Text("Edit Template: \(template.name)"))
            .accessibilityHint(Text("Opens \(template.name) for editing."))

            Button(action: onLoad) {
                Label("Load Template", systemImage: "arrow.down.doc")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.mint))
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(Text("Load Template: \(template.name)"))
            .accessibilityHint(Text("Loads \(template.name) into Generate."))
        }
    }

    @ViewBuilder
    private var metricPills: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                stepsPill
                samplerPill
                sizePill
            }
        } else {
            HStack(spacing: 8) {
                stepsPill
                samplerPill
                sizePill
            }
        }
    }

    private var stepsPill: some View {
        SciFiStatusPill(title: "\(template.steps)", systemImage: "number", color: SciFiTheme.cyan)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Template denoising steps"))
            .accessibilityValue(Text("\(template.steps) steps"))
            .accessibilityHint(Text("Shows the number of denoising steps saved with this template."))
    }

    private var samplerPill: some View {
        SciFiStatusPill(title: template.samplerRawValue, systemImage: "slider.horizontal.3", color: SciFiTheme.magenta)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Template sampler algorithm"))
            .accessibilityValue(Text(template.samplerRawValue))
            .accessibilityHint(Text("Shows the sampler algorithm saved with this template."))
    }

    private var sizePill: some View {
        SciFiStatusPill(title: "\(template.width)x\(template.height)", systemImage: "aspectratio", color: SciFiTheme.amber)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Template canvas pixel size"))
            .accessibilityValue(Text("\(template.width) by \(template.height) pixels"))
            .accessibilityHint(Text("Shows the canvas width and height saved with this template."))
    }

    private var templateAccessibilityValue: String {
        "Prompt \(template.prompt). \(template.steps) steps. Sampler \(template.samplerRawValue). Size \(template.width) by \(template.height) pixels."
    }
}

struct PromptTemplateEditor: View {
    let title: String
    let onSave: (String, String, GenerationParameters) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var name: String
    @State private var category: String
    @State private var parameters: GenerationParameters

    init(
        title: String,
        initialName: String,
        initialCategory: String,
        initialParameters: GenerationParameters,
        onSave: @escaping (String, String, GenerationParameters) -> Void
    ) {
        self.title = title
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _category = State(initialValue: initialCategory)
        _parameters = State(initialValue: initialParameters)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Name", text: $name)
                    TextField("Category", text: $category)
                }
                .listRowBackground(SciFiTheme.panel)

                Section("Prompts") {
                    promptEditor(
                        title: "Positive Signal",
                        placeholder: "Describe the image this template should generate",
                        text: $parameters.prompt,
                        minHeight: 104,
                        accent: SciFiTheme.cyan,
                        accessibilityHint: "Edits the positive prompt saved with this template."
                    )

                    promptEditor(
                        title: "Negative Mask",
                        placeholder: "Artifacts, styles, or details to avoid",
                        text: $parameters.negativePrompt,
                        minHeight: 80,
                        accent: SciFiTheme.magenta,
                        accessibilityHint: "Edits the negative prompt saved with this template."
                    )
                }
                .listRowBackground(SciFiTheme.panel)

                ParameterEditor(parameters: $parameters)
            }
            .navigationTitle(title)
            .sciFiScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel(Text("Cancel template editing"))
                    .accessibilityValue(Text("No changes saved"))
                    .accessibilityHint(Text("Closes the template editor without saving the current edits."))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            category.trimmingCharacters(in: .whitespacesAndNewlines),
                            parameters
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(Text("Save template"))
                    .accessibilityValue(Text(templateSaveAccessibilityValue))
                    .accessibilityHint(Text(templateSaveAccessibilityHint))
                }
            }
        }
    }

    private func promptEditor(
        title: String,
        placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat,
        accent: Color,
        accessibilityHint: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                    Text("\(text.wrappedValue.count) chars")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(SciFiTheme.secondaryText)
                }
            } else {
                HStack {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                    Spacer()
                    Text("\(text.wrappedValue.count) chars")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(SciFiTheme.secondaryText)
                }
            }

            TextEditor(text: text)
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
                .accessibilityHint(Text(accessibilityHint))
        }
    }

    private func promptEditorMinHeight(_ minHeight: CGFloat) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? minHeight + 48 : minHeight
    }

    private var hasTemplateName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var templateSaveAccessibilityValue: String {
        hasTemplateName ? "Ready" : "Template name required"
    }

    private var templateSaveAccessibilityHint: String {
        hasTemplateName
        ? "Saves this template name, category, prompts, and generation parameters."
        : "Enter a template name before saving."
    }
}

private struct PromptCategoryNameEditor: View {
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
                Section("Category") {
                    TextField("Name", text: $name)
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
                    .accessibilityLabel(Text("Cancel category rename"))
                    .accessibilityValue(Text("No changes saved"))
                    .accessibilityHint(Text("Closes the category editor without saving the rename."))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(Text("Save category name"))
                    .accessibilityValue(Text(categorySaveAccessibilityValue))
                    .accessibilityHint(Text(categorySaveAccessibilityHint))
                }
            }
        }
    }

    private var hasCategoryName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var categorySaveAccessibilityValue: String {
        hasCategoryName ? "Ready" : "Category name required"
    }

    private var categorySaveAccessibilityHint: String {
        hasCategoryName
        ? "Saves the category name for matching prompt templates."
        : "Enter a category name before saving."
    }
}
