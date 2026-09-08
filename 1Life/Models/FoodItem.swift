import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID
    var name: String
    var amount: Double
    var unit: String
    var servingGrams: Double
    var calories: Double
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?
    var sodium: Double?
    var sugar: Double?
    var cholesterol: Double?
    var caffeine: Double?
    var teaPolyphenols: Double?
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
    var nutritionDataBasisRaw: String = NutritionDataBasis.direct.rawValue
    var labelBaseAmount: Double?
    var labelBaseUnit: String?
    var packageNetAmount: Double?
    var packageNetUnit: String?
    var consumedAmount: Double?
    var consumedUnit: String?
    var nutritionDataNote: String?
    var sourceRaw: String = FoodSource.manual.rawValue
    var createdAt: Date

    var meal: Meal?

    init(name: String,
         amount: Double,
         unit: String = "g",
         servingGrams: Double,
         calories: Double,
         protein: Double? = nil,
         carbs: Double? = nil,
         fat: Double? = nil,
         fiber: Double? = nil,
         sodium: Double? = nil,
         sugar: Double? = nil,
         cholesterol: Double? = nil,
         caffeine: Double? = nil,
         teaPolyphenols: Double? = nil,
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
         nutritionDataBasis: NutritionDataBasis = .direct,
         labelBaseAmount: Double? = nil,
         labelBaseUnit: String? = nil,
         packageNetAmount: Double? = nil,
         packageNetUnit: String? = nil,
         consumedAmount: Double? = nil,
         consumedUnit: String? = nil,
         nutritionDataNote: String? = nil,
         source: FoodSource = .manual) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.unit = unit
        self.servingGrams = servingGrams
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sodium = sodium
        self.sugar = sugar
        self.cholesterol = cholesterol
        self.caffeine = caffeine
        self.teaPolyphenols = teaPolyphenols
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
        self.nutritionDataBasisRaw = nutritionDataBasis.rawValue
        self.labelBaseAmount = labelBaseAmount
        self.labelBaseUnit = labelBaseUnit
        self.packageNetAmount = packageNetAmount
        self.packageNetUnit = packageNetUnit
        self.consumedAmount = consumedAmount
        self.consumedUnit = consumedUnit
        self.nutritionDataNote = nutritionDataNote
        self.sourceRaw = source.rawValue
        self.createdAt = .now
    }

    var source: FoodSource {
        get { FoodSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var nutritionDataBasis: NutritionDataBasis {
        get { NutritionDataBasis(rawValue: nutritionDataBasisRaw) ?? .direct }
        set { nutritionDataBasisRaw = newValue.rawValue }
    }
}
