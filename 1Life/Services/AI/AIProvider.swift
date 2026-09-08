import Foundation

enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case claude, chatGPT, kimi, qwen, doubao, yuanbao, deepseek, mimo
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .chatGPT: return "ChatGPT"
        case .kimi: return "Kimi"
        case .qwen: return "通义千问"
        case .doubao: return "豆包"
        case .yuanbao: return "腾讯混元"
        case .deepseek: return "DeepSeek"
        case .mimo: return "小米 MiMo"
        }
    }
    var supportsVision: Bool { self != .deepseek }
    func supportsVision(model: String) -> Bool {
        let normalized = model.lowercased()
        switch self {
        case .claude: return normalized.contains("claude") || normalized.contains("sonnet") || normalized.contains("opus") || normalized.contains("haiku")
        case .chatGPT: return normalized.contains("gpt-5") || normalized.contains("gpt-4.1") || normalized.contains("gpt-4o") || normalized.contains("o4")
        case .kimi: return normalized.contains("vision") || normalized == "kimi-k2.5" || normalized == "kimi-k2.6"
        case .qwen: return normalized.contains("vl") || normalized.contains("qvq") || normalized.contains("ocr")
        case .doubao: return normalized.contains("vision") || normalized.contains("visual") || normalized.contains("multimodal") || normalized.contains("doubao-1.6") || normalized.contains("seed-2-0-vision")
        case .yuanbao: return normalized.contains("vision") || normalized.contains("t1-vision") || normalized.contains("turbos-vision")
        case .mimo: return normalized == "mimo-v2.5"
        case .deepseek: return false
        }
    }
    var defaultModel: String {
        switch self {
        case .claude: return "claude-sonnet-4-6"
        case .chatGPT: return "gpt-5.5"
        case .kimi: return "kimi-k2.6"
        case .qwen: return "qwen-vl-plus"
        case .doubao: return "doubao-1.6-vision"
        case .yuanbao: return "hunyuan-vision-1.5-instruct"
        case .deepseek: return "deepseek-v4-flash"
        case .mimo: return "mimo-v2.5"
        }
    }
    var isEndpointBound: Bool { [.kimi, .qwen, .doubao, .yuanbao, .mimo].contains(self) }
}
