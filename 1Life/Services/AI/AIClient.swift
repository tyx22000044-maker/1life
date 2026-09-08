import Foundation

enum AIRole: String, Codable {
    case system
    case user
    case assistant
}

struct AIClientMessage: Codable {
    let role: AIRole
    let content: String
}

struct AIClientRequest {
    let messages: [AIClientMessage]
    let model: String
    let apiKey: String
    let timeoutInterval: TimeInterval
    let temperature: Double?

    init(messages: [AIClientMessage],
         model: String,
         apiKey: String,
         timeoutInterval: TimeInterval = 30,
         temperature: Double? = nil) {
        self.messages = messages
        self.model = model
        self.apiKey = apiKey
        self.timeoutInterval = timeoutInterval
        self.temperature = temperature
    }
}

struct AIClientResponse {
    let text: String
    let rawPayload: String?
}

enum AIClientError: LocalizedError {
    case missingAPIKey
    case unsupportedProvider(AIProvider)
    case invalidResponse
    case providerError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "缺少 API Key"
        case .unsupportedProvider(let p): return "暂不支持的 AI 服务商：\(p.rawValue)"
        case .invalidResponse: return "AI 返回格式无效"
        case .providerError(let msg): return msg
        }
    }
}

protocol AIClient {
    var provider: AIProvider { get }
    func send(_ request: AIClientRequest) async throws -> AIClientResponse
}

// MARK: - Vision Extension (1Life specific)

struct AIImageAttachment {
    let data: Data
    let mediaType: String
}

struct AIVisionRequest {
    let messages: [AIClientMessage]
    let images: [AIImageAttachment]
    let model: String
    let apiKey: String
    let timeoutInterval: TimeInterval
    let temperature: Double?

    var image: AIImageAttachment { images[0] }

    init(messages: [AIClientMessage],
         image: AIImageAttachment,
         model: String,
         apiKey: String,
         timeoutInterval: TimeInterval = 45,
         temperature: Double? = nil) {
        self.init(
            messages: messages,
            images: [image],
            model: model,
            apiKey: apiKey,
            timeoutInterval: timeoutInterval,
            temperature: temperature
        )
    }

    init(messages: [AIClientMessage],
         images: [AIImageAttachment],
         model: String,
         apiKey: String,
         timeoutInterval: TimeInterval = 45,
         temperature: Double? = nil) {
        self.messages = messages
        self.images = Array(images.prefix(6))
        self.model = model
        self.apiKey = apiKey
        self.timeoutInterval = timeoutInterval
        self.temperature = temperature
    }
}

protocol AIVisionClient {
    var supportsVision: Bool { get }
    func sendWithImage(_ request: AIVisionRequest) async throws -> AIClientResponse
}
