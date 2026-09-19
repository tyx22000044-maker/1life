import Foundation
import SwiftData

@Model
final class UserFood {
    var id: UUID
    var brand: String
    var name: String
    var defaultAmount: Double
    var defaultUnit: String
    var defaultServingGrams: Double
    var caloriesPer100g: Double
    /// 新餐食记录使用每份营养；旧的 per100g 字段仅用于兼容历史数据。
    var servingNutritionJSON: String = "{}"
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
    var useCount: Int
    var lastUsedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(brand: String = "",
         name: String,
         defaultAmount: Double = 1,
         defaultUnit: String = "份",
         defaultServingGrams: Double = 100,
         caloriesPer100g: Double,
         servingNutrition: [String: Double] = [:],
         proteinPer100g: Double? = nil,
         carbsPer100g: Double? = nil,
         fatPer100g: Double? = nil,
         fiberPer100g: Double? = nil,
         sodiumPer100g: Double? = nil,
         sugarPer100g: Double? = nil,
         cholesterolPer100g: Double? = nil,
         caffeinePer100g: Double? = nil,
         teaPolyphenolsPer100g: Double? = nil,
         calciumPer100g: Double? = nil,
         magnesiumPer100g: Double? = nil,
         potassiumPer100g: Double? = nil,
         ironPer100g: Double? = nil,
         zincPer100g: Double? = nil,
         vitaminAPer100g: Double? = nil,
         vitaminCPer100g: Double? = nil,
         vitaminDPer100g: Double? = nil,
         vitaminEPer100g: Double? = nil,
         vitaminB1Per100g: Double? = nil,
         vitaminB2Per100g: Double? = nil,
         niacinPer100g: Double? = nil,
         vitaminB6Per100g: Double? = nil,
         folatePer100g: Double? = nil,
         vitaminB12Per100g: Double? = nil) {
        self.id = UUID()
        self.brand = brand
        self.name = name
        self.defaultAmount = defaultAmount
        self.defaultUnit = defaultUnit
        self.defaultServingGrams = defaultServingGrams
        self.caloriesPer100g = caloriesPer100g
        self.servingNutritionJSON = (try? String(data: JSONEncoder().encode(servingNutrition), encoding: .utf8)) ?? "{}"
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.sodiumPer100g = sodiumPer100g
        self.sugarPer100g = sugarPer100g
        self.cholesterolPer100g = cholesterolPer100g
        self.caffeinePer100g = caffeinePer100g
        self.teaPolyphenolsPer100g = teaPolyphenolsPer100g
        self.calciumPer100g = calciumPer100g
        self.magnesiumPer100g = magnesiumPer100g
        self.potassiumPer100g = potassiumPer100g
        self.ironPer100g = ironPer100g
        self.zincPer100g = zincPer100g
        self.vitaminAPer100g = vitaminAPer100g
        self.vitaminCPer100g = vitaminCPer100g
        self.vitaminDPer100g = vitaminDPer100g
        self.vitaminEPer100g = vitaminEPer100g
        self.vitaminB1Per100g = vitaminB1Per100g
        self.vitaminB2Per100g = vitaminB2Per100g
        self.niacinPer100g = niacinPer100g
        self.vitaminB6Per100g = vitaminB6Per100g
        self.folatePer100g = folatePer100g
        self.vitaminB12Per100g = vitaminB12Per100g
        self.useCount = 0
        self.createdAt = .now
        self.updatedAt = .now
    }

    var servingNutrition: [String: Double] {
        get {
            guard let data = servingNutritionJSON.data(using: .utf8),
                  let values = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
            return values
        }
        set {
            servingNutritionJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "{}"
        }
    }

    func incrementUseCount() {
        useCount += 1
        lastUsedAt = .now
        updatedAt = .now
    }
}

/// What one default serving of a `UserFood` is worth, computed the same way for every
/// entry point.
struct UserFoodServingProfile {
    let amount: Double
    let unit: String
    let servingGrams: Double
    let calories: Double
    let nutrients: [NutrientKey: Double]
}

extension UserFood {
    /// Per-serving values win; the legacy `…Per100g` columns are only a fallback for rows
    /// created before `servingNutrition` existed. Before this, 饮食页 multiplied legacy
    /// values by the serving size while AI Chat ignored `servingNutrition` entirely, so
    /// the same food produced different calories depending on how it was logged.
    func servingProfile() -> UserFoodServingProfile {
        let serving = servingNutrition
        let legacyScale = defaultServingGrams / 100 * defaultAmount

        var nutrients: [NutrientKey: Double] = [:]
        for key in NutrientKey.allCases {
            if let perServing = serving[key.rawValue] {
                nutrients[key] = perServing * defaultAmount
            } else if let legacy = legacyPer100gValue(for: key) {
                nutrients[key] = legacy * legacyScale
            }
        }

        let calories = serving["calories"].map { $0 * defaultAmount } ?? (caloriesPer100g * legacyScale)
        return UserFoodServingProfile(
            amount: defaultAmount,
            unit: defaultUnit,
            servingGrams: defaultServingGrams,
            calories: calories,
            nutrients: nutrients
        )
    }

    private func legacyPer100gValue(for key: NutrientKey) -> Double? {
        switch key {
        case .protein: return proteinPer100g
        case .carbs: return carbsPer100g
        case .fat: return fatPer100g
        case .fiber: return fiberPer100g
        case .sodium: return sodiumPer100g
        case .sugar: return sugarPer100g
        case .cholesterol: return cholesterolPer100g
        case .caffeine: return caffeinePer100g
        case .teaPolyphenols: return teaPolyphenolsPer100g
        case .calcium: return calciumPer100g
        case .magnesium: return magnesiumPer100g
        case .potassium: return potassiumPer100g
        case .iron: return ironPer100g
        case .zinc: return zincPer100g
        case .vitaminA: return vitaminAPer100g
        case .vitaminC: return vitaminCPer100g
        case .vitaminD: return vitaminDPer100g
        case .vitaminE: return vitaminEPer100g
        case .vitaminB1: return vitaminB1Per100g
        case .vitaminB2: return vitaminB2Per100g
        case .niacin: return niacinPer100g
        case .vitaminB6: return vitaminB6Per100g
        case .folate: return folatePer100g
        case .vitaminB12: return vitaminB12Per100g
        }
    }
}
