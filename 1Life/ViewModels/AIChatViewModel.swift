import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class AIChatViewModel {
    var messages: [AIChatMessage] = []
    var inputText = ""
    var isLoading = false
    var errorMessage: String?
    var pendingConfirmation: MealIdentificationConfirmation?
    /// Every meal awaiting user confirmation — one for 单餐, N for `add_meals`/`batch`.
    /// Confirmation, cancellation and manual editing all read and write this list, so a
    /// multi-meal result can no longer be recorded as only its first entry.
    var pendingMeals: [AIParsedMeal] = []

    var pendingMealForEditing: AIParsedMeal? { pendingMeals.first }

    private var modelContext: ModelContext?
    private var settings: UserSettings?
    private var lastInputText: String = ""
    private var lastPhotoInputText: String?
    private var lastPhotoImageDataList: [Data] = []
    private var stableMealResultCache: [String: AIChatIntentResult] = [:]

    func configure(modelContext: ModelContext, settings: UserSettings) {
        self.modelContext = modelContext
        self.settings = settings
    }

    func loadMessages(from stored: [AIChatMessage]) {
        messages = stored.sorted { $0.createdAt < $1.createdAt }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let settings, let modelContext else { return }
        inputText = ""
        lastInputText = text
        lastPhotoInputText = nil
        lastPhotoImageDataList = []
        isLoading = true
        errorMessage = nil

        let historyForThisTurn = chatHistory()
        let userMsg = AIChatMessage(role: "user", content: text, provider: settings.selectedAIProvider)
        modelContext.insert(userMsg)
        messages.append(userMsg)
        persist(reason: "send AI message")

        if isModelIdentityQuestion(text) {
            appendAssistant(
                "本次请求实际使用的模型是：\(settings.selectedAIModel)。服务商：\(settings.selectedAIProvider.displayName)。模型自身无法可靠读取或证明自己的后端身份，因此这里以 App 实际发送请求时使用的配置为准。",
                provider: settings.selectedAIProvider
            )
            isLoading = false
            return
        }

        do {
            // 1. 本地解析
            let userFoods = fetchUserFoods()
            let mealTemplates = fetchMealTemplates()
            let localParser = LocalAIIntentParser(userFoods: userFoods, mealTemplates: mealTemplates)
            if let localResult = localParser.parse(text) {
                let libraryAwareResult = AIChatSupplementLibraryResolver.applyMatch(
                    to: AIChatDrinkLibraryResolver.applyMatch(
                        to: localResult,
                        originalText: text,
                        modelContext: modelContext
                    ),
                    originalText: text,
                    modelContext: modelContext
                )
                if case .addMeal(let meal) = libraryAwareResult {
                    let hasUnmatched = meal.items.contains { $0.calories == 0 }
                    if hasUnmatched {
                        if settings.isAIConfigured {
                            if let aiResult = try await aiParseMeal(text: text, settings: settings, history: historyForThisTurn) {
                                let validated = validatedMealIntent(aiResult, localResult: libraryAwareResult)
                                beginMealReview(validated, originalText: text, isLocal: false)
                            } else {
                                let matched = meal.items.filter { $0.calories > 0 }
                                if matched.isEmpty {
                                    appendAssistant("AI 无法识别这些食物的营养数据，请手动在饮食页添加。", provider: settings.selectedAIProvider)
                                } else {
                                    let partialMeal = AIParsedMeal(mealType: meal.mealType, items: matched, note: meal.note)
                                    let unmatched = meal.items.filter { $0.calories == 0 }.map(\.name).joined(separator: "、")
                                    appendAssistant("「\(unmatched)」未能识别，已忽略。", provider: settings.selectedAIProvider)
                                    beginMealReview(.addMeal(partialMeal), originalText: text, isLocal: true)
                                }
                            }
                        } else {
                            let matched = meal.items.filter { $0.calories > 0 }
                            if matched.isEmpty {
                                appendAssistant("需要配置 AI 才能自动识别热量，或在饮食页手动添加。", provider: settings.selectedAIProvider)
                            } else {
                                let partialMeal = AIParsedMeal(mealType: meal.mealType, items: matched, note: meal.note)
                                let unmatched = meal.items.filter { $0.calories == 0 }.map(\.name).joined(separator: "、")
                                appendAssistant("「\(unmatched)」不在我的食物库中，需配置 AI 或手动添加。", provider: settings.selectedAIProvider)
                                beginMealReview(.addMeal(partialMeal), originalText: text, isLocal: true)
                            }
                        }
                    } else {
                        beginMealReview(libraryAwareResult, originalText: text, isLocal: true)
                    }
                } else {
                    if case .addWater = localResult,
                       let drinkMeal = AIChatDrinkLibraryResolver.makeMealIntent(originalText: text, modelContext: modelContext) {
                        beginMealReview(drinkMeal, originalText: text, isLocal: true)
                        isLoading = false
                        return
                    }
                    handleIntentResult(libraryAwareResult, provider: settings.selectedAIProvider)
                }
                isLoading = false
                return
            }

            if AIChatDrinkLibraryResolver.shouldPreferLibraryOnlyIntent(originalText: text),
               let drinkMeal = AIChatDrinkLibraryResolver.makeMealIntent(originalText: text, modelContext: modelContext) {
                beginMealReview(drinkMeal, originalText: text, isLocal: true)
                isLoading = false
                return
            }

            // 2. AI 解析
            guard settings.isAIConfigured else {
                appendAssistant("请先在设置中配置 AI 服务商和 API Key。", provider: settings.selectedAIProvider)
                isLoading = false
                return
            }

            let service = ConfiguredAIService(settings: settings)
            let context = await buildDataContext()

            if let intentResult = try await parseStructuredIntentWithStableMealCache(
                service: service,
                text: text,
                history: historyForThisTurn,
                context: context,
                settings: settings
            ) {
                if intentResult.isMealResult {
                    beginMealReview(validatedMealIntent(intentResult, localResult: nil), originalText: text, isLocal: false)
                } else if case .chat = intentResult {
                    let reply = try await service.sendMessage(text, history: historyForThisTurn, context: context)
                    appendAssistant(reply, provider: settings.selectedAIProvider)
                } else {
                    handleIntentResult(intentResult, provider: settings.selectedAIProvider)
                }
            } else {
                let reply = try await service.sendMessage(text, history: historyForThisTurn, context: context)
                appendAssistant(reply, provider: settings.selectedAIProvider)
            }
        } catch {
            errorMessage = error.localizedDescription
            appendAssistant("请求失败：\(error.localizedDescription)", provider: settings.selectedAIProvider)
        }

        isLoading = false
    }

    private func isModelIdentityQuestion(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: "？", with: "?")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let markers = [
            "你是什么模型", "你现在是什么模型", "你用的是什么模型", "你现在使用的模型",
            "当前用的是什么模型", "现在用的是哪个模型", "现在使用什么模型",
            "当前使用的模型", "当前模型是什么", "使用的模型", "模型名称是什么",
            "what model are you", "which model are you", "what model do you use",
            "what model is this"
        ]
        return markers.contains { normalized.contains($0) }
    }

    private func aiParseMeal(text: String, settings: UserSettings, history: [AIChatHistoryItem]) async throws -> AIChatIntentResult? {
        let service = ConfiguredAIService(settings: settings)
        let context = await buildDataContext()
        return try await parseStructuredIntentWithStableMealCache(
            service: service,
            text: text,
            history: history,
            context: context,
            settings: settings
        )
    }

    private func parseStructuredIntentWithStableMealCache(
        service: ConfiguredAIService,
        text: String,
        history: [AIChatHistoryItem],
        context: AIDataContext?,
        settings: UserSettings
    ) async throws -> AIChatIntentResult? {
        let key = stableMealCacheKey(text: text, settings: settings)
        if let cached = stableMealResultCache[key] {
            return cached
        }

        guard let result = try await service.parseStructuredIntent(from: text, history: history, context: context) else {
            return nil
        }
        let libraryAwareResult = AIChatSupplementLibraryResolver.applyMatch(
            to: AIChatDrinkLibraryResolver.applyMatch(
                to: result,
                originalText: text,
                modelContext: modelContext
            ),
            originalText: text,
            modelContext: modelContext
        )
        if libraryAwareResult.isMealResult {
            stableMealResultCache[key] = libraryAwareResult
        }
        return libraryAwareResult
    }

    private func stableMealCacheKey(text: String, settings: UserSettings) -> String {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let day = Date.now.formatted(.iso8601.year().month().day())
        return "\(settings.selectedAIProvider.rawValue)|\(settings.selectedAIModel)|\(day)|\(normalized)"
    }

    private func validatedMealIntent(_ aiResult: AIChatIntentResult, localResult: AIChatIntentResult?) -> AIChatIntentResult {
        switch aiResult {
        case .addMeal(let meal):
            return .addMeal(AIChatMealValidation.applySanityReview(to: meal))
        case .addMeals(let meals):
            return .addMeals(meals.map { AIChatMealValidation.applySanityReview(to: $0) })
        default:
            return aiResult
        }
    }

    /// Presents the review card for one or many parsed meals.
    func beginMealReview(_ result: AIChatIntentResult, originalText: String, isLocal: Bool) {
        let meals: [AIParsedMeal]
        switch result {
        case .addMeal(let meal):
            meals = [meal]
        case .addMeals(let parsedMeals):
            meals = parsedMeals
        default:
            return
        }
        guard !meals.isEmpty else { return }
        pendingMeals = meals
        pendingConfirmation = MealIdentificationConfirmation(
            originalText: originalText,
            identificationType: meals.count == 1 ? .meal(meals[0]) : .meals(meals),
            isFromLocalParser: isLocal
        )
    }

    func reidentifyWithAI() async {
        guard let settings, settings.isAIConfigured else { return }
        clearPendingMealReview()
        isLoading = true

        do {
            let service = ConfiguredAIService(settings: settings)
            let context = await buildDataContext()
            if !lastPhotoImageDataList.isEmpty {
                let displayContent: String
                if let lastPhotoInputText, !lastPhotoInputText.isEmpty {
                    displayContent = "\(lastPhotoInputText)\n[照片 x\(lastPhotoImageDataList.count)]"
                } else {
                    displayContent = "[照片 x\(lastPhotoImageDataList.count)]"
                }

                if let result = try await service.recognizeMealPhoto(
                    imageDataList: lastPhotoImageDataList,
                    text: lastPhotoInputText,
                    context: context
                ) {
                    let normalizedResult = AIChatMealValidation.normalizePhotoMealResult(result)
                    if normalizedResult.isMealResult {
                        let validated = validatedMealIntent(normalizedResult, localResult: nil)
                        beginMealReview(validated, originalText: displayContent, isLocal: false)
                    } else {
                        handleIntentResult(normalizedResult, provider: settings.selectedAIProvider)
                    }
                } else {
                    appendAssistant("无法重新识别这些照片中的食物，请尝试补充文字描述。", provider: settings.selectedAIProvider)
                }
            } else if let result = try await service.parseStructuredIntent(from: lastInputText, history: chatHistory(), context: context) {
                let validated = validatedMealIntent(result, localResult: nil)
                beginMealReview(validated, originalText: lastInputText, isLocal: false)
            } else {
                let reply = try await service.sendMessage(lastInputText, history: chatHistory(), context: context)
                appendAssistant(reply, provider: settings.selectedAIProvider)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func undoMeal(message: AIChatMessage) {
        guard let modelContext, let mealID = message.createdMealID else { return }
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate { $0.id == mealID })
        if let meal = try? modelContext.fetch(descriptor).first {
            (meal.foodItems ?? []).forEach { modelContext.delete($0) }
            modelContext.delete(meal)
        }
        if var payload = message.decodedBubblePayload {
            payload.isRevoked = true
            message.toolPayloadJSON = (try? String(data: JSONEncoder().encode(payload), encoding: .utf8))
        }
        HapticEngine.warning()
    }

    func sendPhoto(imageData: Data, text: String? = nil) async {
        await sendPhotos(imageDataList: [imageData], text: text)
    }

    func sendPhotos(imageDataList: [Data], text: String? = nil) async {
        guard let settings, let modelContext else { return }
        let images = Array(imageDataList.prefix(6))
        guard !images.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        let displayContent: String
        if let text, !text.isEmpty {
            displayContent = "\(text)\n[照片 x\(images.count)]"
        } else {
            displayContent = "[照片 x\(images.count)]"
        }
        lastInputText = text ?? ""
        lastPhotoInputText = text
        lastPhotoImageDataList = images

        let userMsg = AIChatMessage(role: "user", content: displayContent, provider: settings.selectedAIProvider)
        modelContext.insert(userMsg)
        messages.append(userMsg)
        persist(reason: "send AI photo")

        guard settings.isAIConfigured else {
            appendAssistant("请先在设置中配置 AI 服务商。", provider: settings.selectedAIProvider)
            isLoading = false
            return
        }

        do {
            let service = ConfiguredAIService(settings: settings)
            let context = await buildDataContext()
            if let result = try await service.recognizeMealPhoto(imageDataList: images, text: text, context: context) {
                let normalizedResult = AIChatMealValidation.normalizePhotoMealResult(result)
                if normalizedResult.isMealResult {
                    let validated = validatedMealIntent(normalizedResult, localResult: nil)
                    beginMealReview(validated, originalText: displayContent, isLocal: false)
                } else {
                    handleIntentResult(normalizedResult, provider: settings.selectedAIProvider)
                }
            } else {
                appendAssistant("无法识别照片中的食物，请手动描述。", provider: settings.selectedAIProvider)
            }
        } catch {
            errorMessage = error.localizedDescription
            appendAssistant("识别失败：\(error.localizedDescription)", provider: settings.selectedAIProvider)
        }

        isLoading = false
    }

    func confirmPendingMeals() {
        guard let modelContext, !pendingMeals.isEmpty else { return }
        if let blocked = pendingMeals.first(where: { $0.items.contains(where: \.isLazyNutritionEstimate) }) {
            HapticEngine.warning()
            appendAssistant(missingNutritionMessage(for: blocked), provider: settings?.selectedAIProvider ?? .claude)
            return
        }

        let mealDate = mealDateForPendingConfirmation()
        let provider = settings?.selectedAIProvider ?? .claude
        for parsed in pendingMeals {
            let toolMsg = AIChatMealRecorder.record(
                parsed: parsed,
                mealDate: mealDate,
                provider: provider,
                modelContext: modelContext
            )
            messages.append(toolMsg)
        }
        persist(reason: "confirm AI meal")
        clearPendingMealReview()
        HapticEngine.success()
    }

    private func missingNutritionMessage(for parsed: AIParsedMeal) -> String {
        let missing = parsed.items
            .filter(\.isLazyNutritionEstimate)
            .map { item in
                let fields = item.missingCoreNutrientKeys.map(\.displayName).joined(separator: "、")
                return "\(item.name)：\(fields.isEmpty ? "热量" : fields)"
            }
            .joined(separator: "；")
        return "这次识别缺少关键营养字段：\(missing)。请手动编辑后再保存。"
    }

    private func clearPendingMealReview() {
        pendingConfirmation = nil
        pendingMeals = []
    }

    func saveAsTemplate(_ parsed: AIParsedMeal, name: String) {
        guard let modelContext else { return }
        let items = parsed.items.map(AIParsedMealPersistenceMapper.templateFoodItem)
        let template = MealTemplate(name: name, mealType: parsed.mealType, foodItems: items)
        modelContext.insert(template)
        HapticEngine.success()
    }

    func cancelMeal() {
        clearPendingMealReview()
    }

    func applyManualMealEdit(_ meal: AIParsedMeal) {
        if pendingMeals.isEmpty {
            pendingMeals = [meal]
        } else {
            pendingMeals[0] = meal
        }
        pendingConfirmation = MealIdentificationConfirmation(
            originalText: pendingConfirmation?.originalText ?? lastInputText,
            identificationType: pendingMeals.count == 1 ? .meal(meal) : .meals(pendingMeals),
            isFromLocalParser: pendingConfirmation?.isFromLocalParser ?? true
        )
    }

    // MARK: - Private

    private func handleIntentResult(_ result: AIChatIntentResult, provider: AIProvider) {
        switch result {
        case .addMeal, .addMeals:
            beginMealReview(result, originalText: lastInputText, isLocal: false)
        case .createTemplate(let name, let meal):
            createTemplateFromIntent(name: name, meal: meal, provider: provider)
        case .addWater(let amount):
            guard let modelContext else { return }
            let recorded = AIChatIntentRecorder.recordWater(amount: amount, date: recordDateForCurrentInput(), modelContext: modelContext)
            completeRecordedIntent(recorded, provider: provider)
        case .addJournal(let content, let mood, let tags):
            guard let modelContext else { return }
            let recorded = AIChatIntentRecorder.recordJournal(
                content: content,
                mood: mood,
                tags: tags,
                date: recordDateForCurrentInput(),
                modelContext: modelContext
            )
            completeRecordedIntent(recorded, provider: provider)
        case .addHabitLog(let name, let value):
            guard let modelContext else { return }
            let recorded = AIChatIntentRecorder.recordHabitLog(
                habitName: name,
                value: value,
                date: recordDateForCurrentInput(),
                modelContext: modelContext
            )
            completeRecordedIntent(recorded, provider: provider)
        case .addWorkout(let workout):
            guard let modelContext else { return }
            let recorded = AIChatIntentRecorder.recordWorkout(workout, date: recordDateForCurrentInput(), modelContext: modelContext)
            completeRecordedIntent(recorded, provider: provider)
        case .addBodyMeasurement(let measurement):
            guard let modelContext else { return }
            let recorded = AIChatIntentRecorder.recordBodyMeasurement(
                measurement,
                date: recordDateForCurrentInput(),
                modelContext: modelContext
            )
            if settings?.isHealthKitEnabled == true {
                Task { @MainActor in
                    do {
                        try await HealthKitService.shared.requestAuthorization(needsWriteAccess: true)
                        try await HealthKitService.shared.saveBodyMeasurement(
                            weightKg: measurement.weightKg,
                            bodyFatPercentage: measurement.bodyFatPercentage,
                            date: recorded.record.date
                        )
                        recorded.record.syncedToAppleHealth = true
                        recorded.record.updatedAt = .now
                        try? modelContext.save()
                    } catch {
                        errorMessage = "身体数据已保存到本地，但同步 Apple Health 失败：\(error.localizedDescription)"
                    }
                }
            }
            completeRecordedIntent(recorded.intent, provider: provider)
        case .addBowelLog(let log):
            guard let modelContext else { return }
            let recorded = AIChatIntentRecorder.recordBowelLog(log, date: recordDateForCurrentInput(), modelContext: modelContext)
            completeRecordedIntent(recorded, provider: provider)
        case .batch(let results):
            for result in results {
                handleIntentResult(result, provider: provider)
            }
        case .fitnessSummary:
            appendAssistant(AIChatInsightReplyBuilder.fitnessSummary(modelContext: modelContext, settings: settings), provider: provider)
            persist(reason: "fitness summary")
        case .energyAnalysis:
            appendAssistant(AIChatInsightReplyBuilder.energyAnalysis(modelContext: modelContext, settings: settings), provider: provider)
            persist(reason: "energy analysis")
        case .postWorkoutNutritionAdvice:
            appendAssistant(AIChatInsightReplyBuilder.postWorkoutNutrition(modelContext: modelContext, settings: settings), provider: provider)
            persist(reason: "post workout nutrition")
        case .chat(let reply):
            appendAssistant(reply, provider: provider)
        }
    }

    private func createTemplateFromIntent(name: String, meal: AIParsedMeal, provider: AIProvider) {
        guard modelContext != nil else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            appendAssistant("模板需要一个名字，请告诉我这个模板叫什么。", provider: provider)
            return
        }
        if fetchMealTemplates().contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) {
            appendAssistant("模板库里已经有「\(trimmedName)」了。换个名字再试，或去 设置 → 餐食模板 里编辑它。", provider: provider)
            return
        }

        let reviewed = AIChatMealValidation.applySanityReview(to: meal)
        if reviewed.items.contains(where: \.isLazyNutritionEstimate) {
            let missing = reviewed.items
                .filter(\.isLazyNutritionEstimate)
                .map { item in
                    let fields = item.missingCoreNutrientKeys.map(\.displayName).joined(separator: "、")
                    return "\(item.name)：\(fields.isEmpty ? "热量" : fields)"
                }
                .joined(separator: "；")
            appendAssistant("这次识别缺少关键营养字段，暂时没有创建模板：\(missing)。补充信息后再试一次。", provider: provider)
            return
        }

        saveAsTemplate(reviewed, name: trimmedName)
        persist(reason: "create template from AI chat")

        let itemSummary = reviewed.items
            .map { "\($0.name) \($0.amountDisplay)（\($0.caloriesDisplay)kcal）" }
            .joined(separator: "、")
        let totalCalories = Int(reviewed.items.reduce(0) { $0 + $1.calories })
        appendAssistant(
            "已创建模板「\(trimmedName)」（\(reviewed.mealType.displayName)）：\(itemSummary)，合计约 \(totalCalories)kcal。\n营养值为 AI 估算，可在 设置 → 餐食模板 中查看和修改。之后直接说“吃了\(trimmedName)”即可按模板记录。",
            provider: provider
        )
    }

    private func appendAssistant(_ content: String, provider: AIProvider) {
        guard let modelContext else { return }
        let msg = AIChatMessage(role: "assistant", content: content, provider: provider)
        modelContext.insert(msg)
        messages.append(msg)
        persist(reason: "append assistant message")
    }

    private func completeRecordedIntent(_ recorded: AIChatRecordedIntent, provider: AIProvider) {
        appendAssistant(recorded.assistantMessage, provider: provider)
        if let persistReason = recorded.persistReason {
            persist(reason: persistReason)
        }
        if recorded.shouldPlaySuccessHaptic {
            HapticEngine.success()
        }
    }

    private func persist(reason: String) {
        guard let modelContext else { return }
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// History for the turn in flight. Callers snapshot this **before** inserting the
    /// current user message, otherwise the same text reaches the provider twice:
    /// once inside `history` and once as the request text.
    private func chatHistory() -> [AIChatHistoryItem] {
        messages.suffix(20).map { AIChatHistoryItem(role: $0.role, content: $0.content) }
    }

    private func fetchUserFoods() -> [UserFood] {
        guard let modelContext else { return [] }
        let descriptor = FetchDescriptor<UserFood>(sortBy: [SortDescriptor(\.useCount, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchMealTemplates() -> [MealTemplate] {
        guard let modelContext else { return [] }
        let descriptor = FetchDescriptor<MealTemplate>(
            sortBy: [SortDescriptor(\.useCount, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func buildDataContext() async -> AIDataContext {
        await AIChatDataContextBuilder.build(modelContext: modelContext, settings: settings)
    }

    private func mealDateForPendingConfirmation() -> Date {
        let text = pendingConfirmation?.originalText ?? lastInputText
        return recordDate(from: text)
    }

    private func recordDateForCurrentInput() -> Date {
        recordDate(from: lastInputText)
    }

    private func recordDate(from text: String) -> Date {
        AIChatRecordDateResolver.date(from: text)
    }

}
