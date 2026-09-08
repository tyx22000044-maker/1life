import Foundation
import SwiftData

// MARK: - 补剂知识库记录

enum SupplementConfidence: String, CaseIterable, Codable, Identifiable {
    case high = "高"
    case medium = "中"
    case low = "低"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high: return "高（官方标签/说明书）"
        case .medium: return "中（第三方检测/电商详情页）"
        case .low: return "低（估算）"
        }
    }
}

@Model
final class SupplementRecord {
    var id: UUID
    var brand: String
    var productName: String
    /// 剂型，如 片剂/胶囊/软糖/粉剂/液体；未知为空字符串
    var form: String
    /// 每份说明，如 "2粒"、"1勺(约5g)"、"10ml"；未知为空字符串
    var servingSize: String
    /// 以下均为"每份"数值（对齐说明书计量口径，不做每100g折算）；未知为 nil
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
    /// 自由文本兜底：标准字段覆盖不到的活性成分，如"肌酸一水合物5g；EPA 180mg；DHA 120mg"
    var activeIngredientsNote: String
    var sourceNote: String
    var sourceDate: Date
    var confidenceRaw: String = SupplementConfidence.medium.rawValue
    var createdAt: Date
    var updatedAt: Date

    init(brand: String,
         productName: String,
         form: String = "",
         servingSize: String = "",
         calories: Double? = nil,
         protein: Double? = nil,
         carbs: Double? = nil,
         fat: Double? = nil,
         sodium: Double? = nil,
         calcium: Double? = nil,
         magnesium: Double? = nil,
         potassium: Double? = nil,
         iron: Double? = nil,
         zinc: Double? = nil,
         vitaminA: Double? = nil,
         vitaminC: Double? = nil,
         vitaminD: Double? = nil,
         vitaminE: Double? = nil,
         vitaminB1: Double? = nil,
         vitaminB2: Double? = nil,
         niacin: Double? = nil,
         vitaminB6: Double? = nil,
         folate: Double? = nil,
         vitaminB12: Double? = nil,
         activeIngredientsNote: String = "",
         sourceNote: String = "",
         sourceDate: Date = .now,
         confidence: SupplementConfidence = .medium) {
        self.id = UUID()
        self.brand = brand
        self.productName = productName
        self.form = form
        self.servingSize = servingSize
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.sodium = sodium
        self.calcium = calcium
        self.magnesium = magnesium
        self.potassium = potassium
        self.iron = iron
        self.zinc = zinc
        self.vitaminA = vitaminA
        self.vitaminC = vitaminC
        self.vitaminD = vitaminD
        self.vitaminE = vitaminE
        self.vitaminB1 = vitaminB1
        self.vitaminB2 = vitaminB2
        self.niacin = niacin
        self.vitaminB6 = vitaminB6
        self.folate = folate
        self.vitaminB12 = vitaminB12
        self.activeIngredientsNote = activeIngredientsNote
        self.sourceNote = sourceNote
        self.sourceDate = sourceDate
        self.confidenceRaw = confidence.rawValue
        self.createdAt = .now
        self.updatedAt = .now
    }

    var confidence: SupplementConfidence {
        get { SupplementConfidence(rawValue: confidenceRaw) ?? .medium }
        set { confidenceRaw = newValue.rawValue }
    }

    /// 展示名，如 "XX品牌 鱼油（软胶囊·1粒）"
    var displayName: String {
        var specs: [String] = []
        if !form.isEmpty { specs.append(form) }
        if !servingSize.isEmpty { specs.append(servingSize) }
        let suffix = specs.isEmpty ? "" : "（\(specs.joined(separator: "·"))）"
        return "\(brand) \(productName)\(suffix)"
    }

    /// 去重键：品牌+商品+剂型+规格版本
    var dedupeKey: String {
        SupplementLibraryIndex.normalize("\(brand)|\(productName)|\(form)|\(servingSize)")
    }
}

// MARK: - 内存索引

/// 补剂知识库的内存快照条目（值类型，避免跨上下文持有 @Model 引用）
struct SupplementLibraryEntry {
    let brand: String
    let productName: String
    let form: String
    let servingSize: String
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let sodium: Double?
    let calcium: Double?
    let magnesium: Double?
    let potassium: Double?
    let iron: Double?
    let zinc: Double?
    let vitaminA: Double?
    let vitaminC: Double?
    let vitaminD: Double?
    let vitaminE: Double?
    let vitaminB1: Double?
    let vitaminB2: Double?
    let niacin: Double?
    let vitaminB6: Double?
    let folate: Double?
    let vitaminB12: Double?
    let activeIngredientsNote: String
    let sourceNote: String
    let confidence: SupplementConfidence

    var displayName: String {
        var specs: [String] = []
        if !form.isEmpty { specs.append(form) }
        if !servingSize.isEmpty { specs.append(servingSize) }
        let suffix = specs.isEmpty ? "" : "（\(specs.joined(separator: "·"))）"
        return "\(brand) \(productName)\(suffix)"
    }

    init(record: SupplementRecord) {
        self.brand = record.brand
        self.productName = record.productName
        self.form = record.form
        self.servingSize = record.servingSize
        self.calories = record.calories
        self.protein = record.protein
        self.carbs = record.carbs
        self.fat = record.fat
        self.sodium = record.sodium
        self.calcium = record.calcium
        self.magnesium = record.magnesium
        self.potassium = record.potassium
        self.iron = record.iron
        self.zinc = record.zinc
        self.vitaminA = record.vitaminA
        self.vitaminC = record.vitaminC
        self.vitaminD = record.vitaminD
        self.vitaminE = record.vitaminE
        self.vitaminB1 = record.vitaminB1
        self.vitaminB2 = record.vitaminB2
        self.niacin = record.niacin
        self.vitaminB6 = record.vitaminB6
        self.folate = record.folate
        self.vitaminB12 = record.vitaminB12
        self.activeIngredientsNote = record.activeIngredientsNote
        self.sourceNote = record.sourceNote
        self.confidence = record.confidence
    }
}

struct SupplementLibraryMatch {
    enum MatchKind {
        case exactVersion
        case uniqueProduct
        case defaultVersion

        var note: String {
            switch self {
            case .exactVersion:
                return "补剂知识库精确命中"
            case .uniqueProduct:
                return "补剂知识库商品名唯一命中"
            case .defaultVersion:
                return "补剂知识库默认版本命中"
            }
        }
    }

    let entry: SupplementLibraryEntry
    let kind: MatchKind
}

/// 全局内存索引：App 运行期间只从 SwiftData 加载一次，数据变更后标记失效再重建。
/// AI 识别补剂时查这里，不重复读库。
@MainActor
final class SupplementLibraryIndex {
    static let shared = SupplementLibraryIndex()

    private var entries: [SupplementLibraryEntry] = []
    private var isLoaded = false

    private init() {}

    var count: Int { entries.count }

    /// 数据写入/删除后调用，下次查询时自动重建
    func invalidate() {
        isLoaded = false
    }

    func rebuildIfNeeded(using context: ModelContext) {
        guard !isLoaded else { return }
        let descriptor = FetchDescriptor<SupplementRecord>()
        let records = (try? context.fetch(descriptor)) ?? []
        entries = records.map(SupplementLibraryEntry.init)
        isLoaded = true
    }

    /// 从自由文本（如"吃了2粒XX牌鱼油"）中匹配补剂记录。
    /// 优先品牌+商品名；如果商品名在库中唯一，也允许只凭商品名命中。
    func match(text: String) -> SupplementLibraryEntry? {
        matchResult(text: text)?.entry
    }

    func matchResult(text: String) -> SupplementLibraryMatch? {
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

    /// 商品名模糊搜索（库管理页用）
    func search(_ query: String) -> [SupplementLibraryEntry] {
        let q = Self.normalize(query)
        guard !q.isEmpty else { return entries }
        return entries.filter {
            Self.normalize($0.brand).contains(q)
                || Self.normalize($0.productName).contains(q)
                || Self.normalize("\($0.brand)\($0.productName)").contains(q)
                || Self.normalize($0.form).contains(q)
                || Self.normalize($0.activeIngredientsNote).contains(q)
                || Self.normalize($0.sourceNote).contains(q)
        }
    }

    private func confidenceRank(_ confidence: SupplementConfidence) -> Int {
        switch confidence {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    private func defaultEntry(from candidates: [SupplementLibraryEntry]) -> SupplementLibraryEntry? {
        candidates.min { lhs, rhs in
            let lhsScore = defaultScore(lhs)
            let rhsScore = defaultScore(rhs)
            if lhsScore != rhsScore { return lhsScore < rhsScore }

            let lhsConfidence = confidenceRank(lhs.confidence)
            let rhsConfidence = confidenceRank(rhs.confidence)
            if lhsConfidence != rhsConfidence { return lhsConfidence < rhsConfidence }

            let lhsHasCalories = lhs.calories == nil ? 1 : 0
            let rhsHasCalories = rhs.calories == nil ? 1 : 0
            return lhsHasCalories < rhsHasCalories
        }
    }

    /// 剂型（form）是候选收窄的关键维度：同品牌同商品名可能有片剂版和粉剂版，营养值不同。
    private func bestMatch(from candidates: [SupplementLibraryEntry], text normalized: String, productOnly: Bool) -> SupplementLibraryMatch? {
        if let formMatch = bestEntry(candidates.filter({ entry in
            let form = Self.normalize(entry.form)
            return !form.isEmpty && normalized.contains(form)
        })) {
            return SupplementLibraryMatch(entry: formMatch, kind: .exactVersion)
        }

        guard let defaultMatch = defaultEntry(from: candidates) else { return nil }
        return SupplementLibraryMatch(entry: defaultMatch, kind: productOnly ? .uniqueProduct : .defaultVersion)
    }

    private func bestEntry(_ candidates: [SupplementLibraryEntry]) -> SupplementLibraryEntry? {
        guard !candidates.isEmpty else { return nil }
        return defaultEntry(from: candidates)
    }

    private func defaultScore(_ entry: SupplementLibraryEntry) -> Int {
        let version = Self.normalize("\(entry.form)\(entry.servingSize)\(entry.sourceNote)")
        if version.contains("默认") || version.contains("标准") || version.contains("正常") { return 0 }
        if entry.form.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && entry.servingSize.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return 1
        }
        return 2
    }

    /// 规范化：去空白、转小写、全角转半角
    nonisolated static func normalize(_ text: String) -> String {
        let converted = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        return converted
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .lowercased()
    }
}
