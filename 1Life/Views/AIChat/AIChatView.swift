import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AIChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @Query(sort: [SortDescriptor(\AIChatMessage.createdAt)])
    private var storedMessages: [AIChatMessage]

    var onOpenSettings: () -> Void = {}

    @State private var viewModel = AIChatViewModel()
    @State private var configurationStatus: AIConfigurationStatus?
    @State private var configurationError: String?
    @State private var isShowingImageSourceDialog = false
    @State private var isShowingImagePicker = false
    @State private var isShowingPhotosPicker = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImageDataList: [Data] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showClearAlert = false
    @State private var isShowingPendingMealEditor = false
    @State private var isShowingSaveTemplateSheet = false
    @State private var saveTemplateName = ""
    @State private var speechInput = SpeechInputController()
    @State private var requestElapsedSeconds = 0
    @State private var requestHasImages = false
    @State private var requestTimerTask: Task<Void, Never>?
    @FocusState private var messageFieldFocused: Bool
    @State private var bannerCenter = GlobalBannerCenter.shared

    private let configurationService = LocalAIConfigurationService()

    private var currentSettings: UserSettings? { settings.first }
    private var currentProvider: AIProvider { currentSettings?.selectedAIProvider ?? .claude }
    private var chatBottomID: String { "chat-bottom" }

    private var isConfigured: Bool {
        configurationStatus?.hasAPIKey == true && currentSettings?.isAIConfigured == true
    }

    private var canUseVision: Bool {
        guard let currentSettings else { return false }
        return isConfigured && currentSettings.selectedAIProvider.supportsVision(model: currentSettings.selectedAIModel)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AIConfigurationHeader(
                    status: configurationStatus,
                    isConfigured: isConfigured,
                    errorMessage: configurationError,
                    providerOptions: configurationService.providerOptions,
                    selectedProvider: currentProvider,
                    selectedModel: currentSettings?.selectedAIModel ?? currentProvider.defaultModel,
                    onSelectProvider: switchProvider,
                    onSelectModel: switchModel,
                    onOpenSettings: onOpenSettings
                )

                chatSection

                pendingSection

                inputSection
            }
            .background(FamilyUI.pageBackground)
            .navigationTitle("AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        messageFieldFocused = false
                        showClearAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .accessibilityLabel("清空对话")
                    }
                    .disabled(storedMessages.isEmpty)
                }
            }
            .alert("清空聊天历史", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    HapticEngine.warning()
                    for msg in storedMessages { modelContext.delete(msg) }
                    try? modelContext.save()
                    viewModel.messages = []
                }
            }
            .confirmationDialog("添加图片", isPresented: $isShowingImageSourceDialog, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("拍照") {
                        imagePickerSourceType = .camera
                        isShowingImagePicker = true
                    }
                }
                Button("从相册选择") {
                    isShowingPhotosPicker = true
                }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $isShowingImagePicker) {
                AIImagePicker(sourceType: imagePickerSourceType) { data in
                    appendImageData(data)
                }
            }
            .sheet(isPresented: $isShowingPendingMealEditor) {
                if let meal = viewModel.pendingMealForEditing {
                    MealManualEditSheet(meal: meal) { updatedMeal in
                        viewModel.applyManualMealEdit(updatedMeal)
                    }
                }
            }
            .sheet(isPresented: $isShowingSaveTemplateSheet) {
                SaveTemplateFromReviewSheet(name: $saveTemplateName) {
                    let trimmed = saveTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
                    var saved = false
                    if let meal = viewModel.pendingMeals.first {
                        saved = viewModel.saveAsTemplate(meal, name: trimmed)
                    }
                    if saved {
                        bannerCenter.show(title: "已存入模板库", message: "之后说“吃了\(trimmed)”即可按这份模板记录。", tone: .success)
                    } else {
                        bannerCenter.show(title: "没能保存模板", message: "名称为空或模板库里已有同名模板。", tone: .warning)
                    }
                    isShowingSaveTemplateSheet = false
                } onCancel: {
                    isShowingSaveTemplateSheet = false
                }
                .presentationDetents([.height(240)])
                .presentationDragIndicator(.visible)
            }
            .photosPicker(isPresented: $isShowingPhotosPicker, selection: $selectedPhotoItems, maxSelectionCount: max(1, 6 - selectedImageDataList.count), matching: .images)
            .onChange(of: selectedPhotoItems) { _, items in
                Task { await appendPhotoItems(items) }
            }
            .onChange(of: settings.first?.isAIConfigured) { _, _ in loadConfigurationStatus() }
            .onChange(of: settings.first?.selectedAIProviderRaw) { _, _ in loadConfigurationStatus() }
            .onChange(of: settings.first?.selectedAIModel) { _, _ in loadConfigurationStatus() }
            .onChange(of: viewModel.errorMessage) { _, error in
                guard let error else { return }
                bannerCenter.show(title: "AI 请求失败", message: error, tone: .error)
                viewModel.errorMessage = nil
            }
            .onChange(of: configurationError) { _, error in
                guard let error else { return }
                bannerCenter.show(title: "AI 配置异常", message: error, tone: .warning)
                configurationError = nil
            }
            .onChange(of: speechInput.errorMessage) { _, error in
                guard let error else { return }
                bannerCenter.show(title: "语音输入异常", message: error, tone: .warning)
                speechInput.errorMessage = nil
            }
            .onDisappear {
                messageFieldFocused = false
                speechInput.stopRecording()
                stopRequestTimer()
            }
        }
    }

    private var chatSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        AIEmptyStateContent(isConfigured: isConfigured, onOpenSettings: onOpenSettings)
                    } else {
                        ForEach(viewModel.messages) { msg in
                            ChatBubble(message: msg) { message in
                                viewModel.undoMeal(message: message)
                            }
                            .id(msg.id)
                        }
                    }

                    Color.clear.frame(height: 1).id(chatBottomID)
                }
                .padding(16)
            }
            .background(FamilyUI.pageBackground)
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { messageFieldFocused = false })
            .onAppear {
                if let s = currentSettings {
                    viewModel.configure(modelContext: modelContext, settings: s)
                }
                viewModel.loadMessages(from: storedMessages)
                loadConfigurationStatus()
                scrollToChatBottom(proxy, animated: false)
            }
            .onChange(of: storedMessages.count) { _, _ in
                viewModel.loadMessages(from: storedMessages)
                scrollToChatBottom(proxy, animated: true)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToChatBottom(proxy, animated: true)
            }
        }
    }

    private func scrollToChatBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(chatBottomID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(chatBottomID, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private var pendingSection: some View {
        if let confirmation = viewModel.pendingConfirmation {
            AIMealIdentificationConfirmationView(
                confirmation: confirmation,
                onAccept: {
                    viewModel.confirmPendingMeals()
                },
                onReidentifyWithAI: {
                    Task { await viewModel.reidentifyWithAI() }
                },
                onManualEdit: {
                    isShowingPendingMealEditor = true
                },
                onCancel: { viewModel.cancelMeal() },
                onSaveAsTemplate: {
                    saveTemplateName = viewModel.pendingMeals.first?.nameSuggestion ?? ""
                    isShowingSaveTemplateSheet = true
                }
            )
        }
    }

    private var inputSection: some View {
        VStack(spacing: 10) {
            if viewModel.isLoading {
                AIRequestProgressView(elapsedSeconds: requestElapsedSeconds, hasImages: requestHasImages)
                    .padding(.horizontal, 16)
            }

            if !selectedImageDataList.isEmpty {
                selectedImagesSection
            }

            promptChipsSection
            inputBarSection
        }
        .padding(.vertical, 12)
        .background(
            FamilyUI.pageBackground
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(FamilyUI.panelBorder)
                        .frame(height: 1)
                }
        )
    }

    private var selectedImagesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(selectedImageDataList.enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 58, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                )
                                .clipped()

                            Button {
                                HapticEngine.tap()
                                selectedImageDataList.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .accessibilityLabel("移除这张照片")
                                    .font(.caption)
                                    .foregroundStyle(.white, .black.opacity(0.45))
                            }
                            .offset(x: 5, y: -5)
                        }
                    }
                }

                Text("已附加 \(selectedImageDataList.count)/6")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }

    private var promptChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(["记录早餐", "拍照识别", "营养分析", "记录训练", "记录排便", "写日记", "记录喝水"], id: \.self) { chip in
                    Button(chip) {
                        HapticEngine.tap()
                        if chip == "记录训练" {
                            viewModel.inputText = "记录今天训练："
                            messageFieldFocused = true
                        } else if chip == "记录排便" {
                            viewModel.inputText = "记录今天排便："
                            messageFieldFocused = true
                        } else if chip == "写日记" {
                            viewModel.inputText = "帮我记录今天的状态："
                            messageFieldFocused = true
                        } else {
                            messageFieldFocused = false
                            viewModel.inputText = chip
                            sendMessage()
                        }
                    }
                    .disabled(!isConfigured && !["记录喝水", "记录训练", "记录排便", "写日记"].contains(chip))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.badgeCornerRadius))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var inputBarSection: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button {
                HapticEngine.tap()
                if canUseVision {
                    messageFieldFocused = false
                    isShowingImageSourceDialog = true
                } else {
                    viewModel.errorMessage = isConfigured ? "当前模型不支持图片识别，请切换到支持视觉输入的模型。" : "请先配置 AI。"
                }
            } label: {
                Image(systemName: "camera.fill")
                    .fontWeight(.semibold)
                    .frame(width: 38, height: 38)
                    .background(FamilyUI.panelMutedBackground)
                    .foregroundStyle(canUseVision ? FamilyUI.accent : FamilyUI.inkFaint)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
            }
            .disabled(viewModel.isLoading)
            .accessibilityLabel("拍照或上传图片")

            Button {
                HapticEngine.tap()
                toggleVoiceInput()
            } label: {
                Image(systemName: speechInput.isRecording ? "mic.fill" : "mic")
                    .accessibilityLabel(speechInput.isRecording ? "停止语音输入" : "开始语音输入")
                    .fontWeight(.semibold)
                    .frame(width: 38, height: 38)
                    .background(speechInput.isRecording ? FamilyUI.danger : FamilyUI.panelMutedBackground)
                    .foregroundStyle(speechInput.isRecording ? FamilyUI.buttonForeground : Color.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
            }
            .disabled(!isConfigured || viewModel.isLoading)
            .accessibilityLabel(speechInput.isRecording ? "停止语音输入" : "语音输入")

            TextField(
                isConfigured ? "描述饮食、训练、喝水或状态..." : "可记录喝水，完整 AI 需先配置",
                text: $viewModel.inputText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(1...6)
            .fixedSize(horizontal: false, vertical: true)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .tint(FamilyUI.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FamilyUI.panelMutedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
            .focused($messageFieldFocused)
            .accessibilityLabel("输入要记录的内容")

            Button {
                HapticEngine.tap()
                messageFieldFocused = false
                sendMessage()
            } label: {
                Image(systemName: viewModel.isLoading ? "hourglass" : "arrow.up")
                    .accessibilityLabel(viewModel.isLoading ? "正在请求 AI" : "发送")
                    .fontWeight(.bold)
                    .frame(width: 38, height: 38)
                    .background(FamilyUI.buttonBackground)
                    .foregroundStyle(FamilyUI.buttonForeground)
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
            }
            .disabled(viewModel.isLoading || (viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageDataList.isEmpty))
        }
        .padding(.horizontal, 16)
    }

    private func loadConfigurationStatus() {
        guard let currentSettings else {
            configurationStatus = nil
            configurationError = nil
            return
        }
        do {
            configurationStatus = try configurationService.status(for: currentSettings)
            configurationError = nil
        } catch {
            configurationStatus = nil
            configurationError = error.localizedDescription
        }
    }

    private func switchProvider(_ provider: AIProvider) {
        guard let currentSettings else {
            onOpenSettings()
            return
        }
        guard provider != currentProvider else { return }
        let option = configurationService.providerOptions.first { $0.provider == provider }
        currentSettings.selectedAIProvider = provider
        currentSettings.selectedAIModel = option?.defaultModel ?? currentSettings.selectedAIModel
        let hasKey = (try? configurationService.readAPIKey(provider: provider))?.isEmpty == false
        currentSettings.isAIConfigured = hasKey
        currentSettings.updatedAt = .now
        try? modelContext.save()
        viewModel.configure(modelContext: modelContext, settings: currentSettings)
        HapticEngine.tap()
        loadConfigurationStatus()
    }

    private func switchModel(_ model: String) {
        guard let currentSettings else {
            onOpenSettings()
            return
        }
        guard currentSettings.selectedAIModel != model else { return }
        let currentProviderModels = configurationService.providerOptions.first { $0.provider == currentSettings.selectedAIProvider }?.models ?? []
        guard currentProviderModels.contains(model) else { return }
        currentSettings.selectedAIModel = model
        currentSettings.updatedAt = .now
        try? modelContext.save()
        viewModel.configure(modelContext: modelContext, settings: currentSettings)
        HapticEngine.tap()
        loadConfigurationStatus()
    }

    private func sendMessage() {
        let imageDataList = selectedImageDataList
        selectedImageDataList = []
        speechInput.stopRecording()
        startRequestTimer(hasImages: !imageDataList.isEmpty)
        Task {
            defer { stopRequestTimer() }
            if !imageDataList.isEmpty {
                let text = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                viewModel.inputText = ""
                await viewModel.sendPhotos(imageDataList: imageDataList, text: text.isEmpty ? nil : text)
            } else {
                await viewModel.sendMessage()
            }
        }
    }

    private func appendImageData(_ data: Data) {
        guard selectedImageDataList.count < 6 else { return }
        selectedImageDataList.append(ImageService.compress(data) ?? data)
    }

    @MainActor
    private func appendPhotoItems(_ items: [PhotosPickerItem]) async {
        defer { selectedPhotoItems = [] }
        for item in items where selectedImageDataList.count < 6 {
            if let data = try? await item.loadTransferable(type: Data.self) {
                appendImageData(data)
            }
        }
    }

    private func toggleVoiceInput() {
        messageFieldFocused = false
        speechInput.toggleRecording { transcript in
            viewModel.inputText = transcript
        }
    }

    private func startRequestTimer(hasImages: Bool) {
        requestTimerTask?.cancel()
        requestElapsedSeconds = 0
        requestHasImages = hasImages
        requestTimerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                requestElapsedSeconds += 1
            }
        }
    }

    private func stopRequestTimer() {
        requestTimerTask?.cancel()
        requestTimerTask = nil
        requestElapsedSeconds = 0
        requestHasImages = false
    }
}
