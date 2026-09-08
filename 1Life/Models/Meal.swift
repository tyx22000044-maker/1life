import Foundation
import SwiftData

@Model
final class Meal {
    var id: UUID
    var date: Date
    var mealTypeRaw: String = MealType.lunch.rawValue
    var mealTypeSortOrder: Int = MealType.lunch.sortOrder
    @Attribute(.externalStorage) var photoData: Data?
    var photoThumbnail: Data?
    var note: String
    var sourceRaw: String = MealSource.manual.rawValue
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \FoodItem.meal)
    var foodItems: [FoodItem]?

    init(date: Date = .now,
         mealType: MealType = .lunch,
         photoData: Data? = nil,
         photoThumbnail: Data? = nil,
         note: String = "",
         source: MealSource = .manual) {
        self.id = UUID()
        self.date = date
        self.mealTypeRaw = mealType.rawValue
        self.mealTypeSortOrder = mealType.sortOrder
        self.photoData = photoData
        self.photoThumbnail = photoThumbnail
        self.note = note
        self.sourceRaw = source.rawValue
        self.createdAt = .now
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .lunch }
        set {
            mealTypeRaw = newValue.rawValue
            mealTypeSortOrder = newValue.sortOrder
        }
    }

    var source: MealSource {
        get { MealSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var totalCalories: Double {
        foodItems?.reduce(0) { $0 + $1.calories } ?? 0
    }

    var totalProtein: Double? {
        let values = foodItems?.compactMap(\.protein) ?? []
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    var totalCarbs: Double? {
        let values = foodItems?.compactMap(\.carbs) ?? []
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    var totalFat: Double? {
        let values = foodItems?.compactMap(\.fat) ?? []
        return values.isEmpty ? nil : values.reduce(0, +)
    }
}
