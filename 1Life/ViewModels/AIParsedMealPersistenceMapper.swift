import Foundation

struct AIParsedMealPersistenceMapper {
    static func foodItem(from item: AIParsedFoodItem, source: FoodSource = .ai) -> FoodItem {
        FoodItem(
            name: item.name,
            amount: item.amount,
            unit: item.unit,
            servingGrams: servingGrams(for: item),
            calories: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat,
            fiber: item.fiber,
            sodium: item.sodium,
            sugar: item.sugar,
            cholesterol: item.cholesterol,
            caffeine: item.caffeine,
            teaPolyphenols: item.teaPolyphenols,
            calcium: item.calcium,
            magnesium: item.magnesium,
            potassium: item.potassium,
            iron: item.iron,
            zinc: item.zinc,
            vitaminA: item.vitaminA,
            vitaminC: item.vitaminC,
            vitaminD: item.vitaminD,
            vitaminE: item.vitaminE,
            vitaminB1: item.vitaminB1,
            vitaminB2: item.vitaminB2,
            niacin: item.niacin,
            vitaminB6: item.vitaminB6,
            folate: item.folate,
            vitaminB12: item.vitaminB12,
            nutritionDataBasis: item.nutritionDataBasis,
            labelBaseAmount: item.labelBaseAmount,
            labelBaseUnit: item.labelBaseUnit,
            packageNetAmount: item.packageNetAmount,
            packageNetUnit: item.packageNetUnit,
            consumedAmount: item.consumedAmount,
            consumedUnit: item.consumedUnit,
            nutritionDataNote: item.nutritionDataNote,
            source: source
        )
    }

    static func templateFoodItem(from item: AIParsedFoodItem) -> TemplateFoodItem {
        TemplateFoodItem(
            name: item.name,
            amount: item.amount,
            unit: item.unit,
            servingGrams: servingGrams(for: item),
            calories: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat,
            fiber: item.fiber,
            sodium: item.sodium,
            sugar: item.sugar,
            cholesterol: item.cholesterol,
            caffeine: item.caffeine,
            teaPolyphenols: item.teaPolyphenols,
            calcium: item.calcium,
            magnesium: item.magnesium,
            potassium: item.potassium,
            iron: item.iron,
            zinc: item.zinc,
            vitaminA: item.vitaminA,
            vitaminC: item.vitaminC,
            vitaminD: item.vitaminD,
            vitaminE: item.vitaminE,
            vitaminB1: item.vitaminB1,
            vitaminB2: item.vitaminB2,
            niacin: item.niacin,
            vitaminB6: item.vitaminB6,
            folate: item.folate,
            vitaminB12: item.vitaminB12,
            nutritionDataBasisRaw: item.nutritionDataBasis.rawValue,
            labelBaseAmount: item.labelBaseAmount,
            labelBaseUnit: item.labelBaseUnit,
            packageNetAmount: item.packageNetAmount,
            packageNetUnit: item.packageNetUnit,
            consumedAmount: item.consumedAmount,
            consumedUnit: item.consumedUnit,
            nutritionDataNote: item.nutritionDataNote
        )
    }

    static func servingGrams(for item: AIParsedFoodItem) -> Double {
        let unit = item.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch unit {
        case "g", "克", "gram", "grams":
            return max(item.amount, 0)
        case "kg", "千克", "公斤":
            return max(item.amount * 1_000, 0)
        case "ml", "毫升":
            return max(item.amount, 0)
        default:
            return max(item.amount * 100, 0)
        }
    }
}
