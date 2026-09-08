import Foundation
import SwiftData

@Model
final class MealTemplate {
    var id: UUID
    var name: String
    var mealTypeRaw: String = MealType.breakfast.rawValue
    var foodItemsJSON: String
    var useCount: Int
    var lastUsedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    @Transient private var cachedFoodItemsJSON: String? = nil
    @Transient private var cachedFoodItems: [TemplateFoodItem]? = nil

    init(name: String,
         mealType: MealType = .breakfast,
         foodItems: [TemplateFoodItem] = []) {
        self.id = UUID()
        self.name = name
        self.mealTypeRaw = mealType.rawValue
        self.foodItemsJSON = (try? String(data: JSONEncoder().encode(foodItems), encoding: .utf8)) ?? "[]"
        self.useCount = 0
        self.createdAt = .now
        self.updatedAt = .now
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .breakfast }
        set { mealTypeRaw = newValue.rawValue }
    }

    var foodItems: [TemplateFoodItem] {
        get {
            if cachedFoodItemsJSON == foodItemsJSON, let cachedFoodItems {
                return cachedFoodItems
            }

            guard let data = foodItemsJSON.data(using: .utf8) else { return [] }
            let decoded = (try? JSONDecoder().decode([TemplateFoodItem].self, from: data)) ?? []
            cachedFoodItemsJSON = foodItemsJSON
            cachedFoodItems = decoded
            return decoded
        }
        set {
            foodItemsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
            cachedFoodItemsJSON = foodItemsJSON
            cachedFoodItems = newValue
        }
    }

    var totalCalories: Double {
        foodItems.reduce(0) { $0 + $1.calories }
    }

    func incrementUseCount() {
        useCount += 1
        lastUsedAt = .now
        updatedAt = .now
    }
}
