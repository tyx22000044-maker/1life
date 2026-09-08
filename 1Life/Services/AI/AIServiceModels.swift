import Foundation

struct AIParsedFoodItem: Identifiable {
    let id = UUID()
    var name: String
    var amount: Double
    var unit: String
    var calories: Double
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double? = nil
    var sodium: Double? = nil
    var sugar: Double? = nil
    var cholesterol: Double? = nil
    var caffeine: Double? = nil
    var teaPolyphenols: Double? = nil
    var calcium: Double? = nil
    var magnesium: Double? = nil
    var potassium: Double? = nil
    var iron: Double? = nil
    var zinc: Double? = nil
    var vitaminA: Double? = nil
    var vitaminC: Double? = nil
    var vitaminD: Double? = nil
    var vitaminE: Double? = nil
    var vitaminB1: Double? = nil
    var vitaminB2: Double? = nil
    var niacin: Double? = nil
    var vitaminB6: Double? = nil
    var folate: Double? = nil
    var vitaminB12: Double? = nil
    var nutritionDataBasis: NutritionDataBasis = .estimated
    var labelBaseAmount: Double? = nil
    var labelBaseUnit: String? = nil
    var packageNetAmount: Double? = nil
    var packageNetUnit: String? = nil
    var consumedAmount: Double? = nil
    var consumedUnit: String? = nil
    var nutritionDataNote: String? = nil

    var amountMin: Double? = nil
    var amountMax: Double? = nil
    var caloriesMin: Double? = nil
    var caloriesMax: Double? = nil
    var confidence: String? = nil

    var isEstimatedRange: Bool {
        if let min = caloriesMin, let max = caloriesMax { return min != max }
        return false
    }

    var caloriesDisplay: String {
        if let min = caloriesMin, let max = caloriesMax, min != max {
            return "\(Int(min))-\(Int(max))"
        }
        return "\(Int(calories))"
    }

    var amountDisplay: String {
        if let min = amountMin, let max = amountMax, min != max {
            return "\(Int(min))-\(Int(max))\(unit)"
        }
        return "\(amount.nutritionDecimal)\(unit)"
    }

    var missingNutrientKeys: [NutrientKey] {
        NutrientKey.allCases.filter { $0.countsForCompleteness && nutrientValue(for: $0) == nil }
    }

    var estimatedNutrientCount: Int {
        NutrientKey.allCases.filter(\.countsForCompleteness).count - missingNutrientKeys.count
    }

    var hasCoreMacroNutrients: Bool {
        protein != nil && carbs != nil && fat != nil
    }

    var missingCoreNutrientKeys: [NutrientKey] {
        [.protein, .carbs, .fat].filter { nutrientValue(for: $0) == nil }
    }

    var isRecordableNutritionEstimate: Bool {
        calories > 0 && hasCoreMacroNutrients
    }

    var isLazyNutritionEstimate: Bool {
        nutritionDataBasis == .estimated
            && !isRecordableNutritionEstimate
    }

    var missingNutrientSummary: String? {
        let missing = missingNutrientKeys
        guard !missing.isEmpty else { return nil }
        let names = missing.prefix(6).map(\.displayName).joined(separator: "、")
        let suffix = missing.count > 6 ? "等\(missing.count)项" : ""
        return "未估算：\(names)\(suffix)"
    }

    func nutrientValue(for key: NutrientKey) -> Double? {
        switch key {
        case .protein: return protein
        case .carbs: return carbs
        case .fat: return fat
        case .fiber: return fiber
        case .sodium: return sodium
        case .sugar: return sugar
        case .cholesterol: return cholesterol
        case .caffeine: return caffeine
        case .teaPolyphenols: return teaPolyphenols
        case .calcium: return calcium
        case .magnesium: return magnesium
        case .potassium: return potassium
        case .iron: return iron
        case .zinc: return zinc
        case .vitaminA: return vitaminA
        case .vitaminC: return vitaminC
        case .vitaminD: return vitaminD
        case .vitaminE: return vitaminE
        case .vitaminB1: return vitaminB1
        case .vitaminB2: return vitaminB2
        case .niacin: return niacin
        case .vitaminB6: return vitaminB6
        case .folate: return folate
        case .vitaminB12: return vitaminB12
        }
    }

    mutating func applyScale(_ scale: Double) {
        // scale 0 = 0.5x原始值, 0.5 = 1x不变, 1.0 = 2x
        let multiplier = pow(2.0, 2.0 * scale - 1.0)
        let baseAmount: Double
        if let minAmt = amountMin, let maxAmt = amountMax {
            baseAmount = (minAmt + maxAmt) / 2
        } else {
            baseAmount = amount
        }
        applyNutritionRatio(multiplier)
        amount = baseAmount * multiplier
    }

    mutating func scaleToAmount(_ newAmount: Double) {
        guard amount > 0, newAmount > 0 else {
            amount = newAmount
            return
        }
        let ratio = newAmount / amount
        amount = newAmount
        applyNutritionRatio(ratio)
    }

    mutating func applyNutritionRatio(_ ratio: Double) {
        protein = protein.map { $0 * ratio }
        carbs = carbs.map { $0 * ratio }
        fat = fat.map { $0 * ratio }
        calories *= ratio
        fiber = fiber.map { $0 * ratio }
        sodium = sodium.map { $0 * ratio }
        sugar = sugar.map { $0 * ratio }
        cholesterol = cholesterol.map { $0 * ratio }
        caffeine = caffeine.map { $0 * ratio }
        teaPolyphenols = teaPolyphenols.map { $0 * ratio }
        calcium = calcium.map { $0 * ratio }
        magnesium = magnesium.map { $0 * ratio }
        potassium = potassium.map { $0 * ratio }
        iron = iron.map { $0 * ratio }
        zinc = zinc.map { $0 * ratio }
        vitaminA = vitaminA.map { $0 * ratio }
        vitaminC = vitaminC.map { $0 * ratio }
        vitaminD = vitaminD.map { $0 * ratio }
        vitaminE = vitaminE.map { $0 * ratio }
        vitaminB1 = vitaminB1.map { $0 * ratio }
        vitaminB2 = vitaminB2.map { $0 * ratio }
        niacin = niacin.map { $0 * ratio }
        vitaminB6 = vitaminB6.map { $0 * ratio }
        folate = folate.map { $0 * ratio }
        vitaminB12 = vitaminB12.map { $0 * ratio }
    }
}

struct AIParsedMeal: Identifiable {
    let id = UUID()
    var mealType: MealType
    var items: [AIParsedFoodItem]
    var note: String
}

struct AIParsedWorkout {
    var workoutType: WorkoutType
    var durationMinutes: Double
    var caloriesBurned: Double?
    var intensity: WorkoutIntensity
    var note: String
}

struct AIParsedBodyMeasurement {
    var weightKg: Double?
    var bodyFatPercentage: Double?
    var note: String
}

struct AIParsedBowelLog {
    var bristolType: BristolStoolType
    var note: String
}

enum AIChatIntentResult {
    case addMeal(AIParsedMeal)
    case addMeals([AIParsedMeal])
    case createTemplate(name: String, meal: AIParsedMeal)
    case addWater(Double)
    case addJournal(content: String, mood: Mood?, tags: [ActivityTag])
    case addHabitLog(habitName: String, value: Double)
    case addWorkout(AIParsedWorkout)
    case addBodyMeasurement(AIParsedBodyMeasurement)
    case addBowelLog(AIParsedBowelLog)
    case batch([AIChatIntentResult])
    case fitnessSummary
    case energyAnalysis
    case postWorkoutNutritionAdvice
    case chat(String)

    var isMealResult: Bool {
        switch self {
        case .addMeal, .addMeals:
            return true
        default:
            return false
        }
    }

}

struct AIChatHistoryItem: Sendable {
    let role: String
    let content: String
}

struct AIDataContext {
    let todayCalories: Double
    let todayProtein: Double?
    let todayCarbs: Double?
    let todayFat: Double?
    let calorieTarget: Double
    let dietGoalMode: String
    let mealSummaries: [String]
    let recentDaysSummaries: [String]
    let habitSummaries: [String]
    let recentStatusSummaries: [String]
    let mealTemplateSummaries: [String]
}

nonisolated struct AIChatBubblePayload: Codable {
    let mealType: String
    let totalCalories: Double
    let items: [BubbleItem]
    var isRevoked: Bool? = nil

    nonisolated struct BubbleItem: Codable {
        let name: String
        let amount: Double
        let unit: String
        let calories: Double
    }
}

struct MealIdentificationConfirmation {
    enum IdentificationType {
        case meal(AIParsedMeal)
        case meals([AIParsedMeal])
    }

    let originalText: String
    let identificationType: IdentificationType
    let isFromLocalParser: Bool

    var identificationSource: String {
        isFromLocalParser ? "本地识别" : "AI 识别"
    }
}
