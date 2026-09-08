import Foundation
import SwiftData

struct DailyNutritionSummary {
    let totalCalories: Double
    let totalProtein: Double?
    let totalCarbs: Double?
    let totalFat: Double?
    let totalFiber: Double?
    let totalSodium: Double?
    let totalSugar: Double?
    let totalCholesterol: Double?
    let totalCaffeine: Double?
    let totalTeaPolyphenols: Double?
    let totalCalcium: Double?
    let totalMagnesium: Double?
    let totalPotassium: Double?
    let totalIron: Double?
    let totalZinc: Double?
    let totalVitaminA: Double?
    let totalVitaminC: Double?
    let totalVitaminD: Double?
    let totalVitaminE: Double?
    let totalVitaminB1: Double?
    let totalVitaminB2: Double?
    let totalNiacin: Double?
    let totalVitaminB6: Double?
    let totalFolate: Double?
    let totalVitaminB12: Double?
    let totalWaterMl: Double
    let mealCount: Int
    let foodItemCount: Int
}

struct MealNutritionSummary: Identifiable {
    let id: UUID
    let mealType: MealType
    let totalCalories: Double
    let foodItemCount: Int
    let mealCount: Int
    let date: Date
}

private struct OptionalNutrientTotal {
    private(set) var total: Double = 0
    private(set) var hasValue = false

    mutating func add(_ value: Double?) {
        guard let value else { return }
        total += value
        hasValue = true
    }

    var optionalValue: Double? {
        hasValue ? total : nil
    }
}

@MainActor
enum NutritionService {
    static func dailySummary(meals: [Meal], waterLogs: [WaterLog], for date: Date) -> DailyNutritionSummary {
        var totalCalories = 0.0
        var protein = OptionalNutrientTotal()
        var carbs = OptionalNutrientTotal()
        var fat = OptionalNutrientTotal()
        var fiber = OptionalNutrientTotal()
        var sodium = OptionalNutrientTotal()
        var sugar = OptionalNutrientTotal()
        var cholesterol = OptionalNutrientTotal()
        var caffeine = OptionalNutrientTotal()
        var teaPolyphenols = OptionalNutrientTotal()
        var calcium = OptionalNutrientTotal()
        var magnesium = OptionalNutrientTotal()
        var potassium = OptionalNutrientTotal()
        var iron = OptionalNutrientTotal()
        var zinc = OptionalNutrientTotal()
        var vitaminA = OptionalNutrientTotal()
        var vitaminC = OptionalNutrientTotal()
        var vitaminD = OptionalNutrientTotal()
        var vitaminE = OptionalNutrientTotal()
        var vitaminB1 = OptionalNutrientTotal()
        var vitaminB2 = OptionalNutrientTotal()
        var niacin = OptionalNutrientTotal()
        var vitaminB6 = OptionalNutrientTotal()
        var folate = OptionalNutrientTotal()
        var vitaminB12 = OptionalNutrientTotal()
        var mealCount = 0
        var foodItemCount = 0

        for meal in meals where meal.date.isSameDay(as: date) {
            mealCount += 1
            for item in meal.foodItems ?? [] {
                foodItemCount += 1
                totalCalories += item.calories
                protein.add(item.protein)
                carbs.add(item.carbs)
                fat.add(item.fat)
                fiber.add(item.fiber)
                sodium.add(item.sodium)
                sugar.add(item.sugar)
                cholesterol.add(item.cholesterol)
                caffeine.add(item.caffeine)
                teaPolyphenols.add(item.teaPolyphenols)
                calcium.add(item.calcium)
                magnesium.add(item.magnesium)
                potassium.add(item.potassium)
                iron.add(item.iron)
                zinc.add(item.zinc)
                vitaminA.add(item.vitaminA)
                vitaminC.add(item.vitaminC)
                vitaminD.add(item.vitaminD)
                vitaminE.add(item.vitaminE)
                vitaminB1.add(item.vitaminB1)
                vitaminB2.add(item.vitaminB2)
                niacin.add(item.niacin)
                vitaminB6.add(item.vitaminB6)
                folate.add(item.folate)
                vitaminB12.add(item.vitaminB12)
            }
        }

        return DailyNutritionSummary(
            totalCalories: totalCalories,
            totalProtein: protein.optionalValue,
            totalCarbs: carbs.optionalValue,
            totalFat: fat.optionalValue,
            totalFiber: fiber.optionalValue,
            totalSodium: sodium.optionalValue,
            totalSugar: sugar.optionalValue,
            totalCholesterol: cholesterol.optionalValue,
            totalCaffeine: caffeine.optionalValue,
            totalTeaPolyphenols: teaPolyphenols.optionalValue,
            totalCalcium: calcium.optionalValue,
            totalMagnesium: magnesium.optionalValue,
            totalPotassium: potassium.optionalValue,
            totalIron: iron.optionalValue,
            totalZinc: zinc.optionalValue,
            totalVitaminA: vitaminA.optionalValue,
            totalVitaminC: vitaminC.optionalValue,
            totalVitaminD: vitaminD.optionalValue,
            totalVitaminE: vitaminE.optionalValue,
            totalVitaminB1: vitaminB1.optionalValue,
            totalVitaminB2: vitaminB2.optionalValue,
            totalNiacin: niacin.optionalValue,
            totalVitaminB6: vitaminB6.optionalValue,
            totalFolate: folate.optionalValue,
            totalVitaminB12: vitaminB12.optionalValue,
            totalWaterMl: waterLogs.reduce(0) { total, log in
                log.date.isSameDay(as: date) ? total + log.amount : total
            },
            mealCount: mealCount,
            foodItemCount: foodItemCount
        )
    }

    static func mealSummaries(meals: [Meal], for date: Date) -> [MealNutritionSummary] {
        meals
            .filter { $0.date.isSameDay(as: date) }
            .sorted { a, b in
                if a.mealTypeSortOrder != b.mealTypeSortOrder {
                    return a.mealTypeSortOrder < b.mealTypeSortOrder
                }
                return a.createdAt < b.createdAt
            }
            .map { meal in
                MealNutritionSummary(
                    id: meal.id,
                    mealType: meal.mealType,
                    totalCalories: meal.totalCalories,
                    foodItemCount: meal.foodItems?.count ?? 0,
                    mealCount: 1,
                    date: meal.date
                )
            }
    }

    /// Returns one snapshot per meal type, including all meals recorded for that type.
    /// This keeps the dashboard snapshot aligned with the daily calorie total when a
    /// template is added more than once for the same meal.
    static func mealTypeSummaries(meals: [Meal], for date: Date) -> [MealNutritionSummary] {
        let dayMeals = meals.filter { $0.date.isSameDay(as: date) }

        return MealType.allCases.compactMap { mealType in
            let mealsForType = dayMeals.filter { $0.mealType == mealType }
            guard let firstMeal = mealsForType.first else { return nil }

            return MealNutritionSummary(
                id: firstMeal.id,
                mealType: mealType,
                totalCalories: mealsForType.reduce(0) { $0 + $1.totalCalories },
                foodItemCount: mealsForType.reduce(0) { $0 + ($1.foodItems?.count ?? 0) },
                mealCount: mealsForType.count,
                date: mealsForType.map(\.date).min() ?? firstMeal.date
            )
        }
    }

    static func bmr(gender: Gender, weightKg: Double, heightCm: Double, age: Int) -> Double {
        switch gender {
        case .male:
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        case .female:
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        }
    }

}
