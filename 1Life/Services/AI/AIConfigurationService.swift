import Foundation

struct AIProviderOption: Identifiable {
    let provider: AIProvider
    let displayName: String
    let defaultModel: String
    let models: [String]
    var usesEndpointBoundKey: Bool = false
    var id: AIProvider { provider }
}

struct AIConfigurationStatus {
    let provider: AIProvider
    let model: String
    let hasAPIKey: Bool
    let maskedKey: String
    let supportsVision: Bool
}

protocol AIConfigurationService {
    var providerOptions: [AIProviderOption] { get }
    func status(for settings: UserSettings) throws -> AIConfigurationStatus
    func saveAPIKey(_ apiKey: String, provider: AIProvider) throws
    func readAPIKey(provider: AIProvider) throws -> String?
    func deleteAPIKey(provider: AIProvider) throws
    func maskedKey(for apiKey: String?) -> String
    func validateLocalConfiguration(settings: UserSettings) throws -> Bool
}

struct LocalAIConfigurationService: AIConfigurationService {
    let keychain: KeychainService

    init(keychain: KeychainService = AppKeychainService()) {
        self.keychain = keychain
    }

    var providerOptions: [AIProviderOption] {
        [
            AIProviderOption(provider: .claude, displayName: "Claude",
                             defaultModel: AIProvider.claude.defaultModel,
                             models: ["claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5"]),
            AIProviderOption(provider: .chatGPT, displayName: "ChatGPT",
                             defaultModel: AIProvider.chatGPT.defaultModel,
                             models: ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-5.4-nano", "gpt-5-mini", "gpt-5-nano", "gpt-5.2", "o4-mini", "gpt-4.1-mini", "gpt-4.1-nano"]),
            AIProviderOption(provider: .kimi, displayName: "Kimi",
                             defaultModel: AIProvider.kimi.defaultModel,
                             models: ["kimi-k2.6", "kimi-k2.5", "moonshot-v1-8k-vision-preview", "moonshot-v1-32k-vision-preview", "moonshot-v1-128k-vision-preview", "moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"]),
            AIProviderOption(provider: .qwen, displayName: "通义千问",
                             defaultModel: AIProvider.qwen.defaultModel,
                             models: ["qwen-vl-plus", "qwen-vl-max", "qwen3-vl", "qwen2.5-vl", "qwen-ocr", "qwen3.7-plus", "qwen3.7-max", "qwen3.6-flash"]),
            AIProviderOption(provider: .doubao, displayName: "豆包",
                             defaultModel: AIProvider.doubao.defaultModel,
                             models: ["doubao-1.6-vision", "doubao-seed-2-0-vision", "doubao-seed-2-1-pro-260628", "doubao-pro-32k", "doubao-lite-32k"],
                             usesEndpointBoundKey: true),
            AIProviderOption(provider: .yuanbao, displayName: "腾讯混元",
                             defaultModel: AIProvider.yuanbao.defaultModel,
                             models: ["hunyuan-vision-1.5-instruct", "hunyuan-t1-vision-20250916", "hunyuan-turbos-vision-video", "hunyuan-turbos-latest", "hunyuan-a13b"],
                             usesEndpointBoundKey: true),
            AIProviderOption(provider: .deepseek, displayName: "DeepSeek",
                             defaultModel: AIProvider.deepseek.defaultModel,
                             models: ["deepseek-v4-flash", "deepseek-v4-pro", "deepseek-chat", "deepseek-reasoner"]),
            AIProviderOption(provider: .mimo, displayName: "小米 MiMo",
                             defaultModel: AIProvider.mimo.defaultModel,
                             models: ["mimo-v2.5", "mimo-v2.5-pro"],
                             usesEndpointBoundKey: true),
        ]
    }

    func status(for settings: UserSettings) throws -> AIConfigurationStatus {
        let provider = settings.selectedAIProvider
        let apiKey = try readAPIKey(provider: provider)
        return AIConfigurationStatus(
            provider: provider,
            model: settings.selectedAIModel,
            hasAPIKey: apiKey?.isEmpty == false,
            maskedKey: maskedKey(for: apiKey),
            supportsVision: provider.supportsVision(model: settings.selectedAIModel)
        )
    }

    func saveAPIKey(_ apiKey: String, provider: AIProvider) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try deleteAPIKey(provider: provider)
        } else {
            try keychain.save(trimmed, account: keychainAccount(for: provider))
        }
    }

    func readAPIKey(provider: AIProvider) throws -> String? {
        try keychain.read(account: keychainAccount(for: provider))
    }

    func deleteAPIKey(provider: AIProvider) throws {
        try keychain.delete(account: keychainAccount(for: provider))
    }

    func maskedKey(for apiKey: String?) -> String {
        guard let apiKey, !apiKey.isEmpty else { return "未配置" }
        if apiKey.count <= 8 { return "••••" }
        return "\(apiKey.prefix(4))••••\(apiKey.suffix(4))"
    }

    func validateLocalConfiguration(settings: UserSettings) throws -> Bool {
        let provider = settings.selectedAIProvider
        guard let apiKey = try readAPIKey(provider: provider) else { return false }
        return apiKey.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
    }

    private func keychainAccount(for provider: AIProvider) -> String {
        "ai-api-key-\(provider.rawValue)"
    }
}
