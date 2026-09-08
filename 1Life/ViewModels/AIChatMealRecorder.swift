import Foundation
import SwiftData

@MainActor
struct AIChatMealRecorder {
    static func record(
        parsed: AIParsedMeal,
        mealDate: Date,
        provider: AIProvider,
        modelContext: ModelContext
    ) -> AIChatMessage {
        let meal = Meal(date: mealDate, mealType: parsed.mealType, note: parsed.note, source: .aiText)
        modelContext.insert(meal)

        for item in parsed.items {
            let foodItem = AIParsedMealPersistenceMapper.foodItem(from: item)
            foodItem.meal = meal
            modelContext.insert(foodItem)
        }

        let drinkWaterAmount = AIChatDrinkLibraryResolver.waterAmount(from: parsed.items)
        if drinkWaterAmount > 0 {
            modelContext.insert(WaterLog(date: mealDate, amount: drinkWaterAmount))
        }

        let payload = AIChatBubblePayload(
            mealType: parsed.mealType.rawValue,
            totalCalories: parsed.items.reduce(0) { $0 + $1.calories },
            items: parsed.items.map { .init(name: $0.name, amount: $0.amount, unit: $0.unit, calories: $0.calories) }
        )

        let toolMsg = AIChatMessage(
            role: "assistant",
            content: "已记录\(parsed.mealType.displayName)",
            provider: provider,
            toolName: "add_meal",
            toolPayloadJSON: (try? String(data: JSONEncoder().encode(payload), encoding: .utf8)),
            createdMealID: meal.id
        )
        modelContext.insert(toolMsg)
        return toolMsg
    }
}
