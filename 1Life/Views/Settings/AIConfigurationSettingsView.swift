import SwiftUI
import SwiftData

struct AIConfigurationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: UserSettings
    @Query(sort: [SortDescriptor(\AIChatMessage.createdAt)])
    private var chatMessages: [AIChatMessage]

    @State private var apiKeyText = ""
    @State private var maskedKey = ""
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var showClearChatAlert = false

    private let configService = LocalAIConfigurationService()

    private var currentProviderOption: AIProviderOption? {
        configService.providerOptions.first { $0.provider == settings.selectedAIProvider }
    }

    private var supportsVision: Bool {
        settings.selectedAIProvider.supportsVision(model: settings.selectedAIModel)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                SystemPageHeader(
                    eyebrow: "AI 控制台",
                    title: "AI 配置",
                    detail: "Family 共享 AI Chat 骨架下的 Provider、Model、Key 与历史控制台"
                )

                SystemPanel(title: "服务状态", detail: "当前服务状态与视觉能力") {
                    AppSettingsRow(
                        icon: "cpu",
                        title: "当前服务商",
                        subtitle: "Provider",
                        value: settings.selectedAIProvider.displayName,
                        emphasizesValue: true
                    )

                    SystemPanelDivider()

                    AppSettingsRow(
                        icon: "wand.and.stars",
                        title: "当前模型",
                        subtitle: "Model",
                        value: settings.selectedAIModel
                    )

                    SystemPanelDivider()

                    HStack(spacing: 8) {
                        SystemStatusBadge(
                            text: settings.isAIConfigured ? "已配置" : "未设置",
                            tone: settings.isAIConfigured ? .success : .warning
                        )
                        SystemStatusBadge(
                            text: supportsVision ? "支持视觉" : "仅文本",
                            tone: supportsVision ? .accent : .neutral
                        )
                    }

                    SystemPanelDivider()

                    Picker(selection: Binding<AIProvider>(
                        get: { settings.selectedAIProvider },
                        set: { provider in
                            settings.selectedAIProvider = provider
                            settings.selectedAIModel = provider.defaultModel
                            settings.updatedAt = .now
                            loadMaskedKey()
                        }
                    )) {
                        ForEach(AIProvider.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    } label: {
                        AppSettingsRow(
                            icon: "sparkles.rectangle.stack",
                            iconColor: .purple,
                            title: "AI 服务商",
                            subtitle: "切换 Provider 会同步刷新默认模型",
                            value: settings.selectedAIProvider.displayName
                        )
                    }
                    .pickerStyle(.menu)
                    .tint(FamilyUI.accent)

                    SystemPanelDivider()

                    Picker(selection: Binding<String>(
                        get: { settings.selectedAIModel },
                        set: { model in
                            settings.selectedAIModel = model
                            settings.updatedAt = .now
                        }
                    )) {
                        ForEach(currentProviderOption?.models ?? [settings.selectedAIModel], id: \.self) { model in
                            Text(model).tag(model)
                        }
                    } label: {
                        AppSettingsRow(
                            icon: "slider.horizontal.3",
                            title: "模型",
                            subtitle: supportsVision ? "当前模型支持拍照识别" : "当前模型仅支持文本对话",
                            value: settings.selectedAIModel
                        )
                    }
                    .pickerStyle(.menu)
                    .tint(FamilyUI.accent)
                }

                SystemPanel(title: "API Key", detail: "本地 Keychain 保存与连接校验") {
                    AppSettingsRow(
                        icon: "key.fill",
                        title: "当前 Key",
                        subtitle: "已保存的密钥会用掩码显示",
                        value: maskedKey
                    )

                    SystemPanelDivider()

                    SecureField("粘贴新的 API Key", text: $apiKeyText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(FamilyUI.panelMutedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))

                    HStack(spacing: 10) {
                        Button {
                            saveKey()
                        } label: {
                            Label("保存 Key", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SystemActionButtonStyle(
                            tone: .dark,
                            isEnabled: !apiKeyText.isEmpty
                        ))
                        .disabled(apiKeyText.isEmpty)

                        Button {
                            testConnection()
                        } label: {
                            if isTesting {
                                HStack(spacing: 8) {
                                    ProgressView().scaleEffect(0.8)
                                    Text("测试中")
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Label("测试连接", systemImage: "network")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(SystemActionButtonStyle(
                            tone: .outline,
                            isEnabled: settings.isAIConfigured && !isTesting
                        ))
                        .disabled(isTesting || !settings.isAIConfigured)
                    }

                    if settings.isAIConfigured {
                        Button(role: .destructive) {
                            deleteKey()
                        } label: {
                            Label("删除 Key", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SystemActionButtonStyle(
                            tone: .dangerOutline,
                            isEnabled: true
                        ))
                    }

                    if let testResult {
                        Text(testResult)
                            .font(.caption)
                            .foregroundStyle(testResult.contains("成功") ? FamilyUI.success : FamilyUI.danger)
                    }
                }

                SystemPanel(title: "获取 API Key", detail: "官方开发平台入口，仅供参考") {
                    Text("请确认域名、账号与计费信息安全。不要向非官方页面提交 API Key；1Life 只会把你主动保存的 Key 存入本机 Keychain。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SystemPanelDivider()

                    VStack(spacing: 0) {
                        ForEach(apiKeyLinks) { item in
                            Link(destination: item.url) {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(FamilyUI.panelMutedBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                                        )
                                        .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                                        .overlay(
                                            Image(systemName: "key.viewfinder")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundStyle(FamilyUI.accent)
                                        )

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.provider.displayName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(item.note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 9)
                            }
                            if item.id != apiKeyLinks.last?.id {
                                SystemPanelDivider()
                            }
                        }
                    }
                }

                SystemPanel(title: "聊天历史", detail: "Family 统一 AI 对话清理规则") {
                    AppSettingsRow(
                        icon: "text.bubble",
                        title: "消息数量",
                        subtitle: "当前本机保存的 AI 聊天记录",
                        value: "\(chatMessages.count) 条"
                    )

                    SystemPanelDivider()

                    Button(role: .destructive) {
                        showClearChatAlert = true
                    } label: {
                        AppSettingsRow(
                            icon: "trash",
                            iconColor: .red,
                            title: "清空聊天历史",
                            subtitle: "删除所有 AI 对话消息，不可恢复",
                            value: chatMessages.isEmpty ? "无数据" : "清空"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(chatMessages.isEmpty)
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.pageBottom)
        }
        .background(FamilyUI.pageBackground.ignoresSafeArea())
        .navigationTitle("AI 配置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadMaskedKey() }
        .alert("清空聊天历史", isPresented: $showClearChatAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                HapticEngine.warning()
                for msg in chatMessages { modelContext.delete(msg) }
            }
        } message: {
            Text("将删除所有 \(chatMessages.count) 条聊天消息，此操作不可恢复。")
        }
    }

    private var apiKeyLinks: [AIAPIKeyLink] {
        [
            AIAPIKeyLink(provider: .claude, url: URL(string: "https://console.anthropic.com/settings/keys")!, note: "Anthropic Console"),
            AIAPIKeyLink(provider: .chatGPT, url: URL(string: "https://platform.openai.com/api-keys")!, note: "OpenAI Platform"),
            AIAPIKeyLink(provider: .kimi, url: URL(string: "https://platform.moonshot.cn/console/api-keys")!, note: "Moonshot AI 开放平台"),
            AIAPIKeyLink(provider: .qwen, url: URL(string: "https://bailian.console.aliyun.com/")!, note: "阿里云百炼控制台"),
            AIAPIKeyLink(provider: .doubao, url: URL(string: "https://console.volcengine.com/ark/")!, note: "火山方舟控制台"),
            AIAPIKeyLink(provider: .yuanbao, url: URL(string: "https://console.cloud.tencent.com/hunyuan")!, note: "腾讯云混元控制台"),
            AIAPIKeyLink(provider: .deepseek, url: URL(string: "https://platform.deepseek.com/api_keys")!, note: "DeepSeek 开放平台"),
            AIAPIKeyLink(provider: .mimo, url: URL(string: "https://platform.xiaomimimo.com/")!, note: "MiMo 开放平台；tp- Key 使用 Token Plan，sk- Key 使用开放平台")
        ]
    }

    private func loadMaskedKey() {
        let key = try? configService.readAPIKey(provider: settings.selectedAIProvider)
        maskedKey = configService.maskedKey(for: key)
    }

    private func saveKey() {
        try? configService.saveAPIKey(apiKeyText, provider: settings.selectedAIProvider)
        settings.isAIConfigured = true
        settings.updatedAt = .now
        HapticEngine.success()
        apiKeyText = ""
        loadMaskedKey()
        testResult = nil
    }

    private func deleteKey() {
        try? configService.deleteAPIKey(provider: settings.selectedAIProvider)
        settings.isAIConfigured = false
        settings.updatedAt = .now
        HapticEngine.warning()
        loadMaskedKey()
        testResult = nil
    }

    private func testConnection() {
        guard settings.isAIConfigured else {
            testResult = "请先保存 API Key"
            return
        }
        isTesting = true
        testResult = nil

        Task {
            do {
                let service = ConfiguredAIService(settings: settings)
                let reply = try await service.sendMessage("你好，请简短回复确认连接正常。", history: [], context: nil)
                testResult = reply.isEmpty ? "连接失败：空回复" : "连接成功 ✓"
            } catch {
                testResult = "连接失败：\(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}

private struct AIAPIKeyLink: Identifiable {
    let provider: AIProvider
    let url: URL
    let note: String

    var id: String { provider.rawValue }
}

private struct SystemActionButtonStyle: ButtonStyle {
    enum Tone {
        case dark
        case outline
        case dangerOutline
    }

    let tone: Tone
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(background(configuration: configuration))
            .foregroundStyle(foreground)
            .overlay(
                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                    .stroke(border, lineWidth: tone == .dark ? 0 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }

    private var foreground: Color {
        switch tone {
        case .dark:
            return .white
        case .outline:
            return isEnabled ? .primary : .secondary
        case .dangerOutline:
            return FamilyUI.danger
        }
    }

    private var border: Color {
        switch tone {
        case .dark:
            return .clear
        case .outline:
            return FamilyUI.panelBorder
        case .dangerOutline:
            return FamilyUI.danger.opacity(0.35)
        }
    }

    @ViewBuilder
    private func background(configuration: Configuration) -> some View {
        switch tone {
        case .dark:
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .fill(isEnabled ? Color.black : Color(.systemGray3))
        case .outline:
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .fill(isEnabled ? Color.white : FamilyUI.panelMutedBackground)
        case .dangerOutline:
            RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                .fill(FamilyUI.danger.opacity(configuration.isPressed ? 0.12 : 0.08))
        }
    }
}
