import Foundation
import UIKit

protocol AIService {
    var provider: AIProvider { get }
    func sendMessage(_ text: String, history: [AIChatHistoryItem], context: AIDataContext?) async throws -> String
    func parseStructuredIntent(from text: String, history: [AIChatHistoryItem], context: AIDataContext?) async throws -> AIChatIntentResult?
    func recognizeMealPhoto(imageData: Data, text: String?, context: AIDataContext?) async throws -> AIChatIntentResult?
    func recognizeMealPhoto(imageDataList: [Data], text: String?, context: AIDataContext?) async throws -> AIChatIntentResult?
}

struct ConfiguredAIService: AIService {
    let settings: UserSettings
    let configurationService: AIConfigurationService
    let clientFactory: AIClientFactory

    var provider: AIProvider { settings.selectedAIProvider }

    init(settings: UserSettings,
         configurationService: AIConfigurationService = LocalAIConfigurationService(),
         clientFactory: AIClientFactory = AIClientFactory()) {
        self.settings = settings
        self.configurationService = configurationService
        self.clientFactory = clientFactory
    }

    func sendMessage(_ text: String, history: [AIChatHistoryItem], context: AIDataContext?) async throws -> String {
        let apiKey = try requireAPIKey()
        let client = clientFactory.client(for: provider)
        let request = AIClientRequest(
            messages: AIPromptBuilder.makeMessages(text: text, history: history, context: context),
            model: settings.selectedAIModel,
            apiKey: apiKey
        )
        return try await client.send(request).text
    }

    func parseStructuredIntent(from text: String, history: [AIChatHistoryItem], context: AIDataContext?) async throws -> AIChatIntentResult? {
        let apiKey = try requireAPIKey()
        let client = clientFactory.client(for: provider)
        let decoder = AIIntentDecoder()
        let planningRequest = AIClientRequest(
            messages: AIPromptBuilder.makeIntentPortionPlanningMessages(text: text, history: history, context: context),
            model: settings.selectedAIModel,
            apiKey: apiKey,
            temperature: 0.1
        )
        let planningResponse = try await client.send(planningRequest)
        guard let plannedResult = decoder.decode(from: planningResponse.text) else {
            return try await parseStructuredIntentOneShot(
                text: text,
                history: history,
                context: context,
                client: client,
                apiKey: apiKey,
                decoder: decoder
            )
        }

        guard Self.needsNutritionCompletion(plannedResult) else {
            return plannedResult
        }

        if let completed = try await completeNutrition(
            for: plannedResult,
            context: context,
            client: client,
            apiKey: apiKey,
            decoder: decoder
        ), !Self.needsNutritionCompletion(completed) {
            return completed
        }

        return try await parseStructuredIntentOneShot(
            text: text,
            history: history,
            context: context,
            client: client,
            apiKey: apiKey,
            decoder: decoder
        )
    }

    func recognizeMealPhoto(imageData: Data, text: String? = nil, context: AIDataContext?) async throws -> AIChatIntentResult? {
        try await recognizeMealPhoto(imageDataList: [imageData], text: text, context: context)
    }

    func recognizeMealPhoto(imageDataList: [Data], text: String? = nil, context: AIDataContext?) async throws -> AIChatIntentResult? {
        let apiKey = try requireAPIKey()
        guard provider.supportsVision(model: settings.selectedAIModel) else {
            throw AIClientError.providerError("当前模型不支持图片识别，请切换到支持视觉输入的模型。")
        }
        guard let visionClient = clientFactory.visionClient(for: provider) else {
            throw AIClientError.providerError("当前 AI 服务商不支持拍照识别")
        }
        let images = imageDataList.prefix(6).map {
            AIImageAttachment(data: prepareImageForVision($0), mediaType: "image/jpeg")
        }
        guard !images.isEmpty else { return nil }
        let prompt = AIPromptBuilder.makeFoodRecognitionPrompt()
        var userMessage = images.count == 1 ? "请识别这张照片中的食物。" : "请综合识别这 \(images.count) 张照片中的食物。"
        if let text, !text.isEmpty {
            userMessage = "\(text)\n请结合以上描述识别这些照片中的食物。"
        }
        let timeout = 45.0 + Double(images.count) * 30.0
        let request = AIVisionRequest(
            messages: [
                AIClientMessage(role: .system, content: prompt),
                AIClientMessage(role: .user, content: userMessage)
            ],
            images: images,
            model: settings.selectedAIModel,
            apiKey: apiKey,
            timeoutInterval: timeout,
            temperature: 0.1
        )
        let response = try await visionClient.sendWithImage(request)
        return AIIntentDecoder().decode(from: response.text)
    }

    private func prepareImageForVision(_ data: Data, maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        guard max(size.width, size.height) > maxDimension else {
            return image.jpegData(compressionQuality: quality) ?? data
        }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality) ?? data
    }

    private func requireAPIKey() throws -> String {
        guard let apiKey = try configurationService.readAPIKey(provider: provider),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.missingAPIKey
        }
        return apiKey
    }

    private func parseStructuredIntentOneShot(
        text: String,
        history: [AIChatHistoryItem],
        context: AIDataContext?,
        client: AIClient,
        apiKey: String,
        decoder: AIIntentDecoder
    ) async throws -> AIChatIntentResult? {
        let request = AIClientRequest(
            messages: AIPromptBuilder.makeIntentMessages(text: text, history: history, context: context),
            model: settings.selectedAIModel,
            apiKey: apiKey,
            temperature: 0.1
        )
        let response = try await client.send(request)
        return decoder.decode(from: response.text)
    }

    private func completeNutrition(
        for result: AIChatIntentResult,
        context: AIDataContext?,
        client: AIClient,
        apiKey: String,
        decoder: AIIntentDecoder
    ) async throws -> AIChatIntentResult? {
        if case .batch(let results) = result {
            var completedResults: [AIChatIntentResult] = []
            for child in results {
                if Self.needsNutritionCompletion(child),
                   let completed = try await completeNutrition(
                       for: child,
                       context: context,
                       client: client,
                       apiKey: apiKey,
                       decoder: decoder
                   ) {
                    completedResults.append(completed)
                } else {
                    completedResults.append(child)
                }
            }
            return .batch(completedResults)
        }

        guard let payload = AIIntentJSONPayloadBuilder.jsonString(from: result) else { return nil }
        let request = AIClientRequest(
            messages: AIPromptBuilder.makeNutritionCompletionMessages(portionPlanJSON: payload, context: context),
            model: settings.selectedAIModel,
            apiKey: apiKey,
            timeoutInterval: 45,
            temperature: 0.1
        )
        let response = try await client.send(request)
        return decoder.decode(from: response.text)
    }

    private static func needsNutritionCompletion(_ result: AIChatIntentResult) -> Bool {
        switch result {
        case .addMeal(let meal):
            return meal.items.contains { !$0.isRecordableNutritionEstimate }
        case .addMeals(let meals):
            return meals.contains { meal in meal.items.contains { !$0.isRecordableNutritionEstimate } }
        case .createTemplate(_, let meal):
            return meal.items.contains { !$0.isRecordableNutritionEstimate }
        case .batch(let results):
            return results.contains { Self.needsNutritionCompletion($0) }
        default:
            return false
        }
    }
}

nonisolated private enum AIIntentJSONPayloadBuilder {
    static func jsonString(from result: AIChatIntentResult) -> String? {
        guard let object = object(from: result),
              JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func object(from result: AIChatIntentResult) -> [String: Any]? {
        switch result {
        case .addMeal(let meal):
            return mealObject(meal, intent: "add_meal")
        case .addMeals(let meals):
            return ["intent": "add_meals", "meals": meals.map { mealObjectBody($0) }]
        case .createTemplate(let name, let meal):
            var object = mealObject(meal, intent: "create_template")
            object["template_name"] = name
            return object
        case .batch(let results):
            let actions = results.compactMap(object)
            return actions.isEmpty ? nil : ["intent": "batch", "actions": actions]
        default:
            return nil
        }
    }

    private static func mealObject(_ meal: AIParsedMeal, intent: String) -> [String: Any] {
        var object = mealObjectBody(meal)
        object["intent"] = intent
        return object
    }

    private static func mealObjectBody(_ meal: AIParsedMeal) -> [String: Any] {
        [
            "meal_type": meal.mealType.rawValue,
            "items": meal.items.map(foodItemObject),
            "note": meal.note
        ]
    }

    private static func foodItemObject(_ item: AIParsedFoodItem) -> [String: Any] {
        var object: [String: Any] = [
            "name": item.name,
            "amount": item.amount,
            "unit": item.unit,
            "calories": item.calories,
            "nutrition_data_basis": item.nutritionDataBasis.rawValue
        ]
        put(item.protein, key: "protein", into: &object)
        put(item.carbs, key: "carbs", into: &object)
        put(item.fat, key: "fat", into: &object)
        put(item.fiber, key: "fiber", into: &object)
        put(item.sodium, key: "sodium", into: &object)
        put(item.sugar, key: "sugar", into: &object)
        put(item.cholesterol, key: "cholesterol", into: &object)
        put(item.caffeine, key: "caffeine", into: &object)
        put(item.teaPolyphenols, key: "tea_polyphenols", into: &object)
        put(item.calcium, key: "calcium", into: &object)
        put(item.magnesium, key: "magnesium", into: &object)
        put(item.potassium, key: "potassium", into: &object)
        put(item.iron, key: "iron", into: &object)
        put(item.zinc, key: "zinc", into: &object)
        put(item.vitaminA, key: "vitamin_a", into: &object)
        put(item.vitaminC, key: "vitamin_c", into: &object)
        put(item.vitaminD, key: "vitamin_d", into: &object)
        put(item.vitaminE, key: "vitamin_e", into: &object)
        put(item.vitaminB1, key: "vitamin_b1", into: &object)
        put(item.vitaminB2, key: "vitamin_b2", into: &object)
        put(item.niacin, key: "niacin", into: &object)
        put(item.vitaminB6, key: "vitamin_b6", into: &object)
        put(item.folate, key: "folate", into: &object)
        put(item.vitaminB12, key: "vitamin_b12", into: &object)
        put(item.amountMin, key: "amount_min", into: &object)
        put(item.amountMax, key: "amount_max", into: &object)
        put(item.caloriesMin, key: "calories_min", into: &object)
        put(item.caloriesMax, key: "calories_max", into: &object)
        put(item.labelBaseAmount, key: "label_base_amount", into: &object)
        put(item.labelBaseUnit, key: "label_base_unit", into: &object)
        put(item.packageNetAmount, key: "package_net_amount", into: &object)
        put(item.packageNetUnit, key: "package_net_unit", into: &object)
        put(item.consumedAmount, key: "consumed_amount", into: &object)
        put(item.consumedUnit, key: "consumed_unit", into: &object)
        put(item.nutritionDataNote, key: "nutrition_data_note", into: &object)
        put(item.confidence, key: "confidence", into: &object)
        return object
    }

    private static func put(_ value: Double?, key: String, into object: inout [String: Any]) {
        if let value { object[key] = value }
    }

    private static func put(_ value: String?, key: String, into object: inout [String: Any]) {
        if let value, !value.isEmpty { object[key] = value }
    }
}

struct DemoAIService: AIService {
    let provider: AIProvider = .claude

    func sendMessage(_ text: String, history: [AIChatHistoryItem], context: AIDataContext?) async throws -> String {
        "AI 营养助手已就绪。配置 API Key 后，可以拍照识别食物、记录饮食和分析营养。"
    }

    func parseStructuredIntent(from text: String, history: [AIChatHistoryItem], context: AIDataContext?) async throws -> AIChatIntentResult? { nil }
    func recognizeMealPhoto(imageData: Data, text: String?, context: AIDataContext?) async throws -> AIChatIntentResult? { nil }
    func recognizeMealPhoto(imageDataList: [Data], text: String?, context: AIDataContext?) async throws -> AIChatIntentResult? { nil }
}
