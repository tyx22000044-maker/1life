import Foundation
import SwiftData

@Model
nonisolated final class AIChatMessage {
    var id: UUID
    var role: String
    var content: String
    var providerRaw: String
    var toolName: String?
    var toolPayloadJSON: String?
    var createdMealID: UUID?
    var isLinkedDataDeleted: Bool
    var createdAt: Date

    init(role: String,
         content: String,
         provider: AIProvider = .claude,
         toolName: String? = nil,
         toolPayloadJSON: String? = nil,
         createdMealID: UUID? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.providerRaw = provider.rawValue
        self.toolName = toolName
        self.toolPayloadJSON = toolPayloadJSON
        self.createdMealID = createdMealID
        self.isLinkedDataDeleted = false
        self.createdAt = .now
    }

    var provider: AIProvider {
        AIProvider(rawValue: providerRaw) ?? .claude
    }

    var decodedBubblePayload: AIChatBubblePayload? {
        guard let json = toolPayloadJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AIChatBubblePayload.self, from: data)
    }
}
