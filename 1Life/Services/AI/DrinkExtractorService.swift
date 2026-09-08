import Foundation
import UIKit

// MARK: - 提取结果草稿（识别后可编辑，确认入库前的中间态）

struct DrinkExtractedDraft: Identifiable {
    let id = UUID()
    var brand: String = ""
    var productName: String = ""
    var sizeML: Double?
    var sugarLevel: String = ""
    var toppings: String = ""
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var sugar: Double?
    var sodium: Double?
    var caffeine: Double?
    var teaPolyphenols: Double?
    var sourceNote: String = ""
    var confidence: DrinkConfidence = .medium

    var isValid: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && calories != nil
    }

    func makeRecord(sourceDate: Date = .now) -> DrinkRecord {
        DrinkRecord(
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            productName: productName.trimmingCharacters(in: .whitespacesAndNewlines),
            sizeML: sizeML,
            sugarLevel: sugarLevel.trimmingCharacters(in: .whitespacesAndNewlines),
            toppings: toppings.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            sugar: sugar,
            sodium: sodium,
            caffeine: caffeine,
            teaPolyphenols: teaPolyphenols,
            sourceNote: sourceNote.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceDate: sourceDate,
            confidence: confidence
        )
    }
}

struct DrinkCandidate: Identifiable {
    let id = UUID()
    var brand: String = ""
    var productName: String = ""
    var sizeML: Double?
    var sourceNote: String = ""
    var isSelected: Bool = true

    var isValid: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var promptLine: String {
        var parts = [
            "品牌：\(brand.trimmingCharacters(in: .whitespacesAndNewlines))",
            "饮品名：\(productName.trimmingCharacters(in: .whitespacesAndNewlines))"
        ]
        if let sizeML {
            parts.append("规格：\(Int(sizeML))ml")
        }
        if !sourceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("来源线索：\(sourceNote.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return parts.joined(separator: "；")
    }
}

private enum DrinkSugarEstimateSource: String {
    case carbs = "糖为根据碳水估算"
    case calories = "糖为根据热量估算"
}

private enum DrinkSizeEstimateSource: String {
    case small = "规格按小杯估算"
    case medium = "规格按中杯估算"
    case large = "规格按大杯估算"
    case extraLarge = "规格按超大杯估算"
}

private struct DrinkSizeEstimator {
    static func apply(to draft: inout DrinkExtractedDraft, context additionalContext: String = "") {
        guard draft.sizeML == nil else { return }

        let context = [
            draft.brand,
            draft.productName,
            draft.sugarLevel,
            draft.toppings,
            draft.sourceNote,
            additionalContext
        ].joined(separator: " ")
        let normalized = DrinkAdjustmentPolicy.normalize(context)

        // 文字/图片中已写明容量时优先使用原文数值，不做杯型估算
        if let explicitML = explicitVolume(in: context) {
            draft.sizeML = explicitML
            return
        }

        let estimate: (value: Double, source: DrinkSizeEstimateSource)
        if containsAny(normalized, ["超大杯", "特大杯", "巨无霸杯"]) {
            estimate = (650, .extraLarge)
        } else if containsAny(normalized, ["大杯", "大份", "large"]) {
            estimate = (480, .large)
        } else if containsAny(normalized, ["中杯", "中份", "medium"]) {
            estimate = (350, .medium)
        } else if containsAny(normalized, ["小杯", "小份", "small"]) {
            estimate = (300, .small)
        } else {
            // 识别不到杯型信息时按大杯估算
            estimate = (480, .large)
        }

        draft.sizeML = estimate.value
        draft.sourceNote = appendEstimateNote(estimate.source.rawValue, to: draft.sourceNote)
        if draft.confidence == .high {
            draft.confidence = .medium
        }
    }

    private static func appendEstimateNote(_ note: String, to sourceNote: String) -> String {
        let trimmed = sourceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(note) else { return trimmed }
        return trimmed.isEmpty ? note : "\(trimmed)；\(note)"
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static func explicitVolume(in text: String) -> Double? {
        // 排除"每100ml""/100ml"这类营养基准表述，避免误当成整杯容量
        guard let regex = try? NSRegularExpression(pattern: #"(?<![每/\d.])(\d{2,4}(?:\.\d+)?)\s*(?:ml|mL|ML|毫升)"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text),
              let value = Double(text[valueRange]),
              (100...1500).contains(value) else { return nil }
        return value
    }
}

private struct DrinkSugarEstimator {
    static func apply(to draft: inout DrinkExtractedDraft, context additionalContext: String = "") {
        guard draft.sugar == nil else { return }

        let context = [
            draft.brand,
            draft.productName,
            draft.sugarLevel,
            draft.toppings,
            draft.sourceNote,
            additionalContext
        ].joined(separator: " ")

        let estimate: (value: Double, source: DrinkSugarEstimateSource)?
        if let carbs = draft.carbs, carbs > 0 {
            estimate = (clamp(carbs * carbsSugarRatio(for: context), lower: 0, upper: carbs), .carbs)
        } else if let calories = draft.calories, calories > 0 {
            estimate = (calories / 4.0 * calorieSugarRatio(for: context), .calories)
        } else {
            estimate = nil
        }

        guard let estimate, estimate.value > 0 else { return }
        draft.sugar = roundedSugar(estimate.value)
        draft.sourceNote = appendEstimateNote(estimate.source.rawValue, to: draft.sourceNote)
        if draft.confidence == .high {
            draft.confidence = .medium
        }
    }

    private static func carbsSugarRatio(for text: String) -> Double {
        let normalized = DrinkAdjustmentPolicy.normalize(text)
        if containsAny(normalized, ["果茶", "水果茶", "柠檬茶", "葡萄", "杨枝甘露", "橙", "莓", "桃", "芒果"]) {
            return sugarLevelMultiplier(for: normalized, base: 0.88, noSugarFloor: 0.25)
        }
        if containsAny(normalized, ["拿铁", "咖啡", "美式", "冷萃", "生椰", "厚乳"]) {
            return sugarLevelMultiplier(for: normalized, base: 0.55, noSugarFloor: 0.2)
        }
        if containsAny(normalized, ["奶茶", "奶绿", "奶盖", "波波", "珍珠", "布蕾", "冰淇淋", "芝士"]) {
            return sugarLevelMultiplier(for: normalized, base: 0.72, noSugarFloor: 0.25)
        }
        return sugarLevelMultiplier(for: normalized, base: 0.75, noSugarFloor: 0.2)
    }

    private static func calorieSugarRatio(for text: String) -> Double {
        let normalized = DrinkAdjustmentPolicy.normalize(text)
        if containsAny(normalized, ["果茶", "水果茶", "柠檬茶", "葡萄", "杨枝甘露", "橙", "莓", "桃", "芒果"]) {
            return sugarLevelMultiplier(for: normalized, base: 0.85, noSugarFloor: 0.25)
        }
        if containsAny(normalized, ["拿铁", "咖啡", "厚乳", "生椰"]) {
            return sugarLevelMultiplier(for: normalized, base: 0.45, noSugarFloor: 0.18)
        }
        if containsAny(normalized, ["奶盖", "芝士", "冰淇淋", "布蕾", "冰沙"]) {
            return sugarLevelMultiplier(for: normalized, base: 0.55, noSugarFloor: 0.2)
        }
        if containsAny(normalized, ["奶茶", "奶绿", "波波", "珍珠"]) {
            return sugarLevelMultiplier(for: normalized, base: 0.65, noSugarFloor: 0.22)
        }
        return sugarLevelMultiplier(for: normalized, base: 0.7, noSugarFloor: 0.18)
    }

    private static func sugarLevelMultiplier(for normalizedText: String, base: Double, noSugarFloor: Double) -> Double {
        if containsAny(normalizedText, ["不另外加糖", "无额外糖", "无另外加糖"]) {
            return min(base, noSugarFloor)
        }
        if DrinkAdjustmentPolicy.canonicalSugarLevel(in: normalizedText) == .noSugar {
            return min(base, noSugarFloor)
        }
        if containsAny(normalizedText, ["少少少甜", "少少少糖"]) {
            return base * 0.2
        }
        if containsAny(normalizedText, ["少少甜", "少少糖"]) {
            return base * 0.35
        }
        if containsAny(normalizedText, ["少甜", "少糖"]) {
            return base * 0.7
        }
        switch DrinkAdjustmentPolicy.canonicalSugarLevel(in: normalizedText) {
        case .some(.light):
            return base * 0.3
        case .some(.half):
            return base * 0.5
        case .some(.less):
            return base * 0.7
        case .some(.standard):
            return base
        case .some(.noSugar):
            return min(base, noSugarFloor)
        case .none:
            return base
        }
    }

    private static func appendEstimateNote(_ note: String, to sourceNote: String) -> String {
        let trimmed = sourceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(note) else { return trimmed }
        return trimmed.isEmpty ? note : "\(trimmed)；\(note)"
    }

    private static func roundedSugar(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}

// MARK: - 提取服务

struct DrinkExtractorService {
    let settings: UserSettings
    let configurationService: AIConfigurationService
    let clientFactory: AIClientFactory

    init(settings: UserSettings,
         configurationService: AIConfigurationService = LocalAIConfigurationService(),
         clientFactory: AIClientFactory = AIClientFactory()) {
        self.settings = settings
        self.configurationService = configurationService
        self.clientFactory = clientFactory
    }

    private var provider: AIProvider { settings.selectedAIProvider }
    private var model: String { settings.effectiveDrinkPluginAIModel }

    /// 第一步：只从图片中读取原始文字，供用户校对。图片 OCR 不做结构化换算，降低视觉模型负担。
    func recognizeText(imageDataList: [Data], text: String?) async throws -> String {
        let apiKey = try requireAPIKey()
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !imageDataList.isEmpty else {
            return trimmedText ?? ""
        }
        guard provider.supportsVision(model: model) else {
            throw AIClientError.providerError("当前模型不支持图片识别，请在 AI 配置中切换到支持视觉输入的模型。")
        }
        guard let visionClient = clientFactory.visionClient(for: provider) else {
            throw AIClientError.providerError("当前 AI 服务商不支持图片识别")
        }

        var userMessage = "请逐张读取图片中的所有可见文字，尤其是品牌、商品名、规格、糖度/冰量、营养成分表、单位、来源信息。只输出纯文本，不要总结，不要 JSON。"
        if let trimmedText, !trimmedText.isEmpty {
            userMessage = "用户补充说明：\(trimmedText)\n\n\(userMessage)"
        }
        let images = imageDataList.prefix(6).map {
            AIImageAttachment(data: Self.prepareImageForVision($0), mediaType: "image/jpeg")
        }
        let request = AIVisionRequest(
            messages: [
                AIClientMessage(role: .system, content: Self.ocrPrompt),
                AIClientMessage(role: .user, content: userMessage)
            ],
            images: Array(images),
            model: model,
            apiKey: apiKey,
            timeoutInterval: 120,
            temperature: 0.0
        )
        let recognized = try await visionClient.sendWithImage(request).text
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedText, !trimmedText.isEmpty, !recognized.contains(trimmedText) {
            return "用户补充说明：\n\(trimmedText)\n\n图片识别文字：\n\(recognized)"
        }
        return recognized
    }

    /// 第二步：先从校对后的文字里找出候选饮品，供用户确认范围。
    func identifyCandidates(fromConfirmedText text: String) async throws -> [DrinkCandidate] {
        let apiKey = try requireAPIKey()
        let client = clientFactory.client(for: provider)
        let request = AIClientRequest(
            messages: [
                AIClientMessage(role: .system, content: Self.candidatePrompt),
                AIClientMessage(role: .user, content: text)
            ],
            model: model,
            apiKey: apiKey,
            timeoutInterval: 120,
            temperature: 0.0
        )
        return try Self.parseCandidates(from: try await client.send(request).text)
    }

    /// 第三步：只围绕用户确认的候选饮品提取热量和营养。
    func extract(fromConfirmedText text: String, candidates: [DrinkCandidate]) async throws -> [DrinkExtractedDraft] {
        let selected = candidates.filter(\.isSelected).filter(\.isValid)
        let candidateText = selected.enumerated()
            .map { index, candidate in "\(index + 1). \(candidate.promptLine)" }
            .joined(separator: "\n")
        let userText = """
        已确认要入库的饮品：
        \(candidateText)

        校对后的原文：
        \(text)
        """
        return try await extractStructuredRecords(from: userText, prompt: Self.targetedStructuringPrompt, timeout: 120)
    }

    /// 兼容旧入口：从用户校对后的文字中提取饮品营养记录
    func extract(fromConfirmedText text: String) async throws -> [DrinkExtractedDraft] {
        try await extractStructuredRecords(from: text, prompt: Self.textStructuringPrompt, timeout: 120)
    }

    private func extractStructuredRecords(from text: String, prompt: String, timeout: TimeInterval) async throws -> [DrinkExtractedDraft] {
        let apiKey = try requireAPIKey()
        let client = clientFactory.client(for: provider)
        let request = AIClientRequest(
            messages: [
                AIClientMessage(role: .system, content: prompt),
                AIClientMessage(role: .user, content: text)
            ],
            model: model,
            apiKey: apiKey,
            timeoutInterval: timeout,
            temperature: 0.0
        )
        return try Self.parseDrafts(from: try await client.send(request).text, context: text)
    }

    /// 兼容旧入口：从图片（营养成分表照片/菜单截图）和可选文字中提取饮品营养记录
    func extract(imageDataList: [Data], text: String?) async throws -> [DrinkExtractedDraft] {
        let apiKey = try requireAPIKey()
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)

        var userMessage = "请逐张读取图片中的饮品营养信息，提取所有可确认的饮品记录。只输出 JSON 对象，不要解释，不要 markdown。"
        if let trimmedText, !trimmedText.isEmpty {
            userMessage = "补充文字信息：\(trimmedText)\n\n\(userMessage)"
        }
        let messages = [
            AIClientMessage(role: .system, content: Self.extractionPrompt),
            AIClientMessage(role: .user, content: userMessage)
        ]

        let responseText: String
        if imageDataList.isEmpty {
            // 纯文字提取
            let client = clientFactory.client(for: provider)
            let request = AIClientRequest(
                messages: messages,
                model: model,
                apiKey: apiKey,
                timeoutInterval: 120,
                temperature: 0.1
            )
            responseText = try await client.send(request).text
        } else {
            guard provider.supportsVision(model: model) else {
                throw AIClientError.providerError("当前模型不支持图片识别，请在 AI 配置中切换到支持视觉输入的模型。")
            }
            guard let visionClient = clientFactory.visionClient(for: provider) else {
                throw AIClientError.providerError("当前 AI 服务商不支持图片识别")
            }
            let images = imageDataList.prefix(6).map {
                AIImageAttachment(data: Self.prepareImageForVision($0), mediaType: "image/jpeg")
            }
            let request = AIVisionRequest(
                messages: messages,
                images: Array(images),
                model: model,
                apiKey: apiKey,
                timeoutInterval: 120,
                temperature: 0.1
            )
            responseText = try await visionClient.sendWithImage(request).text
        }

        return try Self.parseDrafts(from: responseText, context: trimmedText ?? userMessage)
    }

    private func requireAPIKey() throws -> String {
        guard let apiKey = try configurationService.readAPIKey(provider: provider),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.missingAPIKey
        }
        return apiKey
    }

    // MARK: - 提示词

    static let ocrPrompt = """
    你是饮品营养成分表 OCR 助手。任务只有一个：尽可能完整地抄录图片里的文字。
    规则：
    - 多张图片按顺序输出，使用“图片1/图片2”分隔。
    - 保留品牌、商品名、规格、糖度、冰量、小料、营养成分表、单位、每100ml/每份/整杯等基准。
    - 看不清的文字用 [?] 标记，不要猜。
    - 不要换算，不要整理成 JSON，不要解释。
    """

    static let extractionPrompt = """
    你是一个饮品营养数据录入助手，负责从图片（营养成分表照片、菜单截图、官方小程序页面）和文字信息中提取奶茶、咖啡、果茶等饮品的营养数据。

    提取规则：
    - 输入可能是用户校对后的 OCR 原文。必须尽量提取完整字段，但只有能确认品牌、商品名和热量时才生成记录；蛋白质/碳水/脂肪/糖/钠未知时填 null。
    - 多张图片时，必须按图片顺序逐张读取：先识别每张图包含的品牌、商品、规格、糖度/冰量和营养表，再合并同一「品牌+商品+规格+糖度版本」的重复记录。
    - 一条记录对应一个「品牌+商品+规格+糖度版本」组合。同一图片里有多个商品或多个糖度版本时，拆成多条记录。
    - 营养数值只填数字。热量单位 kcal，蛋白质/碳水/脂肪/糖单位 g，钠/咖啡因/茶多酚单位 mg，规格单位 ml。
    - 如果原始数据以千焦(kJ)标注热量，换算为 kcal（1 kcal = 4.184 kJ），保留整数。
    - 如果原始数据是每100ml，尽量按规格换算为整杯数值；无法确定规格时保留原值，并在 source 中注明"每100ml数据"。
    - 看不清或未标注的字段填 null，绝不编造数值；尤其不要为了补齐糖、咖啡因或茶多酚而编造官方数据，App 会对缺失糖做统一估算并标注。
    - tea_polyphenols_mg：仅茶饮/奶茶/抹茶等含茶饮品，且原文明确标注时填写；非茶类或未标注一律填 null。
    - confidence 判断：官方营养成分表照片/官网/官方小程序 = 高；第三方实测、媒体测评 = 中；估算、来源不明 = 低。
    - source 要具体，如"喜茶官方小程序营养成分表截图"，不要笼统写"图片"。
    \(DrinkAdjustmentPolicy.promptText)

    输出格式：只输出一个 JSON 对象，不要任何解释文字或 markdown 代码块标记。结构如下：
    {"records":[{"brand":"喜茶","name":"多肉葡萄","size_ml":650,"sugar_level":"少糖","toppings":"葡萄果肉","calories_kcal":230,"protein_g":1.2,"carbs_g":55,"fat_g":0.5,"sugar_g":42,"sodium_mg":35,"caffeine_mg":null,"tea_polyphenols_mg":null,"source":"喜茶官方小程序营养成分表截图","confidence":"高"}]}
    未知字段填 null。confidence 只能是"高"、"中"、"低"之一。sugar_level 用中文，如 全糖/七分糖/五分糖/三分糖/少糖/无糖。只有热量可确认但其它营养素未知时，也必须输出该记录。
    """

    static let textStructuringPrompt = """
    你是饮品营养文字整理器。输入是用户校对后的 OCR/手写文字。
    任务：只抽取可确认的饮品记录，输出 JSON，不要解释。

    最低记录门槛：
    - brand 必须有
    - name 必须有
    - calories_kcal 必须有
    其它字段无法确认就填 null 或空字符串，不要编造。

    字段要求：
    - size_ml: 规格 ml；未知填 null；如果原文只写小杯/中杯/大杯/超大杯但没写 ml，size_ml 填 null，并在 source 保留这个杯型线索。
    - sugar_level: 中文糖度，如 无糖/三分糖/五分糖/七分糖/标准糖；未知填 ""
    - toppings: 小料；无或未知填 ""
    - calories_kcal: 整杯热量 kcal。原文是 kJ 时用 kcal = kJ / 4.184 换算并取整数。
    - protein_g/carbs_g/fat_g/sugar_g/sodium_mg/caffeine_mg/tea_polyphenols_mg: 尽量提取，未知填 null；不要为了补齐糖、咖啡因或茶多酚而编造官方数据。tea_polyphenols_mg 仅茶饮类且原文明确标注时填写。
    - source: 用简短文字说明来源，如 "用户校对的营养表文字"。
    - confidence: 官方/清晰营养表为 "高"，信息不完整为 "中"，估算为 "低"。

    只输出这个结构：
    {"records":[{"brand":"品牌","name":"饮品名","size_ml":650,"sugar_level":"无糖","toppings":"","calories_kcal":120,"protein_g":null,"carbs_g":null,"fat_g":null,"sugar_g":null,"sodium_mg":null,"caffeine_mg":null,"tea_polyphenols_mg":null,"source":"用户校对的营养表文字","confidence":"中"}]}
    """

    static let candidatePrompt = """
    你是饮品候选识别器。输入是用户校对后的 OCR/手写文字。
    任务：只找出可能要入库的饮品候选，不提取营养，不计算热量。

    规则：
    - 只输出能看出品牌和饮品名的候选。
    - 同一饮品有不同规格时可以拆成多条。
    - 不确定规格时 size_ml 填 null。
    - source 写简短线索，如 "图片1营养表"、"用户补充说明"。
    - 不要输出解释，不要 markdown。

    只输出这个结构：
    {"candidates":[{"brand":"品牌","name":"饮品名","size_ml":650,"source":"图片1营养表"}]}
    """

    static let targetedStructuringPrompt = """
    你是饮品营养文字整理器。输入包含两部分：用户确认的候选饮品，以及校对后的 OCR/手写原文。
    任务：只针对候选饮品提取热量和营养，输出 JSON，不要解释。

    最低记录门槛：
    - brand 必须来自候选饮品
    - name 必须来自候选饮品
    - calories_kcal 必须能从原文确认或由原文 kJ 换算
    其它字段无法确认就填 null 或空字符串，不要编造。

    字段要求：
    - size_ml: 优先使用候选规格；原文有更明确规格时使用原文；未知填 null。如果原文只写小杯/中杯/大杯/超大杯但没写 ml，size_ml 填 null，并在 source 保留这个杯型线索。
    - sugar_level: 中文糖度，如 无糖/三分糖/五分糖/七分糖/标准糖；未知填 ""。
    - toppings: 小料；无或未知填 ""。
    - calories_kcal: 整杯热量 kcal。原文是 kJ 时用 kcal = kJ / 4.184 换算并取整数。
    - protein_g/carbs_g/fat_g/sugar_g/sodium_mg/caffeine_mg/tea_polyphenols_mg: 尽量提取，未知填 null；不要为了补齐糖、咖啡因或茶多酚而编造官方数据，App 会对缺失糖做统一估算并标注。tea_polyphenols_mg 仅茶饮类且原文明确标注时填写。
    - source: 用简短文字说明来源，如 "用户校对的营养表文字"。
    - confidence: 官方/清晰营养表为 "高"，信息不完整为 "中"，估算为 "低"。
    \(DrinkAdjustmentPolicy.promptText)

    只输出这个结构：
    {"records":[{"brand":"品牌","name":"饮品名","size_ml":650,"sugar_level":"无糖","toppings":"","calories_kcal":120,"protein_g":null,"carbs_g":null,"fat_g":null,"sugar_g":null,"sodium_mg":null,"caffeine_mg":null,"tea_polyphenols_mg":null,"source":"用户校对的营养表文字","confidence":"中"}]}
    """

    // MARK: - 解析

    /// 解析模型输出的 JSON，容忍 markdown 代码块包裹、前后杂质文本、数字以字符串形式返回等常见情况
    static func parseDrafts(from text: String, context: String = "") throws -> [DrinkExtractedDraft] {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start <= end else {
            throw AIClientError.providerError("AI 未返回有效的 JSON 数据")
        }
        let jsonString = String(text[start...end])
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = object["records"] as? [[String: Any]] else {
            throw AIClientError.providerError("AI 返回的数据格式无法解析")
        }

        let drafts: [DrinkExtractedDraft] = records.compactMap { dict in
            var draft = DrinkExtractedDraft()
            draft.brand = stringValue(dict["brand"]) ?? ""
            draft.productName = stringValue(dict["name"]) ?? ""
            draft.sizeML = doubleValue(dict["size_ml"])
            draft.sugarLevel = stringValue(dict["sugar_level"]) ?? ""
            draft.toppings = stringValue(dict["toppings"]) ?? ""
            draft.calories = doubleValue(dict["calories_kcal"])
            draft.protein = doubleValue(dict["protein_g"])
            draft.carbs = doubleValue(dict["carbs_g"])
            draft.fat = doubleValue(dict["fat_g"])
            draft.sugar = doubleValue(dict["sugar_g"])
            draft.sodium = doubleValue(dict["sodium_mg"])
            draft.caffeine = doubleValue(dict["caffeine_mg"]) ?? doubleValue(dict["caffeine"])
            draft.teaPolyphenols = doubleValue(dict["tea_polyphenols_mg"]) ?? doubleValue(dict["tea_polyphenols"])
            draft.sourceNote = stringValue(dict["source"]) ?? ""
            draft.confidence = DrinkConfidence(rawValue: stringValue(dict["confidence"]) ?? "") ?? .medium
            DrinkSizeEstimator.apply(to: &draft, context: context)
            DrinkSugarEstimator.apply(to: &draft, context: context)
            return draft.isValid ? draft : nil
        }
        guard !drafts.isEmpty else {
            throw AIClientError.providerError("未能从图片或文字中提取到饮品数据，请换更清晰的成分表照片重试。")
        }
        return drafts
    }

    static func parseCandidates(from text: String) throws -> [DrinkCandidate] {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start <= end else {
            throw AIClientError.providerError("AI 未返回有效的候选饮品 JSON")
        }
        let jsonString = String(text[start...end])
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = object["candidates"] as? [[String: Any]] else {
            throw AIClientError.providerError("AI 返回的候选饮品格式无法解析")
        }

        let candidates: [DrinkCandidate] = records.compactMap { dict in
            var candidate = DrinkCandidate()
            candidate.brand = stringValue(dict["brand"]) ?? ""
            candidate.productName = stringValue(dict["name"]) ?? ""
            candidate.sizeML = doubleValue(dict["size_ml"])
            candidate.sourceNote = stringValue(dict["source"]) ?? ""
            return candidate.isValid ? candidate : nil
        }
        guard !candidates.isEmpty else {
            throw AIClientError.providerError("未能识别到品牌和饮品名，请在文字里补充后重试。")
        }
        return candidates
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let s = value as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed.lowercased() == "null" ? nil : trimmed
        }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String {
            let cleaned = s.replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " kcalgm毫升ml克"))
            return Double(cleaned)
        }
        return nil
    }

    /// 与 ConfiguredAIService 相同的图片压缩策略：长边 1024、JPEG 0.7
    private static func prepareImageForVision(_ data: Data, maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> Data {
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
}
