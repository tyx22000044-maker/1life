import Foundation

enum NutrientGroup: String, CaseIterable, Identifiable {
    case macro
    case general
    case mineral
    case vitamin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .macro: return "宏量营养素"
        case .general: return "常规指标"
        case .mineral: return "矿物质"
        case .vitamin: return "维生素"
        }
    }
}

enum NutrientKey: String, CaseIterable, Identifiable, Codable {
    case protein
    case carbs
    case fat
    case fiber
    case sodium
    case sugar
    case cholesterol
    case caffeine
    case teaPolyphenols
    case calcium
    case magnesium
    case potassium
    case iron
    case zinc
    case vitaminA
    case vitaminC
    case vitaminD
    case vitaminE
    case vitaminB1
    case vitaminB2
    case niacin
    case vitaminB6
    case folate
    case vitaminB12

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .protein: return "蛋白质"
        case .carbs: return "碳水化合物"
        case .fat: return "脂肪"
        case .fiber: return "膳食纤维"
        case .sodium: return "钠"
        case .sugar: return "糖"
        case .cholesterol: return "胆固醇"
        case .caffeine: return "咖啡因"
        case .teaPolyphenols: return "茶多酚"
        case .calcium: return "钙"
        case .magnesium: return "镁"
        case .potassium: return "钾"
        case .iron: return "铁"
        case .zinc: return "锌"
        case .vitaminA: return "维生素 A"
        case .vitaminC: return "维生素 C"
        case .vitaminD: return "维生素 D"
        case .vitaminE: return "维生素 E"
        case .vitaminB1: return "维生素 B1"
        case .vitaminB2: return "维生素 B2"
        case .niacin: return "烟酸"
        case .vitaminB6: return "维生素 B6"
        case .folate: return "叶酸"
        case .vitaminB12: return "维生素 B12"
        }
    }

    var unit: String {
        switch self {
        case .protein, .carbs, .fat, .fiber, .sugar:
            return "g"
        case .vitaminA, .vitaminD, .folate, .vitaminB12:
            return "ug"
        case .sodium, .cholesterol, .caffeine, .teaPolyphenols, .calcium, .magnesium, .potassium, .iron, .zinc,
             .vitaminC, .vitaminE, .vitaminB1, .vitaminB2, .niacin, .vitaminB6:
            return "mg"
        }
    }

    var group: NutrientGroup {
        switch self {
        case .protein, .carbs, .fat:
            return .macro
        case .fiber, .sodium, .sugar, .cholesterol, .caffeine, .teaPolyphenols:
            return .general
        case .calcium, .magnesium, .potassium, .iron, .zinc:
            return .mineral
        case .vitaminA, .vitaminC, .vitaminD, .vitaminE, .vitaminB1, .vitaminB2, .niacin, .vitaminB6, .folate, .vitaminB12:
            return .vitamin
        }
    }

    var jsonKey: String {
        switch self {
        case .vitaminA: return "vitamin_a"
        case .vitaminC: return "vitamin_c"
        case .vitaminD: return "vitamin_d"
        case .vitaminE: return "vitamin_e"
        case .vitaminB1: return "vitamin_b1"
        case .vitaminB2: return "vitamin_b2"
        case .vitaminB6: return "vitamin_b6"
        case .vitaminB12: return "vitamin_b12"
        case .teaPolyphenols: return "tea_polyphenols"
        default: return rawValue
        }
    }

    var csvHeader: String { displayName }

    nonisolated var countsForCompleteness: Bool {
        self != .caffeine && self != .teaPolyphenols
    }
}

struct NutrientValue: Identifiable {
    let key: NutrientKey
    let current: Double?
    let target: Double

    var id: NutrientKey { key }
}

struct NutrientGroupDefinition: Identifiable {
    let group: NutrientGroup
    let keys: [NutrientKey]

    var id: NutrientGroup { group }
}

enum NutrientDefinitions {
    static let dashboardGroups: [NutrientGroupDefinition] = [
        NutrientGroupDefinition(group: .general, keys: [.fiber, .sodium, .sugar, .cholesterol, .caffeine, .teaPolyphenols]),
        NutrientGroupDefinition(group: .mineral, keys: [.calcium, .magnesium, .potassium, .iron, .zinc]),
        NutrientGroupDefinition(group: .vitamin, keys: [.vitaminA, .vitaminC, .vitaminD, .vitaminE, .vitaminB1, .vitaminB2, .niacin, .vitaminB6, .folate, .vitaminB12])
    ]
}

// MARK: - Nutrient key → persisted field
//
// Entry points (饮食页手动添加、AI 会话、模板/库导入) all write the same 24 columns.
// Mapping the key once keeps those paths from disagreeing about which field a nutrient is.

extension NutrientKey {
    var foodItemKeyPath: ReferenceWritableKeyPath<FoodItem, Double?>? {
        switch self {
        case .protein: return \FoodItem.protein
        case .carbs: return \FoodItem.carbs
        case .fat: return \FoodItem.fat
        case .fiber: return \FoodItem.fiber
        case .sodium: return \FoodItem.sodium
        case .sugar: return \FoodItem.sugar
        case .cholesterol: return \FoodItem.cholesterol
        case .caffeine: return \FoodItem.caffeine
        case .teaPolyphenols: return \FoodItem.teaPolyphenols
        case .calcium: return \FoodItem.calcium
        case .magnesium: return \FoodItem.magnesium
        case .potassium: return \FoodItem.potassium
        case .iron: return \FoodItem.iron
        case .zinc: return \FoodItem.zinc
        case .vitaminA: return \FoodItem.vitaminA
        case .vitaminC: return \FoodItem.vitaminC
        case .vitaminD: return \FoodItem.vitaminD
        case .vitaminE: return \FoodItem.vitaminE
        case .vitaminB1: return \FoodItem.vitaminB1
        case .vitaminB2: return \FoodItem.vitaminB2
        case .niacin: return \FoodItem.niacin
        case .vitaminB6: return \FoodItem.vitaminB6
        case .folate: return \FoodItem.folate
        case .vitaminB12: return \FoodItem.vitaminB12
        }
    }

    var parsedItemKeyPath: WritableKeyPath<AIParsedFoodItem, Double?>? {
        switch self {
        case .protein: return \AIParsedFoodItem.protein
        case .carbs: return \AIParsedFoodItem.carbs
        case .fat: return \AIParsedFoodItem.fat
        case .fiber: return \AIParsedFoodItem.fiber
        case .sodium: return \AIParsedFoodItem.sodium
        case .sugar: return \AIParsedFoodItem.sugar
        case .cholesterol: return \AIParsedFoodItem.cholesterol
        case .caffeine: return \AIParsedFoodItem.caffeine
        case .teaPolyphenols: return \AIParsedFoodItem.teaPolyphenols
        case .calcium: return \AIParsedFoodItem.calcium
        case .magnesium: return \AIParsedFoodItem.magnesium
        case .potassium: return \AIParsedFoodItem.potassium
        case .iron: return \AIParsedFoodItem.iron
        case .zinc: return \AIParsedFoodItem.zinc
        case .vitaminA: return \AIParsedFoodItem.vitaminA
        case .vitaminC: return \AIParsedFoodItem.vitaminC
        case .vitaminD: return \AIParsedFoodItem.vitaminD
        case .vitaminE: return \AIParsedFoodItem.vitaminE
        case .vitaminB1: return \AIParsedFoodItem.vitaminB1
        case .vitaminB2: return \AIParsedFoodItem.vitaminB2
        case .niacin: return \AIParsedFoodItem.niacin
        case .vitaminB6: return \AIParsedFoodItem.vitaminB6
        case .folate: return \AIParsedFoodItem.folate
        case .vitaminB12: return \AIParsedFoodItem.vitaminB12
        }
    }
}
