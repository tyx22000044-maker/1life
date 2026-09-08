import Foundation
import SwiftUI

// MARK: - Diet & Nutrition

enum DietGoalMode: String, CaseIterable, Codable, Identifiable {
    case fatLoss
    case muscleGain
    case maintain
    case balanced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fatLoss: return "减脂"
        case .muscleGain: return "增肌"
        case .maintain: return "维持"
        case .balanced: return "均衡饮食"
        }
    }

    var calorieMultiplier: Double {
        switch self {
        case .fatLoss: return 0.80
        case .muscleGain: return 1.15
        case .maintain, .balanced: return 1.0
        }
    }

    var proteinRatio: Double {
        switch self {
        case .fatLoss: return 0.30
        case .muscleGain: return 0.30
        case .maintain: return 0.20
        case .balanced: return 0.15
        }
    }

    var carbsRatio: Double {
        switch self {
        case .fatLoss: return 0.40
        case .muscleGain: return 0.50
        case .maintain: return 0.55
        case .balanced: return 0.60
        }
    }

    var fatRatio: Double {
        switch self {
        case .fatLoss: return 0.30
        case .muscleGain: return 0.20
        case .maintain: return 0.25
        case .balanced: return 0.25
        }
    }

    var carbFatRatioTotal: Double {
        carbsRatio + fatRatio
    }
}

enum ProteinTargetStrategy: String, CaseIterable, Codable, Identifiable {
    case macroRatio
    case bodyWeight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .macroRatio: return "按宏量比例"
        case .bodyWeight: return "按体重倍数"
        }
    }
}

struct RecommendedMacroTargets {
    let protein: Double
    let carbs: Double
    let fat: Double
}

enum MealType: String, CaseIterable, Codable, Identifiable, Equatable {
    case breakfast
    case lunch
    case dinner
    case fruit
    case snack
    case supper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "早餐"
        case .lunch: return "午餐"
        case .dinner: return "晚餐"
        case .fruit: return "水果"
        case .snack: return "零食"
        case .supper: return "夜宵"
        }
    }

    var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .dinner: return 2
        case .fruit: return 3
        case .snack: return 4
        case .supper: return 5
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .fruit: return "leaf.fill"
        case .snack: return "cup.and.saucer.fill"
        case .supper: return "moon.stars.fill"
        }
    }

    var defaultReminderHour: Int {
        switch self {
        case .breakfast: return 8
        case .lunch: return 12
        case .dinner: return 19
        case .fruit: return 15
        case .snack: return 15
        case .supper: return 22
        }
    }

    static func guessByTime(_ date: Date = .now) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<10: return .breakfast
        case 10..<16: return .lunch
        case 16..<21: return .dinner
        case 21..<24: return .supper
        default: return .supper
        }
    }
}

enum FoodSource: String, CaseIterable, Codable, Identifiable {
    case manual
    case ai

    var id: String { rawValue }
}

enum NutritionDataBasis: String, CaseIterable, Codable, Identifiable {
    case direct
    case per100g
    case per100ml
    case perServing
    case estimated

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .direct: return "直接录入"
        case .per100g: return "每100g标签换算"
        case .per100ml: return "每100ml标签换算"
        case .perServing: return "每份标签换算"
        case .estimated: return "估算"
        }
    }
}

enum MealSource: String, CaseIterable, Codable, Identifiable {
    case manual
    case aiText
    case aiPhoto

    var id: String { rawValue }
}

// MARK: - Body & Activity

enum Gender: String, CaseIterable, Codable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "男"
        case .female: return "女"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Codable, Identifiable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sedentary: return "久坐"
        case .lightlyActive: return "轻度活动"
        case .moderatelyActive: return "中度活动"
        case .veryActive: return "重度活动"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        }
    }
}

enum BodyMeasurementSource: String, CaseIterable, Codable, Identifiable {
    case manual
    case appleHealth
    case ai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: return "手动记录"
        case .appleHealth: return "Apple Health"
        case .ai: return "AI 记录"
        }
    }
}

// MARK: - Habit

enum HabitFrequencyType: String, CaseIterable, Codable, Identifiable {
    case daily
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "每天"
        case .weekly: return "每周"
        }
    }
}

// MARK: - Workout

enum WorkoutType: String, CaseIterable, Codable, Identifiable {
    case strength
    case running
    case cycling
    case swimming
    case walking
    case yoga
    case hiit
    case ballSports
    case rest
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: return "力量"
        case .running: return "跑步"
        case .cycling: return "骑行"
        case .swimming: return "游泳"
        case .walking: return "步行"
        case .yoga: return "瑜伽"
        case .hiit: return "HIIT"
        case .ballSports: return "球类"
        case .rest: return "休息"
        case .other: return "其他"
        }
    }

    var icon: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .walking: return "figure.walk"
        case .yoga: return "figure.mind.and.body"
        case .hiit: return "bolt.fill"
        case .ballSports: return "basketball.fill"
        case .rest: return "bed.double.fill"
        case .other: return "figure.mixed.cardio"
        }
    }
}

enum WorkoutIntensity: String, CaseIterable, Codable, Identifiable {
    case low
    case moderate
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "低"
        case .moderate: return "中"
        case .high: return "高"
        }
    }
}

enum WorkoutSource: String, CaseIterable, Codable {
    case manual
    case healthKit

    var displayName: String {
        switch self {
        case .manual: return "手动"
        case .healthKit: return "Apple Health"
        }
    }
}

// MARK: - Bowel Health

enum BristolStoolType: String, CaseIterable, Codable, Identifiable {
    case hard
    case normal
    case soft
    case loose
    case watery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hard:   return "偏硬"
        case .normal: return "正常"
        case .soft:   return "偏软"
        case .loose:  return "稀便"
        case .watery: return "水样"
        }
    }

    var emoji: String {
        switch self {
        case .hard:   return "🟤"
        case .normal: return "✅"
        case .soft:   return "🟡"
        case .loose:  return "🟠"
        case .watery: return "🔴"
        }
    }

    var bristolDescription: String {
        switch self {
        case .hard:   return "干燥、颗粒状，排便费力"
        case .normal: return "成形、质软，排便顺畅"
        case .soft:   return "较软但成形，边缘模糊"
        case .loose:  return "蓬松、稀烂，无固定形状"
        case .watery: return "完全液态，无固体成分"
        }
    }
}

// MARK: - Journal

enum Mood: String, CaseIterable, Codable, Identifiable {
    case happy
    case calm
    case sad
    case angry
    case tired

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .calm: return "😐"
        case .sad: return "😢"
        case .angry: return "😤"
        case .tired: return "😴"
        }
    }

    var displayName: String {
        switch self {
        case .happy: return "开心"
        case .calm: return "平静"
        case .sad: return "难过"
        case .angry: return "生气"
        case .tired: return "疲惫"
        }
    }
}

enum ActivityTag: String, CaseIterable, Codable, Identifiable {
    case stress
    case sleep
    case exercise
    case work
    case overtime
    case diningOut
    case social
    case travel
    case study
    case rest
    case sick
    case period
    case gaming
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stress: return "压力"
        case .sleep: return "睡眠"
        case .exercise: return "运动"
        case .work: return "工作"
        case .overtime: return "加班"
        case .diningOut: return "外食"
        case .social: return "社交"
        case .travel: return "旅行"
        case .study: return "学习"
        case .rest: return "休息"
        case .sick: return "生病"
        case .period: return "经期"
        case .gaming: return "游戏/娱乐"
        case .other: return "其他"
        }
    }
}

// MARK: - App Settings

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case system
    case zhHans
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .zhHans: return "简体中文"
        case .english: return "English"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Supporting Structs

struct TemplateFoodItem: Codable {
    let name: String
    let amount: Double
    let unit: String
    let servingGrams: Double
    let calories: Double
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let sodium: Double?
    let sugar: Double?
    let cholesterol: Double?
    let caffeine: Double?
    let teaPolyphenols: Double?
    let calcium: Double?
    let magnesium: Double?
    let potassium: Double?
    let iron: Double?
    let zinc: Double?
    let vitaminA: Double?
    let vitaminC: Double?
    let vitaminD: Double?
    let vitaminE: Double?
    let vitaminB1: Double?
    let vitaminB2: Double?
    let niacin: Double?
    let vitaminB6: Double?
    let folate: Double?
    let vitaminB12: Double?
    let nutritionDataBasisRaw: String?
    let labelBaseAmount: Double?
    let labelBaseUnit: String?
    let packageNetAmount: Double?
    let packageNetUnit: String?
    let consumedAmount: Double?
    let consumedUnit: String?
    let nutritionDataNote: String?

    init(name: String,
         amount: Double,
         unit: String,
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
         nutritionDataBasisRaw: String? = nil,
         labelBaseAmount: Double? = nil,
         labelBaseUnit: String? = nil,
         packageNetAmount: Double? = nil,
         packageNetUnit: String? = nil,
         consumedAmount: Double? = nil,
         consumedUnit: String? = nil,
         nutritionDataNote: String? = nil) {
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
        self.nutritionDataBasisRaw = nutritionDataBasisRaw
        self.labelBaseAmount = labelBaseAmount
        self.labelBaseUnit = labelBaseUnit
        self.packageNetAmount = packageNetAmount
        self.packageNetUnit = packageNetUnit
        self.consumedAmount = consumedAmount
        self.consumedUnit = consumedUnit
        self.nutritionDataNote = nutritionDataNote
    }
}
