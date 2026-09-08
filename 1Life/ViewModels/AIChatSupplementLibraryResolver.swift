import Foundation
import SwiftData

@MainActor
struct AIChatSupplementLibraryResolver {
    static func applyMatch(
        to result: AIChatIntentResult,
        originalText: String,
        modelContext: ModelContext?
    ) -> AIChatIntentResult {
        guard let modelContext else { return result }
        SupplementLibraryIndex.shared.rebuildIfNeeded(using: modelContext)
        guard let match = SupplementLibraryIndex.shared.matchResult(text: originalText) else { return result }

        switch result {
        case .addMeal(let meal):
            return .addMeal(applyMatch(match, to: meal, originalText: originalText))
        case .addMeals(let meals):
            return .addMeals(meals.map { applyMatch(match, to: $0, originalText: originalText) })
        case .batch(let actions):
            return .batch(actions.map { applyMatch(to: $0, originalText: originalText, modelContext: modelContext) })
        default:
            return result
        }
    }

    private static func applyMatch(_ match: SupplementLibraryMatch, to meal: AIParsedMeal, originalText: String) -> AIParsedMeal {
        var updated = meal
        let supplement = match.entry
        let servings = servingCount(from: originalText, defaultValue: 1)
        let supplementItem = makeFoodItem(from: match, servings: servings)
        let normalizedProductName = SupplementLibraryIndex.normalize("\(supplement.brand)\(supplement.productName)")
        let normalizedText = SupplementLibraryIndex.normalize(originalText)

        if let exactIndex = updated.items.firstIndex(where: { item in
            let normalizedItem = SupplementLibraryIndex.normalize(item.name)
            return normalizedProductName.contains(normalizedItem)
                || normalizedItem.contains(SupplementLibraryIndex.normalize(supplement.productName))
                || normalizedText.contains(normalizedItem)
        }) {
            updated.items[exactIndex] = supplementItem
        } else if !updated.items.contains(where: { SupplementLibraryIndex.normalize($0.name) == SupplementLibraryIndex.normalize(supplementItem.name) }) {
            updated.items.append(supplementItem)
        }

        let note = "补剂已命中知识库：\(supplement.displayName)"
        updated.note = updated.note.isEmpty ? note : "\(updated.note) | \(note)"
        return updated
    }

    private static func makeFoodItem(from match: SupplementLibraryMatch, servings: Double) -> AIParsedFoodItem {
        let supplement = match.entry
        let sourceDetail = supplement.sourceNote.isEmpty ? supplement.confidence.displayName : "原来源备注：\(supplement.sourceNote)"
        var noteParts = [
            match.kind.note,
            "数据来源：补剂知识库（\(sourceDetail)）"
        ]
        if !supplement.activeIngredientsNote.isEmpty {
            noteParts.append("活性成分：\(supplement.activeIngredientsNote)")
        }
        if servings != 1 {
            noteParts.append("按份数 ×\(servings.nutritionDecimal) 换算")
        }

        let servingLabel = supplement.servingSize.isEmpty ? "份" : supplement.servingSize

        return AIParsedFoodItem(
            name: displayName(for: supplement, servings: servings),
            amount: servings,
            unit: servingLabel,
            calories: scaled(supplement.calories, by: servings) ?? 0,
            protein: scaled(supplement.protein, by: servings),
            carbs: scaled(supplement.carbs, by: servings),
            fat: scaled(supplement.fat, by: servings),
            sodium: scaled(supplement.sodium, by: servings),
            calcium: scaled(supplement.calcium, by: servings),
            magnesium: scaled(supplement.magnesium, by: servings),
            potassium: scaled(supplement.potassium, by: servings),
            iron: scaled(supplement.iron, by: servings),
            zinc: scaled(supplement.zinc, by: servings),
            vitaminA: scaled(supplement.vitaminA, by: servings),
            vitaminC: scaled(supplement.vitaminC, by: servings),
            vitaminD: scaled(supplement.vitaminD, by: servings),
            vitaminE: scaled(supplement.vitaminE, by: servings),
            vitaminB1: scaled(supplement.vitaminB1, by: servings),
            vitaminB2: scaled(supplement.vitaminB2, by: servings),
            niacin: scaled(supplement.niacin, by: servings),
            vitaminB6: scaled(supplement.vitaminB6, by: servings),
            folate: scaled(supplement.folate, by: servings),
            vitaminB12: scaled(supplement.vitaminB12, by: servings),
            nutritionDataBasis: .direct,
            labelBaseAmount: 1,
            labelBaseUnit: servingLabel,
            consumedAmount: servings,
            consumedUnit: servingLabel,
            nutritionDataNote: noteParts.joined(separator: " | "),
            confidence: supplement.confidence == .high ? "high" : (supplement.confidence == .medium ? "medium" : "low")
        )
    }

    private static func scaled(_ value: Double?, by servings: Double) -> Double? {
        guard let value else { return nil }
        return value * servings
    }

    private static func displayName(for supplement: SupplementLibraryEntry, servings: Double) -> String {
        guard servings != 1 else { return supplement.displayName }
        return "\(supplement.displayName) ×\(servings.nutritionDecimal)"
    }

    /// 补剂按"份/粒/片"计数记录，不像饮品整杯记录——从原始文本里找"吃了2粒/服用3片"这类份数表达，
    /// 找不到明确份数时默认按 1 份计算。这是饮品解析器没有的换算逻辑，因为饮品通常整杯记一条。
    private static func servingCount(from text: String, defaultValue: Double) -> Double {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(?:粒|片|颗|勺|袋|包|滴|次|份)"#) else {
            return defaultValue
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text),
              let value = Double(text[valueRange]),
              value > 0 else {
            return defaultValue
        }
        return value
    }
}
