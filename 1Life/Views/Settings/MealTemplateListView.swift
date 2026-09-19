import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct MealTemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\MealTemplate.useCount, order: .reverse), SortDescriptor(\MealTemplate.updatedAt, order: .reverse)])
    private var templates: [MealTemplate]

    private let fixedCategory: TemplateLibraryCategory?
    private let pageEyebrow: String
    private let pageTitle: String?

    @State private var editingTemplate: MealTemplate?
    @State private var isAddingTemplate = false
    @State private var isShowingImportPicker = false
    @State private var shareItem: ShareSheetItem?
    @State private var isShowingTemplateExportSheet = false
    @State private var bannerCenter = GlobalBannerCenter.shared
    @State private var selectedCategory: TemplateLibraryCategory = .meal
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var expandedTemplateGroupKeys: Set<String> = []
    @State private var expandedDrinkBrandKeys: Set<String> = []
    @State private var expandedDrinkGroupKeys: Set<String> = []

    @Query(sort: [SortDescriptor(\DrinkRecord.brand), SortDescriptor(\DrinkRecord.productName)])
    private var drinkRecords: [DrinkRecord]

    init(
        initialCategory: TemplateLibraryCategory = .meal,
        fixedCategory: Bool = false,
        pageEyebrow: String = "模板库",
        pageTitle: String? = nil
    ) {
        self.fixedCategory = fixedCategory ? initialCategory : nil
        self.pageEyebrow = pageEyebrow
        self.pageTitle = pageTitle
        _selectedCategory = State(initialValue: initialCategory)
    }

    private var filteredTemplates: [MealTemplate] {
        templates.filter { template in
            selectedCategory.matches(template) && matchesSearch(template)
        }
    }

    private var filteredDrinkRecords: [DrinkRecord] {
        guard selectedCategory == .beverage else { return [] }
        return drinkRecords.filter(matchesSearch)
    }

    private func templateGroups(from templates: [MealTemplate]) -> [MealTemplateGroup] {
        Dictionary(grouping: templates, by: { MealTemplateGroup.groupKey(for: $0) })
            .values
            .map { MealTemplateGroup(templates: $0) }
            .sorted { lhs, rhs in
                if lhs.defaultTemplate.useCount != rhs.defaultTemplate.useCount {
                    return lhs.defaultTemplate.useCount > rhs.defaultTemplate.useCount
                }
                return lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }
    }

    private func drinkProductGroups(from records: [DrinkRecord]) -> [MealTemplateDrinkRecordGroup] {
        Dictionary(grouping: records, by: { MealTemplateDrinkRecordGroup.groupKey(for: $0) })
            .values
            .map { MealTemplateDrinkRecordGroup(records: $0) }
            .sorted { lhs, rhs in
                if lhs.brand != rhs.brand { return lhs.brand.localizedCompare(rhs.brand) == .orderedAscending }
                return lhs.productName.localizedCompare(rhs.productName) == .orderedAscending
            }
    }

    private func drinkBrandGroups(from records: [DrinkRecord]) -> [MealTemplateDrinkBrandGroup] {
        Dictionary(grouping: drinkProductGroups(from: records), by: { MealTemplateDrinkBrandGroup.groupKey(for: $0) })
            .values
            .map { MealTemplateDrinkBrandGroup(productGroups: $0) }
            .sorted { lhs, rhs in lhs.brand.localizedCompare(rhs.brand) == .orderedAscending }
    }

    private var normalizedSearchText: String {
        debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let visibleTemplates = filteredTemplates
        let visibleDrinkRecords = filteredDrinkRecords
        let visibleTemplateGroups = templateGroups(from: visibleTemplates)
        let visibleDrinkBrandGroups = drinkBrandGroups(from: visibleDrinkRecords)
        let hasVisibleSearchResults = !visibleTemplates.isEmpty || (selectedCategory == .beverage && !visibleDrinkRecords.isEmpty)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SystemPageHeader(
                    eyebrow: pageEyebrow,
                    title: pageTitle ?? selectedCategory.title,
                    detail: selectedCategory == .beverage
                        ? "\(visibleTemplates.count) 个模板 · \(visibleDrinkRecords.count) 条饮品库记录"
                        : "\(visibleTemplates.count) 个模板"
                )

                if fixedCategory == nil {
                    Picker("模板类型", selection: $selectedCategory) {
                        ForEach(TemplateLibraryCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if !templates.isEmpty || !drinkRecords.isEmpty {
                    TextField("搜索模板、食物、品牌、饮品、糖度", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                }

                if !normalizedSearchText.isEmpty && !hasVisibleSearchResults {
                    AppEmptyStateView(
                        icon: "magnifyingglass",
                        title: "没有匹配模板",
                        subtitle: "换一个模板名、食物名、品牌、饮品名或糖度试试。"
                    )
                } else if visibleTemplates.isEmpty && (selectedCategory != .beverage || visibleDrinkRecords.isEmpty) {
                    SystemPanel(title: "暂无模板", detail: "创建常用模板后会显示在这里") {
                        AppEmptyStateView(
                            icon: selectedCategory.icon,
                            title: "还没有\(selectedCategory.title)",
                            subtitle: "点击右上角新建，由你自己命名和维护具体模板。"
                        )
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(visibleTemplateGroups) { group in
                            MealTemplateGroupSection(
                                group: group,
                                isExpanded: Binding(
                                    get: { expandedTemplateGroupKeys.contains(group.id) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedTemplateGroupKeys.insert(group.id)
                                        } else {
                                            expandedTemplateGroupKeys.remove(group.id)
                                        }
                                    }
                                ),
                                onEdit: { editingTemplate = $0 },
                                onDelete: { template in modelContext.delete(template) }
                            )
                        }

                        if selectedCategory == .beverage && !visibleDrinkBrandGroups.isEmpty {
                            ForEach(visibleDrinkBrandGroups) { brandGroup in
                                MealTemplateDrinkBrandGroupSection(
                                    brandGroup: brandGroup,
                                    isExpanded: Binding(
                                        get: { !normalizedSearchText.isEmpty || expandedDrinkBrandKeys.contains(brandGroup.id) },
                                        set: { isExpanded in
                                            if isExpanded {
                                                expandedDrinkBrandKeys.insert(brandGroup.id)
                                            } else {
                                                expandedDrinkBrandKeys.remove(brandGroup.id)
                                            }
                                        }
                                    ),
                                    productExpansion: { group in
                                        Binding(
                                            get: { !normalizedSearchText.isEmpty || expandedDrinkGroupKeys.contains(group.id) },
                                            set: { isExpanded in
                                                if isExpanded {
                                                    expandedDrinkGroupKeys.insert(group.id)
                                                } else {
                                                    expandedDrinkGroupKeys.remove(group.id)
                                                }
                                            }
                                        )
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.vertical, 16)
        }
        .background(FamilyUI.pageBackground)
        .navigationTitle(pageTitle ?? "模板库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Menu {
                        Button {
                            isShowingTemplateExportSheet = true
                        } label: {
                            Label("导出模板 JSON", systemImage: "square.and.arrow.up")
                        }
                        .disabled(templates.isEmpty)

                        Button {
                            isShowingImportPicker = true
                        } label: {
                            Label("导入模板 JSON", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }

                    Button {
                        isAddingTemplate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .fileImporter(isPresented: $isShowingImportPicker, allowedContentTypes: [.json]) { result in
            importTemplates(result)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(isPresented: $isShowingTemplateExportSheet) {
            MealTemplateJSONExportSheet(templates: templates) { selectedTemplates in
                exportTemplates(selectedTemplates)
            }
        }
        .sheet(isPresented: $isAddingTemplate) {
            MealTemplateEditorView(template: nil, initialCategory: selectedCategory)
        }
        .sheet(item: $editingTemplate) { template in
            MealTemplateEditorView(template: template)
        }
        .task(id: searchText) {
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                return
            }
            debouncedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func exportTemplates(_ selectedTemplates: [MealTemplate]) {
        guard !selectedTemplates.isEmpty else {
            bannerCenter.show(title: "请选择模板", message: "至少选择一个要导出的模板。", tone: .warning)
            return
        }
        bannerCenter.show(title: "正在导出模板", message: "已选择 \(selectedTemplates.count) 个模板。", tone: .success)
        Task { @MainActor in
            do {
                try? await Task.sleep(for: .milliseconds(120))
                let data = try ExportService.exportMealTemplatesJSON(selectedTemplates)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("1Life_meal_templates.json")
                try data.write(to: tempURL, options: [.atomic])
                shareItem = ShareSheetItem(url: tempURL)
                HapticEngine.success()
            } catch {
                HapticEngine.warning()
                bannerCenter.show(title: "模板导出失败", message: error.localizedDescription, tone: .error)
            }
        }
    }

    private func importTemplates(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didStart = url.startAccessingSecurityScopedResource()
            defer {
                if didStart {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            let count = try ExportService.importMealTemplatesJSON(data, into: modelContext, existingTemplates: templates)
            HapticEngine.success()
            bannerCenter.show(title: "模板导入完成", message: "已导入 \(count) 个模板。", tone: .success)
        } catch {
            HapticEngine.warning()
            bannerCenter.show(title: "模板导入失败", message: error.localizedDescription, tone: .error)
        }
    }

    private func matchesSearch(_ template: MealTemplate) -> Bool {
        guard !normalizedSearchText.isEmpty else { return true }
        return template.name.localizedCaseInsensitiveContains(normalizedSearchText)
            || template.mealType.displayName.localizedCaseInsensitiveContains(normalizedSearchText)
            || template.foodItems.contains { item in
                item.name.localizedCaseInsensitiveContains(normalizedSearchText)
                    || item.unit.localizedCaseInsensitiveContains(normalizedSearchText)
            }
    }

    private func matchesSearch(_ record: DrinkRecord) -> Bool {
        guard !normalizedSearchText.isEmpty else { return true }
        return record.displayName.localizedCaseInsensitiveContains(normalizedSearchText)
            || record.brand.localizedCaseInsensitiveContains(normalizedSearchText)
            || record.productName.localizedCaseInsensitiveContains(normalizedSearchText)
            || record.sugarLevel.localizedCaseInsensitiveContains(normalizedSearchText)
            || record.toppings.localizedCaseInsensitiveContains(normalizedSearchText)
            || record.sourceNote.localizedCaseInsensitiveContains(normalizedSearchText)
            || record.confidence.displayName.localizedCaseInsensitiveContains(normalizedSearchText)
    }
}

enum TemplateLibraryCategory: String, CaseIterable, Identifiable {
    case meal
    case beverage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meal: return "餐食模板"
        case .beverage: return "饮品模板"
        }
    }

    var icon: String {
        switch self {
        case .meal: return "fork.knife"
        case .beverage: return "cup.and.saucer.fill"
        }
    }

    func matches(_ template: MealTemplate) -> Bool {
        switch self {
        case .meal:
            return !TemplateLibraryCategory.beverage.matches(template)
        case .beverage:
            let beverageUnits = ["ml", "毫升", "杯"]
            let beverageWords = ["咖啡", "美式", "拿铁", "奶茶", "果茶", "茶", "豆浆", "牛奶", "酸奶", "饮料", "可乐", "水", "蛋白粉"]
            guard !template.foodItems.isEmpty else { return template.mealType == .snack }
            return template.foodItems.allSatisfy { item in
                let unit = item.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return beverageUnits.contains(unit) || beverageWords.contains { item.name.contains($0) }
            }
        }
    }
}

private struct MealTemplateRow: View {
    let template: MealTemplate
    var isCompact = false
    var showsTemplateName = true

    private var category: TemplateLibraryCategory {
        TemplateLibraryCategory.beverage.matches(template) ? .beverage : .meal
    }

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    Rectangle()
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FamilyUI.ink)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(showsTemplateName ? template.name : detail)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    SystemStatusBadge(text: category.title, tone: .neutral)
                }
                Text(showsTemplateName ? detail : "使用 \(template.useCount) 次")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(template.totalCalories)) kcal")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FamilyUI.accent)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(isCompact ? 12 : 14)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }

    private var iconName: String {
        category.icon
    }

    private var detail: String {
        "\(template.foodItems.count) 项食物 / 使用 \(template.useCount) 次"
    }
}

private struct MealTemplateGroup: Identifiable {
    let id: String
    let title: String
    let templates: [MealTemplate]
    let defaultTemplate: MealTemplate

    init(templates: [MealTemplate]) {
        let sorted = templates.sorted { lhs, rhs in
            if lhs.useCount != rhs.useCount { return lhs.useCount > rhs.useCount }
            if lhs.totalCalories != rhs.totalCalories { return lhs.totalCalories > rhs.totalCalories }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
        let first = sorted.first ?? templates[0]
        self.id = Self.groupKey(for: first)
        self.title = first.name
        self.templates = sorted
        self.defaultTemplate = first
    }

    static func groupKey(for template: MealTemplate) -> String {
        let normalizedName = template.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return DrinkLibraryIndex.normalize(normalizedName)
    }
}

private struct MealTemplateGroupSection: View {
    let group: MealTemplateGroup
    @Binding var isExpanded: Bool
    let onEdit: (MealTemplate) -> Void
    let onDelete: (MealTemplate) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                MealTemplateGroupHeader(group: group, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    group.templates.forEach(onDelete)
                } label: {
                    Label("删除这个模板组", systemImage: "trash")
                }
            }

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(group.templates) { template in
                        HStack(spacing: 8) {
                            Button {
                                onEdit(template)
                            } label: {
                                MealTemplateRow(template: template, isCompact: true, showsTemplateName: group.templates.count == 1)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDelete(template)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }

                            Button(role: .destructive) {
                                onDelete(template)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(FamilyUI.danger)
                                    .frame(width: 34, height: 34)
                                    .background(FamilyUI.panelMutedBackground)
                                    .overlay(
                                        Rectangle()
                                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                    )
                                    .clipShape(Rectangle())
                            }
                            .accessibilityLabel("删除这个模板")
                        }
                    }
                }
                .padding(.leading, 12)
            }
        }
    }
}

private struct MealTemplateGroupHeader: View {
    let group: MealTemplateGroup
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    Rectangle()
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FamilyUI.ink)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(group.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(group.templates.count) 个版本 · 默认 \(defaultSpecLine)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(group.defaultTemplate.totalCalories)) kcal")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FamilyUI.accent)
                    .monospacedDigit()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }

    private var category: TemplateLibraryCategory {
        TemplateLibraryCategory.beverage.matches(group.defaultTemplate) ? .beverage : .meal
    }

    private var defaultSpecLine: String {
        "\(group.defaultTemplate.foodItems.count) 项 · 使用 \(group.defaultTemplate.useCount) 次"
    }
}

private struct MealTemplateJSONExportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [MealTemplate]
    let onExport: ([MealTemplate]) -> Void

    @State private var selectedIDs: Set<UUID> = []

    private var categoryGroups: [(category: TemplateLibraryCategory, templates: [MealTemplate])] {
        TemplateLibraryCategory.allCases.compactMap { category in
            let items = templates
                .filter { category.matches($0) }
                .sorted { lhs, rhs in
                    if lhs.useCount != rhs.useCount { return lhs.useCount > rhs.useCount }
                    return lhs.name.localizedCompare(rhs.name) == .orderedAscending
                }
            guard !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "模板库",
                        title: "导出模板 JSON",
                        detail: "已选 \(selectedIDs.count)/\(templates.count) 个模板 · 点分组行可整组选择"
                    )

                    HStack(spacing: 10) {
                        selectionActionButton("全选") { selectedIDs = Set(templates.map(\.id)) }
                        selectionActionButton("清空") { selectedIDs = [] }
                    }

                    ForEach(categoryGroups, id: \.category.id) { group in
                        categorySection(group)
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("导出模板 JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导出") {
                        onExport(templates.filter { selectedIDs.contains($0.id) })
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
            .onAppear {
                if selectedIDs.isEmpty {
                    selectedIDs = Set(templates.map(\.id))
                }
            }
        }
    }

    private func categorySection(_ group: (category: TemplateLibraryCategory, templates: [MealTemplate])) -> some View {
        let selectedCount = group.templates.filter { selectedIDs.contains($0.id) }.count
        let allSelected = selectedCount == group.templates.count

        return VStack(spacing: 8) {
            Button {
                if allSelected {
                    group.templates.forEach { selectedIDs.remove($0.id) }
                } else {
                    group.templates.forEach { selectedIDs.insert($0.id) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: allSelected ? "checkmark.circle.fill" : (selectedCount > 0 ? "minus.circle.fill" : "circle"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(selectedCount > 0 ? FamilyUI.accent : .secondary)
                    Text(group.category.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(selectedCount)/\(group.templates.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(12)
                .background(FamilyUI.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
            }
            .buttonStyle(.plain)

            VStack(spacing: 6) {
                ForEach(group.templates) { template in
                    templateRow(template)
                }
            }
            .padding(.leading, 12)
        }
    }

    private func templateRow(_ template: MealTemplate) -> some View {
        let isSelected = selectedIDs.contains(template.id)

        return Button {
            if isSelected {
                selectedIDs.remove(template.id)
            } else {
                selectedIDs.insert(template.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? FamilyUI.accent : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name.isEmpty ? "未命名模板" : template.name)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(template.foodItems.count) 项 · 使用 \(template.useCount) 次")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(Int(template.totalCalories)) kcal")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FamilyUI.accent)
                    .monospacedDigit()
            }
            .padding(10)
            .background(FamilyUI.panelMutedBackground)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? FamilyUI.accent.opacity(0.5) : FamilyUI.panelBorder, lineWidth: 1)
            )
            .clipShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectionActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(FamilyUI.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    Rectangle()
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct MealTemplateDrinkRecordGroup: Identifiable {
    let id: String
    let brand: String
    let productName: String
    let records: [DrinkRecord]
    let defaultRecord: DrinkRecord

    init(records: [DrinkRecord]) {
        let sorted = records.sorted { lhs, rhs in
            let lhsScore = Self.defaultScore(lhs)
            let rhsScore = Self.defaultScore(rhs)
            if lhsScore != rhsScore { return lhsScore < rhsScore }
            let lhsConfidence = Self.confidenceRank(lhs.confidence)
            let rhsConfidence = Self.confidenceRank(rhs.confidence)
            if lhsConfidence != rhsConfidence { return lhsConfidence < rhsConfidence }
            return (lhs.sizeML ?? 500) < (rhs.sizeML ?? 500)
        }
        let first = sorted.first ?? records[0]
        self.id = Self.groupKey(for: first)
        self.brand = first.brand
        self.productName = first.productName
        self.records = sorted
        self.defaultRecord = first
    }

    static func groupKey(for record: DrinkRecord) -> String {
        DrinkLibraryIndex.normalize("\(record.brand)|\(record.productName)")
    }

    private static func defaultScore(_ record: DrinkRecord) -> Int {
        let version = DrinkLibraryIndex.normalize("\(record.sugarLevel)\(record.toppings)\(record.sourceNote)")
        if version.contains("默认") || version.contains("标准") || version.contains("正常") { return 0 }
        if record.sugarLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && record.toppings.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return 1
        }
        return 2
    }

    private static func confidenceRank(_ confidence: DrinkConfidence) -> Int {
        switch confidence {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

private struct MealTemplateDrinkBrandGroup: Identifiable {
    let id: String
    let brand: String
    let productGroups: [MealTemplateDrinkRecordGroup]

    var recordCount: Int {
        productGroups.reduce(0) { $0 + $1.records.count }
    }

    init(productGroups: [MealTemplateDrinkRecordGroup]) {
        let sorted = productGroups.sorted { lhs, rhs in
            lhs.productName.localizedCompare(rhs.productName) == .orderedAscending
        }
        let first = sorted.first ?? productGroups[0]
        self.id = Self.groupKey(for: first)
        let trimmedBrand = first.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        self.brand = trimmedBrand.isEmpty ? "未标品牌" : trimmedBrand
        self.productGroups = sorted
    }

    static func groupKey(for group: MealTemplateDrinkRecordGroup) -> String {
        DrinkLibraryIndex.normalize(group.brand)
    }
}

private struct MealTemplateDrinkBrandGroupSection: View {
    let brandGroup: MealTemplateDrinkBrandGroup
    @Binding var isExpanded: Bool
    let productExpansion: (MealTemplateDrinkRecordGroup) -> Binding<Bool>

    var body: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                MealTemplateDrinkBrandGroupHeader(brandGroup: brandGroup, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(brandGroup.productGroups) { group in
                        MealTemplateDrinkRecordGroupSection(
                            group: group,
                            isExpanded: productExpansion(group),
                            showsBrandName: false
                        )
                    }
                }
                .padding(.leading, 12)
            }
        }
    }
}

private struct MealTemplateDrinkBrandGroupHeader: View {
    let brandGroup: MealTemplateDrinkBrandGroup
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    Rectangle()
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FamilyUI.ink)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(brandGroup.brand)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(brandGroup.productGroups.count) 款饮品 · \(brandGroup.recordCount) 条记录")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }
}

private struct MealTemplateDrinkRecordGroupSection: View {
    let group: MealTemplateDrinkRecordGroup
    @Binding var isExpanded: Bool
    var showsBrandName = true

    var body: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                MealTemplateDrinkRecordGroupHeader(group: group, isExpanded: isExpanded, showsBrandName: showsBrandName)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(group.records) { record in
                        MealTemplateDrinkRecordRow(record: record, isCompact: true, showsProductName: false)
                    }
                }
                .padding(.leading, 12)
            }
        }
    }
}

private struct MealTemplateDrinkRecordGroupHeader: View {
    let group: MealTemplateDrinkRecordGroup
    let isExpanded: Bool
    let showsBrandName: Bool

    var body: some View {
        HStack(spacing: 12) {
            drinkIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(showsBrandName ? "\(group.brand) \(group.productName)" : group.productName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(group.records.count) 个版本 · 默认 \(defaultSpecLine)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(group.defaultRecord.calories.map { "\(Int($0)) kcal" } ?? "热量未知")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FamilyUI.accent)
                    .monospacedDigit()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }

    private var drinkIcon: some View {
        Rectangle()
            .fill(FamilyUI.panelMutedBackground)
            .overlay(
                Rectangle()
                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
            )
            .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
            .overlay(
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FamilyUI.ink)
            )
    }

    private var defaultSpecLine: String {
        var parts: [String] = []
        if let sizeML = group.defaultRecord.sizeML { parts.append("\(Int(sizeML))ml") }
        if !group.defaultRecord.sugarLevel.isEmpty { parts.append(group.defaultRecord.sugarLevel) }
        if !group.defaultRecord.toppings.isEmpty { parts.append(group.defaultRecord.toppings) }
        return parts.isEmpty ? "未标规格" : parts.joined(separator: " · ")
    }
}

private struct MealTemplateDrinkRecordRow: View {
    let record: DrinkRecord
    var isCompact = false
    var showsProductName = true

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    Rectangle()
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FamilyUI.ink)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(showsProductName ? "\(record.brand) \(record.productName)" : specLine)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    SystemStatusBadge(
                        text: record.confidence.rawValue,
                        tone: record.confidence == .high ? .success : (record.confidence == .medium ? .neutral : .warning)
                    )
                }
                Text(showsProductName ? specLine : sourceLine)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(record.calories.map { "\(Int($0)) kcal" } ?? "热量未知")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FamilyUI.accent)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(isCompact ? 12 : 14)
        .background(FamilyUI.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .stroke(FamilyUI.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
    }

    private var specLine: String {
        var parts: [String] = []
        if let sizeML = record.sizeML { parts.append("\(Int(sizeML))ml") }
        if !record.sugarLevel.isEmpty { parts.append(record.sugarLevel) }
        if !record.toppings.isEmpty { parts.append("小料：\(record.toppings)") }
        if let sugar = record.sugar { parts.append("糖 \(sugar.nutritionDecimal)g") }
        if let caffeine = record.caffeine { parts.append("咖啡因 \(caffeine.nutritionDecimal)mg") }
        return parts.isEmpty ? "规格未知" : parts.joined(separator: " · ")
    }

    private var sourceLine: String {
        record.sourceNote.isEmpty ? "来源未注明" : record.sourceNote
    }
}

private struct MealTemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let template: MealTemplate?
    let initialCategory: TemplateLibraryCategory

    @State private var name = ""
    @State private var category: TemplateLibraryCategory
    @State private var mealType: MealType = .breakfast
    @State private var foodItems: [TemplateFoodItem] = []
    @State private var isAddingFood = false
    @State private var searchText = ""
    @State private var commitToken = UUID()

    init(template: MealTemplate?, initialCategory: TemplateLibraryCategory = .meal) {
        self.template = template
        self.initialCategory = initialCategory
        _category = State(initialValue: initialCategory)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !foodItems.isEmpty
    }

    @Query(sort: [SortDescriptor(\UserFood.useCount, order: .reverse)])
    private var userFoods: [UserFood]

    private var searchResults: [UserFood] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return Array(userFoods.filter { $0.name.localizedCaseInsensitiveContains(q) }.prefix(10))
    }

    private var totalCalories: Double {
        foodItems.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "模板库",
                        title: template == nil ? "创建模板" : "编辑模板",
                        detail: "二级模板由你自己创建和命名"
                    )

                    SystemPanel(title: "模板信息", detail: "设置模板类型、名称和餐次") {
                        editorHeader("模板信息", value: category.title)
                        Picker("模板类型", selection: $category) {
                            ForEach(TemplateLibraryCategory.allCases) { value in
                                Text(value.title).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField("模板名称", text: $name)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(FamilyUI.panelMutedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
                            )

                        if category == .meal {
                            Picker("餐次", selection: $mealType) {
                                ForEach(MealType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    SystemPanel(title: category == .beverage ? "饮品明细" : "食物明细", detail: "管理模板内的具体条目") {
                        editorHeader(category == .beverage ? "饮品明细" : "食物明细", value: "\(foodItems.count) 项")

                        if foodItems.isEmpty {
                            Text("点击下方添加条目到模板")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(foodItems.enumerated()), id: \.offset) { index, item in
                                    if index > 0 {
                                        SystemPanelDivider()
                                    }
                                    TemplateFoodItemEditRow(
                                        item: item,
                                        onUpdate: { updated in foodItems[index] = updated },
                                        onDelete: { foodItems.remove(at: index) },
                                        commitToken: commitToken
                                    )
                                }
                            }

                            SystemPanelDivider()
                            HStack {
                                Text("合计")
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                Text("\(Int(totalCalories)) kcal")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(FamilyUI.accent)
                                    .monospacedDigit()
                            }
                        }

                        Button {
                            withAnimation { isAddingFood.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: isAddingFood ? "minus.circle" : "plus.circle")
                                Text(isAddingFood ? "收起搜索" : "添加食物")
                                Spacer()
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(FamilyUI.panelMutedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
                            )
                        }
                    }

                    if isAddingFood {
                        SystemPanel(title: "搜索条目", detail: "从我的食物中添加到模板") {
                            editorHeader("搜索食物", value: "\(searchResults.count) 个结果")
                            TextField("输入食物名称", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(FamilyUI.panelMutedBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                )

                            ForEach(searchResults) { uf in
                                Button {
                                    addFood(from: uf)
                                } label: {
                                    searchFoodRow(uf)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle(template == nil ? "新增模板" : "编辑模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .onChange(of: category) { _, newValue in
                if newValue == .beverage {
                    mealType = .snack
                }
            }
        }
    }

    private func editorHeader(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Spacer()
            SystemStatusBadge(text: value.uppercased(), tone: .neutral)
        }
    }


    private func searchFoodRow(_ food: UserFood) -> some View {
        let caloriesPerServing = food.servingProfile().calories
        return HStack(spacing: 10) {
            Text(food.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            Text("\(food.defaultAmount.nutritionDecimal)\(food.defaultUnit)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(Int(caloriesPerServing * food.defaultAmount)) kcal")
                .font(.caption.weight(.bold))
                .foregroundStyle(FamilyUI.accent)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
    }

    private func addFood(from uf: UserFood) {
        let profile = uf.servingProfile()
        func nutrient(_ key: NutrientKey) -> Double? { profile.nutrients[key] }
        let item = TemplateFoodItem(
            name: uf.name,
            amount: profile.amount,
            unit: profile.unit,
            servingGrams: profile.servingGrams,
            calories: profile.calories,
            protein: nutrient(.protein),
            carbs: nutrient(.carbs),
            fat: nutrient(.fat),
            fiber: nutrient(.fiber),
            sodium: nutrient(.sodium),
            sugar: nutrient(.sugar),
            cholesterol: nutrient(.cholesterol),
            caffeine: nutrient(.caffeine),
            teaPolyphenols: nutrient(.teaPolyphenols),
            calcium: nutrient(.calcium),
            magnesium: nutrient(.magnesium),
            potassium: nutrient(.potassium),
            iron: nutrient(.iron),
            zinc: nutrient(.zinc),
            vitaminA: nutrient(.vitaminA),
            vitaminC: nutrient(.vitaminC),
            vitaminD: nutrient(.vitaminD),
            vitaminE: nutrient(.vitaminE),
            vitaminB1: nutrient(.vitaminB1),
            vitaminB2: nutrient(.vitaminB2),
            niacin: nutrient(.niacin),
            vitaminB6: nutrient(.vitaminB6),
            folate: nutrient(.folate),
            vitaminB12: nutrient(.vitaminB12)
        )
        foodItems.append(item)
        searchText = ""
        HapticEngine.tap()
    }

    private func load() {
        guard let template else { return }
        name = template.name
        mealType = template.mealType
        foodItems = template.foodItems
        category = TemplateLibraryCategory.beverage.matches(template) ? .beverage : initialCategory
    }

    private func save() {
        commitToken = UUID()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let template {
            template.name = trimmedName
            template.mealType = category == .beverage ? .snack : mealType
            template.foodItems = foodItems
            template.updatedAt = .now
        } else {
            modelContext.insert(MealTemplate(name: trimmedName, mealType: category == .beverage ? .snack : mealType, foodItems: foodItems))
        }
        HapticEngine.success()
        dismiss()
    }
}

private struct TemplateFoodItemEditRow: View {
    let item: TemplateFoodItem
    let onUpdate: (TemplateFoodItem) -> Void
    let onDelete: () -> Void
    let commitToken: UUID

    @State private var amountText: String
    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case amount
        case calories
        case protein
        case carbs
        case fat
    }

    init(item: TemplateFoodItem, onUpdate: @escaping (TemplateFoodItem) -> Void, onDelete: @escaping () -> Void, commitToken: UUID) {
        self.item = item
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.commitToken = commitToken
        _amountText = State(initialValue: item.amount.nutritionDecimal)
        _caloriesText = State(initialValue: item.calories.nutritionDecimal)
        _proteinText = State(initialValue: item.protein?.nutritionDecimal ?? "")
        _carbsText = State(initialValue: item.carbs?.nutritionDecimal ?? "")
        _fatText = State(initialValue: item.fat?.nutritionDecimal ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 4) {
                        numericField("份量", text: $amountText, field: .amount, width: 58)
                        Text(item.unit)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(Int(Double(caloriesText) ?? item.calories)) kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(FamilyUI.accent)
                    .monospacedDigit()
                Button {
                    commitAll()
                    focusedField = nil
                } label: {
                    Text("确认")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FamilyUI.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            Rectangle()
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(Rectangle())
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption.weight(.bold))
                }
            }

            HStack(spacing: 8) {
                nutritionField("热量", text: $caloriesText, unit: "kcal", field: .calories)
                nutritionField("蛋白", text: $proteinText, unit: "g", field: .protein)
                nutritionField("碳水", text: $carbsText, unit: "g", field: .carbs)
                nutritionField("脂肪", text: $fatText, unit: "g", field: .fat)
            }
        }
        .padding(.vertical, 8)
        .onChange(of: commitToken) { _, _ in
            commitAll()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue != nil, newValue == nil {
                commitAll()
            }
        }
    }

    private func commitAll() {
        let newAmount = numericValue(amountText)
        guard let newAmount, newAmount > 0 else {
            amountText = item.amount.nutritionDecimal
            return
        }

        var updated = item
        let didEditCalories = hasEdited(caloriesText, original: item.calories)
        let didEditProtein = hasEdited(proteinText, original: item.protein)
        let didEditCarbs = hasEdited(carbsText, original: item.carbs)
        let didEditFat = hasEdited(fatText, original: item.fat)
        if abs(newAmount - item.amount) > 0.001 {
            let scale = newAmount / item.amount
            updated = scaledItem(amount: newAmount, scale: scale)
            if !didEditCalories { caloriesText = updated.calories.nutritionDecimal }
            if !didEditProtein { proteinText = updated.protein?.nutritionDecimal ?? "" }
            if !didEditCarbs { carbsText = updated.carbs?.nutritionDecimal ?? "" }
            if !didEditFat { fatText = updated.fat?.nutritionDecimal ?? "" }
        }

        let calories = numericValue(caloriesText) ?? updated.calories
        guard calories >= 0 else {
            caloriesText = updated.calories.nutritionDecimal
            return
        }

        updated = TemplateFoodItem(
            name: updated.name,
            amount: newAmount,
            unit: updated.unit,
            servingGrams: updated.servingGrams,
            calories: calories,
            protein: optionalNumericValue(proteinText),
            carbs: optionalNumericValue(carbsText),
            fat: optionalNumericValue(fatText),
            fiber: updated.fiber,
            sodium: updated.sodium,
            sugar: updated.sugar,
            cholesterol: updated.cholesterol,
            caffeine: updated.caffeine,
            teaPolyphenols: updated.teaPolyphenols,
            calcium: updated.calcium,
            magnesium: updated.magnesium,
            potassium: updated.potassium,
            iron: updated.iron,
            zinc: updated.zinc,
            vitaminA: updated.vitaminA,
            vitaminC: updated.vitaminC,
            vitaminD: updated.vitaminD,
            vitaminE: updated.vitaminE,
            vitaminB1: updated.vitaminB1,
            vitaminB2: updated.vitaminB2,
            niacin: updated.niacin,
            vitaminB6: updated.vitaminB6,
            folate: updated.folate,
            vitaminB12: updated.vitaminB12,
            nutritionDataBasisRaw: updated.nutritionDataBasisRaw,
            labelBaseAmount: updated.labelBaseAmount,
            labelBaseUnit: updated.labelBaseUnit,
            packageNetAmount: updated.packageNetAmount,
            packageNetUnit: updated.packageNetUnit,
            consumedAmount: updated.consumedAmount,
            consumedUnit: updated.consumedUnit,
            nutritionDataNote: updated.nutritionDataNote
        )

        amountText = updated.amount.nutritionDecimal
        caloriesText = updated.calories.nutritionDecimal
        proteinText = updated.protein?.nutritionDecimal ?? ""
        carbsText = updated.carbs?.nutritionDecimal ?? ""
        fatText = updated.fat?.nutritionDecimal ?? ""
        HapticEngine.tap()
        onUpdate(updated)
    }

    private func scaledItem(amount newAmount: Double, scale: Double) -> TemplateFoodItem {
        let updated = TemplateFoodItem(
            name: item.name,
            amount: newAmount,
            unit: item.unit,
            servingGrams: item.servingGrams * scale,
            calories: item.calories * scale,
            protein: item.protein.map { $0 * scale },
            carbs: item.carbs.map { $0 * scale },
            fat: item.fat.map { $0 * scale },
            fiber: item.fiber.map { $0 * scale },
            sodium: item.sodium.map { $0 * scale },
            sugar: item.sugar.map { $0 * scale },
            cholesterol: item.cholesterol.map { $0 * scale },
            caffeine: item.caffeine.map { $0 * scale },
            teaPolyphenols: item.teaPolyphenols.map { $0 * scale },
            calcium: item.calcium.map { $0 * scale },
            magnesium: item.magnesium.map { $0 * scale },
            potassium: item.potassium.map { $0 * scale },
            iron: item.iron.map { $0 * scale },
            zinc: item.zinc.map { $0 * scale },
            vitaminA: item.vitaminA.map { $0 * scale },
            vitaminC: item.vitaminC.map { $0 * scale },
            vitaminD: item.vitaminD.map { $0 * scale },
            vitaminE: item.vitaminE.map { $0 * scale },
            vitaminB1: item.vitaminB1.map { $0 * scale },
            vitaminB2: item.vitaminB2.map { $0 * scale },
            niacin: item.niacin.map { $0 * scale },
            vitaminB6: item.vitaminB6.map { $0 * scale },
            folate: item.folate.map { $0 * scale },
            vitaminB12: item.vitaminB12.map { $0 * scale },
            nutritionDataBasisRaw: item.nutritionDataBasisRaw,
            labelBaseAmount: item.labelBaseAmount,
            labelBaseUnit: item.labelBaseUnit,
            packageNetAmount: item.packageNetAmount,
            packageNetUnit: item.packageNetUnit,
            consumedAmount: item.consumedAmount,
            consumedUnit: item.consumedUnit,
            nutritionDataNote: item.nutritionDataNote
        )
        return updated
    }

    private func numericField(_ placeholder: String, text: Binding<String>, field: Field, width: CGFloat) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: width)
            .focused($focusedField, equals: field)
            .onSubmit { commitAll() }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(FamilyUI.panelMutedBackground)
            .overlay(
                Rectangle()
                    .stroke(focusedField == field ? FamilyUI.accent : FamilyUI.panelBorder, lineWidth: 1)
            )
            .clipShape(Rectangle())
    }

    private func nutritionField(_ label: String, text: Binding<String>, unit: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 3) {
                numericField(label, text: text, field: field, width: 48)
                Text(unit)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func numericValue(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func optionalNumericValue(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return numericValue(trimmed)
    }

    private func hasEdited(_ text: String, original: Double?) -> Bool {
        let normalized = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        let originalText = original?.nutritionDecimal ?? ""
        return normalized != originalText
    }
}
