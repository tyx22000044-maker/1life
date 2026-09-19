import Foundation
import SwiftData

@MainActor
struct AIChatDrinkLibraryResolver {
    static func applyMatch(
        to result: AIChatIntentResult,
        originalText: String,
        modelContext: ModelContext?
    ) -> AIChatIntentResult {
        guard let modelContext else { return result }
        DrinkLibraryIndex.shared.rebuildIfNeeded(using: modelContext)
        guard let match = DrinkLibraryIndex.shared.matchResult(text: originalText) else { return result }

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

    static func makeMealIntent(originalText: String, modelContext: ModelContext?) -> AIChatIntentResult? {
        guard let modelContext else { return nil }
        DrinkLibraryIndex.shared.rebuildIfNeeded(using: modelContext)
        guard let match = DrinkLibraryIndex.shared.matchResult(text: originalText) else { return nil }
        let meal = AIParsedMeal(
            mealType: .snack,
            items: [makeFoodItem(from: match, originalText: originalText)],
            note: "饮品已命中知识库：\(match.entry.displayName)"
        )
        return .addMeal(meal)
    }

    static func shouldPreferLibraryOnlyIntent(originalText: String) -> Bool {
        let normalized = DrinkLibraryIndex.normalize(originalText)
        let drinkSignals = ["喝", "饮", "奶茶", "咖啡", "拿铁", "美式", "果茶", "茶", "杯"]
        let mealSignals = ["吃", "早餐", "午餐", "晚餐", "午饭", "晚饭", "早饭", "餐", "饭", "面", "粉", "米", "包", "菜", "肉"]
        return drinkSignals.contains { normalized.contains($0) }
            && !mealSignals.contains { normalized.contains($0) }
    }

    static func waterAmount(from items: [AIParsedFoodItem]) -> Double {
        items.reduce(0) { total, item in
            guard item.nutritionDataBasis == .direct,
                  item.nutritionDataNote?.contains("饮品知识库") == true else {
                return total
            }

            let unit = item.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if unit == "ml" || unit == "毫升" {
                return total + max(item.amount, 0)
            }
            if item.consumedUnit?.lowercased() == "ml" || item.consumedUnit == "毫升",
               let consumedAmount = item.consumedAmount {
                return total + max(consumedAmount, 0)
            }
            return total
        }
    }

    private static func applyMatch(_ match: DrinkLibraryMatch, to meal: AIParsedMeal, originalText: String) -> AIParsedMeal {
        var updated = meal
        let drink = match.entry
        let drinkItem = makeFoodItem(from: match, originalText: originalText)
        let normalizedDrinkName = DrinkLibraryIndex.normalize("\(drink.brand)\(drink.productName)")
        let normalizedText = DrinkLibraryIndex.normalize(originalText)

        if let exactIndex = updated.items.firstIndex(where: { item in
            let normalizedItem = DrinkLibraryIndex.normalize(item.name)
            return normalizedDrinkName.contains(normalizedItem)
                || normalizedItem.contains(DrinkLibraryIndex.normalize(drink.productName))
                || normalizedText.contains(normalizedItem)
        }) {
            updated.items[exactIndex] = drinkItem
        } else if !updated.items.contains(where: { DrinkLibraryIndex.normalize($0.name) == DrinkLibraryIndex.normalize(drinkItem.name) }) {
            updated.items.append(drinkItem)
        }

        let note = "饮品已命中知识库：\(drink.displayName)"
        updated.note = updated.note.isEmpty ? note : "\(updated.note) | \(note)"
        return updated
    }

    private static func makeFoodItem(from match: DrinkLibraryMatch, originalText: String) -> AIParsedFoodItem {
        let drink = match.entry
        let adjustment = drinkAdjustment(for: drink, originalText: originalText)
        let calories = drink.calories.map { max($0 + adjustment.calorieDelta, 0) } ?? adjustment.calorieDelta
        let sourceDetail = drink.sourceNote.isEmpty ? drink.confidence.displayName : "原来源备注：\(drink.sourceNote)"
        let noteParts = [
            match.kind.note,
            "数据来源：饮品知识库（\(sourceDetail)）",
            adjustment.note
        ].compactMap { $0 }.filter { !$0.isEmpty }

        return AIParsedFoodItem(
            name: adjustedDisplayName(for: drink, adjustment: adjustment),
            amount: drink.sizeML ?? 1,
            unit: drink.sizeML == nil ? "杯" : "ml",
            calories: calories,
            protein: drink.protein,
            carbs: adjustedCarbs(drink.carbs, adjustment: adjustment),
            fat: drink.fat,
            sodium: drink.sodium,
            sugar: adjustedSugar(drink.sugar, adjustment: adjustment),
            caffeine: drink.caffeine,
            teaPolyphenols: drink.teaPolyphenols,
            nutritionDataBasis: .direct,
            labelBaseAmount: drink.sizeML,
            labelBaseUnit: drink.sizeML == nil ? nil : "ml",
            consumedAmount: drink.sizeML,
            consumedUnit: drink.sizeML == nil ? nil : "ml",
            nutritionDataNote: noteParts.joined(separator: " | "),
            confidence: drink.confidence == .high ? "high" : (drink.confidence == .medium ? "medium" : "low"),
            labelDataConfirmedByUser: true
        )
    }

    private struct DrinkCalorieAdjustment {
        let calorieDelta: Double
        let sugarDelta: Double?
        let sugarLabel: String?
        let iceLabel: String?
        let note: String?
    }

    private static func drinkAdjustment(for drink: DrinkLibraryEntry, originalText: String) -> DrinkCalorieAdjustment {
        var calorieDelta: Double = 0
        var sugarDelta: Double?
        var sugarLabel: String?
        var iceLabel: String?
        var notes: [String] = []

        if shouldApplySugarAdjustment(to: drink),
           let requestedSugar = DrinkAdjustmentPolicy.canonicalSugarLevel(in: originalText),
           requestedSugar != .noSugar {
            let range = requestedSugar.calorieRange
            calorieDelta += range.midpoint
            sugarDelta = range.midpoint / 4
            sugarLabel = requestedSugar.rawValue
            notes.append("甜度：\(requestedSugar.rawValue)，按默认无糖基线\(range.displayText)估算")
        }

        if let requestedIce = DrinkAdjustmentPolicy.canonicalIceLevel(in: originalText),
           requestedIce != .normal {
            let range = requestedIce.calorieRange
            calorieDelta += range.midpoint
            iceLabel = requestedIce.rawValue
            notes.append("冰量：\(requestedIce.rawValue)，按默认正常冰基线\(range.displayText)估算")
        }

        return DrinkCalorieAdjustment(
            calorieDelta: calorieDelta,
            sugarDelta: sugarDelta,
            sugarLabel: sugarLabel,
            iceLabel: iceLabel,
            note: notes.isEmpty ? nil : notes.joined(separator: "；")
        )
    }

    /// 用户点了糖度/冰量时，显示名里的规格用请求值替换库内默认值（如 无糖 → 七分糖）
    private static func adjustedDisplayName(for drink: DrinkLibraryEntry, adjustment: DrinkCalorieAdjustment) -> String {
        guard adjustment.sugarLabel != nil || adjustment.iceLabel != nil else { return drink.displayName }
        var specs: [String] = []
        if let sizeML = drink.sizeML { specs.append("\(Int(sizeML))ml") }
        if let sugarLabel = adjustment.sugarLabel {
            specs.append(sugarLabel)
        } else if !drink.sugarLevel.isEmpty {
            specs.append(drink.sugarLevel)
        }
        if let iceLabel = adjustment.iceLabel { specs.append(iceLabel) }
        if !drink.toppings.isEmpty { specs.append(drink.toppings) }
        let suffix = specs.isEmpty ? "" : "（\(specs.joined(separator: "·"))）"
        return "\(drink.brand) \(drink.productName)\(suffix)"
    }

    private static func shouldApplySugarAdjustment(to drink: DrinkLibraryEntry) -> Bool {
        let sugarLevel = DrinkAdjustmentPolicy.canonicalSugarLevel(in: drink.sugarLevel)
        return sugarLevel == nil || sugarLevel == .noSugar
    }

    private static func adjustedSugar(_ sugar: Double?, adjustment: DrinkCalorieAdjustment) -> Double? {
        guard let sugarDelta = adjustment.sugarDelta else { return sugar }
        return (sugar ?? 0) + sugarDelta
    }

    /// Syrup is carbohydrate: adding its calories and its sugar while leaving `carbs` at
    /// the no-sugar baseline made the row internally contradictory, and the confirmation
    /// gate now (correctly) refuses to save that. Ice adjustments stay calorie-only and
    /// are disclosed as estimates in the note.
    private static func adjustedCarbs(_ carbs: Double?, adjustment: DrinkCalorieAdjustment) -> Double? {
        guard let sugarDelta = adjustment.sugarDelta else { return carbs }
        return (carbs ?? 0) + sugarDelta
    }
}
