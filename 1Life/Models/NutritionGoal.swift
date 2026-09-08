import Foundation
import SwiftData

@Model
final class NutritionGoal {
    var id: UUID
    var effectiveDate: Date
    var dailyCalories: Double
    var dailyProtein: Double
    var dailyCarbs: Double
    var dailyFat: Double
    var dailyFiber: Double
    var dailySodium: Double
    var dailySugar: Double
    var dailyCholesterol: Double
    var dailyCaffeine: Double = 400
    var dailyTeaPolyphenols: Double = 500
    var dailyCalcium: Double
    var dailyMagnesium: Double
    var dailyPotassium: Double
    var dailyIron: Double
    var dailyZinc: Double
    var dailyVitaminA: Double
    var dailyVitaminC: Double
    var dailyVitaminD: Double
    var dailyVitaminE: Double
    var dailyVitaminB1: Double
    var dailyVitaminB2: Double
    var dailyNiacin: Double
    var dailyVitaminB6: Double
    var dailyFolate: Double
    var dailyVitaminB12: Double
    var createdAt: Date
    var updatedAt: Date

    init(effectiveDate: Date = .now,
         dailyCalories: Double = 2000,
         dailyProtein: Double = 75,
         dailyCarbs: Double = 300,
         dailyFat: Double = 56,
         dailyFiber: Double = 25,
         dailySodium: Double = 2000,
         dailySugar: Double = 50,
         dailyCholesterol: Double = 300,
         dailyCaffeine: Double = 400,
         dailyTeaPolyphenols: Double = 500,
         dailyCalcium: Double = 800,
         dailyMagnesium: Double = 330,
         dailyPotassium: Double = 2000,
         dailyIron: Double = 12,
         dailyZinc: Double = 12,
         dailyVitaminA: Double = 800,
         dailyVitaminC: Double = 100,
         dailyVitaminD: Double = 10,
         dailyVitaminE: Double = 14,
         dailyVitaminB1: Double = 1.4,
         dailyVitaminB2: Double = 1.4,
         dailyNiacin: Double = 14,
         dailyVitaminB6: Double = 1.4,
         dailyFolate: Double = 400,
         dailyVitaminB12: Double = 2.4) {
        self.id = UUID()
        self.effectiveDate = effectiveDate
        self.dailyCalories = dailyCalories
        self.dailyProtein = dailyProtein
        self.dailyCarbs = dailyCarbs
        self.dailyFat = dailyFat
        self.dailyFiber = dailyFiber
        self.dailySodium = dailySodium
        self.dailySugar = dailySugar
        self.dailyCholesterol = dailyCholesterol
        self.dailyCaffeine = dailyCaffeine
        self.dailyTeaPolyphenols = dailyTeaPolyphenols
        self.dailyCalcium = dailyCalcium
        self.dailyMagnesium = dailyMagnesium
        self.dailyPotassium = dailyPotassium
        self.dailyIron = dailyIron
        self.dailyZinc = dailyZinc
        self.dailyVitaminA = dailyVitaminA
        self.dailyVitaminC = dailyVitaminC
        self.dailyVitaminD = dailyVitaminD
        self.dailyVitaminE = dailyVitaminE
        self.dailyVitaminB1 = dailyVitaminB1
        self.dailyVitaminB2 = dailyVitaminB2
        self.dailyNiacin = dailyNiacin
        self.dailyVitaminB6 = dailyVitaminB6
        self.dailyFolate = dailyFolate
        self.dailyVitaminB12 = dailyVitaminB12
        self.createdAt = .now
        self.updatedAt = .now
    }

    static func fromRecommendedTargets(
        calories: Double,
        macros: RecommendedMacroTargets
    ) -> NutritionGoal {
        return NutritionGoal(
            dailyCalories: calories,
            dailyProtein: macros.protein,
            dailyCarbs: macros.carbs,
            dailyFat: macros.fat
        )
    }

    func applyRecommendedValues(calories: Double, macros: RecommendedMacroTargets) {
        dailyCalories = calories
        dailyProtein = macros.protein
        dailyCarbs = macros.carbs
        dailyFat = macros.fat
        dailyFiber = 25
        dailySodium = 2000
        dailySugar = 50
        dailyCholesterol = 300
        dailyCaffeine = 400
        dailyTeaPolyphenols = 500
        dailyCalcium = 800
        dailyMagnesium = 330
        dailyPotassium = 2000
        dailyIron = 12
        dailyZinc = 12
        dailyVitaminA = 800
        dailyVitaminC = 100
        dailyVitaminD = 10
        dailyVitaminE = 14
        dailyVitaminB1 = 1.4
        dailyVitaminB2 = 1.4
        dailyNiacin = 14
        dailyVitaminB6 = 1.4
        dailyFolate = 400
        dailyVitaminB12 = 2.4
        updatedAt = .now
    }
}
