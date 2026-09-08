import Foundation

struct AIChatMealValidation {
    nonisolated static func applySanityReview(to meal: AIParsedMeal) -> AIParsedMeal {
        var reviewed = meal
        reviewed.items = reviewed.items.map(applySanityReview)
        return reviewed
    }

    nonisolated static func normalizePhotoMealResult(_ result: AIChatIntentResult) -> AIChatIntentResult {
        switch result {
        case .addMeal(let meal):
            return .addMeal(normalizePhotoMeal(meal))
        case .addMeals(let meals):
            return .addMeals(meals.map(normalizePhotoMeal))
        default:
            return result
        }
    }

    private nonisolated static func applySanityReview(to item: AIParsedFoodItem) -> AIParsedFoodItem {
        var reviewed = sanitizeUnverifiedSourceNote(item)
        guard let protein = item.protein,
              let carbs = item.carbs,
              let fat = item.fat,
              item.calories > 0 else {
            return reviewed
        }

        let macroCalories = protein * 4 + carbs * 4 + fat * 9
        guard macroCalories > 0 else { return reviewed }
        let deltaRatio = abs(macroCalories - item.calories) / max(item.calories, macroCalories)
        guard deltaRatio > 0.35 else { return reviewed }

        reviewed.confidence = "low"
        reviewed.caloriesMin = min(item.caloriesMin ?? item.calories, macroCalories, item.calories)
        reviewed.caloriesMax = max(item.caloriesMax ?? item.calories, macroCalories, item.calories)
        appendNutritionNote("AI 自检：热量与三大营养素换算差异较大，已标记为低置信度", to: &reviewed)
        return reviewed
    }

    private nonisolated static func sanitizeUnverifiedSourceNote(_ item: AIParsedFoodItem) -> AIParsedFoodItem {
        var sanitized = item
        guard let note = item.nutritionDataNote?.trimmingCharacters(in: .whitespacesAndNewlines),
              !note.isEmpty,
              hasUnverifiedOfficialSourceClaim(note),
              !hasTrustedLocalSource(note),
              !hasVerifiedNutritionLabelData(item) else {
            return sanitized
        }

        let parts = note
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !hasUnverifiedOfficialSourceClaim($0) }

        let fallback = "数据来源：AI估算"
        sanitized.nutritionDataBasis = .estimated
        sanitized.confidence = sanitized.confidence == "high" ? "medium" : sanitized.confidence
        sanitized.nutritionDataNote = parts.isEmpty ? fallback : ([fallback] + parts).joined(separator: " | ")
        return sanitized
    }

    private nonisolated static func hasTrustedLocalSource(_ note: String) -> Bool {
        ["饮品知识库", "模板库", "我的食物", "包装营养成分表"].contains { note.contains($0) }
    }

    private nonisolated static func hasUnverifiedOfficialSourceClaim(_ note: String) -> Bool {
        ["官方产品信息", "官方信息", "官网", "官方小程序", "官方数据", "产品信息"].contains { note.contains($0) }
    }

    private nonisolated static func hasVerifiedNutritionLabelData(_ item: AIParsedFoodItem) -> Bool {
        item.labelBaseAmount != nil
            || item.labelBaseUnit != nil
            || item.packageNetAmount != nil
            || item.packageNetUnit != nil
            || item.consumedAmount != nil
            || item.consumedUnit != nil
            || item.nutritionDataBasis == .per100g
            || item.nutritionDataBasis == .per100ml
            || item.nutritionDataBasis == .perServing
    }

    private nonisolated static func normalizePhotoMeal(_ meal: AIParsedMeal) -> AIParsedMeal {
        let items = meal.items.map(normalizePhotoFoodItem)
        let note = meal.note.isEmpty
            ? "图片识别结果仅代表菜品识别；份量、热量和营养素为估算区间，请按实际大小校准。"
            : meal.note
        return AIParsedMeal(mealType: meal.mealType, items: items, note: note)
    }

    private nonisolated static func normalizePhotoFoodItem(_ item: AIParsedFoodItem) -> AIParsedFoodItem {
        var normalized = item
        guard !hasVerifiedPortionData(item) else {
            normalized.confidence = normalized.confidence ?? "high"
            return normalized
        }

        normalized.nutritionDataBasis = .estimated
        normalized.confidence = "low"

        let amount = max(normalized.amount, 1)
        if normalized.amountMin == nil || normalized.amountMax == nil || normalized.amountMin == normalized.amountMax {
            normalized.amountMin = roundedPortion(amount * 0.75)
            normalized.amountMax = roundedPortion(amount * 1.25)
        }

        let calories = max(normalized.calories, 0)
        if calories > 0,
           normalized.caloriesMin == nil || normalized.caloriesMax == nil || normalized.caloriesMin == normalized.caloriesMax {
            normalized.caloriesMin = roundedPortion(calories * 0.75)
            normalized.caloriesMax = roundedPortion(calories * 1.25)
        }

        let note = normalized.nutritionDataNote?.trimmingCharacters(in: .whitespacesAndNewlines)
        let uncertaintyNote = "份量未由图片证实，按常见份量区间估算"
        if let note, !note.isEmpty {
            if !note.contains(uncertaintyNote) {
                normalized.nutritionDataNote = "\(note) | \(uncertaintyNote)"
            }
        } else {
            normalized.nutritionDataNote = "数据来源：AI估算 | \(uncertaintyNote)"
        }
        appendLazyNutritionNote(to: &normalized)
        appendMissingNutrientNote(to: &normalized)
        return normalized
    }

    private nonisolated static func appendNutritionNote(_ note: String, to item: inout AIParsedFoodItem) {
        let current = item.nutritionDataNote?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let current, !current.isEmpty {
            guard !current.contains(note) else { return }
            item.nutritionDataNote = "\(current) | \(note)"
        } else {
            item.nutritionDataNote = note
        }
    }

    private nonisolated static func appendLazyNutritionNote(to item: inout AIParsedFoodItem) {
        guard isLazyNutritionEstimate(item) else { return }
        let warning = "营养素估算不完整，请重新识别或手动补充"
        let currentNote = item.nutritionDataNote?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let currentNote, !currentNote.isEmpty {
            guard !currentNote.contains(warning) else { return }
            item.nutritionDataNote = "\(currentNote) | \(warning)"
        } else {
            item.nutritionDataNote = warning
        }
    }

    private nonisolated static func appendMissingNutrientNote(to item: inout AIParsedFoodItem) {
        guard let missingSummary = missingNutrientSummary(for: item) else { return }
        let currentNote = item.nutritionDataNote?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let currentNote, !currentNote.isEmpty {
            guard !currentNote.contains("未估算：") else { return }
            item.nutritionDataNote = "\(currentNote) | \(missingSummary)"
        } else {
            item.nutritionDataNote = missingSummary
        }
    }

    private nonisolated static func isLazyNutritionEstimate(_ item: AIParsedFoodItem) -> Bool {
        item.nutritionDataBasis == .estimated
            && !(item.calories > 0 && item.protein != nil && item.carbs != nil && item.fat != nil)
    }

    private nonisolated static func missingNutrientSummary(for item: AIParsedFoodItem) -> String? {
        let missing = NutrientKey.allCases.filter { $0.countsForCompleteness && nutrientValue(for: $0, in: item) == nil }
        guard !missing.isEmpty else { return nil }
        let names = missing.prefix(6).map(nutrientDisplayName).joined(separator: "、")
        let suffix = missing.count > 6 ? "等\(missing.count)项" : ""
        return "未估算：\(names)\(suffix)"
    }

    private nonisolated static func nutrientDisplayName(_ key: NutrientKey) -> String {
        switch key {
        case .protein: return "蛋白质"
        case .carbs: return "碳水化合物"
        case .fat: return "脂肪"
        case .fiber: return "膳食纤维"
        case .sodium: return "钠"
        case .sugar: return "糖"
        case .cholesterol: return "胆固醇"
        case .caffeine: return "咖啡因"
        case .teaPolyphenols: return "茶多酚"
        case .calcium: return "钙"
        case .magnesium: return "镁"
        case .potassium: return "钾"
        case .iron: return "铁"
        case .zinc: return "锌"
        case .vitaminA: return "维生素 A"
        case .vitaminC: return "维生素 C"
        case .vitaminD: return "维生素 D"
        case .vitaminE: return "维生素 E"
        case .vitaminB1: return "维生素 B1"
        case .vitaminB2: return "维生素 B2"
        case .niacin: return "烟酸"
        case .vitaminB6: return "维生素 B6"
        case .folate: return "叶酸"
        case .vitaminB12: return "维生素 B12"
        }
    }

    private nonisolated static func nutrientValue(for key: NutrientKey, in item: AIParsedFoodItem) -> Double? {
        switch key {
        case .protein: return item.protein
        case .carbs: return item.carbs
        case .fat: return item.fat
        case .fiber: return item.fiber
        case .sodium: return item.sodium
        case .sugar: return item.sugar
        case .cholesterol: return item.cholesterol
        case .caffeine: return item.caffeine
        case .teaPolyphenols: return item.teaPolyphenols
        case .calcium: return item.calcium
        case .magnesium: return item.magnesium
        case .potassium: return item.potassium
        case .iron: return item.iron
        case .zinc: return item.zinc
        case .vitaminA: return item.vitaminA
        case .vitaminC: return item.vitaminC
        case .vitaminD: return item.vitaminD
        case .vitaminE: return item.vitaminE
        case .vitaminB1: return item.vitaminB1
        case .vitaminB2: return item.vitaminB2
        case .niacin: return item.niacin
        case .vitaminB6: return item.vitaminB6
        case .folate: return item.folate
        case .vitaminB12: return item.vitaminB12
        }
    }

    private nonisolated static func hasVerifiedPortionData(_ item: AIParsedFoodItem) -> Bool {
        if item.confidence == "high" {
            return item.nutritionDataBasis != .estimated
                || item.labelBaseAmount != nil
                || item.packageNetAmount != nil
                || item.consumedAmount != nil
        }
        return item.nutritionDataBasis != .estimated
            && (item.labelBaseAmount != nil || item.packageNetAmount != nil || item.consumedAmount != nil)
    }

    private nonisolated static func roundedPortion(_ value: Double) -> Double {
        guard value >= 10 else { return max(value.rounded(), 1) }
        return (value / 5).rounded() * 5
    }
}
