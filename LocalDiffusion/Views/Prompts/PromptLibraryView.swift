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
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if filteredTemplates.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "No matching templates",
                        message: "Try a different template name, category, or prompt term."
                    )
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTemplate = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
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

    var body: some View {
        HStack {
            Text(group.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SciFiTheme.cyan)
            Spacer()
            if !group.isUncategorized {
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
                    Image(systemName: "ellipsis.circle")
                }
                .foregroundStyle(SciFiTheme.cyan)
                .accessibilityLabel("Category actions")
            }
        }
    }
}

private struct PromptTemplateRow: View {
    let template: PromptTemplate
    let onLoad: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(SciFiTheme.primaryText)
                    Text(template.prompt)
                        .font(.subheadline)
                        .foregroundStyle(SciFiTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.amber))
                .accessibilityLabel("Edit template")

                Button(action: onLoad) {
                    Image(systemName: "arrow.down.doc")
                }
                .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.mint))
                .accessibilityLabel("Load template")
            }

            HStack(spacing: 8) {
                SciFiStatusPill(title: "\(template.steps)", systemImage: "number", color: SciFiTheme.cyan)
                SciFiStatusPill(title: template.samplerRawValue, systemImage: "slider.horizontal.3", color: SciFiTheme.magenta)
                SciFiStatusPill(title: "\(template.width)x\(template.height)", systemImage: "aspectratio", color: SciFiTheme.amber)
            }
        }
        .padding(12)
        .sciFiPanel()
    }
}

struct PromptTemplateEditor: View {
    let title: String
    let onSave: (String, String, GenerationParameters) -> Void

    @Environment(\.dismiss) private var dismiss
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
                    TextEditor(text: $parameters.prompt)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(SciFiTheme.primaryText)
                        .frame(minHeight: 96)
                    TextEditor(text: $parameters.negativePrompt)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(SciFiTheme.primaryText)
                        .frame(minHeight: 72)
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
                }
            }
        }
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
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
