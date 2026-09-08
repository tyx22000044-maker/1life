import Foundation
import SwiftData

// MARK: - 饮品知识库记录

enum DrinkConfidence: String, CaseIterable, Codable, Identifiable {
    case high = "高"
    case medium = "中"
    case low = "低"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high: return "高（官方数据）"
        case .medium: return "中（第三方实测）"
        case .low: return "低（估算）"
        }
    }
}

enum DrinkAdjustmentPolicy {
    struct CalorieRange {
        let min: Double
        let max: Double

        var midpoint: Double { (min + max) / 2 }
        var displayText: String { "+\(Int(min))-\(Int(max)) kcal" }
    }

    enum SugarLevel: String, CaseIterable {
        case noSugar = "无糖"
        case light = "三分糖"
        case half = "五分糖"
        case less = "七分糖"
        case standard = "标准糖"

        var calorieRange: CalorieRange {
            switch self {
            case .noSugar: return CalorieRange(min: 0, max: 0)
            case .light: return CalorieRange(min: 20, max: 30)
            case .half: return CalorieRange(min: 40, max: 50)
            case .less: return CalorieRange(min: 60, max: 80)
            case .standard: return CalorieRange(min: 90, max: 110)
            }
        }
    }

    enum IceLevel: String, CaseIterable {
        case normal = "正常冰"
        case less = "少冰"
        case noIce = "去冰"
        case hot = "热饮"
        case smoothie = "冰沙"

        var calorieRange: CalorieRange {
            switch self {
            case .normal: return CalorieRange(min: 0, max: 0)
            case .less: return CalorieRange(min: 20, max: 25)
            case .noIce, .hot: return CalorieRange(min: 35, max: 50)
            case .smoothie: return CalorieRange(min: 40, max: 60)
            }
        }
    }

    static let promptText = """
    现制饮品热量调整统一策略（以默认无糖/正常冰热量为基线，若有官方精确糖度/冰量数据则优先官方数据）：
    - 冰量：少冰 +20-25 kcal；去冰/热饮 +35-50 kcal；冰沙 +40-60 kcal；正常冰 +0 kcal。
    - 甜度：三分糖 +20-30 kcal；五分糖/半糖 +40-50 kcal；七分糖/少糖 +60-80 kcal；标准糖/全糖/正常糖/标准甜 +90-110 kcal；无糖/零糖/0糖 +0 kcal。
    - “不另外加糖/无额外糖”不等于总糖 0，应保留奶、水果、小料、配方基础糖。
    - 做过冰量或甜度估算时，nutrition_data_note 必须写明基线和增量。
    """

    nonisolated static func canonicalSugarLevel(in text: String) -> SugarLevel? {
        let normalized = normalize(text)
        for (alias, level) in sugarAliases {
            if normalized.contains(alias) { return level }
        }
        return nil
    }

    nonisolated static func canonicalIceLevel(in text: String) -> IceLevel? {
        let normalized = normalize(text)
        for (alias, level) in iceAliases {
            if normalized.contains(alias) { return level }
        }
        return nil
    }

    nonisolated static func canonicalSugarText(_ text: String) -> String {
        canonicalSugarLevel(in: text)?.rawValue ?? text
    }

    nonisolated static func normalize(_ text: String) -> String {
        let converted = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        return converted
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .lowercased()
    }

    private nonisolated static let sugarAliases: [(String, SugarLevel)] = [
        ("无糖", .noSugar),
        ("零糖", .noSugar),
        ("0糖", .noSugar),
        ("微糖", .light),
        ("微甜", .light),
        ("三分糖", .light),
        ("3分糖", .light),
        ("五分糖", .half),
        ("5分糖", .half),
        ("半糖", .half),
        ("七分糖", .less),
        ("7分糖", .less),
        ("少糖", .less),
        ("标准糖", .standard),
        ("标准甜", .standard),
        ("正常糖", .standard),
        ("全糖", .standard)
    ]

    private nonisolated static let iceAliases: [(String, IceLevel)] = [
        ("少冰", .less),
        ("去冰", .noIce),
        ("不加冰", .noIce),
        ("热饮", .hot),
        ("热的", .hot),
        ("冰沙", .smoothie),
        ("正常冰", .normal),
        ("标准冰", .normal)
    ]
}

@Model
final class DrinkRecord {
    var id: UUID
    var brand: String
    var productName: String
    /// 规格，单位 ml；未知为 nil
    var sizeML: Double?
    /// 糖度版本，如 全糖/七分糖/少糖/无糖；未标注为空字符串
    var sugarLevel: String
    /// 小料说明，如 "珍珠"、"椰果"；无小料为空字符串
    var toppings: String
    /// 以下营养数值均为整杯值；未知为 nil
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var sugar: Double?
    /// 钠，单位 mg
    var sodium: Double?
    /// 咖啡因，单位 mg
    var caffeine: Double?
    /// 茶多酚，单位 mg
    var teaPolyphenols: Double?
    var sourceNote: String
    var sourceDate: Date
    var confidenceRaw: String = DrinkConfidence.medium.rawValue
    var createdAt: Date
    var updatedAt: Date

    init(brand: String,
         productName: String,
         sizeML: Double? = nil,
         sugarLevel: String = "",
         toppings: String = "",
         calories: Double? = nil,
         protein: Double? = nil,
         carbs: Double? = nil,
         fat: Double? = nil,
         sugar: Double? = nil,
         sodium: Double? = nil,
         caffeine: Double? = nil,
         teaPolyphenols: Double? = nil,
         sourceNote: String = "",
         sourceDate: Date = .now,
         confidence: DrinkConfidence = .medium) {
        self.id = UUID()
        self.brand = brand
        self.productName = productName
        self.sizeML = sizeML
        self.sugarLevel = sugarLevel
        self.toppings = toppings
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.sugar = sugar
        self.sodium = sodium
        self.caffeine = caffeine
        self.teaPolyphenols = teaPolyphenols
        self.sourceNote = sourceNote
        self.sourceDate = sourceDate
        self.confidenceRaw = confidence.rawValue
        self.createdAt = .now
        self.updatedAt = .now
    }

    var confidence: DrinkConfidence {
        get { DrinkConfidence(rawValue: confidenceRaw) ?? .medium }
        set { confidenceRaw = newValue.rawValue }
    }

    /// 展示名，如 "喜茶 多肉葡萄（650ml·少糖）"
    var displayName: String {
        var specs: [String] = []
        if let sizeML { specs.append("\(Int(sizeML))ml") }
        if !sugarLevel.isEmpty { specs.append(sugarLevel) }
        if !toppings.isEmpty { specs.append(toppings) }
        let suffix = specs.isEmpty ? "" : "（\(specs.joined(separator: "·"))）"
        return "\(brand) \(productName)\(suffix)"
    }

    /// 去重键：品牌+商品+规格+糖度+小料/冰量版本
    var dedupeKey: String {
        DrinkLibraryIndex.normalize("\(brand)|\(productName)|\(sizeML.map { String(Int($0)) } ?? "")|\(sugarLevel)|\(toppings)")
    }
}

// MARK: - 内存索引

/// 饮品知识库的内存快照条目（值类型，避免跨上下文持有 @Model 引用）
struct DrinkLibraryEntry {
    let brand: String
    let productName: String
    let sizeML: Double?
    let sugarLevel: String
    let toppings: String
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let sugar: Double?
    let sodium: Double?
    let caffeine: Double?
    let teaPolyphenols: Double?
    let sourceNote: String
    let confidence: DrinkConfidence

    var displayName: String {
        var specs: [String] = []
        if let sizeML { specs.append("\(Int(sizeML))ml") }
        if !sugarLevel.isEmpty { specs.append(sugarLevel) }
        if !toppings.isEmpty { specs.append(toppings) }
        let suffix = specs.isEmpty ? "" : "（\(specs.joined(separator: "·"))）"
        return "\(brand) \(productName)\(suffix)"
    }

    init(record: DrinkRecord) {
        self.brand = record.brand
        self.productName = record.productName
        self.sizeML = record.sizeML
        self.sugarLevel = record.sugarLevel
        self.toppings = record.toppings
        self.calories = record.calories
        self.protein = record.protein
        self.carbs = record.carbs
        self.fat = record.fat
        self.sugar = record.sugar
        self.sodium = record.sodium
        self.caffeine = record.caffeine
        self.teaPolyphenols = record.teaPolyphenols
        self.sourceNote = record.sourceNote
        self.confidence = record.confidence
    }
}

struct DrinkLibraryMatch {
    enum MatchKind {
        case exactVersion
        case uniqueProduct
        case baselineAdjusted
        case defaultVersion

        var note: String {
            switch self {
            case .exactVersion:
                return "饮品知识库精确命中"
            case .uniqueProduct:
                return "饮品知识库商品名唯一命中"
            case .baselineAdjusted:
                return "饮品知识库基线命中"
            case .defaultVersion:
                return "饮品知识库默认版本命中"
            }
        }
    }

    let entry: DrinkLibraryEntry
    let kind: MatchKind
}

/// 全局内存索引：App 运行期间只从 SwiftData 加载一次，数据变更后标记失效再重建。
/// AI 识别饮品时查这里，不重复读库。
@MainActor
final class DrinkLibraryIndex {
    static let shared = DrinkLibraryIndex()

    private var entries: [DrinkLibraryEntry] = []
    private var isLoaded = false

    private init() {}

    var count: Int { entries.count }

    /// 数据写入/删除后调用，下次查询时自动重建
    func invalidate() {
        isLoaded = false
    }

    func rebuildIfNeeded(using context: ModelContext) {
        guard !isLoaded else { return }
        let descriptor = FetchDescriptor<DrinkRecord>()
        let records = (try? context.fetch(descriptor)) ?? []
        entries = records.map(DrinkLibraryEntry.init)
        isLoaded = true
    }

    /// 从自由文本（如"喝了杯喜茶多肉葡萄少糖"）中匹配饮品记录。
    /// 优先品牌+商品名；如果商品名在库中唯一，也允许只凭商品名命中。
    func match(text: String) -> DrinkLibraryEntry? {
        matchResult(text: text)?.entry
    }

    func matchResult(text: String) -> DrinkLibraryMatch? {
        let normalized = Self.normalize(text)
        guard !normalized.isEmpty else { return nil }

        let brandProductCandidates = entries.filter { entry in
            let brand = Self.normalize(entry.brand)
            let product = Self.normalize(entry.productName)
            guard !product.isEmpty else { return false }
            if brand.isEmpty {
                return normalized.contains(product)
            }
            return normalized.contains(brand) && normalized.contains(product)
        }

        if !brandProductCandidates.isEmpty {
            return bestMatch(from: brandProductCandidates, text: normalized, productOnly: false)
        }

        let productCandidates = entries.filter { entry in
            let product = Self.normalize(entry.productName)
            return !product.isEmpty && normalized.contains(product)
        }
        guard !productCandidates.isEmpty else { return nil }

        let uniqueBrandProducts = Set(productCandidates.map { "\(Self.normalize($0.brand))|\(Self.normalize($0.productName))" })
        guard uniqueBrandProducts.count == 1 else { return nil }
        return bestMatch(from: productCandidates, text: normalized, productOnly: true)
    }

    /// 商品名模糊搜索（管理页/模板库合集用）
    func search(_ query: String) -> [DrinkLibraryEntry] {
        let q = Self.normalize(query)
        guard !q.isEmpty else { return entries }
        return entries.filter {
            Self.normalize($0.brand).contains(q)
                || Self.normalize($0.productName).contains(q)
                || Self.normalize("\($0.brand)\($0.productName)").contains(q)
                || Self.normalize($0.sugarLevel).contains(q)
                || Self.normalize($0.toppings).contains(q)
                || Self.normalize($0.sourceNote).contains(q)
        }
    }

    private func confidenceRank(_ confidence: DrinkConfidence) -> Int {
        switch confidence {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    private func defaultEntry(from candidates: [DrinkLibraryEntry]) -> DrinkLibraryEntry? {
        candidates.min { lhs, rhs in
            let lhsScore = defaultScore(lhs)
            let rhsScore = defaultScore(rhs)
            if lhsScore != rhsScore { return lhsScore < rhsScore }

            let lhsConfidence = confidenceRank(lhs.confidence)
            let rhsConfidence = confidenceRank(rhs.confidence)
            if lhsConfidence != rhsConfidence { return lhsConfidence < rhsConfidence }

            let lhsHasCalories = lhs.calories == nil ? 1 : 0
            let rhsHasCalories = rhs.calories == nil ? 1 : 0
            if lhsHasCalories != rhsHasCalories { return lhsHasCalories < rhsHasCalories }

            return (lhs.sizeML ?? 500) < (rhs.sizeML ?? 500)
        }
    }

    private func bestMatch(from candidates: [DrinkLibraryEntry], text normalized: String, productOnly: Bool) -> DrinkLibraryMatch? {
        if let requestedSugar = DrinkAdjustmentPolicy.canonicalSugarLevel(in: normalized),
           let sugarMatch = bestEntry(candidates.filter { entry in
               DrinkAdjustmentPolicy.canonicalSugarLevel(in: entry.sugarLevel) == requestedSugar
           }) {
            return DrinkLibraryMatch(entry: sugarMatch, kind: .exactVersion)
        }

        if let variantMatch = bestEntry(candidates.filter({ entry in
            let variant = Self.normalize(entry.toppings)
            return !variant.isEmpty && normalized.contains(variant)
        })) {
            return DrinkLibraryMatch(entry: variantMatch, kind: .exactVersion)
        }

        if DrinkAdjustmentPolicy.canonicalSugarLevel(in: normalized) != nil,
           let baseline = bestEntry(candidates.filter({ entry in
               DrinkAdjustmentPolicy.canonicalSugarLevel(in: entry.sugarLevel) == .noSugar
           })) {
            return DrinkLibraryMatch(entry: baseline, kind: .baselineAdjusted)
        }

        guard let defaultMatch = defaultEntry(from: candidates) else { return nil }
        return DrinkLibraryMatch(entry: defaultMatch, kind: productOnly ? .uniqueProduct : .defaultVersion)
    }

    private func bestEntry(_ candidates: [DrinkLibraryEntry]) -> DrinkLibraryEntry? {
        guard !candidates.isEmpty else { return nil }
        return defaultEntry(from: candidates)
    }

    private func defaultScore(_ entry: DrinkLibraryEntry) -> Int {
        let version = Self.normalize("\(entry.sugarLevel)\(entry.toppings)\(entry.sourceNote)")
        if version.contains("默认") || version.contains("标准") || version.contains("正常") { return 0 }
        if entry.sugarLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && entry.toppings.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return 1
        }
        return 2
    }

    /// 规范化：去空白、转小写、全角转半角、统一常见糖度别名
    nonisolated static func normalize(_ text: String) -> String {
        var result = DrinkAdjustmentPolicy.normalize(text)
        for (alias, canonical) in Self.normalizationAliases {
            result = result.replacingOccurrences(of: alias, with: canonical)
        }
        return result
    }

    private nonisolated static let normalizationAliases: [(String, String)] = [
        ("0糖", "无糖"),
        ("零糖", "无糖"),
        ("标准甜", "标准糖"),
        ("正常糖", "标准糖"),
        ("全糖", "标准糖"),
        ("半糖", "五分糖"),
        ("5分糖", "五分糖"),
        ("3分糖", "三分糖"),
        ("7分糖", "七分糖"),
        ("少糖", "七分糖"),
        ("不加冰", "去冰")
    ]
}
