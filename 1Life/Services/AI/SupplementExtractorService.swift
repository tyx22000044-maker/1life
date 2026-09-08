import Foundation
import UIKit

// MARK: - 提取结果草稿（识别后可编辑，确认入库前的中间态）

struct SupplementExtractedDraft: Identifiable {
    let id = UUID()
    var brand: String = ""
    var productName: String = ""
    var form: String = ""
    var servingSize: String = ""
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var sodium: Double?
    var calcium: Double?
    var magnesium: Double?
    var potassium: Double?
    var iron: Double?
    var zinc: Double?
    var vitaminA: Double?
    var vitaminC: Double?
    var vitaminD: Double?
    var vitaminE: Double?
    var vitaminB1: Double?
    var vitaminB2: Double?
    var niacin: Double?
    var vitaminB6: Double?
    var folate: Double?
    var vitaminB12: Double?
    var activeIngredientsNote: String = ""
    var sourceNote: String = ""
    var confidence: SupplementConfidence = .medium

    /// 补剂不像饮品那样把"热量"当硬门槛——纯维生素/矿物质补剂通常没有热量，
    /// 只要品牌、商品名齐全，且至少有一个营养/活性成分字段非空即可入库。
    var isValid: Bool {
        guard !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        let hasAnyNutrient = [calories, protein, carbs, fat, sodium, calcium, magnesium, potassium,
                               iron, zinc, vitaminA, vitaminC, vitaminD, vitaminE, vitaminB1, vitaminB2,
                               niacin, vitaminB6, folate, vitaminB12].contains { $0 != nil }
        let hasActiveIngredients = !activeIngredientsNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasAnyNutrient || hasActiveIngredients
    }

    func makeRecord(sourceDate: Date = .now) -> SupplementRecord {
        SupplementRecord(
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            productName: productName.trimmingCharacters(in: .whitespacesAndNewlines),
            form: form.trimmingCharacters(in: .whitespacesAndNewlines),
            servingSize: servingSize.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            sodium: sodium,
            calcium: calcium,
            magnesium: magnesium,
            potassium: potassium,
            iron: iron,
            zinc: zinc,
            vitaminA: vitaminA,
            vitaminC: vitaminC,
            vitaminD: vitaminD,
            vitaminE: vitaminE,
            vitaminB1: vitaminB1,
            vitaminB2: vitaminB2,
            niacin: niacin,
            vitaminB6: vitaminB6,
            folate: folate,
            vitaminB12: vitaminB12,
            activeIngredientsNote: activeIngredientsNote.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceNote: sourceNote.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceDate: sourceDate,
            confidence: confidence
        )
    }
}

struct SupplementCandidate: Identifiable {
    let id = UUID()
    var brand: String = ""
    var productName: String = ""
    var form: String = ""
    var sourceNote: String = ""
    var isSelected: Bool = true

    var isValid: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var promptLine: String {
        var parts = [
            "品牌：\(brand.trimmingCharacters(in: .whitespacesAndNewlines))",
            "商品名：\(productName.trimmingCharacters(in: .whitespacesAndNewlines))"
        ]
        if !form.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("剂型：\(form.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        if !sourceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("来源线索：\(sourceNote.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return parts.joined(separator: "；")
    }
}

// MARK: - 提取服务

struct SupplementExtractorService {
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
    private var model: String { settings.effectiveSupplementPluginAIModel }

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

        var userMessage = "请逐张读取图片中的所有可见文字，尤其是品牌、商品名、剂型、每份剂量、营养成分表/活性成分表、建议摄入量、来源信息。只输出纯文本，不要总结，不要 JSON。"
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

    /// 第二步：先从校对后的文字里找出候选补剂，供用户确认范围。
    func identifyCandidates(fromConfirmedText text: String) async throws -> [SupplementCandidate] {
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

    /// 第三步：只围绕用户确认的候选补剂提取营养/活性成分。
    func extract(fromConfirmedText text: String, candidates: [SupplementCandidate]) async throws -> [SupplementExtractedDraft] {
        let selected = candidates.filter(\.isSelected).filter(\.isValid)
        let candidateText = selected.enumerated()
            .map { index, candidate in "\(index + 1). \(candidate.promptLine)" }
            .joined(separator: "\n")
        let userText = """
        已确认要入库的补剂：
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
    你是补剂营养标签 OCR 助手。任务只有一个：尽可能完整地抄录图片里的文字。
    规则：
    - 多张图片按顺序输出，使用"图片1/图片2"分隔。
    - 保留品牌、商品名、剂型（片剂/胶囊/软糖/粉剂/液体等）、每份剂量、营养成分表/活性成分表、建议摄入量、单位、来源信息。
    - 看不清的文字用 [?] 标记，不要猜。
    - 不要换算，不要整理成 JSON，不要解释。
    """

    static let candidatePrompt = """
    你是补剂候选识别器。输入是用户校对后的 OCR/手写文字。
    任务：只找出可能要入库的补剂候选，不提取营养，不计算数值。

    规则：
    - 只输出能看出品牌和商品名的候选。
    - 同一商品有不同剂型（如片剂版/粉剂版）时可以拆成多条，剂型信息务必保留，是后续区分候选的关键。
    - source 写简短线索，如"图片1营养标签""用户补充说明"。
    - 不要输出解释，不要 markdown。

    只输出这个结构：
    {"candidates":[{"brand":"品牌","name":"商品名","form":"胶囊","source":"图片1营养标签"}]}
    """

    static let targetedStructuringPrompt = """
    你是补剂营养文字整理器。输入包含两部分：用户确认的候选补剂，以及校对后的 OCR/手写原文。
    任务：只针对候选补剂提取营养素和活性成分，输出 JSON，不要解释。

    最低记录门槛：
    - brand 必须来自候选补剂
    - name 必须来自候选补剂
    - 不要求必须有热量：很多补剂（维生素、矿物质、鱼油等）本身没有热量，只要至少能提取出一个营养素或活性成分即可输出该记录。
    其它字段无法确认就填 null 或空字符串，绝不编造，尤其不要为了补齐剂量而编造官方数据。

    字段要求：
    - form: 剂型，如 片剂/胶囊/软糖/粉剂/液体；未知填 ""。
    - serving_size: 每份说明，如"2粒""1勺(约5g)""10ml"；未知填 ""，不要估算。
    - calories_kcal/protein_g/carbs_g/fat_g: 仅蛋白粉、代餐粉等食物型补剂适用；普通维生素/矿物质/单一成分补剂通常没有，填 null。
    - sodium_mg/calcium_mg/magnesium_mg/potassium_mg/iron_mg/zinc_mg/vitamin_a_ug/vitamin_c_mg/vitamin_d_ug/vitamin_e_mg/
      vitamin_b1_mg/vitamin_b2_mg/niacin_mg/vitamin_b6_mg/folate_ug/vitamin_b12_ug：每份剂量，原文明确标注才填，未标注填 null。
    - active_ingredients_note: 上面标准字段无法承载的活性成分，必须写明剂量和单位，如"肌酸一水合物5g；EPA 180mg；DHA 120mg；益生菌100亿CFU"；
      不要把标准字段已经覆盖的成分重复写进这里；没有这类成分时填 ""。
    - source: 用简短文字说明来源，如"包装营养标签照片"。
    - confidence: 官方标签/说明书清晰可读为"高"，信息不完整为"中"，估算或来源不明为"低"。

    只输出这个结构（未提及的字段一律用 null 或 ""，不要省略 key）：
    {"records":[{"brand":"品牌","name":"商品名","form":"胶囊","serving_size":"2粒","calories_kcal":null,"protein_g":null,"carbs_g":null,"fat_g":null,"sodium_mg":null,"calcium_mg":null,"magnesium_mg":null,"potassium_mg":null,"iron_mg":null,"zinc_mg":null,"vitamin_a_ug":null,"vitamin_c_mg":null,"vitamin_d_ug":null,"vitamin_e_mg":null,"vitamin_b1_mg":null,"vitamin_b2_mg":null,"niacin_mg":null,"vitamin_b6_mg":null,"folate_ug":null,"vitamin_b12_ug":null,"active_ingredients_note":"鱼油 EPA 180mg；DHA 120mg","source":"包装营养标签照片","confidence":"高"}]}
    """

    // MARK: - 解析

    /// 解析模型输出的 JSON，容忍 markdown 代码块包裹、前后杂质文本、数字以字符串形式返回等常见情况
    static func parseDrafts(from text: String) throws -> [SupplementExtractedDraft] {
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

        let drafts: [SupplementExtractedDraft] = records.compactMap { dict in
            var draft = SupplementExtractedDraft()
            draft.brand = stringValue(dict["brand"]) ?? ""
            draft.productName = stringValue(dict["name"]) ?? ""
            draft.form = stringValue(dict["form"]) ?? ""
            draft.servingSize = stringValue(dict["serving_size"]) ?? ""
            draft.calories = doubleValue(dict["calories_kcal"])
            draft.protein = doubleValue(dict["protein_g"])
            draft.carbs = doubleValue(dict["carbs_g"])
            draft.fat = doubleValue(dict["fat_g"])
            draft.sodium = doubleValue(dict["sodium_mg"])
            draft.calcium = doubleValue(dict["calcium_mg"])
            draft.magnesium = doubleValue(dict["magnesium_mg"])
            draft.potassium = doubleValue(dict["potassium_mg"])
            draft.iron = doubleValue(dict["iron_mg"])
            draft.zinc = doubleValue(dict["zinc_mg"])
            draft.vitaminA = doubleValue(dict["vitamin_a_ug"])
            draft.vitaminC = doubleValue(dict["vitamin_c_mg"])
            draft.vitaminD = doubleValue(dict["vitamin_d_ug"])
            draft.vitaminE = doubleValue(dict["vitamin_e_mg"])
            draft.vitaminB1 = doubleValue(dict["vitamin_b1_mg"])
            draft.vitaminB2 = doubleValue(dict["vitamin_b2_mg"])
            draft.niacin = doubleValue(dict["niacin_mg"])
            draft.vitaminB6 = doubleValue(dict["vitamin_b6_mg"])
            draft.folate = doubleValue(dict["folate_ug"])
            draft.vitaminB12 = doubleValue(dict["vitamin_b12_ug"])
            draft.activeIngredientsNote = stringValue(dict["active_ingredients_note"]) ?? ""
            draft.sourceNote = stringValue(dict["source"]) ?? ""
            draft.confidence = SupplementConfidence(rawValue: stringValue(dict["confidence"]) ?? "") ?? .medium
            return draft.isValid ? draft : nil
        }
        guard !drafts.isEmpty else {
            throw AIClientError.providerError("未能从图片或文字中提取到补剂数据，请换更清晰的标签照片重试。")
        }
        return drafts
    }

    static func parseCandidates(from text: String) throws -> [SupplementCandidate] {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start <= end else {
            throw AIClientError.providerError("AI 未返回有效的候选补剂 JSON")
        }
        let jsonString = String(text[start...end])
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = object["candidates"] as? [[String: Any]] else {
            throw AIClientError.providerError("AI 返回的候选补剂格式无法解析")
        }

        let candidates: [SupplementCandidate] = records.compactMap { dict in
            var candidate = SupplementCandidate()
            candidate.brand = stringValue(dict["brand"]) ?? ""
            candidate.productName = stringValue(dict["name"]) ?? ""
            candidate.form = stringValue(dict["form"]) ?? ""
            candidate.sourceNote = stringValue(dict["source"]) ?? ""
            return candidate.isValid ? candidate : nil
        }
        guard !candidates.isEmpty else {
            throw AIClientError.providerError("未能识别到品牌和商品名，请在文字里补充后重试。")
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
