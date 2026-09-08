import Foundation

// MARK: - Claude

struct ClaudeClient: AIClient, AIVisionClient {
    let provider: AIProvider = .claude
    var supportsVision: Bool { true }

    func send(_ request: AIClientRequest) async throws -> AIClientResponse {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIClientError.invalidResponse
        }
        let systemContent = request.messages.first(where: { $0.role == .system })?.content
        let conversation = request.messages.filter { $0.role != .system }

        let body = ClaudeRequestBody(
            model: request.model, maxTokens: 1024, system: systemContent,
            messages: conversation.map { ClaudeMessage(role: $0.role.rawValue, content: .text($0.content)) },
            temperature: request.temperature
        )
        return try await executeClaudeRequest(url: url, body: body, apiKey: request.apiKey, timeout: request.timeoutInterval)
    }

    func sendWithImage(_ request: AIVisionRequest) async throws -> AIClientResponse {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIClientError.invalidResponse
        }
        let systemContent = request.messages.first(where: { $0.role == .system })?.content
        let imageBlocks = request.images.map { image in
            ClaudeContentBlock(type: "image", source: ClaudeImageSource(
                type: "base64", mediaType: image.mediaType, data: image.data.base64EncodedString()
            ), text: nil)
        }
        let textContent = request.messages.last(where: { $0.role == .user })?.content ?? ""
        let textBlock = ClaudeContentBlock(type: "text", source: nil, text: textContent)

        let body = ClaudeRequestBody(
            model: request.model, maxTokens: 1024, system: systemContent,
            messages: [ClaudeMessage(role: "user", content: .blocks(imageBlocks + [textBlock]))],
            temperature: request.temperature
        )
        return try await executeClaudeRequest(url: url, body: body, apiKey: request.apiKey, timeout: request.timeoutInterval)
    }

    private func executeClaudeRequest(url: URL, body: ClaudeRequestBody, apiKey: String, timeout: TimeInterval) async throws -> AIClientResponse {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.timeoutInterval = timeout
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw AIClientError.invalidResponse }
        let raw = String(data: data, encoding: .utf8)
        guard (200..<300).contains(http.statusCode) else {
            let err = try? JSONDecoder().decode(ClaudeErrorBody.self, from: data)
            throw AIClientError.providerError(err?.error.message ?? "Claude 请求失败（\(http.statusCode)）")
        }
        let decoded = try JSONDecoder().decode(ClaudeResponseBody.self, from: data)
        let text = decoded.content.compactMap(\.text).joined()
        guard !text.isEmpty else { throw AIClientError.invalidResponse }
        return AIClientResponse(text: text, rawPayload: raw)
    }
}

private struct ClaudeRequestBody: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [ClaudeMessage]
    let temperature: Double?
    enum CodingKeys: String, CodingKey {
        case model, system, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct ClaudeMessage: Encodable {
    let role: String
    let content: ClaudeContent
}

private enum ClaudeContent: Encodable {
    case text(String)
    case blocks([ClaudeContentBlock])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s): try container.encode(s)
        case .blocks(let b): try container.encode(b)
        }
    }
}

private struct ClaudeContentBlock: Encodable {
    let type: String
    let source: ClaudeImageSource?
    let text: String?
}

private struct ClaudeImageSource: Encodable {
    let type: String
    let mediaType: String
    let data: String
    enum CodingKeys: String, CodingKey {
        case type, data
        case mediaType = "media_type"
    }
}

private struct ClaudeResponseBody: Decodable {
    struct Block: Decodable { let type: String; let text: String? }
    let content: [Block]
}

private struct ClaudeErrorBody: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}

// MARK: - OpenAI

struct OpenAIClient: AIClient, AIVisionClient {
    let provider: AIProvider = .chatGPT
    var supportsVision: Bool { true }

    func send(_ request: AIClientRequest) async throws -> AIClientResponse {
        let text = try await sendOpenAI(request: request, imageURLs: [])
        return AIClientResponse(text: text, rawPayload: nil)
    }

    func sendWithImage(_ request: AIVisionRequest) async throws -> AIClientResponse {
        let textRequest = AIClientRequest(
            messages: request.messages,
            model: request.model,
            apiKey: request.apiKey,
            timeoutInterval: request.timeoutInterval,
            temperature: request.temperature
        )
        let imageURLs = request.images.map { image in
            "data:\(image.mediaType);base64,\(image.data.base64EncodedString())"
        }
        let text = try await sendOpenAI(request: textRequest, imageURLs: imageURLs)
        return AIClientResponse(text: text, rawPayload: nil)
    }

    private func sendOpenAI(request: AIClientRequest, imageURLs: [String]) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIClientError.invalidResponse
        }
        var messages: [[String: Any]] = request.messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        if !imageURLs.isEmpty {
            let lastUser = messages.lastIndex(where: { $0["role"] as? String == "user" })
            if let idx = lastUser {
                let text = messages[idx]["content"] as? String ?? ""
                let imageBlocks: [[String: Any]] = imageURLs.map { imageURL in
                    ["type": "image_url", "image_url": ["url": imageURL]]
                }
                messages[idx]["content"] = (imageBlocks + [["type": "text", "text": text]]) as Any
            }
        }
        var body: [String: Any] = ["model": request.model, "messages": messages]
        if let temperature = request.temperature {
            body["temperature"] = temperature
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(request.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = request.timeoutInterval
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AIClientError.providerError("OpenAI 请求失败")
        }
        let decoded = try JSONDecoder().decode(CCResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw AIClientError.invalidResponse
        }
        return text
    }
}

// MARK: - OpenAI-compatible helper

private func sendChatCompletion(baseURL: String, request: AIClientRequest) async throws -> String {
    guard let url = URL(string: baseURL) else { throw AIClientError.invalidResponse }
    let body = CCBody(model: request.model,
                      messages: request.messages.map { CCMsg(role: $0.role.rawValue, content: $0.content) },
                      temperature: request.temperature)
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("Bearer \(request.apiKey)", forHTTPHeaderField: "Authorization")
    urlRequest.timeoutInterval = request.timeoutInterval
    urlRequest.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        let err = try? JSONDecoder().decode(CCError.self, from: data)
        throw AIClientError.providerError(err?.error.message ?? "请求失败")
    }
    let decoded = try JSONDecoder().decode(CCResponse.self, from: data)
    guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
        throw AIClientError.invalidResponse
    }
    return text
}

private func sendOpenAICompatibleMultimodal(baseURL: String, request: AIVisionRequest) async throws -> String {
    guard let url = URL(string: baseURL) else { throw AIClientError.invalidResponse }
    let textContent = request.messages.last(where: { $0.role == .user })?.content ?? ""
    let imageBlocks: [[String: Any]] = request.images.map { image in
        [
            "type": "image_url",
            "image_url": ["url": "data:\(image.mediaType);base64,\(image.data.base64EncodedString())"]
        ]
    }

    let messages: [[String: Any]] = request.messages.map { message in
        if message.role == .user {
            return [
                "role": message.role.rawValue,
                "content": [["type": "text", "text": textContent]] + imageBlocks
            ]
        }
        return ["role": message.role.rawValue, "content": message.content]
    }

    var body: [String: Any] = [
        "model": request.model,
        "messages": messages
    ]
    if let temperature = request.temperature {
        body["temperature"] = temperature
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("Bearer \(request.apiKey)", forHTTPHeaderField: "Authorization")
    urlRequest.timeoutInterval = request.timeoutInterval
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        let err = try? JSONDecoder().decode(CCError.self, from: data)
        throw AIClientError.providerError(err?.error.message ?? "多模态请求失败")
    }
    let decoded = try JSONDecoder().decode(CCResponse.self, from: data)
    guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
        throw AIClientError.invalidResponse
    }
    return text
}

private struct CCBody: Encodable { let model: String; let messages: [CCMsg]; let temperature: Double? }
private struct CCMsg: Encodable { let role: String; let content: String }
private struct CCResponse: Decodable {
    struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
    let choices: [Choice]
}
private struct CCError: Decodable {
    struct Body: Decodable { let message: String }
    let error: Body
}

// MARK: - Kimi

struct KimiClient: AIClient, AIVisionClient {
    let provider: AIProvider = .kimi
    var supportsVision: Bool { true }

    func send(_ request: AIClientRequest) async throws -> AIClientResponse {
        AIClientResponse(text: try await sendChatCompletion(baseURL: "https://api.moonshot.cn/v1/chat/completions", request: request), rawPayload: nil)
    }

    func sendWithImage(_ request: AIVisionRequest) async throws -> AIClientResponse {
        AIClientResponse(text: try await sendOpenAICompatibleMultimodal(baseURL: "https://api.moonshot.cn/v1/chat/completions", request: request), rawPayload: nil)
    }
}

// MARK: - 通义千问

struct QwenClient: AIClient, AIVisionClient {
    let provider: AIProvider = .qwen
    var supportsVision: Bool { true }

    func send(_ request: AIClientRequest) async throws -> AIClientResponse {
        AIClientResponse(text: try await sendChatCompletion(baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", request: request), rawPayload: nil)
    }

    func sendWithImage(_ request: AIVisionRequest) async throws -> AIClientResponse {
        AIClientResponse(text: try await sendOpenAICompatibleMultimodal(baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", request: request), rawPayload: nil)
    }
}

// MARK: - 豆包

struct DoubaoClient: AIClient, AIVisionClient {
    let provider: AIProvider = .doubao
    var supportsVision: Bool { true }

    func send(_ request: AIClientRequest) async throws -> AIClientResponse {
        AIClientResponse(text: try await sendChatCompletion(baseURL: "https://ark.cn-beijing.volces.com/api/v3/chat/completions", request: request), rawPayload: nil)
    }

    func sendWithImage(_ request: AIVisionRequest) async throws -> AIClientResponse {
        AIClientResponse(text: try await sendOpenAICompatibleMultimodal(baseURL: "https://ark.cn-beijing.volces.com/api/v3/chat/completions", request: request), rawPayload: nil)
    }
}

// MARK: - 腾讯混元

struct YuanbaoClient: AIClient, AIVisionClient {
    let provider: AIProvider = .yuanbao
    var supportsVision: Bool { true }

    func send(_ request: AIClientRequest) async throws -> AIClientResponse {
        AIClientResponse(text: try await sendChatCompletion(baseURL: "https://api.hunyuan.cloud.tencent.com/v1/chat/completions", request: request), rawPayload: nil)
    }

    func sendWithImage(_ request: AIVisionRequest) async throws -> AIClientResponse {
        AIClientResponse(text: try await sendOpenAICompatibleMultimodal(baseURL: "https://api.hunyuan.cloud.tencent.com/v1/chat/completions", request: request), rawPayload: nil)
    }
}

// MARK: - DeepSeek

struct DeepSeekClient: AIClient {
    let provider: AIProvider = .deepseek
    func send(_ request: AIClientRequest) async throws -> AIClientResponse {
        AIClientResponse(text: try await sendChatCompletion(baseURL: "https://api.deepseek.com/v1/chat/completions", request: request), rawPayload: nil)
    }
}

// MARK: - 小米 MiMo

struct MiMoClient: AIClient, AIVisionClient {
    let provider: AIProvider = .mimo
    var supportsVision: Bool { true }

    private func baseURL(for apiKey: String) -> String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("sk-")
            ? "https://api.xiaomimimo.com/v1/chat/completions"
            : "https://token-plan-cn.xiaomimimo.com/v1/chat/completions"
    }

    func send(_ request: AIClientRequest) async throws -> AIClientResponse {
        AIClientResponse(text: try await sendChatCompletion(baseURL: baseURL(for: request.apiKey), request: request), rawPayload: nil)
    }

    func sendWithImage(_ request: AIVisionRequest) async throws -> AIClientResponse {
        AIClientResponse(text: try await sendOpenAICompatibleMultimodal(baseURL: baseURL(for: request.apiKey), request: request), rawPayload: nil)
    }
}

// MARK: - Factory

struct AIClientFactory {
    func client(for provider: AIProvider) -> AIClient {
        switch provider {
        case .claude: return ClaudeClient()
        case .chatGPT: return OpenAIClient()
        case .kimi: return KimiClient()
        case .qwen: return QwenClient()
        case .doubao: return DoubaoClient()
        case .yuanbao: return YuanbaoClient()
        case .deepseek: return DeepSeekClient()
        case .mimo: return MiMoClient()
        }
    }

    func visionClient(for provider: AIProvider) -> AIVisionClient? {
        let c = client(for: provider)
        return (c as? AIVisionClient)?.supportsVision == true ? c as? AIVisionClient : nil
    }
}
