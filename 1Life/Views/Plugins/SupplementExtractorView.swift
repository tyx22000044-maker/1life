import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers

// MARK: - 补剂库与补剂识别

enum SupplementLibraryViewMode {
    case library
    case plugin

    var eyebrow: String {
        switch self {
        case .library: return "食物库"
        case .plugin: return "插件"
        }
    }

    var title: String {
        switch self {
        case .library: return "补剂库"
        case .plugin: return "补剂营养识别"
        }
    }

    var detailSuffix: String {
        switch self {
        case .library:
            return "品牌补剂、剂型与营养/活性成分版本"
        case .plugin:
            return "拍标签建库，AI 记补剂时自动引用"
        }
    }

    var instructionTitle: String {
        switch self {
        case .library: return "补剂库"
        case .plugin: return "使用说明"
        }
    }

    var instructionDetail: String {
        switch self {
        case .library: return "已确认补剂如何复用"
        case .plugin: return "补剂库如何工作"
        }
    }

    var instructionBody: String {
        switch self {
        case .library:
            return "这里管理已经确认的蛋白粉、维生素、鱼油等补剂资料。补剂营养识别插件确认后的结果会保存到这里，AI 记录补剂时会优先引用库内数据。不提供用药建议、剂量推荐或药物相互作用判断。"
        case .plugin:
            return "拍摄补剂说明书/营养标签，AI 识别后经你校对存入补剂库。之后在 AI 对话里说\"吃了2粒XX牌鱼油\"，会直接采用库内精确数据并按份数换算，不再估算。"
        }
    }

    var emptySubtitle: String {
        switch self {
        case .library:
            return "从补剂营养识别插件校对保存后，补剂会出现在这里。"
        case .plugin:
            return "点击右上角相机按钮，拍一张补剂标签开始建库。"
        }
    }

    var showsRecognitionButton: Bool {
        switch self {
        case .library: return false
        case .plugin: return true
        }
    }
}

struct SupplementLibraryPluginView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @Query(sort: [SortDescriptor(\SupplementRecord.brand), SortDescriptor(\SupplementRecord.productName)])
    private var records: [SupplementRecord]

    let mode: SupplementLibraryViewMode

    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var isShowingExtractSheet = false
    @State private var editingRecord: SupplementRecord?
    @State private var newVersionBaseRecord: SupplementRecord?
    @State private var shareItem: ShareSheetItem?
    @State private var isShowingImportPicker = false
    @State private var isShowingPDFExportSheet = false
    @State private var bannerCenter = GlobalBannerCenter.shared
    @State private var expandedGroupKeys: Set<String> = []
    @State private var isSelectionMode = false
    @State private var selectedRecordIDs: Set<UUID> = []
    @State private var isShowingBatchBrandEditor = false

    private var currentSettings: UserSettings? { settings.first }

    init(mode: SupplementLibraryViewMode = .plugin) {
        self.mode = mode
    }

    @MainActor
    private var filteredRecords: [SupplementRecord] {
        let q = debouncedSearchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return records }
        return records.filter {
            $0.brand.localizedCaseInsensitiveContains(q)
                || $0.productName.localizedCaseInsensitiveContains(q)
                || $0.form.localizedCaseInsensitiveContains(q)
                || $0.activeIngredientsNote.localizedCaseInsensitiveContains(q)
                || $0.sourceNote.localizedCaseInsensitiveContains(q)
        }
    }

    @MainActor
    private var filteredGroups: [SupplementRecordGroup] {
        Dictionary(grouping: filteredRecords, by: { SupplementRecordGroup.groupKey(for: $0) })
            .values
            .map { SupplementRecordGroup(records: $0) }
            .sorted { lhs, rhs in
                if lhs.brand != rhs.brand { return lhs.brand.localizedCompare(rhs.brand) == .orderedAscending }
                return lhs.productName.localizedCompare(rhs.productName) == .orderedAscending
            }
    }

    private var headerDetail: String {
        "\(records.count) 条记录 · \(mode.detailSuffix)"
    }

    var body: some View {
        let groups = filteredGroups

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SystemPageHeader(
                    eyebrow: mode.eyebrow,
                    title: mode.title,
                    detail: headerDetail
                )

                SystemPanel(title: mode.instructionTitle, detail: mode.instructionDetail) {
                    Text(mode.instructionBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !records.isEmpty {
                    TextField("搜索品牌或商品名", text: $searchText)
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

                if groups.isEmpty {
                    SystemPanel(title: "补剂库", detail: "尚无记录") {
                        AppEmptyStateView(
                            icon: "pills.fill",
                            title: records.isEmpty ? "补剂库还是空的" : "没有匹配的记录",
                            subtitle: records.isEmpty ? mode.emptySubtitle : "换个关键词试试。"
                        )
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(groups) { group in
                            SupplementRecordGroupSection(
                                group: group,
                                isSelectionMode: isSelectionMode,
                                selectedIDs: $selectedRecordIDs,
                                isExpanded: Binding(
                                    get: { expandedGroupKeys.contains(group.id) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedGroupKeys.insert(group.id)
                                        } else {
                                            expandedGroupKeys.remove(group.id)
                                        }
                                    }
                                ),
                                onEdit: { editingRecord = $0 },
                                onDelete: { record in
                                    modelContext.delete(record)
                                    try? modelContext.save()
                                    SupplementLibraryIndex.shared.invalidate()
                                },
                                onDeleteGroup: {
                                    group.records.forEach { modelContext.delete($0) }
                                    try? modelContext.save()
                                    expandedGroupKeys.remove(group.id)
                                    SupplementLibraryIndex.shared.invalidate()
                                },
                                onAddVersion: {
                                    newVersionBaseRecord = group.defaultRecord
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.vertical, 16)
        }
        .background(FamilyUI.pageBackground)
        .scrollDismissesKeyboard(.interactively)
        .task(id: searchText) {
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                return
            }
            debouncedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !records.isEmpty {
                        Button(isSelectionMode ? "完成" : "多选") {
                            isSelectionMode.toggle()
                            if !isSelectionMode { selectedRecordIDs.removeAll() }
                        }
                    }
                    Menu {
                        Button {
                            exportJSON()
                        } label: {
                            Label("导出补剂库 JSON", systemImage: "square.and.arrow.up")
                        }
                        .disabled(records.isEmpty)

                        Button {
                            isShowingImportPicker = true
                        } label: {
                            Label("导入补剂库 JSON", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            isShowingPDFExportSheet = true
                        } label: {
                            Label("导出补剂 PDF", systemImage: "doc.richtext")
                        }
                        .disabled(records.isEmpty)

                        Button {
                            exportCSV()
                        } label: {
                            Label("导出补剂库 CSV", systemImage: "tablecells")
                        }
                        .disabled(records.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis")
                    }

                    if mode.showsRecognitionButton {
                        Button {
                            isShowingExtractSheet = true
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .accessibilityLabel("拍照识别")
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectionMode {
                HStack(spacing: 10) {
                    Button("全选") { selectedRecordIDs = Set(filteredRecords.map(\.id)) }
                    Button("批量改品牌") { isShowingBatchBrandEditor = true }
                        .disabled(selectedRecordIDs.isEmpty)
                    Button("删除 \(selectedRecordIDs.count) 条", role: .destructive) {
                        records.filter { selectedRecordIDs.contains($0.id) }.forEach { modelContext.delete($0) }
                        selectedRecordIDs.removeAll(); isSelectionMode = false
                        try? modelContext.save(); SupplementLibraryIndex.shared.invalidate()
                    }
                    .disabled(selectedRecordIDs.isEmpty)
                }
                .font(.caption.weight(.bold)).padding(10).frame(maxWidth: .infinity).background(.thinMaterial)
            }
        }
        .sheet(isPresented: $isShowingExtractSheet) {
            if let currentSettings {
                SupplementExtractSheet(settings: currentSettings)
            }
        }
        .sheet(item: $editingRecord) { record in
            SupplementRecordEditorSheet(record: record)
        }
        .sheet(item: $newVersionBaseRecord) { record in
            SupplementRecordEditorSheet(record: record, isNewVersion: true)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(isPresented: $isShowingPDFExportSheet) {
            SupplementPDFExportSheet(records: records)
        }
        .sheet(isPresented: $isShowingBatchBrandEditor) {
            BatchBrandEditorSheet { brand in
                records.filter { selectedRecordIDs.contains($0.id) }.forEach {
                    $0.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines); $0.updatedAt = .now
                }
                selectedRecordIDs.removeAll(); isSelectionMode = false
                try? modelContext.save(); SupplementLibraryIndex.shared.invalidate()
            }
        }
        .fileImporter(isPresented: $isShowingImportPicker, allowedContentTypes: [.json]) { result in
            importJSON(result)
        }
    }

    private func exportJSON() {
        bannerCenter.show(title: "正在导出补剂库", message: "已准备 \(records.count) 条补剂记录。", tone: .success)
        Task { @MainActor in
            do {
                try? await Task.sleep(for: .milliseconds(120))
                let data = try ExportService.exportSupplementLibraryJSON(records)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("1Life_supplements_library.json")
                try data.write(to: tempURL, options: [.atomic])
                shareItem = ShareSheetItem(url: tempURL)
                HapticEngine.success()
            } catch {
                HapticEngine.warning()
                bannerCenter.show(title: "导出失败", message: error.localizedDescription, tone: .error)
            }
        }
    }

    private func importJSON(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didStart = url.startAccessingSecurityScopedResource()
            defer {
                if didStart {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            let outcome = try ExportService.importSupplementLibraryJSON(data, into: modelContext, existingRecords: records)
            SupplementLibraryIndex.shared.invalidate()
            HapticEngine.success()
            bannerCenter.show(
                title: "导入完成",
                message: "新增 \(outcome.imported) 条，跳过重复 \(outcome.skipped) 条。",
                tone: .success
            )
        } catch {
            HapticEngine.warning()
            bannerCenter.show(title: "导入失败", message: error.localizedDescription, tone: .error)
        }
    }

    private func exportCSV() {
        let header = "品牌,商品名,剂型,每份规格,热量/kcal,蛋白质/g,碳水/g,脂肪/g,钠/mg,钙/mg,镁/mg,钾/mg,铁/mg,锌/mg,维生素A/ug,维生素C/mg,维生素D/ug,维生素E/mg,维生素B1/mg,维生素B2/mg,烟酸/mg,维生素B6/mg,叶酸/ug,维生素B12/ug,其它活性成分,数据来源,来源日期,可信等级"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let rows = records.map { record -> String in
            let fields: [String] = [
                record.brand,
                record.productName,
                record.form,
                record.servingSize,
                record.calories.map { $0.nutritionDecimal } ?? "",
                record.protein.map { $0.nutritionDecimal } ?? "",
                record.carbs.map { $0.nutritionDecimal } ?? "",
                record.fat.map { $0.nutritionDecimal } ?? "",
                record.sodium.map { $0.nutritionDecimal } ?? "",
                record.calcium.map { $0.nutritionDecimal } ?? "",
                record.magnesium.map { $0.nutritionDecimal } ?? "",
                record.potassium.map { $0.nutritionDecimal } ?? "",
                record.iron.map { $0.nutritionDecimal } ?? "",
                record.zinc.map { $0.nutritionDecimal } ?? "",
                record.vitaminA.map { $0.nutritionDecimal } ?? "",
                record.vitaminC.map { $0.nutritionDecimal } ?? "",
                record.vitaminD.map { $0.nutritionDecimal } ?? "",
                record.vitaminE.map { $0.nutritionDecimal } ?? "",
                record.vitaminB1.map { $0.nutritionDecimal } ?? "",
                record.vitaminB2.map { $0.nutritionDecimal } ?? "",
                record.niacin.map { $0.nutritionDecimal } ?? "",
                record.vitaminB6.map { $0.nutritionDecimal } ?? "",
                record.folate.map { $0.nutritionDecimal } ?? "",
                record.vitaminB12.map { $0.nutritionDecimal } ?? "",
                record.activeIngredientsNote,
                record.sourceNote,
                formatter.string(from: record.sourceDate),
                record.confidence.rawValue
            ]
            return fields.map { field in
                field.contains(",") || field.contains("\"")
                    ? "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
                    : field
            }.joined(separator: ",")
        }
        let csv = "\u{FEFF}" + ([header] + rows).joined(separator: "\n")
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("1Life_supplements_library.csv")
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            shareItem = ShareSheetItem(url: tempURL)
        } catch {
            bannerCenter.show(title: "导出失败", message: error.localizedDescription, tone: .error)
        }
    }
}

struct SupplementNutritionRecognitionPluginView: View {
    @Query private var settings: [UserSettings]
    @Query(sort: [SortDescriptor(\SupplementRecord.brand), SortDescriptor(\SupplementRecord.productName)])
    private var records: [SupplementRecord]

    @State private var isShowingExtractSheet = false

    private var currentSettings: UserSettings? { settings.first }
    private var isConfigured: Bool {
        guard let currentSettings else { return false }
        return (try? LocalAIConfigurationService().validateLocalConfiguration(settings: currentSettings)) == true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SystemPageHeader(
                    eyebrow: "插件",
                    title: "补剂营养识别",
                    detail: "识别图片或文字，校对后保存到补剂库"
                )

                SystemPanel(title: "识别流程", detail: "插件只负责识别与校对") {
                    VStack(alignment: .leading, spacing: 10) {
                        recognitionRow("1", "输入", "拍摄补剂说明书、营养标签，或粘贴文字说明。")
                        recognitionRow("2", "校对", "确认品牌、商品名、剂型、每份剂量和营养/活性成分。")
                        recognitionRow("3", "入库", "保存后进入补剂库，AI 记录补剂时优先引用库内数据。")
                    }
                }

                SystemPanel(title: "当前补剂库", detail: "\(records.count) 条已确认记录") {
                    AppSettingsRow(
                        icon: "pills.fill",
                        iconColor: FamilyUI.accent,
                        title: "保存目标",
                        subtitle: "识别完成后写入食物库中的补剂库",
                        value: "\(records.count) 条"
                    )
                }

                Button {
                    isShowingExtractSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .accessibilityLabel("从相册选择照片")
                            .font(.headline.weight(.bold))
                        Text("开始补剂识别")
                            .font(.headline.weight(.bold))
                        Spacer()
                    }
                    .foregroundStyle(isConfigured ? FamilyUI.buttonForeground : FamilyUI.inkFaint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(isConfigured ? FamilyUI.accent : FamilyUI.panelMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
                .buttonStyle(.plain)
                .disabled(!isConfigured)

                if !isConfigured {
                    AppEmptyStateView(
                        icon: "sparkles",
                        title: "需要先配置 AI",
                        subtitle: "补剂营养识别需要可用的 AI 服务商和 API Key。"
                    )
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.vertical, 16)
        }
        .background(FamilyUI.pageBackground)
        .navigationTitle("补剂营养识别")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingExtractSheet) {
            if let currentSettings {
                SupplementExtractSheet(settings: currentSettings)
            }
        }
    }

    private func recognitionRow(_ index: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(index)
                .font(.caption.weight(.bold))
                .foregroundStyle(FamilyUI.buttonForeground)
                .frame(width: 22, height: 22)
                .background(Circle().fill(FamilyUI.accent))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 分组

private struct SupplementRecordGroup: Identifiable {
    let id: String
    let brand: String
    let productName: String
    let records: [SupplementRecord]
    let defaultRecord: SupplementRecord

    var productCount: Int {
        Set(records.map(\.productName)).count
    }

    init(records: [SupplementRecord]) {
        let sorted = records.sorted { lhs, rhs in
            let lhsScore = Self.defaultScore(lhs)
            let rhsScore = Self.defaultScore(rhs)
            if lhsScore != rhsScore { return lhsScore < rhsScore }
            let lhsConfidence = Self.confidenceRank(lhs.confidence)
            let rhsConfidence = Self.confidenceRank(rhs.confidence)
            return lhsConfidence < rhsConfidence
        }
        let first = sorted.first ?? records[0]
        self.id = Self.groupKey(for: first)
        self.brand = first.brand
        self.productName = first.productName
        self.records = sorted
        self.defaultRecord = first
    }

    static func groupKey(for record: SupplementRecord) -> String {
        let brand = record.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        return SupplementLibraryIndex.normalize(brand.isEmpty ? "未标品牌" : brand)
    }

    private static func defaultScore(_ record: SupplementRecord) -> Int {
        let version = SupplementLibraryIndex.normalize("\(record.form)\(record.servingSize)\(record.sourceNote)")
        if version.contains("默认") || version.contains("标准") || version.contains("正常") { return 0 }
        if record.form.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && record.servingSize.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return 1
        }
        return 2
    }

    private static func confidenceRank(_ confidence: SupplementConfidence) -> Int {
        switch confidence {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

private struct SupplementRecordGroupSection: View {
    let group: SupplementRecordGroup
    let isSelectionMode: Bool
    @Binding var selectedIDs: Set<UUID>
    @Binding var isExpanded: Bool
    let onEdit: (SupplementRecord) -> Void
    let onDelete: (SupplementRecord) -> Void
    let onDeleteGroup: () -> Void
    let onAddVersion: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                SupplementRecordGroupHeader(group: group, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(action: onAddVersion) {
                    Label("新增版本", systemImage: "plus.circle")
                }
                Button(role: .destructive, action: onDeleteGroup) {
                    Label("删除这个品牌的全部补剂", systemImage: "trash")
                }
            }

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(group.records) { record in
                        HStack(spacing: 8) {
                            if isSelectionMode {
                                Button {
                                    if selectedIDs.contains(record.id) { selectedIDs.remove(record.id) }
                                    else { selectedIDs.insert(record.id) }
                                } label: {
                                    Image(systemName: selectedIDs.contains(record.id) ? "checkmark.circle.fill" : "circle")
                                        .accessibilityLabel(selectedIDs.contains(record.id) ? "取消选择这条记录" : "选择这条记录")
                                        .foregroundStyle(selectedIDs.contains(record.id) ? FamilyUI.accent : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                if isSelectionMode {
                                    if selectedIDs.contains(record.id) { selectedIDs.remove(record.id) }
                                    else { selectedIDs.insert(record.id) }
                                } else { onEdit(record) }
                            } label: {
                                SupplementRecordRow(record: record, isCompact: true, showsProductName: true)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDelete(record)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }

                            Button(role: .destructive) {
                                onDelete(record)
                            } label: {
                                Image(systemName: "trash")
                                    .accessibilityLabel("删除这条记录")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(FamilyUI.danger)
                                    .frame(width: 34, height: 34)
                                    .background(FamilyUI.panelMutedBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                            }
                            .accessibilityLabel("删除这条补剂记录")
                        }
                    }

                    Button(action: onAddVersion) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("新增版本")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FamilyUI.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 12)
            }
        }
    }
}

private struct SupplementRecordGroupHeader: View {
    let group: SupplementRecordGroup
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: "pills.fill")
                        .font(FamilyTypography.text(size: 14, weight: .bold))
                        .foregroundStyle(FamilyUI.accent)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(group.brand.isEmpty ? "未标品牌" : group.brand)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1...2)
                Text("\(group.records.count) 条记录 · \(group.productCount) 个商品")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1...2)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(group.defaultRecord.calories.map { "\(Int($0)) kcal" } ?? "无热量")
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

    private var defaultSpecLine: String {
        var parts: [String] = []
        if !group.defaultRecord.form.isEmpty { parts.append(group.defaultRecord.form) }
        if !group.defaultRecord.servingSize.isEmpty { parts.append(group.defaultRecord.servingSize) }
        return parts.isEmpty ? "未标规格" : parts.joined(separator: " · ")
    }

}

// MARK: - 记录行

private struct SupplementRecordRow: View {
    let record: SupplementRecord
    var isCompact = false
    var showsProductName = true

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: "pills.fill")
                        .font(FamilyTypography.text(size: 14, weight: .bold))
                        .foregroundStyle(FamilyUI.accent)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(showsProductName ? "\(record.brand) \(record.productName)" : specLine)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1...2)
                    SystemStatusBadge(
                        text: record.confidence.rawValue,
                        tone: record.confidence == .high ? .success : (record.confidence == .medium ? .neutral : .warning)
                    )
                }
                Text(showsProductName ? specLine : sourceLine)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1...2)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(record.calories.map { "\(Int($0)) kcal" } ?? "无热量")
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
        if !record.form.isEmpty { parts.append(record.form) }
        if !record.servingSize.isEmpty { parts.append("每份 \(record.servingSize)") }
        if !record.activeIngredientsNote.isEmpty { parts.append(record.activeIngredientsNote) }
        return parts.isEmpty ? "规格未知" : parts.joined(separator: " · ")
    }

    private var sourceLine: String {
        record.sourceNote.isEmpty ? "来源未注明" : record.sourceNote
    }
}

// MARK: - 识别 Sheet（选图 → 识别 → 校对 → 入库）

private struct SupplementExtractSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let settings: UserSettings

    private enum Phase {
        case input
        case readingText
        case textReview
        case identifyingCandidates
        case candidateReview
        case parsing
        case review
    }

    @State private var phase: Phase = .input
    @State private var selectedModel: String
    @State private var imageDataList: [Data] = []
    @State private var supplementText = ""
    @State private var recognizedText = ""
    @State private var candidates: [SupplementCandidate] = []
    @State private var drafts: [SupplementExtractedDraft] = []
    @State private var errorMessage: String?
    @State private var isShowingCameraPicker = false
    @State private var isShowingPhotosPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var bannerCenter = GlobalBannerCenter.shared

    init(settings: UserSettings) {
        self.settings = settings
        _selectedModel = State(initialValue: settings.effectiveSupplementPluginAIModel)
    }

    private var canExtract: Bool {
        !imageDataList.isEmpty || !supplementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canParseConfirmedText: Bool {
        !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canParseCandidates: Bool {
        candidates.contains { $0.isSelected && $0.isValid }
    }

    private var estimatedExtractionWaitText: String {
        let count = imageDataList.count
        guard count > 0 else { return "纯文字当前请求最多等待 2 分钟。" }
        return "正在读取 \(count) 张图片；当前请求最多等待 2 分钟。"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch phase {
                    case .input:
                        inputSection
                    case .readingText:
                        loadingSection(title: "读取文字中", detail: estimatedExtractionWaitText)
                    case .textReview:
                        textReviewSection
                    case .identifyingCandidates:
                        loadingSection(title: "识别补剂中", detail: "正在从文字里先找品牌和商品名，这一步只确认范围。")
                    case .candidateReview:
                        candidateReviewSection
                    case .parsing:
                        loadingSection(title: "提取营养中", detail: "正在只围绕已确认补剂查找营养和活性成分，最多约 2 分钟。")
                    case .review:
                        reviewSection
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("识别补剂营养")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    KeyboardDoneButton {
                        dismissKeyboard()
                    }
                }
                if phase == .review {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("全部入库", action: saveAll)
                            .disabled(drafts.allSatisfy { !$0.isValid })
                    }
                }
            }
            .sheet(isPresented: $isShowingCameraPicker) {
                AIImagePicker(sourceType: .camera) { data in
                    appendImageData(data)
                }
            }
            .photosPicker(
                isPresented: $isShowingPhotosPicker,
                selection: $selectedPhotoItems,
                maxSelectionCount: max(1, 6 - imageDataList.count),
                matching: .images
            )
            .onChange(of: selectedPhotoItems) { _, items in
                Task { await appendPhotoItems(items) }
            }
        }
    }

    // MARK: 输入阶段

    private var inputSection: some View {
        Group {
            PluginAIModelSelector(settings: settings, selectedModel: $selectedModel) {
                settings.supplementPluginAIModel = $0
                settings.supplementPluginAIProviderRaw = settings.selectedAIProvider.rawValue
            }

            SystemPageHeader(
                eyebrow: "第 1 步",
                title: "提供图片或文字",
                detail: "补剂说明书、营养标签照片，可多张"
            )

            SystemPanel(title: "图片", detail: "已选 \(imageDataList.count) 张（最多 6 张）") {
                if !imageDataList.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(imageDataList.enumerated()), id: \.offset) { index, data in
                                if let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
                                        .overlay(alignment: .topTrailing) {
                                            Button {
                                                imageDataList.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .accessibilityLabel("移除这张照片")
                                                    .font(.caption)
                                                    .foregroundStyle(.white, .black.opacity(0.6))
                                            }
                                            .padding(3)
                                        }
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        pickButton(title: "拍照", icon: "camera.fill") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            isShowingCameraPicker = true
                        }
                    }
                    pickButton(title: "相册选图", icon: "photo.on.rectangle") {
                        isShowingPhotosPicker = true
                    }
                }
            }

            SystemPanel(title: "文字输入（可选）", detail: "可只输入文字，不需要图片；支持品牌、商品名、剂型或营养数据") {
                TextField("例如：XX牌鱼油软胶囊，1粒含 EPA 180mg、DHA 120mg", text: $supplementText, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FamilyUI.danger)
            }

            Button(action: startExtraction) {
                HStack {
                    Spacer()
                    Image(systemName: imageDataList.isEmpty ? "sparkles" : "text.viewfinder")
                    Text(imageDataList.isEmpty ? "解析文字" : "读取文字")
                    Spacer()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(canExtract ? FamilyUI.buttonForeground : FamilyUI.inkSoft)
                .padding(.vertical, 13)
                .background(canExtract ? FamilyUI.accent : FamilyUI.panelMutedBackground)
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
            }
            .disabled(!canExtract)
        }
    }

    private func pickButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(FamilyUI.panelMutedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
            )
        }
        .disabled(imageDataList.count >= 6)
    }

    private func appendImageData(_ data: Data) {
        guard imageDataList.count < 6 else { return }
        imageDataList.append(ImageService.compress(data) ?? data)
    }

    @MainActor
    private func appendPhotoItems(_ items: [PhotosPickerItem]) async {
        defer { selectedPhotoItems = [] }
        for item in items where imageDataList.count < 6 {
            if let data = try? await item.loadTransferable(type: Data.self) {
                appendImageData(data)
            }
        }
    }

    // MARK: 识别中

    private func loadingSection(title: String, detail: String) -> some View {
        SystemPanel(title: "识别中", detail: "正在调用 \(settings.selectedAIProvider.displayName) · \(selectedModel)") {
            HStack(spacing: 12) {
                ProgressView()
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: OCR 校对

    private var textReviewSection: some View {
        Group {
            SystemPageHeader(
                eyebrow: "第 2 步",
                title: "校对读取文字",
                detail: "修正错字或补充缺失字段后继续解析"
            )

            SystemPanel(title: "识别原文", detail: "可编辑") {
                TextField("粘贴或校对营养标签文字", text: $recognizedText, axis: .vertical)
                    .lineLimit(10...18)
                    .textInputAutocapitalization(.never)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FamilyUI.danger)
            }

            HStack(spacing: 10) {
                Button {
                    phase = .input
                    errorMessage = nil
                } label: {
                    Label("返回", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 11)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                }

                Button(action: parseConfirmedText) {
                    Label("识别补剂", systemImage: "list.bullet.clipboard")
                        .frame(maxWidth: .infinity)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(canParseConfirmedText ? FamilyUI.buttonForeground : FamilyUI.inkSoft)
                        .padding(.vertical, 11)
                        .background(canParseConfirmedText ? FamilyUI.accent : FamilyUI.panelMutedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
                .disabled(!canParseConfirmedText)
            }
        }
    }

    // MARK: 候选补剂确认

    private var candidateReviewSection: some View {
        Group {
            SystemPageHeader(
                eyebrow: "第 3 步",
                title: "确认补剂",
                detail: "先确认品牌和商品名，再针对性提取营养"
            )

            if candidates.isEmpty {
                SystemPanel(title: "候选补剂", detail: "暂无候选") {
                    AppEmptyStateView(
                        icon: "pills",
                        title: "还没有候选补剂",
                        subtitle: "可以手动添加一条，或返回补充品牌和商品名。"
                    )
                }
            } else {
                ForEach($candidates) { candidateBinding in
                    SupplementCandidateEditor(candidate: candidateBinding) {
                        candidates.removeAll { $0.id == candidateBinding.wrappedValue.id }
                    }
                }
            }

            Button {
                candidates.append(SupplementCandidate())
            } label: {
                Label("添加补剂", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.vertical, 11)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FamilyUI.danger)
            }

            HStack(spacing: 10) {
                Button {
                    phase = .textReview
                    errorMessage = nil
                } label: {
                    Label("返回文字", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 11)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                }

                Button(action: parseCandidateNutrition) {
                    Label("提取营养", systemImage: "leaf")
                        .frame(maxWidth: .infinity)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(canParseCandidates ? FamilyUI.buttonForeground : FamilyUI.inkSoft)
                        .padding(.vertical, 11)
                        .background(canParseCandidates ? FamilyUI.accent : FamilyUI.panelMutedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
                .disabled(!canParseCandidates)
            }
        }
    }

    // MARK: 校对阶段

    private var reviewSection: some View {
        Group {
            SystemPageHeader(
                eyebrow: "第 4 步",
                title: "校对识别结果",
                detail: "共 \(drafts.count) 条 · 至少需要品牌、商品名和一项营养/成分数据"
            )

            ForEach($drafts) { $draft in
                SupplementDraftEditor(draft: $draft) {
                    drafts.removeAll { $0.id == draft.id }
                    if drafts.isEmpty {
                        phase = .input
                    }
                }
            }

            Button {
                phase = candidates.isEmpty ? (recognizedText.isEmpty ? .input : .textReview) : .candidateReview
                errorMessage = nil
            } label: {
                HStack {
                    Image(systemName: "arrow.uturn.backward")
                    Text(candidates.isEmpty ? (recognizedText.isEmpty ? "返回重新识别" : "返回校对文字") : "返回确认补剂")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: 动作

    private func startExtraction() {
        errorMessage = nil
        candidates = []
        drafts = []
        guard settings.isAIConfigured else {
            errorMessage = "请先在「设置 → AI 配置」中配置服务商和 API Key。"
            return
        }
        if imageDataList.isEmpty {
            recognizedText = supplementText
            parseConfirmedText()
            return
        }

        phase = .readingText
        let images = imageDataList
        let text = supplementText
        Task {
            do {
                let service = SupplementExtractorService(settings: settings)
                recognizedText = try await service.recognizeText(imageDataList: images, text: text)
                phase = .textReview
                HapticEngine.success()
            } catch {
                errorMessage = error.localizedDescription
                phase = .input
                HapticEngine.warning()
            }
        }
    }

    private func parseConfirmedText() {
        errorMessage = nil
        candidates = []
        drafts = []
        let text = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        phase = .identifyingCandidates
        Task {
            do {
                let service = SupplementExtractorService(settings: settings)
                candidates = try await service.identifyCandidates(fromConfirmedText: text)
                phase = .candidateReview
                HapticEngine.success()
            } catch {
                errorMessage = error.localizedDescription
                phase = .textReview
                HapticEngine.warning()
            }
        }
    }

    private func parseCandidateNutrition() {
        errorMessage = nil
        let text = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedCandidates = candidates.filter { $0.isSelected && $0.isValid }
        guard !text.isEmpty, !selectedCandidates.isEmpty else { return }
        phase = .parsing
        Task {
            do {
                let service = SupplementExtractorService(settings: settings)
                drafts = try await service.extract(fromConfirmedText: text, candidates: selectedCandidates)
                phase = .review
                HapticEngine.success()
            } catch {
                errorMessage = error.localizedDescription
                phase = .candidateReview
                HapticEngine.warning()
            }
        }
    }

    private func saveAll() {
        let validDrafts = drafts.filter(\.isValid)
        guard !validDrafts.isEmpty else { return }

        let existing = (try? modelContext.fetch(FetchDescriptor<SupplementRecord>())) ?? []
        var existingByKey = Dictionary(existing.map { ($0.dedupeKey, $0) }, uniquingKeysWith: { first, _ in first })

        var inserted = 0
        var updated = 0
        for draft in validDrafts {
            let record = draft.makeRecord()
            if let old = existingByKey[record.dedupeKey] {
                old.calories = record.calories
                old.protein = record.protein
                old.carbs = record.carbs
                old.fat = record.fat
                old.sodium = record.sodium
                old.calcium = record.calcium
                old.magnesium = record.magnesium
                old.potassium = record.potassium
                old.iron = record.iron
                old.zinc = record.zinc
                old.vitaminA = record.vitaminA
                old.vitaminC = record.vitaminC
                old.vitaminD = record.vitaminD
                old.vitaminE = record.vitaminE
                old.vitaminB1 = record.vitaminB1
                old.vitaminB2 = record.vitaminB2
                old.niacin = record.niacin
                old.vitaminB6 = record.vitaminB6
                old.folate = record.folate
                old.vitaminB12 = record.vitaminB12
                old.activeIngredientsNote = record.activeIngredientsNote
                old.sourceNote = record.sourceNote
                old.sourceDate = record.sourceDate
                old.confidenceRaw = record.confidenceRaw
                old.updatedAt = .now
                updated += 1
            } else {
                modelContext.insert(record)
                existingByKey[record.dedupeKey] = record
                inserted += 1
            }
        }
        SupplementLibraryIndex.shared.invalidate()
        HapticEngine.success()
        var message = "新增 \(inserted) 条"
        if updated > 0 { message += "，更新 \(updated) 条（同款覆盖）" }
        bannerCenter.show(title: "已存入补剂库", message: message + "。", tone: .success)
        dismiss()
    }
}

// MARK: - 候选补剂卡片

private struct SupplementCandidateEditor: View {
    @Binding var candidate: SupplementCandidate
    let onDelete: () -> Void

    var body: some View {
        SystemPanel(
            title: candidate.productName.isEmpty ? "未命名补剂" : "\(candidate.brand) \(candidate.productName)",
            detail: candidate.sourceNote.isEmpty ? "确认后用于定向提取营养" : "线索：\(candidate.sourceNote)"
        ) {
            VStack(spacing: 10) {
                Toggle(isOn: $candidate.isSelected) {
                    Text("入库")
                        .font(.caption.weight(.bold))
                }
                .toggleStyle(AppSwitchStyle())

                HStack(spacing: 10) {
                    labeledField("品牌", text: $candidate.brand)
                    labeledField("商品名", text: $candidate.productName)
                }

                HStack(spacing: 10) {
                    labeledField("剂型", text: $candidate.form)
                    labeledField("线索", text: $candidate.sourceNote)
                }

                Button(role: .destructive, action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                            .accessibilityLabel("删除这条记录")
                        Text("删除候选")
                    }
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 2)
            }
        }
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
        }
    }
}

// MARK: - 草稿编辑卡片

private struct SupplementDraftEditor: View {
    @Binding var draft: SupplementExtractedDraft
    var onDelete: (() -> Void)? = nil

    @State private var showsMoreNutrients = false

    var body: some View {
        SystemPanel(
            title: draft.productName.isEmpty ? "未命名补剂" : "\(draft.brand) \(draft.productName)",
            detail: "来源：\(draft.sourceNote.isEmpty ? "未注明" : draft.sourceNote)"
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    labeledField("品牌", text: $draft.brand)
                    labeledField("商品名", text: $draft.productName)
                }
                HStack(spacing: 10) {
                    labeledField("剂型", text: $draft.form)
                    labeledField("每份规格", text: $draft.servingSize)
                }

                SystemPanelDivider()

                HStack(spacing: 10) {
                    labeledNumberField("热量 kcal", value: $draft.calories)
                    labeledNumberField("蛋白 g", value: $draft.protein)
                }
                HStack(spacing: 10) {
                    labeledNumberField("碳水 g", value: $draft.carbs)
                    labeledNumberField("脂肪 g", value: $draft.fat)
                }

                DisclosureGroup(isExpanded: $showsMoreNutrients) {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            labeledNumberField("钠 mg", value: $draft.sodium)
                            labeledNumberField("钙 mg", value: $draft.calcium)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("镁 mg", value: $draft.magnesium)
                            labeledNumberField("钾 mg", value: $draft.potassium)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("铁 mg", value: $draft.iron)
                            labeledNumberField("锌 mg", value: $draft.zinc)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("维生素A ug", value: $draft.vitaminA)
                            labeledNumberField("维生素C mg", value: $draft.vitaminC)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("维生素D ug", value: $draft.vitaminD)
                            labeledNumberField("维生素E mg", value: $draft.vitaminE)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("维生素B1 mg", value: $draft.vitaminB1)
                            labeledNumberField("维生素B2 mg", value: $draft.vitaminB2)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("烟酸 mg", value: $draft.niacin)
                            labeledNumberField("维生素B6 mg", value: $draft.vitaminB6)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("叶酸 ug", value: $draft.folate)
                            labeledNumberField("维生素B12 ug", value: $draft.vitaminB12)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text(showsMoreNutrients ? "收起更多营养素" : "展开更多营养素（维生素/矿物质）")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FamilyUI.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("其它活性成分")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("如：肌酸一水合物5g；EPA 180mg", text: $draft.activeIngredientsNote, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                }

                Picker("可信等级", selection: $draft.confidence) {
                    ForEach(SupplementConfidence.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        HStack {
                            Image(systemName: "trash")
                                .accessibilityLabel("删除这条记录")
                            Text("删除这条")
                        }
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
        }
    }

    private func labeledNumberField(_ label: String, value: Binding<Double?>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("—", text: Binding(
                get: { value.wrappedValue.map { $0.nutritionDecimal } ?? "" },
                set: { newValue in
                    let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                        .trimmingCharacters(in: .whitespaces)
                    value.wrappedValue = cleaned.isEmpty ? nil : Double(cleaned)
                }
            ))
            .keyboardType(.decimalPad)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(FamilyUI.panelMutedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - 已入库记录编辑 Sheet

private struct SupplementRecordEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let record: SupplementRecord
    /// true 时以 record 为底稿新建一条版本记录，不修改 record 本身
    var isNewVersion = false

    @State private var draft = SupplementExtractedDraft()
    @State private var isLoaded = false
    @State private var duplicateWarning: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "补剂库",
                        title: isNewVersion ? "新增版本" : "编辑记录",
                        detail: isNewVersion ? "\(record.brand) \(record.productName) · 调整剂型/规格后保存" : record.displayName
                    )
                    if let duplicateWarning {
                        Text(duplicateWarning)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FamilyUI.danger)
                    }
                    SupplementDraftEditor(draft: $draft, onDelete: isNewVersion ? nil : {
                        modelContext.delete(record)
                        try? modelContext.save()
                        SupplementLibraryIndex.shared.invalidate()
                        HapticEngine.warning()
                        dismiss()
                    })
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNewVersion ? "新增版本" : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    KeyboardDoneButton {
                        dismissKeyboard()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        draft.brand = record.brand
        draft.productName = record.productName
        draft.form = record.form
        draft.servingSize = record.servingSize
        draft.calories = record.calories
        draft.protein = record.protein
        draft.carbs = record.carbs
        draft.fat = record.fat
        draft.sodium = record.sodium
        draft.calcium = record.calcium
        draft.magnesium = record.magnesium
        draft.potassium = record.potassium
        draft.iron = record.iron
        draft.zinc = record.zinc
        draft.vitaminA = record.vitaminA
        draft.vitaminC = record.vitaminC
        draft.vitaminD = record.vitaminD
        draft.vitaminE = record.vitaminE
        draft.vitaminB1 = record.vitaminB1
        draft.vitaminB2 = record.vitaminB2
        draft.niacin = record.niacin
        draft.vitaminB6 = record.vitaminB6
        draft.folate = record.folate
        draft.vitaminB12 = record.vitaminB12
        draft.activeIngredientsNote = record.activeIngredientsNote
        draft.sourceNote = isNewVersion ? "手动新增版本" : record.sourceNote
        draft.confidence = isNewVersion ? .medium : record.confidence
    }

    private func save() {
        let brand = draft.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let productName = draft.productName.trimmingCharacters(in: .whitespacesAndNewlines)
        let form = draft.form.trimmingCharacters(in: .whitespacesAndNewlines)
        let servingSize = draft.servingSize.trimmingCharacters(in: .whitespacesAndNewlines)

        let dedupeKey = SupplementLibraryIndex.normalize("\(brand)|\(productName)|\(form)|\(servingSize)")
        let allRecords = (try? modelContext.fetch(FetchDescriptor<SupplementRecord>())) ?? []
        // 编辑模式下允许和自己同键；新增版本模式下底稿记录也算重复
        if allRecords.contains(where: { $0.dedupeKey == dedupeKey && (isNewVersion || $0.id != record.id) }) {
            duplicateWarning = "补剂库里已有相同品牌、商品、剂型和规格的版本，请调整后再保存。"
            HapticEngine.warning()
            return
        }

        if isNewVersion {
            let newRecord = SupplementRecord(
                brand: brand,
                productName: productName,
                form: form,
                servingSize: servingSize,
                calories: draft.calories,
                protein: draft.protein,
                carbs: draft.carbs,
                fat: draft.fat,
                sodium: draft.sodium,
                calcium: draft.calcium,
                magnesium: draft.magnesium,
                potassium: draft.potassium,
                iron: draft.iron,
                zinc: draft.zinc,
                vitaminA: draft.vitaminA,
                vitaminC: draft.vitaminC,
                vitaminD: draft.vitaminD,
                vitaminE: draft.vitaminE,
                vitaminB1: draft.vitaminB1,
                vitaminB2: draft.vitaminB2,
                niacin: draft.niacin,
                vitaminB6: draft.vitaminB6,
                folate: draft.folate,
                vitaminB12: draft.vitaminB12,
                activeIngredientsNote: draft.activeIngredientsNote,
                sourceNote: draft.sourceNote,
                confidence: draft.confidence
            )
            modelContext.insert(newRecord)
        } else {
            record.brand = brand
            record.productName = productName
            record.form = form
            record.servingSize = servingSize
            record.calories = draft.calories
            record.protein = draft.protein
            record.carbs = draft.carbs
            record.fat = draft.fat
            record.sodium = draft.sodium
            record.calcium = draft.calcium
            record.magnesium = draft.magnesium
            record.potassium = draft.potassium
            record.iron = draft.iron
            record.zinc = draft.zinc
            record.vitaminA = draft.vitaminA
            record.vitaminC = draft.vitaminC
            record.vitaminD = draft.vitaminD
            record.vitaminE = draft.vitaminE
            record.vitaminB1 = draft.vitaminB1
            record.vitaminB2 = draft.vitaminB2
            record.niacin = draft.niacin
            record.vitaminB6 = draft.vitaminB6
            record.folate = draft.folate
            record.vitaminB12 = draft.vitaminB12
            record.activeIngredientsNote = draft.activeIngredientsNote
            record.confidenceRaw = draft.confidence.rawValue
            record.updatedAt = .now
        }
        try? modelContext.save()
        SupplementLibraryIndex.shared.invalidate()
        HapticEngine.success()
        dismiss()
    }
}

// MARK: - PDF 导出选择 Sheet

private struct SupplementPDFExportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let records: [SupplementRecord]

    @State private var selectedIDs: Set<UUID> = []
    @State private var shareItem: ShareSheetItem?
    @State private var bannerCenter = GlobalBannerCenter.shared

    private var brandGroups: [(brand: String, records: [SupplementRecord])] {
        Dictionary(grouping: records) { $0.brand.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { (brand: $0.key, records: $0.value.sorted { lhs, rhs in
                lhs.productName.localizedCompare(rhs.productName) == .orderedAscending
            }) }
            .sorted { $0.brand.localizedCompare($1.brand) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "补剂库",
                        title: "导出补剂 PDF",
                        detail: "已选 \(selectedIDs.count)/\(records.count) 个版本 · 点品牌行可整组选择"
                    )

                    HStack(spacing: 10) {
                        selectionActionButton("全选") { selectedIDs = Set(records.map(\.id)) }
                        selectionActionButton("清空") { selectedIDs = [] }
                    }

                    ForEach(brandGroups, id: \.brand) { group in
                        brandSection(group)
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("导出补剂 PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导出", action: exportPDF)
                        .disabled(selectedIDs.isEmpty)
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
            .onAppear {
                if selectedIDs.isEmpty {
                    selectedIDs = Set(records.map(\.id))
                }
            }
        }
    }

    private func brandSection(_ group: (brand: String, records: [SupplementRecord])) -> some View {
        let selectedCount = group.records.filter { selectedIDs.contains($0.id) }.count
        let allSelected = selectedCount == group.records.count

        return VStack(spacing: 8) {
            Button {
                if allSelected {
                    group.records.forEach { selectedIDs.remove($0.id) }
                } else {
                    group.records.forEach { selectedIDs.insert($0.id) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: allSelected ? "checkmark.circle.fill" : (selectedCount > 0 ? "minus.circle.fill" : "circle"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(selectedCount > 0 ? FamilyUI.accent : .secondary)
                    Text(group.brand.isEmpty ? "未标品牌" : group.brand)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(selectedCount)/\(group.records.count)")
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
                ForEach(group.records) { record in
                    recordRow(record)
                }
            }
            .padding(.leading, 12)
        }
    }

    private func recordRow(_ record: SupplementRecord) -> some View {
        let isSelected = selectedIDs.contains(record.id)
        var specs: [String] = []
        if !record.form.isEmpty { specs.append(record.form) }
        if !record.servingSize.isEmpty { specs.append("每份 \(record.servingSize)") }

        return Button {
            if isSelected {
                selectedIDs.remove(record.id)
            } else {
                selectedIDs.insert(record.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? FamilyUI.accent : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.productName.isEmpty ? "未命名补剂" : record.productName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1...2)
                    Text(specs.isEmpty ? "规格未知" : specs.joined(separator: " · "))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1...2)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                Text(record.calories.map { "\(Int($0)) kcal" } ?? "—")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FamilyUI.accent)
                    .monospacedDigit()
            }
            .padding(10)
            .background(FamilyUI.panelMutedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                    .stroke(isSelected ? FamilyUI.accent.opacity(0.5) : FamilyUI.panelBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
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
                    RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.panelCornerRadius))
        }
        .buttonStyle(.plain)
    }

    private func exportPDF() {
        do {
            let selected = records.filter { selectedIDs.contains($0.id) }
            let data = try ExportService.exportSupplementLibraryPDF(records: selected)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("1Life_supplements_library.pdf")
            try data.write(to: tempURL, options: [.atomic])
            shareItem = ShareSheetItem(url: tempURL)
            HapticEngine.success()
        } catch {
            HapticEngine.warning()
            bannerCenter.show(title: "PDF 导出失败", message: error.localizedDescription, tone: .error)
        }
    }
}

// MARK: - 辅助

@MainActor
private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
