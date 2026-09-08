import Foundation
import SwiftData

@MainActor
struct FoodTimelineMealWriter {
    static func cleanupEmptyMeals(_ meals: [Meal], modelContext: ModelContext) {
        let emptyMeals = meals.filter { ($0.foodItems ?? []).isEmpty }
        for meal in emptyMeals {
            modelContext.delete(meal)
        }
    }

    static func createMeal(from template: MealTemplate, date: Date, mealTypeOverride: MealType? = nil, modelContext: ModelContext) {
        let meal = Meal(date: date, mealType: mealTypeOverride ?? template.mealType, note: "模板：\(template.name)", source: .manual)
        modelContext.insert(meal)
        for snapshot in template.foodItems {
            insertFoodItem(from: snapshot, into: meal, modelContext: modelContext)
        }
        template.incrementUseCount()
    }

    static func createDrinkMeal(from record: DrinkRecord, date: Date, mealType: MealType = .snack, modelContext: ModelContext) {
        let meal = Meal(date: date, mealType: mealType, source: .manual)
        modelContext.insert(meal)
        insertFoodItem(from: record, into: meal, modelContext: modelContext)
    }

    static func copyMeal(_ sourceMeal: Meal, date: Date, modelContext: ModelContext) {
        let meal = Meal(date: date, mealType: sourceMeal.mealType, source: .manual)
        modelContext.insert(meal)
        for item in sourceMeal.foodItems ?? [] {
            insertFoodItem(copying: item, into: meal, modelContext: modelContext)
        }
    }

    static func addFoodItemCopy(
        _ sourceItem: FoodItem,
        mealType: MealType,
        date: Date,
        existingMeal: Meal?,
        modelContext: ModelContext
    ) {
        let meal = existingMeal ?? Meal(date: date, mealType: mealType, source: .manual)
        if existingMeal == nil {
            modelContext.insert(meal)
        }
        insertFoodItem(copying: sourceItem, into: meal, modelContext: modelContext)
    }

    static func addUserFood(
        _ food: UserFood,
        mealType: MealType,
        date: Date,
        existingMeal: Meal?,
        modelContext: ModelContext
    ) {
        let meal = existingMeal ?? Meal(date: date, mealType: mealType, source: .manual)
        if existingMeal == nil {
            modelContext.insert(meal)
        }

        let serving = food.servingNutrition
        let scale = food.defaultServingGrams / 100
        func nutrient(_ key: String, legacy: Double?) -> Double? {
            if let value = serving[key] { return value * food.defaultAmount }
            return legacy.map { $0 * scale }
        }
        let item = FoodItem(
            name: food.name,
            amount: food.defaultAmount,
            unit: food.defaultUnit,
            servingGrams: 0,
            calories: (serving["calories"] ?? food.caloriesPer100g * scale) * (serving["calories"] == nil ? 1 : food.defaultAmount),
            protein: nutrient("protein", legacy: food.proteinPer100g),
            carbs: nutrient("carbs", legacy: food.carbsPer100g),
            fat: nutrient("fat", legacy: food.fatPer100g),
            fiber: nutrient("fiber", legacy: food.fiberPer100g),
            sodium: nutrient("sodium", legacy: food.sodiumPer100g),
            sugar: nutrient("sugar", legacy: food.sugarPer100g),
            cholesterol: nutrient("cholesterol", legacy: food.cholesterolPer100g),
            caffeine: nutrient("caffeine", legacy: food.caffeinePer100g),
            teaPolyphenols: nutrient("teaPolyphenols", legacy: food.teaPolyphenolsPer100g),
            calcium: nutrient("calcium", legacy: food.calciumPer100g),
            magnesium: nutrient("magnesium", legacy: food.magnesiumPer100g),
            potassium: nutrient("potassium", legacy: food.potassiumPer100g),
            iron: nutrient("iron", legacy: food.ironPer100g),
            zinc: nutrient("zinc", legacy: food.zincPer100g),
            vitaminA: nutrient("vitaminA", legacy: food.vitaminAPer100g),
            vitaminC: nutrient("vitaminC", legacy: food.vitaminCPer100g),
            vitaminD: nutrient("vitaminD", legacy: food.vitaminDPer100g),
            vitaminE: nutrient("vitaminE", legacy: food.vitaminEPer100g),
            vitaminB1: nutrient("vitaminB1", legacy: food.vitaminB1Per100g),
            vitaminB2: nutrient("vitaminB2", legacy: food.vitaminB2Per100g),
            niacin: nutrient("niacin", legacy: food.niacinPer100g),
            vitaminB6: nutrient("vitaminB6", legacy: food.vitaminB6Per100g),
            folate: nutrient("folate", legacy: food.folatePer100g),
            vitaminB12: nutrient("vitaminB12", legacy: food.vitaminB12Per100g),
            source: .manual
        )
        item.meal = meal
        modelContext.insert(item)
        food.incrementUseCount()
    }

    private static func insertFoodItem(from snapshot: TemplateFoodItem, into meal: Meal, modelContext: ModelContext) {
        let item = FoodItem(
            name: snapshot.name,
            amount: snapshot.amount,
            unit: snapshot.unit,
            servingGrams: snapshot.servingGrams,
            calories: snapshot.calories,
            protein: snapshot.protein,
            carbs: snapshot.carbs,
            fat: snapshot.fat,
            fiber: snapshot.fiber,
            sodium: snapshot.sodium,
            sugar: snapshot.sugar,
            cholesterol: snapshot.cholesterol,
            caffeine: snapshot.caffeine,
            teaPolyphenols: snapshot.teaPolyphenols,
            calcium: snapshot.calcium,
            magnesium: snapshot.magnesium,
            potassium: snapshot.potassium,
            iron: snapshot.iron,
            zinc: snapshot.zinc,
            vitaminA: snapshot.vitaminA,
            vitaminC: snapshot.vitaminC,
            vitaminD: snapshot.vitaminD,
            vitaminE: snapshot.vitaminE,
            vitaminB1: snapshot.vitaminB1,
            vitaminB2: snapshot.vitaminB2,
            niacin: snapshot.niacin,
            vitaminB6: snapshot.vitaminB6,
            folate: snapshot.folate,
            vitaminB12: snapshot.vitaminB12,
            nutritionDataBasis: snapshot.nutritionDataBasisRaw.flatMap { NutritionDataBasis(rawValue: $0) } ?? .direct,
            labelBaseAmount: snapshot.labelBaseAmount,
            labelBaseUnit: snapshot.labelBaseUnit,
            packageNetAmount: snapshot.packageNetAmount,
            packageNetUnit: snapshot.packageNetUnit,
            consumedAmount: snapshot.consumedAmount,
            consumedUnit: snapshot.consumedUnit,
            nutritionDataNote: snapshot.nutritionDataNote,
            source: .manual
        )
        item.meal = meal
        modelContext.insert(item)
    }

    private static func insertFoodItem(from record: DrinkRecord, into meal: Meal, modelContext: ModelContext) {
        let item = FoodItem(
            name: record.displayName,
            amount: record.sizeML ?? 1,
            unit: record.sizeML == nil ? "杯" : "ml",
            servingGrams: record.sizeML ?? 0,
            calories: record.calories ?? 0,
            protein: record.protein,
            carbs: record.carbs,
            fat: record.fat,
            sodium: record.sodium,
            sugar: record.sugar,
            caffeine: record.caffeine,
            teaPolyphenols: record.teaPolyphenols,
            nutritionDataBasis: .direct,
            labelBaseAmount: record.sizeML,
            labelBaseUnit: record.sizeML == nil ? nil : "ml",
            consumedAmount: record.sizeML,
            consumedUnit: record.sizeML == nil ? nil : "ml",
            nutritionDataNote: "数据来源：饮品知识库（\(record.sourceNote.isEmpty ? record.confidence.displayName : record.sourceNote)）",
            source: .manual
        )
        item.meal = meal
        modelContext.insert(item)
    }

    private static func insertFoodItem(copying source: FoodItem, into meal: Meal, modelContext: ModelContext) {
        let item = FoodItem(
            name: source.name,
            amount: source.amount,
            unit: source.unit,
            servingGrams: source.servingGrams,
            calories: source.calories,
            protein: source.protein,
            carbs: source.carbs,
            fat: source.fat,
            fiber: source.fiber,
            sodium: source.sodium,
            sugar: source.sugar,
            cholesterol: source.cholesterol,
            caffeine: source.caffeine,
            teaPolyphenols: source.teaPolyphenols,
            calcium: source.calcium,
            magnesium: source.magnesium,
            potassium: source.potassium,
            iron: source.iron,
            zinc: source.zinc,
            vitaminA: source.vitaminA,
            vitaminC: source.vitaminC,
            vitaminD: source.vitaminD,
            vitaminE: source.vitaminE,
            vitaminB1: source.vitaminB1,
            vitaminB2: source.vitaminB2,
            niacin: source.niacin,
            vitaminB6: source.vitaminB6,
            folate: source.folate,
            vitaminB12: source.vitaminB12,
            nutritionDataBasis: source.nutritionDataBasis,
            labelBaseAmount: source.labelBaseAmount,
            labelBaseUnit: source.labelBaseUnit,
            packageNetAmount: source.packageNetAmount,
            packageNetUnit: source.packageNetUnit,
            consumedAmount: source.consumedAmount,
            consumedUnit: source.consumedUnit,
            nutritionDataNote: source.nutritionDataNote,
            source: source.source
        )
        item.meal = meal
        modelContext.insert(item)
    }
}
