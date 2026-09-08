import Foundation
import UIKit

// MARK: - 提取结果草稿（识别后可编辑，确认入库前的中间态）

struct MealNutritionExtractedDraft: Identifiable {
    let id = UUID()
    var brand: String = ""
    var name: String = ""
    var defaultAmount: Double = 1
    var defaultUnit: String = "份"
    var defaultServingGrams: Double?
    var caloriesPerServing: Double?
    var caloriesPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var fiberPer100g: Double?
    var sodiumPer100g: Double?
    var sugarPer100g: Double?
    var cholesterolPer100g: Double?
    var caffeinePer100g: Double?
    var teaPolyphenolsPer100g: Double?
    var calciumPer100g: Double?
    var magnesiumPer100g: Double?
    var potassiumPer100g: Double?
    var ironPer100g: Double?
    var zincPer100g: Double?
    var vitaminAPer100g: Double?
    var vitaminCPer100g: Double?
    var vitaminDPer100g: Double?
    var vitaminEPer100g: Double?
    var vitaminB1Per100g: Double?
    var vitaminB2Per100g: Double?
    var niacinPer100g: Double?
    var vitaminB6Per100g: Double?
    var folatePer100g: Double?
    var vitaminB12Per100g: Double?
    var sourceNote: String = ""

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && caloriesPerServing != nil
    }

    func makeUserFood() -> UserFood {
        let servingNutrition: [String: Double] = [
            "calories": caloriesPerServing,
            "protein": proteinPer100g,
            "carbs": carbsPer100g,
            "fat": fatPer100g,
            "fiber": fiberPer100g,
            "sodium": sodiumPer100g,
            "sugar": sugarPer100g,
            "cholesterol": cholesterolPer100g,
            "caffeine": caffeinePer100g,
            "teaPolyphenols": teaPolyphenolsPer100g,
            "calcium": calciumPer100g,
            "magnesium": magnesiumPer100g,
            "potassium": potassiumPer100g,
            "iron": ironPer100g,
            "zinc": zincPer100g,
            "vitaminA": vitaminAPer100g,
            "vitaminC": vitaminCPer100g,
            "vitaminD": vitaminDPer100g,
            "vitaminE": vitaminEPer100g,
            "vitaminB1": vitaminB1Per100g,
            "vitaminB2": vitaminB2Per100g,
            "niacin": niacinPer100g,
            "vitaminB6": vitaminB6Per100g,
            "folate": folatePer100g,
            "vitaminB12": vitaminB12Per100g
        ].compactMapValues { $0 }
        return UserFood(
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultAmount: defaultAmount,
            defaultUnit: defaultUnit,
            // 旧模型字段仅为历史兼容，新记录不再使用克重。
            defaultServingGrams: defaultServingGrams ?? 100,
            caloriesPer100g: caloriesPerServing ?? caloriesPer100g ?? 0,
            servingNutrition: servingNutrition,
            proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g,
            fiberPer100g: fiberPer100g,
            sodiumPer100g: sodiumPer100g,
            sugarPer100g: sugarPer100g,
            cholesterolPer100g: cholesterolPer100g,
            caffeinePer100g: caffeinePer100g,
            teaPolyphenolsPer100g: teaPolyphenolsPer100g,
            calciumPer100g: calciumPer100g,
            magnesiumPer100g: magnesiumPer100g,
            potassiumPer100g: potassiumPer100g,
            ironPer100g: ironPer100g,
            zincPer100g: zincPer100g,
            vitaminAPer100g: vitaminAPer100g,
            vitaminCPer100g: vitaminCPer100g,
            vitaminDPer100g: vitaminDPer100g,
            vitaminEPer100g: vitaminEPer100g,
            vitaminB1Per100g: vitaminB1Per100g,
            vitaminB2Per100g: vitaminB2Per100g,
            niacinPer100g: niacinPer100g,
            vitaminB6Per100g: vitaminB6Per100g,
            folatePer100g: folatePer100g,
            vitaminB12Per100g: vitaminB12Per100g
        )
    }

    /// 把当前草稿的营养字段写回一条已存在的 UserFood（重名更新场景使用），不改名称/份量设定
    func applyNutrition(to food: UserFood) {
        var servingNutrition = food.servingNutrition
        servingNutrition["calories"] = caloriesPerServing
        let values: [(String, Double?)] = [
            ("protein", proteinPer100g), ("carbs", carbsPer100g), ("fat", fatPer100g),
            ("fiber", fiberPer100g), ("sodium", sodiumPer100g), ("sugar", sugarPer100g),
            ("cholesterol", cholesterolPer100g), ("caffeine", caffeinePer100g),
            ("teaPolyphenols", teaPolyphenolsPer100g), ("calcium", calciumPer100g),
            ("magnesium", magnesiumPer100g), ("potassium", potassiumPer100g),
            ("iron", ironPer100g), ("zinc", zincPer100g), ("vitaminA", vitaminAPer100g),
            ("vitaminC", vitaminCPer100g), ("vitaminD", vitaminDPer100g),
            ("vitaminE", vitaminEPer100g), ("vitaminB1", vitaminB1Per100g),
            ("vitaminB2", vitaminB2Per100g), ("niacin", niacinPer100g),
            ("vitaminB6", vitaminB6Per100g), ("folate", folatePer100g),
            ("vitaminB12", vitaminB12Per100g)
        ]
        for (key, value) in values {
            if let value { servingNutrition[key] = value }
        }
        food.servingNutrition = servingNutrition
        if let caloriesPerServing {
            food.caloriesPer100g = caloriesPerServing
        } else if let caloriesPer100g {
            food.caloriesPer100g = caloriesPer100g
        }
        food.proteinPer100g = proteinPer100g
        food.carbsPer100g = carbsPer100g
        food.fatPer100g = fatPer100g
        food.fiberPer100g = fiberPer100g
        food.sodiumPer100g = sodiumPer100g
        food.sugarPer100g = sugarPer100g
        food.cholesterolPer100g = cholesterolPer100g
        food.caffeinePer100g = caffeinePer100g
        food.teaPolyphenolsPer100g = teaPolyphenolsPer100g
        food.calciumPer100g = calciumPer100g
        food.magnesiumPer100g = magnesiumPer100g
        food.potassiumPer100g = potassiumPer100g
        food.ironPer100g = ironPer100g
        food.zincPer100g = zincPer100g
        food.vitaminAPer100g = vitaminAPer100g
        food.vitaminCPer100g = vitaminCPer100g
        food.vitaminDPer100g = vitaminDPer100g
        food.vitaminEPer100g = vitaminEPer100g
        food.vitaminB1Per100g = vitaminB1Per100g
        food.vitaminB2Per100g = vitaminB2Per100g
        food.niacinPer100g = niacinPer100g
        food.vitaminB6Per100g = vitaminB6Per100g
        food.folatePer100g = folatePer100g
        food.vitaminB12Per100g = vitaminB12Per100g
        food.updatedAt = .now
    }
}

struct MealNutritionCandidate: Identifiable {
    let id = UUID()
    var name: String = ""
    var sourceNote: String = ""
    var isSelected: Bool = true

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var promptLine: String {
        var parts = ["食物名：\(name.trimmingCharacters(in: .whitespacesAndNewlines))"]
        if !sourceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("来源线索：\(sourceNote.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return parts.joined(separator: "；")
    }
}

// MARK: - 提取服务

struct MealNutritionExtractorService {
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
    private var model: String { settings.effectiveMealPluginAIModel }

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

        var userMessage = "请逐张读取图片中的所有可见文字，尤其是食品名称、配料表、营养成分表（每100g/每100ml 和每份两栏都要抄全）、净含量、每份重量。只输出纯文本，不要总结，不要 JSON。"
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

    /// 第二步：先从校对后的文字里找出候选食物，供用户确认范围（一次可能拍了多样食材）。
    func identifyCandidates(fromConfirmedText text: String, brand: String = "") async throws -> [MealNutritionCandidate] {
        let apiKey = try requireAPIKey()
        let client = clientFactory.client(for: provider)
        let normalizedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let userText = normalizedBrand.isEmpty
            ? text
            : "用户指定品牌（优先使用，不要改写）：\(normalizedBrand)\n\n校对后的原文：\n\(text)"
        let request = AIClientRequest(
            messages: [
                AIClientMessage(role: .system, content: Self.candidatePrompt),
                AIClientMessage(role: .user, content: userText)
            ],
            model: model,
            apiKey: apiKey,
            timeoutInterval: 120,
            temperature: 0.0
        )
        return try Self.parseCandidates(from: try await client.send(request).text)
    }

    /// 第三步：只围绕用户确认的候选食物提取每份热量和可确认的营养素。
    func extract(fromConfirmedText text: String, candidates: [MealNutritionCandidate], brand: String = "") async throws -> [MealNutritionExtractedDraft] {
        let selected = candidates.filter(\.isSelected).filter(\.isValid)
        let candidateText = selected.enumerated()
            .map { index, candidate in "\(index + 1). \(candidate.promptLine)" }
            .joined(separator: "\n")
        let normalizedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let brandInstruction = normalizedBrand.isEmpty
            ? ""
            : "用户指定品牌（优先写入每条记录，不要改写）：\(normalizedBrand)\n\n"
        let userText = """
        \(brandInstruction)
        已确认要入库的食物：
        \(candidateText)

        校对后的原文：
        \(text)
        """
        let apiKey = try requireAPIKey()
        let client = clientFactory.client(for: provider)
        let request = AIClientRequest(
            messages: [
                AIClientMessage(role: .system, content: Self.targetedStructuringPrompt),
                AIClientMessage(role: .user, content: userText)
            ],
            model: model,
            apiKey: apiKey,
            timeoutInterval: 120,
            temperature: 0.0
        )
        return try Self.parseDrafts(from: try await client.send(request).text)
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
    你是食品营养成分表 OCR 助手。任务只有一个：尽可能完整地抄录图片里的文字。
    规则：
    - 多张图片按顺序输出，使用"图片1/图片2"分隔。
    - 保留食品名称、配料表、营养成分表（每100g/100ml 和每份两栏都要抄全）、净含量、每份建议重量、单位。
    - 看不清的文字用 [?] 标记，不要猜。
    - 不要换算，不要整理成 JSON，不要解释。
    """

    static let candidatePrompt = """
    你是食材候选识别器。输入是用户校对后的 OCR/手写文字。
    任务：只找出可能要入库的食物候选，不提取营养，不计算数值。

    规则：
    - 只输出能看出食物名称的候选。一张图可能只有一样食材，也可能一次拍了多样食材，都要识别出来。
    - source 写简短线索，如"图片1营养表""用户补充说明"。
    - 不要输出解释，不要 markdown。

    只输出这个结构：
    {"candidates":[{"name":"食物名","source":"图片1营养表"}]}
    """

    static let targetedStructuringPrompt = """
    你是食品营养文字整理器。输入包含两部分：用户确认的候选食物，以及校对后的 OCR/手写原文。
    任务：只针对候选食物提取「每份」热量和可确认的营养素，输出 JSON，不要解释。

    最低记录门槛：
    - brand 和 name 尽量从候选食物或原文中提取；品牌未知时填空字符串。
    - name 必须来自候选食物
    - calories_per_serving_kcal 必须能从原文确认或合理换算得出
    - 每份可以是 1 包、1 片、1 个、1 杯或营养标签明确写出的每份；不要因为缺少每100g而放弃记录。
    其它字段无法确认就不要输出，不要编造。

    换算规则（这是本任务最容易出错的地方，务必按公式换算）：
    - 如果同时有每100g和每份，优先将每份热量写入 calories_per_serving_kcal，同时可填写每100g字段。
    - 如果只有每份数据，直接保留每份数据，不要因为缺少每100g而填 null。
    - 餐食完全以每份口径记录，不要要求或推断克重；default_serving_grams 永远填 null。
    - 如果原始热量以千焦(kJ)标注，先换算为 kcal（1 kcal = 4.184 kJ），再按图片标注的每份口径填写。
    - 如果完全没有标注热量，calories_per_serving_kcal 填 null；只有热量缺失时才不生成记录。

    字段匹配规则：
    - default_amount: 建议的默认份量数字，如 1；无法判断填 1。
    - default_unit: 默认单位，如 g/ml/份/个/片/块；无法判断填 "份"。
    - default_serving_grams: 永远填 null，餐食不记录克重。
    - calories_per_serving_kcal: 每份热量，必须尽力提取；这是能否生成记录的唯一营养门槛。
    - 其余营养字段全部使用每份口径，字段名为 *_per_serving。
    - 只返回原文中明确出现、并且能与下列标准字段匹配的营养字段；没有出现的字段直接省略，不要输出 null。
    - 允许匹配的标准字段包括：protein、carbs、fat、fiber、sodium、sugar、cholesterol、caffeine、tea_polyphenols、calcium、magnesium、potassium、iron、zinc、vitamin_a、vitamin_c、vitamin_d、vitamin_e、vitamin_b1、vitamin_b2、niacin、vitamin_b6、folate、vitamin_b12。
    - 同义词要归一到标准字段：蛋白质/蛋白→protein，碳水化合物/碳水→carbs，脂肪→fat，膳食纤维/纤维→fiber，钠/盐/食盐→sodium，糖/糖类→sugar。
    - “钠”“盐”“食盐”不区分，统一写入 sodium；保留原文数值和单位，不进行钠与食盐之间的换算。
    - 如果营养项目名称不确定或无法与标准字段匹配，直接忽略该项目。
      tea_polyphenols 仅茶饮/抹茶等含茶食物且原文明确标注时填写。caffeine 仅咖啡/茶/含咖啡因食品明确标注时填写。
    - source: 用简短文字说明来源和口径，如"包装营养成分表每份"或"每份热量"。

    只输出 JSON。每条记录必须包含 brand、name、default_amount、default_unit、default_serving_grams、calories_per_serving_kcal、source；其中 default_serving_grams 永远为 null。其余营养字段只在原文明确出现时返回，不要返回 null 字段。
    示例：
    {"records":[{"brand":"","name":"全麦面包","default_amount":1,"default_unit":"份","default_serving_grams":null,"calories_per_serving_kcal":180,"protein_per_serving_g":7,"fat_per_serving_g":2,"sodium_per_serving_mg":210,"source":"原文每份"}]}
    """

    // MARK: - 解析

    /// 解析模型输出的 JSON，容忍 markdown 代码块包裹、前后杂质文本、数字以字符串形式返回等常见情况
    static func parseDrafts(from text: String) throws -> [MealNutritionExtractedDraft] {
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

        let drafts: [MealNutritionExtractedDraft] = records.compactMap { dict in
            var draft = MealNutritionExtractedDraft()
            draft.brand = stringValue(dict["brand"]) ?? ""
            draft.name = stringValue(dict["name"]) ?? ""
            draft.defaultAmount = doubleValue(dict["default_amount"]) ?? 1
            draft.defaultUnit = stringValue(dict["default_unit"]) ?? "份"
            draft.defaultServingGrams = doubleValue(dict["default_serving_grams"])
            draft.caloriesPerServing = doubleValue(dict["calories_per_serving_kcal"])
                ?? doubleValue(dict["calories_per_serving"])
            draft.caloriesPer100g = doubleValue(dict["calories_per_100g_kcal"])
            if draft.caloriesPerServing == nil, let caloriesPer100g = draft.caloriesPer100g {
                draft.caloriesPerServing = caloriesPer100g
            }
            draft.proteinPer100g = doubleValue(dict["protein_per_serving_g"]) ?? doubleValue(dict["protein_per_100g_g"])
            draft.carbsPer100g = doubleValue(dict["carbs_per_serving_g"]) ?? doubleValue(dict["carbs_per_100g_g"])
            draft.fatPer100g = doubleValue(dict["fat_per_serving_g"]) ?? doubleValue(dict["fat_per_100g_g"])
            draft.fiberPer100g = doubleValue(dict["fiber_per_serving_g"]) ?? doubleValue(dict["fiber_per_100g_g"])
            draft.sodiumPer100g = doubleValue(dict["sodium_per_serving_mg"]) ?? doubleValue(dict["sodium_per_100g_mg"])
            draft.sugarPer100g = doubleValue(dict["sugar_per_serving_g"]) ?? doubleValue(dict["sugar_per_100g_g"])
            draft.cholesterolPer100g = doubleValue(dict["cholesterol_per_serving_mg"]) ?? doubleValue(dict["cholesterol_per_100g_mg"])
            draft.caffeinePer100g = doubleValue(dict["caffeine_per_serving_mg"]) ?? doubleValue(dict["caffeine_per_100g_mg"])
            draft.teaPolyphenolsPer100g = doubleValue(dict["tea_polyphenols_per_serving_mg"]) ?? doubleValue(dict["tea_polyphenols_per_100g_mg"])
            draft.calciumPer100g = doubleValue(dict["calcium_per_serving_mg"]) ?? doubleValue(dict["calcium_per_100g_mg"])
            draft.magnesiumPer100g = doubleValue(dict["magnesium_per_serving_mg"]) ?? doubleValue(dict["magnesium_per_100g_mg"])
            draft.potassiumPer100g = doubleValue(dict["potassium_per_serving_mg"]) ?? doubleValue(dict["potassium_per_100g_mg"])
            draft.ironPer100g = doubleValue(dict["iron_per_serving_mg"]) ?? doubleValue(dict["iron_per_100g_mg"])
            draft.zincPer100g = doubleValue(dict["zinc_per_serving_mg"]) ?? doubleValue(dict["zinc_per_100g_mg"])
            draft.vitaminAPer100g = doubleValue(dict["vitamin_a_per_serving_ug"]) ?? doubleValue(dict["vitamin_a_per_100g_ug"])
            draft.vitaminCPer100g = doubleValue(dict["vitamin_c_per_serving_mg"]) ?? doubleValue(dict["vitamin_c_per_100g_mg"])
            draft.vitaminDPer100g = doubleValue(dict["vitamin_d_per_serving_ug"]) ?? doubleValue(dict["vitamin_d_per_100g_ug"])
            draft.vitaminEPer100g = doubleValue(dict["vitamin_e_per_serving_mg"]) ?? doubleValue(dict["vitamin_e_per_100g_mg"])
            draft.vitaminB1Per100g = doubleValue(dict["vitamin_b1_per_serving_mg"]) ?? doubleValue(dict["vitamin_b1_per_100g_mg"])
            draft.vitaminB2Per100g = doubleValue(dict["vitamin_b2_per_serving_mg"]) ?? doubleValue(dict["vitamin_b2_per_100g_mg"])
            draft.niacinPer100g = doubleValue(dict["niacin_per_serving_mg"]) ?? doubleValue(dict["niacin_per_100g_mg"])
            draft.vitaminB6Per100g = doubleValue(dict["vitamin_b6_per_serving_mg"]) ?? doubleValue(dict["vitamin_b6_per_100g_mg"])
            draft.folatePer100g = doubleValue(dict["folate_per_serving_ug"]) ?? doubleValue(dict["folate_per_100g_ug"])
            draft.vitaminB12Per100g = doubleValue(dict["vitamin_b12_per_serving_ug"]) ?? doubleValue(dict["vitamin_b12_per_100g_ug"])
            draft.sourceNote = stringValue(dict["source"]) ?? ""
            return draft.isValid ? draft : nil
        }
        guard !drafts.isEmpty else {
            throw AIClientError.providerError("未能提取到包含食物名称和每份热量的记录，请补充每份热量后重试。")
        }
        return drafts
    }

    static func parseCandidates(from text: String) throws -> [MealNutritionCandidate] {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start <= end else {
            throw AIClientError.providerError("AI 未返回有效的候选食物 JSON")
        }
        let jsonString = String(text[start...end])
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = object["candidates"] as? [[String: Any]] else {
            throw AIClientError.providerError("AI 返回的候选食物格式无法解析")
        }

        let candidates: [MealNutritionCandidate] = records.compactMap { dict in
            var candidate = MealNutritionCandidate()
            candidate.name = stringValue(dict["name"]) ?? ""
            candidate.sourceNote = stringValue(dict["source"]) ?? ""
            return candidate.isValid ? candidate : nil
        }
        guard !candidates.isEmpty else {
            throw AIClientError.providerError("未能识别到食物名称，请在文字里补充后重试。")
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
                .trimmingCharacters(in: CharacterSet(charactersIn: " kcalgmugm毫升克ml"))
            return Double(cleaned)
        }
        return nil
    }

    /// 营养标签需要保留小字体清晰度：发送前才做适度缩放和压缩。
    /// 先将长边控制在 1600，再在仍超过 2MB 时逐步降低质量，避免过早损失 OCR 所需细节。
    private static func prepareImageForVision(
        _ data: Data,
        maxDimension: CGFloat = 1600,
        quality: CGFloat = 0.88,
        maxBytes: Int = 2_000_000
    ) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let renderedImage: UIImage
        if max(size.width, size.height) > maxDimension {
            let scale = maxDimension / max(size.width, size.height)
            let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
            let renderer = UIGraphicsImageRenderer(size: newSize)
            renderedImage = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            renderedImage = image
        }

        var currentQuality = quality
        var compressed = renderedImage.jpegData(compressionQuality: currentQuality)
        while let result = compressed, result.count > maxBytes, currentQuality > 0.55 {
            currentQuality -= 0.05
            compressed = renderedImage.jpegData(compressionQuality: currentQuality)
        }
        return compressed ?? data
    }
}
