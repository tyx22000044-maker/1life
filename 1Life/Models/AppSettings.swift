import Foundation
import SwiftData

// MARK: - Schema versioning for the AppSettings → UserSettings rename
//
// SwiftData identifies persisted models by type name, so renaming the Swift type alone
// would make an existing user's local settings unreadable on next launch (treated as a
// brand-new, empty entity). SettingsSchemaV1 freezes the old shape under the old name so
// SettingsMigrationPlan can read existing rows and copy them into UserSettings before the
// old rows are discarded. Every other model is unchanged, so it's referenced identically
// in both schema versions.

enum SettingsSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            AppSettingsV1.self,
            NutritionGoal.self,
            Meal.self,
            FoodItem.self,
            UserFood.self,
            MealTemplate.self,
            WaterLog.self,
            BowelLog.self,
            Habit.self,
            HabitLog.self,
            JournalEntry.self,
            JournalPhoto.self,
            WorkoutLog.self,
            BodyMeasurement.self,
            AIChatMessage.self,
            DrinkRecord.self,
            SupplementRecord.self
        ]
    }

    /// Frozen snapshot of the pre-rename `AppSettings` shape, used only so the migration
    /// stage below can decode existing persisted rows. Never constructed directly — every
    /// property default here exists purely to satisfy Swift's initialization rules.
    @Model
    final class AppSettingsV1 {
        var id: UUID = UUID()
        var dataSchemaVersion: Int = 8

        var dietGoalModeRaw: String = DietGoalMode.balanced.rawValue
        var useCustomCalorieMultiplier: Bool = false
        var customCalorieMultiplier: Double = 1.0
        var proteinTargetStrategyRaw: String = ProteinTargetStrategy.macroRatio.rawValue
        var proteinTargetMultiplier: Double = 1.2

        var languageRaw: String = AppLanguage.system.rawValue
        var appearanceRaw: String = AppearanceMode.system.rawValue

        var nickname: String = ""
        var avatarImageData: Data?

        var selectedAIProviderRaw: String = AIProvider.claude.rawValue
        var selectedAIModel: String = AIProvider.claude.defaultModel
        var mealPluginAIModel: String = ""
        var drinkPluginAIModel: String = ""
        var supplementPluginAIModel: String = ""
        var mealPluginAIProviderRaw: String = ""
        var drinkPluginAIProviderRaw: String = ""
        var supplementPluginAIProviderRaw: String = ""
        var isAIConfigured: Bool = false

        var genderRaw: String?
        var age: Int?
        var heightCm: Double?
        var weightKg: Double?
        var activityLevelRaw: String?

        var isHealthKitEnabled: Bool = false
        var useHealthKitForDynamicTDEE: Bool = false

        var dailyWaterGoalMl: Double = 2000
        var defaultCupMl: Double = 250
        var defaultBottleMl: Double = 500

        var isBreakfastReminderEnabled: Bool = true
        var breakfastReminderHour: Int = 8
        var isLunchReminderEnabled: Bool = true
        var lunchReminderHour: Int = 12
        var isDinnerReminderEnabled: Bool = true
        var dinnerReminderHour: Int = 19

        var weeklyWorkoutTargetCount: Int = 3
        var weeklyWorkoutTargetMinutes: Int = 150
        var isWorkoutTargetReminderEnabled: Bool = false
        var isWorkoutRestReminderEnabled: Bool = false

        var spotlightNutrientKeysJSON: String = "[\"protein\",\"carbs\",\"fat\",\"fiber\",\"sodium\"]"

        var isCloudSyncEnabled: Bool = false

        var isHapticsEnabled: Bool = true
        var isSoundEffectsEnabled: Bool = true

        var hasCompletedOnboarding: Bool = false

        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now

        init() {}
    }
}

enum SettingsSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            UserSettings.self,
            NutritionGoal.self,
            Meal.self,
            FoodItem.self,
            UserFood.self,
            MealTemplate.self,
            WaterLog.self,
            BowelLog.self,
            Habit.self,
            HabitLog.self,
            JournalEntry.self,
            JournalPhoto.self,
            WorkoutLog.self,
            BodyMeasurement.self,
            AIChatMessage.self,
            DrinkRecord.self,
            SupplementRecord.self
        ]
    }
}

enum SettingsMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SettingsSchemaV1.self, SettingsSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// Copies every existing `AppSettingsV1` row into a new `UserSettings` row, field by
    /// field, then drops the old row. Runs once per store, only for installs that already
    /// have data under the old schema — a fresh install starts directly on SettingsSchemaV2
    /// and never touches this stage.
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SettingsSchemaV1.self,
        toVersion: SettingsSchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let oldRecords = try context.fetch(FetchDescriptor<SettingsSchemaV1.AppSettingsV1>())
            for old in oldRecords {
                let new = UserSettings()
                new.id = old.id
                new.dataSchemaVersion = old.dataSchemaVersion
                new.dietGoalModeRaw = old.dietGoalModeRaw
                new.useCustomCalorieMultiplier = old.useCustomCalorieMultiplier
                new.customCalorieMultiplier = old.customCalorieMultiplier
                new.proteinTargetStrategyRaw = old.proteinTargetStrategyRaw
                new.proteinTargetMultiplier = old.proteinTargetMultiplier
                new.languageRaw = old.languageRaw
                new.appearanceRaw = old.appearanceRaw
                new.nickname = old.nickname
                new.avatarImageData = old.avatarImageData
                new.selectedAIProviderRaw = old.selectedAIProviderRaw
                new.selectedAIModel = old.selectedAIModel
                new.mealPluginAIModel = old.mealPluginAIModel
                new.drinkPluginAIModel = old.drinkPluginAIModel
                new.supplementPluginAIModel = old.supplementPluginAIModel
                new.mealPluginAIProviderRaw = old.mealPluginAIProviderRaw
                new.drinkPluginAIProviderRaw = old.drinkPluginAIProviderRaw
                new.supplementPluginAIProviderRaw = old.supplementPluginAIProviderRaw
                new.isAIConfigured = old.isAIConfigured
                new.genderRaw = old.genderRaw
                new.age = old.age
                new.heightCm = old.heightCm
                new.weightKg = old.weightKg
                new.activityLevelRaw = old.activityLevelRaw
                new.isHealthKitEnabled = old.isHealthKitEnabled
                new.useHealthKitForDynamicTDEE = old.useHealthKitForDynamicTDEE
                new.dailyWaterGoalMl = old.dailyWaterGoalMl
                new.defaultCupMl = old.defaultCupMl
                new.defaultBottleMl = old.defaultBottleMl
                new.isBreakfastReminderEnabled = old.isBreakfastReminderEnabled
                new.breakfastReminderHour = old.breakfastReminderHour
                new.isLunchReminderEnabled = old.isLunchReminderEnabled
                new.lunchReminderHour = old.lunchReminderHour
                new.isDinnerReminderEnabled = old.isDinnerReminderEnabled
                new.dinnerReminderHour = old.dinnerReminderHour
                new.weeklyWorkoutTargetCount = old.weeklyWorkoutTargetCount
                new.weeklyWorkoutTargetMinutes = old.weeklyWorkoutTargetMinutes
                new.isWorkoutTargetReminderEnabled = old.isWorkoutTargetReminderEnabled
                new.isWorkoutRestReminderEnabled = old.isWorkoutRestReminderEnabled
                new.spotlightNutrientKeysJSON = old.spotlightNutrientKeysJSON
                new.isCloudSyncEnabled = old.isCloudSyncEnabled
                new.isHapticsEnabled = old.isHapticsEnabled
                new.isSoundEffectsEnabled = old.isSoundEffectsEnabled
                new.hasCompletedOnboarding = old.hasCompletedOnboarding
                new.createdAt = old.createdAt
                new.updatedAt = old.updatedAt

                context.insert(new)
                context.delete(old)
            }
            try context.save()
        }
    )
}

@Model
final class UserSettings {
    static let currentDataSchemaVersion = 8

    var id: UUID
    var dataSchemaVersion: Int = UserSettings.currentDataSchemaVersion

    // MARK: - Diet Goal
    var dietGoalModeRaw: String = DietGoalMode.balanced.rawValue
    var useCustomCalorieMultiplier: Bool = false
    var customCalorieMultiplier: Double = 1.0
    var proteinTargetStrategyRaw: String = ProteinTargetStrategy.macroRatio.rawValue
    var proteinTargetMultiplier: Double = 1.2

    // MARK: - Language & Appearance
    var languageRaw: String = AppLanguage.system.rawValue
    var appearanceRaw: String = AppearanceMode.system.rawValue

    // MARK: - Profile
    var nickname: String
    var avatarImageData: Data?

    // MARK: - AI Configuration
    var selectedAIProviderRaw: String = AIProvider.claude.rawValue
    var selectedAIModel: String = AIProvider.claude.defaultModel
    /// 三个识别插件固定使用 aichat（ChatGPT 兼容接口），模型允许分别覆盖全局模型。
    var mealPluginAIModel: String = ""
    var drinkPluginAIModel: String = ""
    var supplementPluginAIModel: String = ""
    var mealPluginAIProviderRaw: String = ""
    var drinkPluginAIProviderRaw: String = ""
    var supplementPluginAIProviderRaw: String = ""
    var isAIConfigured: Bool

    // MARK: - Body Parameters (all Optional — user can skip)
    var genderRaw: String?
    var age: Int?
    var heightCm: Double?
    var weightKg: Double?
    var activityLevelRaw: String?

    // MARK: - Apple Health
    var isHealthKitEnabled: Bool = false
    var useHealthKitForDynamicTDEE: Bool = false

    // MARK: - Water Settings
    var dailyWaterGoalMl: Double = 2000
    var defaultCupMl: Double = 250
    var defaultBottleMl: Double = 500

    // MARK: - Notification
    var isBreakfastReminderEnabled: Bool = true
    var breakfastReminderHour: Int = 8
    var isLunchReminderEnabled: Bool = true
    var lunchReminderHour: Int = 12
    var isDinnerReminderEnabled: Bool = true
    var dinnerReminderHour: Int = 19

    // MARK: - Workout Goals
    var weeklyWorkoutTargetCount: Int = 3
    var weeklyWorkoutTargetMinutes: Int = 150
    var isWorkoutTargetReminderEnabled: Bool = false
    var isWorkoutRestReminderEnabled: Bool = false

    // MARK: - Dashboard Spotlight Nutrients
    var spotlightNutrientKeysJSON: String = "[\"protein\",\"carbs\",\"fat\",\"fiber\",\"sodium\"]"

    // MARK: - Sync
    var isCloudSyncEnabled: Bool = false

    // MARK: - Feedback
    var isHapticsEnabled: Bool = true
    var isSoundEffectsEnabled: Bool = true

    // MARK: - Onboarding
    var hasCompletedOnboarding: Bool

    // MARK: - Timestamps
    var createdAt: Date
    var updatedAt: Date

    init(nickname: String = "",
         avatarImageData: Data? = nil,
         dietGoalMode: DietGoalMode = .balanced,
         language: AppLanguage = .system,
         appearance: AppearanceMode = .system,
         selectedAIProvider: AIProvider = .claude,
         selectedAIModel: String = AIProvider.claude.defaultModel,
         isAIConfigured: Bool = false,
         genderRaw: String? = nil,
         age: Int? = nil,
         heightCm: Double? = nil,
         weightKg: Double? = nil,
         activityLevelRaw: String? = nil,
         isHapticsEnabled: Bool = true,
         isSoundEffectsEnabled: Bool = true,
         hasCompletedOnboarding: Bool = false) {
        self.id = UUID()
        self.nickname = nickname
        self.avatarImageData = avatarImageData
        self.dietGoalModeRaw = dietGoalMode.rawValue
        self.languageRaw = language.rawValue
        self.appearanceRaw = appearance.rawValue
        self.selectedAIProviderRaw = selectedAIProvider.rawValue
        self.selectedAIModel = selectedAIModel
        self.isAIConfigured = isAIConfigured
        self.genderRaw = genderRaw
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevelRaw = activityLevelRaw
        self.isHapticsEnabled = isHapticsEnabled
        self.isSoundEffectsEnabled = isSoundEffectsEnabled
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - Computed Properties

    var spotlightNutrientKeys: [NutrientKey] {
        get {
            guard let data = spotlightNutrientKeysJSON.data(using: .utf8),
                  let raws = try? JSONDecoder().decode([String].self, from: data) else {
                return [.protein, .carbs, .fat, .fiber, .sodium]
            }
            return raws.compactMap { NutrientKey(rawValue: $0) }
        }
        set {
            let raws = newValue.map(\.rawValue)
            spotlightNutrientKeysJSON = (try? String(data: JSONEncoder().encode(raws), encoding: .utf8))
                ?? "[\"protein\",\"carbs\",\"fat\",\"fiber\",\"sodium\"]"
        }
    }

    var dietGoalMode: DietGoalMode {
        get { DietGoalMode(rawValue: dietGoalModeRaw) ?? .balanced }
        set { dietGoalModeRaw = newValue.rawValue }
    }

    var proteinTargetStrategy: ProteinTargetStrategy {
        get { ProteinTargetStrategy(rawValue: proteinTargetStrategyRaw) ?? .macroRatio }
        set { proteinTargetStrategyRaw = newValue.rawValue }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .system }
        set { languageRaw = newValue.rawValue }
    }

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    var selectedAIProvider: AIProvider {
        get { AIProvider(rawValue: selectedAIProviderRaw) ?? .claude }
        set { selectedAIProviderRaw = newValue.rawValue }
    }

    var effectiveMealPluginAIModel: String {
        let value = mealPluginAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return mealPluginAIProviderRaw == selectedAIProvider.rawValue && !value.isEmpty ? value : selectedAIModel
    }

    var effectiveDrinkPluginAIModel: String {
        let value = drinkPluginAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return drinkPluginAIProviderRaw == selectedAIProvider.rawValue && !value.isEmpty ? value : selectedAIModel
    }

    var effectiveSupplementPluginAIModel: String {
        let value = supplementPluginAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return supplementPluginAIProviderRaw == selectedAIProvider.rawValue && !value.isEmpty ? value : selectedAIModel
    }

    var gender: Gender? {
        get { genderRaw.flatMap { Gender(rawValue: $0) } }
        set { genderRaw = newValue?.rawValue }
    }

    var activityLevel: ActivityLevel? {
        get { activityLevelRaw.flatMap { ActivityLevel(rawValue: $0) } }
        set { activityLevelRaw = newValue?.rawValue }
    }

    var hasBodyParameters: Bool {
        gender != nil && age != nil && heightCm != nil && weightKg != nil && activityLevel != nil
    }

    var estimatedBMR: Double? {
        guard let gender, let age, let heightCm, let weightKg else { return nil }
        switch gender {
        case .male:
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        case .female:
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        }
    }

    var estimatedTDEE: Double? {
        guard let bmr = estimatedBMR, let activityLevel else { return nil }
        return bmr * activityLevel.multiplier
    }

    var calorieTargetMultiplier: Double {
        useCustomCalorieMultiplier ? max(customCalorieMultiplier, 0.1) : dietGoalMode.calorieMultiplier
    }

    func calorieTarget(from tdee: Double?) -> Double {
        let base = tdee ?? (estimatedTDEE ?? 2000)
        return base * calorieTargetMultiplier
    }

    var recommendedCalories: Double {
        let baseTDEE = estimatedTDEE ?? 2000
        return baseTDEE * calorieTargetMultiplier
    }

    func recommendedMacroTargets(calories: Double) -> RecommendedMacroTargets {
        Self.recommendedMacroTargets(
            calories: calories,
            weightKg: weightKg,
            dietGoalMode: dietGoalMode,
            proteinTargetStrategy: proteinTargetStrategy,
            proteinTargetMultiplier: proteinTargetMultiplier
        )
    }

    func effectiveTarget(healthTDEE: Double?, goal: NutritionGoal?) -> EffectiveNutritionTarget {
        let calories: Double
        let provenance: CalorieTargetProvenance
        if useHealthKitForDynamicTDEE, let healthTDEE {
            calories = calorieTarget(from: healthTDEE)
            provenance = .healthKitDynamic
        } else if !hasBodyParameters {
            // Without body parameters nothing here is personalised: 2000 kcal is a generic
            // reference and the UI must say so.
            calories = goal?.dailyCalories ?? recommendedCalories
            provenance = .genericReference
        } else if let goal {
            calories = goal.dailyCalories
            provenance = .savedGoal
        } else {
            calories = recommendedCalories
            provenance = .bodyParameterEstimate
        }

        let isDynamic = useHealthKitForDynamicTDEE && healthTDEE != nil
        // HealthKit 只动态影响今日热量目标；其余营养目标沿用已保存的个人值，
        // 不随当天 TDEE 的中途变化重新按比例漂移。
        let fallbackMacros = recommendedMacroTargets(calories: recommendedCalories)

        let protein = goal?.dailyProtein ?? fallbackMacros.protein
        let carbs   = goal?.dailyCarbs   ?? fallbackMacros.carbs
        let fat     = goal?.dailyFat     ?? fallbackMacros.fat

        return EffectiveNutritionTarget(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: goal?.dailyFiber ?? 25,
            sodium: goal?.dailySodium ?? 2000,
            sugar: goal?.dailySugar ?? 50,
            cholesterol: goal?.dailyCholesterol ?? 300,
            caffeine: goal?.dailyCaffeine ?? 400,
            teaPolyphenols: goal?.dailyTeaPolyphenols ?? 500,
            calcium: goal?.dailyCalcium ?? 800,
            magnesium: goal?.dailyMagnesium ?? 330,
            potassium: goal?.dailyPotassium ?? 2000,
            iron: goal?.dailyIron ?? 12,
            zinc: goal?.dailyZinc ?? 12,
            vitaminA: goal?.dailyVitaminA ?? 800,
            vitaminC: goal?.dailyVitaminC ?? 100,
            vitaminD: goal?.dailyVitaminD ?? 10,
            vitaminE: goal?.dailyVitaminE ?? 14,
            vitaminB1: goal?.dailyVitaminB1 ?? 1.4,
            vitaminB2: goal?.dailyVitaminB2 ?? 1.4,
            niacin: goal?.dailyNiacin ?? 14,
            vitaminB6: goal?.dailyVitaminB6 ?? 1.4,
            folate: goal?.dailyFolate ?? 400,
            vitaminB12: goal?.dailyVitaminB12 ?? 2.4,
            isDynamic: isDynamic,
            caloriesProvenance: provenance
        )
    }

    static func recommendedMacroTargets(
        calories: Double,
        weightKg: Double?,
        dietGoalMode: DietGoalMode,
        proteinTargetStrategy: ProteinTargetStrategy,
        proteinTargetMultiplier: Double
    ) -> RecommendedMacroTargets {
        let fallbackProtein = calories * dietGoalMode.proteinRatio / 4

        guard proteinTargetStrategy == .bodyWeight, let weightKg, weightKg > 0 else {
            return RecommendedMacroTargets(
                protein: fallbackProtein,
                carbs: calories * dietGoalMode.carbsRatio / 4,
                fat: calories * dietGoalMode.fatRatio / 9
            )
        }

        let protein = max(weightKg * max(proteinTargetMultiplier, 0), 0)
        let remainingCalories = max(calories - protein * 4, 0)
        let carbShare = dietGoalMode.carbsRatio / dietGoalMode.carbFatRatioTotal
        let fatShare = dietGoalMode.fatRatio / dietGoalMode.carbFatRatioTotal

        return RecommendedMacroTargets(
            protein: protein,
            carbs: remainingCalories * carbShare / 4,
            fat: remainingCalories * fatShare / 9
        )
    }
}

/// Where the calorie target came from. A 2000 kcal generic reference must never be
/// presented like a personalised estimate.
enum CalorieTargetProvenance {
    case healthKitDynamic
    case savedGoal
    case bodyParameterEstimate
    case genericReference

    var displayName: String {
        switch self {
        case .healthKitDynamic: return "Apple Health 实测"
        case .savedGoal: return "已保存目标"
        case .bodyParameterEstimate: return "按身体参数估算"
        case .genericReference: return "通用参考值"
        }
    }

    var isGenericReference: Bool { self == .genericReference }
}

struct EffectiveNutritionTarget {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sodium: Double
    let sugar: Double
    let cholesterol: Double
    let caffeine: Double
    let teaPolyphenols: Double
    let calcium: Double
    let magnesium: Double
    let potassium: Double
    let iron: Double
    let zinc: Double
    let vitaminA: Double
    let vitaminC: Double
    let vitaminD: Double
    let vitaminE: Double
    let vitaminB1: Double
    let vitaminB2: Double
    let niacin: Double
    let vitaminB6: Double
    let folate: Double
    let vitaminB12: Double
    let isDynamic: Bool
    let caloriesProvenance: CalorieTargetProvenance

    static let fallback = EffectiveNutritionTarget(
        calories: 2000, protein: 75, carbs: 300, fat: 56,
        fiber: 25, sodium: 2000, sugar: 50, cholesterol: 300, caffeine: 400,
        teaPolyphenols: 500,
        calcium: 800, magnesium: 330, potassium: 2000, iron: 12, zinc: 12,
        vitaminA: 800, vitaminC: 100, vitaminD: 10, vitaminE: 14,
        vitaminB1: 1.4, vitaminB2: 1.4, niacin: 14, vitaminB6: 1.4,
        folate: 400, vitaminB12: 2.4, isDynamic: false, caloriesProvenance: .genericReference
    )

    func value(for key: NutrientKey) -> Double {
        switch key {
        case .protein: return protein
        case .carbs: return carbs
        case .fat: return fat
        case .fiber: return fiber
        case .sodium: return sodium
        case .sugar: return sugar
        case .cholesterol: return cholesterol
        case .caffeine: return caffeine
        case .teaPolyphenols: return teaPolyphenols
        case .calcium: return calcium
        case .magnesium: return magnesium
        case .potassium: return potassium
        case .iron: return iron
        case .zinc: return zinc
        case .vitaminA: return vitaminA
        case .vitaminC: return vitaminC
        case .vitaminD: return vitaminD
        case .vitaminE: return vitaminE
        case .vitaminB1: return vitaminB1
        case .vitaminB2: return vitaminB2
        case .niacin: return niacin
        case .vitaminB6: return vitaminB6
        case .folate: return folate
        case .vitaminB12: return vitaminB12
        }
    }
}
