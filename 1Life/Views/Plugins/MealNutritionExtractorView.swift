import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// 三个识别插件共用的模型选择器。服务商跟随全局 AI 配置，模型可在插件内单独覆盖。
struct PluginAIModelSelector: View {
    let settings: UserSettings
    @Binding var selectedModel: String
    let onChange: (String) -> Void

    private var provider: AIProvider { settings.selectedAIProvider }
    private var models: [String] {
        LocalAIConfigurationService().providerOptions.first { $0.provider == provider }?.models ?? [provider.defaultModel]
    }

    var body: some View {
        SystemPanel(title: "本插件 AI 模型", detail: "服务商跟随全局配置，可按插件单独切换模型") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "network").foregroundStyle(FamilyUI.accent)
                    Text("服务商").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(provider.displayName).font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
                }
                Picker("模型", selection: Binding(
                    get: { selectedModel },
                    set: { selectedModel = $0; onChange($0) }
                )) {
                    ForEach(models, id: \.self) { model in Text(model).tag(model) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - 餐食营养识别插件

/// 插件入口页：说明流程 + 当前餐食库统计 + 开始识别入口。
/// 库本身的管理复用已有的 `UserFoodListView`，这里不重复实现列表/搜索/导出。
struct MealNutritionRecognitionPluginView: View {
    @Query private var settings: [UserSettings]
    @Query private var userFoods: [UserFood]

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
                    title: "餐食营养识别",
                    detail: "识别图片或文字，校对后保存到餐食库"
                )

                SystemPanel(title: "识别流程", detail: "插件只负责识别与校对") {
                    VStack(alignment: .leading, spacing: 10) {
                        recognitionRow("1", "输入", "拍摄食品包装、营养成分表，或粘贴文字说明，支持一次多样食材。")
                        recognitionRow("2", "校对", "确认食物名称和每份热量，其他营养信息按图片实际内容提取。")
                        recognitionRow("3", "入库", "保存后进入餐食库，AI 记录三餐时会优先引用库内数据。")
                    }
                }

                SystemPanel(title: "当前餐食库", detail: "\(userFoods.count) 条已确认记录") {
                    AppSettingsRow(
                        icon: "fork.knife",
                        iconColor: .pink,
                        title: "保存目标",
                        subtitle: "识别完成后写入食物库中的餐食库",
                        value: "\(userFoods.count) 条"
                    )
                }

                Button {
                    isShowingExtractSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .accessibilityLabel("拍照识别")
                            .font(.headline.weight(.bold))
                        Text("开始餐食识别")
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
                        subtitle: "餐食营养识别需要可用的 AI 服务商和 API Key。"
                    )
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.vertical, 16)
        }
        .background(FamilyUI.pageBackground)
        .navigationTitle("餐食营养识别")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingExtractSheet) {
            if let currentSettings {
                MealNutritionExtractSheet(settings: currentSettings)
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

// MARK: - 识别 Sheet（选图 → 识别 → 校对 → 入库）

struct MealNutritionExtractSheet: View {
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

    private enum DuplicateResolution {
        case update
        case saveAsNew
    }

    @Query(sort: [SortDescriptor(\UserFood.name)])
    private var existingFoods: [UserFood]

    @State private var phase: Phase = .input
    @State private var selectedModel: String
    @State private var imageDataList: [Data] = []
    @State private var brandText = ""
    @State private var supplementText = ""
    @State private var recognizedText = ""
    @State private var candidates: [MealNutritionCandidate] = []
    @State private var drafts: [MealNutritionExtractedDraft] = []
    @State private var errorMessage: String?
    @State private var isShowingCameraPicker = false
    @State private var isShowingPhotosPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var bannerCenter = GlobalBannerCenter.shared

    init(settings: UserSettings) {
        self.settings = settings
        _selectedModel = State(initialValue: settings.effectiveMealPluginAIModel)
    }
    @State private var isShowingDuplicateResolution = false
    @State private var duplicateNames: [String] = []

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
                        loadingSection(title: "识别食物中", detail: "正在从文字里先找出食物名称，这一步只确认范围。")
                    case .candidateReview:
                        candidateReviewSection
                    case .parsing:
                        loadingSection(title: "提取营养中", detail: "正在围绕已确认食物提取每份热量和可确认的营养信息，最多约 2 分钟。")
                    case .review:
                        reviewSection
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.vertical, 16)
            }
            .background(FamilyUI.pageBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("识别餐食营养")
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
                        Button("全部入库", action: beginSaveAll)
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
            .confirmationDialog(
                "\(duplicateNames.count) 个食物名称已存在于餐食库",
                isPresented: $isShowingDuplicateResolution,
                titleVisibility: .visible
            ) {
                Button("更新已有记录的营养值") { finishSaveAll(resolution: .update) }
                Button("另存为新记录") { finishSaveAll(resolution: .saveAsNew) }
                Button("取消", role: .cancel) {}
            } message: {
                Text(duplicateNames.joined(separator: "、"))
            }
        }
    }

    // MARK: 输入阶段

    private var inputSection: some View {
        Group {
            PluginAIModelSelector(settings: settings, selectedModel: $selectedModel) {
                settings.mealPluginAIModel = $0
                settings.mealPluginAIProviderRaw = settings.selectedAIProvider.rawValue
            }

            SystemPageHeader(
                eyebrow: "第 1 步",
                title: "提供图片或文字",
                detail: "食品包装、营养成分表照片，可多张"
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

            SystemPanel(title: "品牌（可选）", detail: "填写后优先使用此品牌，方便餐食库按品牌归类") {
                TextField("例如：某某食品", text: $brandText)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
            }

            SystemPanel(title: "文字输入（可选）", detail: "可只输入文字，不需要图片；建议分段输入，过长文本可能因模型能力不同而识别失败") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("建议提供食物名称、每份热量和营养数据")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            if let clipboardText = UIPasteboard.general.string {
                                supplementText = clipboardText
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.clipboard")
                                Text("粘贴文本")
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FamilyUI.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(FamilyUI.accent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
                        }
                        .disabled(!UIPasteboard.general.hasStrings)
                    }

                    TextField("例如：全麦面包，一份热量 180 kcal，蛋白质 7g", text: $supplementText, axis: .vertical)
                        .lineLimit(2...8)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(FamilyUI.panelMutedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                }
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
        // 餐食营养表中的小字体对清晰度敏感，不在选图时先压缩到 1MB；
        // 统一交给 MealNutritionExtractorService 在发送前做自适应处理。
        imageDataList.append(data)
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
                TextField("粘贴或校对营养成分表文字", text: $recognizedText, axis: .vertical)
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
                    Label("识别食物", systemImage: "list.bullet.clipboard")
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

    // MARK: 候选食物确认

    private var candidateReviewSection: some View {
        Group {
            SystemPageHeader(
                eyebrow: "第 3 步",
                title: "确认食物",
                detail: "先确认食物名称，再针对性提取营养"
            )

            if candidates.isEmpty {
                SystemPanel(title: "候选食物", detail: "暂无候选") {
                    AppEmptyStateView(
                        icon: "fork.knife",
                        title: "还没有候选食物",
                        subtitle: "可以手动添加一条，或返回补充食物名称。"
                    )
                }
            } else {
                ForEach($candidates) { candidateBinding in
                    MealNutritionCandidateEditor(candidate: candidateBinding) {
                        candidates.removeAll { $0.id == candidateBinding.wrappedValue.id }
                    }
                }
            }

            Button {
                candidates.append(MealNutritionCandidate())
            } label: {
                Label("添加食物", systemImage: "plus.circle")
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
                detail: "共 \(drafts.count) 条 · 至少需要名称和每份热量"
            )

            ForEach($drafts) { $draft in
                MealNutritionDraftEditor(draft: $draft) {
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
                    Text(candidates.isEmpty ? (recognizedText.isEmpty ? "返回重新识别" : "返回校对文字") : "返回确认食物")
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
                let service = MealNutritionExtractorService(settings: settings)
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
                let service = MealNutritionExtractorService(settings: settings)
                candidates = try await service.identifyCandidates(fromConfirmedText: text, brand: brandText)
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
                let service = MealNutritionExtractorService(settings: settings)
                drafts = try await service.extract(fromConfirmedText: text, candidates: selectedCandidates, brand: brandText)
                phase = .review
                HapticEngine.success()
            } catch {
                errorMessage = error.localizedDescription
                phase = .candidateReview
                HapticEngine.warning()
            }
        }
    }

    /// 保存前先查一遍重名：餐食库（UserFood）按名称唯一管理，不像饮品库允许同名多版本并存，
    /// 命中重名时必须先问用户"更新已有记录"还是"另存为新记录"，不能静默产生同名脏数据。
    private func beginSaveAll() {
        let validDrafts = drafts.filter(\.isValid)
        guard !validDrafts.isEmpty else { return }

        let existingNames = Set(existingFoods.map { Self.foodKey(brand: $0.brand, name: $0.name) })
        let duplicates = validDrafts
            .map { Self.foodKey(brand: $0.brand, name: $0.name) }
            .filter { existingNames.contains($0) }

        if duplicates.isEmpty {
            finishSaveAll(resolution: .saveAsNew)
        } else {
            duplicateNames = duplicates
            isShowingDuplicateResolution = true
        }
    }

    private func finishSaveAll(resolution: DuplicateResolution) {
        let validDrafts = drafts.filter(\.isValid)
        guard !validDrafts.isEmpty else { return }

        var existingByName = Dictionary(
            uniqueKeysWithValues: existingFoods.map {
                (Self.foodKey(brand: $0.brand, name: $0.name), $0)
            }
        )

        var inserted = 0
        var updated = 0
        for draft in validDrafts {
            let key = Self.foodKey(brand: draft.brand, name: draft.name)
            if resolution == .update, let existing = existingByName[key] {
                draft.applyNutrition(to: existing)
                updated += 1
            } else {
                let food = draft.makeUserFood()
                modelContext.insert(food)
                existingByName[key] = food
                inserted += 1
            }
        }

        HapticEngine.success()
        var message = "新增 \(inserted) 条"
        if updated > 0 { message += "，更新 \(updated) 条" }
        bannerCenter.show(title: "已存入餐食库", message: message + "。", tone: .success)
        dismiss()
    }

    private static func foodKey(brand: String, name: String) -> String {
        let normalizedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedBrand)|\(normalizedName)"
    }
}

// MARK: - 候选食物卡片

private struct MealNutritionCandidateEditor: View {
    @Binding var candidate: MealNutritionCandidate
    let onDelete: () -> Void

    var body: some View {
        SystemPanel(
            title: candidate.name.isEmpty ? "未命名食物" : candidate.name,
            detail: candidate.sourceNote.isEmpty ? "确认后用于定向提取营养" : "线索：\(candidate.sourceNote)"
        ) {
            VStack(spacing: 10) {
                Toggle(isOn: $candidate.isSelected) {
                    Text("入库")
                        .font(.caption.weight(.bold))
                }
                .toggleStyle(AppSwitchStyle())

                labeledField("食物名", text: $candidate.name)
                labeledField("线索", text: $candidate.sourceNote)

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

private struct MealNutritionDraftEditor: View {
    @Binding var draft: MealNutritionExtractedDraft
    var onDelete: (() -> Void)? = nil

    @State private var showsMoreNutrients = false

    var body: some View {
        SystemPanel(
            title: draft.name.isEmpty ? "未命名食物" : draft.name,
            detail: "来源：\(draft.sourceNote.isEmpty ? "未注明" : draft.sourceNote)"
        ) {
            VStack(spacing: 10) {
                labeledField("品牌（可选）", text: $draft.brand)
                labeledField("食物名", text: $draft.name)

                HStack(spacing: 10) {
                    labeledNumberField("默认份量", value: Binding(
                        get: { draft.defaultAmount },
                        set: { draft.defaultAmount = $0 ?? 1 }
                    ))
                    labeledField("单位", text: $draft.defaultUnit)
                }

                SystemPanelDivider()

                HStack(spacing: 10) {
                    labeledNumberField("热量 kcal/份", value: $draft.caloriesPerServing)
                            labeledNumberField("蛋白 g/份", value: $draft.proteinPer100g)
                }
                HStack(spacing: 10) {
                    labeledNumberField("碳水 g/份", value: $draft.carbsPer100g)
                    labeledNumberField("脂肪 g/份", value: $draft.fatPer100g)
                }

                DisclosureGroup(isExpanded: $showsMoreNutrients) {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            labeledNumberField("膳食纤维 g", value: $draft.fiberPer100g)
                            labeledNumberField("钠 mg", value: $draft.sodiumPer100g)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("糖 g", value: $draft.sugarPer100g)
                            labeledNumberField("胆固醇 mg", value: $draft.cholesterolPer100g)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("咖啡因 mg", value: $draft.caffeinePer100g)
                            labeledNumberField("茶多酚 mg", value: $draft.teaPolyphenolsPer100g)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("钙 mg", value: $draft.calciumPer100g)
                            labeledNumberField("镁 mg", value: $draft.magnesiumPer100g)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("钾 mg", value: $draft.potassiumPer100g)
                            labeledNumberField("铁 mg", value: $draft.ironPer100g)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("锌 mg", value: $draft.zincPer100g)
                            labeledNumberField("维生素A ug", value: $draft.vitaminAPer100g)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("维生素C mg", value: $draft.vitaminCPer100g)
                            labeledNumberField("维生素D ug", value: $draft.vitaminDPer100g)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("维生素E mg", value: $draft.vitaminEPer100g)
                            labeledNumberField("维生素B1 mg", value: $draft.vitaminB1Per100g)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("维生素B2 mg", value: $draft.vitaminB2Per100g)
                            labeledNumberField("烟酸 mg", value: $draft.niacinPer100g)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("维生素B6 mg", value: $draft.vitaminB6Per100g)
                            labeledNumberField("叶酸 ug", value: $draft.folatePer100g)
                        }
                        HStack(spacing: 10) {
                            labeledNumberField("维生素B12 ug", value: $draft.vitaminB12Per100g)
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text(showsMoreNutrients ? "收起更多营养素" : "展开更多营养素（维生素/矿物质）")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FamilyUI.accent)
                }

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

// MARK: - 辅助

@MainActor
private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
