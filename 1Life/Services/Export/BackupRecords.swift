import Foundation

nonisolated struct BackupFile: Codable {
    let version: Int
    let exportedAt: Date
    let settings: SettingsRecord?
    let nutritionGoals: [GoalRecord]
    let meals: [MealRecord]
    let waterLogs: [WaterRecord]
    let habits: [HabitRecord]
    let journalEntries: [JournalRecord]
    let workouts: [WorkoutRecord]
    let bodyMeasurements: [BodyMeasurementRecord]
    let bowelLogs: [BowelRecord]
    let userFoods: [UserFoodRecord]
    let mealTemplates: [TemplateRecord]
    let chatMessages: [ChatRecord]
    let supplementRecords: [SupplementRecordBackupRecord]
    let drinkRecords: [DrinkRecordBackupRecord]

    init(version: Int,
         exportedAt: Date,
         settings: SettingsRecord?,
         nutritionGoals: [GoalRecord],
         meals: [MealRecord],
         waterLogs: [WaterRecord],
         habits: [HabitRecord],
         journalEntries: [JournalRecord],
         workouts: [WorkoutRecord],
         bodyMeasurements: [BodyMeasurementRecord],
         bowelLogs: [BowelRecord],
         userFoods: [UserFoodRecord],
         mealTemplates: [TemplateRecord],
         chatMessages: [ChatRecord],
         supplementRecords: [SupplementRecordBackupRecord] = [],
         drinkRecords: [DrinkRecordBackupRecord] = []) {
        self.version = version
        self.exportedAt = exportedAt
        self.settings = settings
        self.nutritionGoals = nutritionGoals
        self.meals = meals
        self.waterLogs = waterLogs
        self.habits = habits
        self.journalEntries = journalEntries
        self.workouts = workouts
        self.bodyMeasurements = bodyMeasurements
        self.bowelLogs = bowelLogs
        self.userFoods = userFoods
        self.mealTemplates = mealTemplates
        self.chatMessages = chatMessages
        self.supplementRecords = supplementRecords
        self.drinkRecords = drinkRecords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        settings = try container.decodeIfPresent(SettingsRecord.self, forKey: .settings)
        nutritionGoals = try container.decodeIfPresent([GoalRecord].self, forKey: .nutritionGoals) ?? []
        meals = try container.decodeIfPresent([MealRecord].self, forKey: .meals) ?? []
        waterLogs = try container.decodeIfPresent([WaterRecord].self, forKey: .waterLogs) ?? []
        habits = try container.decodeIfPresent([HabitRecord].self, forKey: .habits) ?? []
        journalEntries = try container.decodeIfPresent([JournalRecord].self, forKey: .journalEntries) ?? []
        workouts = try container.decodeIfPresent([WorkoutRecord].self, forKey: .workouts) ?? []
        bodyMeasurements = try container.decodeIfPresent([BodyMeasurementRecord].self, forKey: .bodyMeasurements) ?? []
        bowelLogs = try container.decodeIfPresent([BowelRecord].self, forKey: .bowelLogs) ?? []
        userFoods = try container.decodeIfPresent([UserFoodRecord].self, forKey: .userFoods) ?? []
        mealTemplates = try container.decodeIfPresent([TemplateRecord].self, forKey: .mealTemplates) ?? []
        chatMessages = try container.decodeIfPresent([ChatRecord].self, forKey: .chatMessages) ?? []
        supplementRecords = try container.decodeIfPresent([SupplementRecordBackupRecord].self, forKey: .supplementRecords) ?? []
        drinkRecords = try container.decodeIfPresent([DrinkRecordBackupRecord].self, forKey: .drinkRecords) ?? []
    }
}

nonisolated struct SupplementRecordBackupRecord: Codable {
    let id: UUID
    let brand: String
    let productName: String
    let form: String
    let servingSize: String
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let sodium: Double?
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
    let activeIngredientsNote: String
    let sourceNote: String
    let sourceDate: Date
    let confidenceRaw: String
    let createdAt: Date
    let updatedAt: Date

    init(_ record: SupplementRecord) {
        id = record.id
        brand = record.brand
        productName = record.productName
        form = record.form
        servingSize = record.servingSize
        calories = record.calories
        protein = record.protein
        carbs = record.carbs
        fat = record.fat
        sodium = record.sodium
        calcium = record.calcium
        magnesium = record.magnesium
        potassium = record.potassium
        iron = record.iron
        zinc = record.zinc
        vitaminA = record.vitaminA
        vitaminC = record.vitaminC
        vitaminD = record.vitaminD
        vitaminE = record.vitaminE
        vitaminB1 = record.vitaminB1
        vitaminB2 = record.vitaminB2
        niacin = record.niacin
        vitaminB6 = record.vitaminB6
        folate = record.folate
        vitaminB12 = record.vitaminB12
        activeIngredientsNote = record.activeIngredientsNote
        sourceNote = record.sourceNote
        sourceDate = record.sourceDate
        confidenceRaw = record.confidenceRaw
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    func model() -> SupplementRecord {
        let record = SupplementRecord(
            brand: brand,
            productName: productName,
            form: form,
            servingSize: servingSize,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            sodium: sodium,
            calcium: calcium,
            magnesium: magnesium,
            potassium: potassium,
            iron: iron,
            zinc: zinc,
            vitaminA: vitaminA,
            vitaminC: vitaminC,
            vitaminD: vitaminD,
            vitaminE: vitaminE,
            vitaminB1: vitaminB1,
            vitaminB2: vitaminB2,
            niacin: niacin,
            vitaminB6: vitaminB6,
            folate: folate,
            vitaminB12: vitaminB12,
            activeIngredientsNote: activeIngredientsNote,
            sourceNote: sourceNote,
            sourceDate: sourceDate,
            confidence: SupplementConfidence(rawValue: confidenceRaw) ?? .medium
        )
        record.id = id
        record.createdAt = createdAt
        record.updatedAt = updatedAt
        return record
    }
}

nonisolated struct DrinkRecordBackupRecord: Codable {
    let id: UUID
    let brand: String
    let productName: String
    let sizeML: Double?
    let sugarLevel: String
    let toppings: String
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let sugar: Double?
    let sodium: Double?
    let caffeine: Double?
    let teaPolyphenols: Double?
    let sourceNote: String
    let sourceDate: Date
    let confidenceRaw: String
    let createdAt: Date
    let updatedAt: Date

    init(_ record: DrinkRecord) {
        id = record.id
        brand = record.brand
        productName = record.productName
        sizeML = record.sizeML
        sugarLevel = record.sugarLevel
        toppings = record.toppings
        calories = record.calories
        protein = record.protein
        carbs = record.carbs
        fat = record.fat
        sugar = record.sugar
        sodium = record.sodium
        caffeine = record.caffeine
        teaPolyphenols = record.teaPolyphenols
        sourceNote = record.sourceNote
        sourceDate = record.sourceDate
        confidenceRaw = record.confidenceRaw
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    func model() -> DrinkRecord {
        let record = DrinkRecord(
            brand: brand,
            productName: productName,
            sizeML: sizeML,
            sugarLevel: sugarLevel,
            toppings: toppings,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            sugar: sugar,
            sodium: sodium,
            caffeine: caffeine,
            teaPolyphenols: teaPolyphenols,
            sourceNote: sourceNote,
            sourceDate: sourceDate,
            confidence: DrinkConfidence(rawValue: confidenceRaw) ?? .medium
        )
        record.id = id
        record.createdAt = createdAt
        record.updatedAt = updatedAt
        return record
    }
}

nonisolated struct TemplateBackupFile: Codable {
    let version: Int
    let exportedAt: Date
    let templates: [TemplateRecord]
}

nonisolated struct SettingsRecord: Codable {
    let dataSchemaVersion: Int
    let dietGoalModeRaw: String
    let useCustomCalorieMultiplier: Bool?
    let customCalorieMultiplier: Double?
    let proteinTargetStrategyRaw: String?
    let proteinTargetMultiplier: Double?
    let languageRaw: String
    let appearanceRaw: String
    let nickname: String
    let avatarImageData: Data?
    let selectedAIProviderRaw: String
    let selectedAIModel: String
    let mealPluginAIModel: String?
    let drinkPluginAIModel: String?
    let supplementPluginAIModel: String?
    let mealPluginAIProviderRaw: String?
    let drinkPluginAIProviderRaw: String?
    let supplementPluginAIProviderRaw: String?
    let isAIConfigured: Bool
    let genderRaw: String?
    let age: Int?
    let heightCm: Double?
    let weightKg: Double?
    let activityLevelRaw: String?
    let isHealthKitEnabled: Bool?
    let useHealthKitForDynamicTDEE: Bool?
    let dailyWaterGoalMl: Double
    let defaultCupMl: Double
    let defaultBottleMl: Double
    let isBreakfastReminderEnabled: Bool
    let breakfastReminderHour: Int
    let isLunchReminderEnabled: Bool
    let lunchReminderHour: Int
    let isDinnerReminderEnabled: Bool
    let dinnerReminderHour: Int
    let weeklyWorkoutTargetCount: Int?
    let weeklyWorkoutTargetMinutes: Int?
    let isWorkoutTargetReminderEnabled: Bool?
    let isWorkoutRestReminderEnabled: Bool?
    let isCloudSyncEnabled: Bool
    let hasCompletedOnboarding: Bool

    init(_ settings: UserSettings) {
        dataSchemaVersion = settings.dataSchemaVersion
        dietGoalModeRaw = settings.dietGoalModeRaw
        useCustomCalorieMultiplier = settings.useCustomCalorieMultiplier
        customCalorieMultiplier = settings.customCalorieMultiplier
        proteinTargetStrategyRaw = settings.proteinTargetStrategyRaw
        proteinTargetMultiplier = settings.proteinTargetMultiplier
        languageRaw = settings.languageRaw
        appearanceRaw = settings.appearanceRaw
        nickname = settings.nickname
        avatarImageData = settings.avatarImageData
        selectedAIProviderRaw = settings.selectedAIProviderRaw
        selectedAIModel = settings.selectedAIModel
        mealPluginAIModel = settings.mealPluginAIModel
        drinkPluginAIModel = settings.drinkPluginAIModel
        supplementPluginAIModel = settings.supplementPluginAIModel
        mealPluginAIProviderRaw = settings.mealPluginAIProviderRaw
        drinkPluginAIProviderRaw = settings.drinkPluginAIProviderRaw
        supplementPluginAIProviderRaw = settings.supplementPluginAIProviderRaw
        isAIConfigured = settings.isAIConfigured
        genderRaw = settings.genderRaw
        age = settings.age
        heightCm = settings.heightCm
        weightKg = settings.weightKg
        activityLevelRaw = settings.activityLevelRaw
        isHealthKitEnabled = settings.isHealthKitEnabled
        useHealthKitForDynamicTDEE = settings.useHealthKitForDynamicTDEE
        dailyWaterGoalMl = settings.dailyWaterGoalMl
        defaultCupMl = settings.defaultCupMl
        defaultBottleMl = settings.defaultBottleMl
        isBreakfastReminderEnabled = settings.isBreakfastReminderEnabled
        breakfastReminderHour = settings.breakfastReminderHour
        isLunchReminderEnabled = settings.isLunchReminderEnabled
        lunchReminderHour = settings.lunchReminderHour
        isDinnerReminderEnabled = settings.isDinnerReminderEnabled
        dinnerReminderHour = settings.dinnerReminderHour
        weeklyWorkoutTargetCount = settings.weeklyWorkoutTargetCount
        weeklyWorkoutTargetMinutes = settings.weeklyWorkoutTargetMinutes
        isWorkoutTargetReminderEnabled = settings.isWorkoutTargetReminderEnabled
        isWorkoutRestReminderEnabled = settings.isWorkoutRestReminderEnabled
        isCloudSyncEnabled = settings.isCloudSyncEnabled
        hasCompletedOnboarding = settings.hasCompletedOnboarding
    }

    @MainActor
    func apply(to settings: UserSettings) {
        settings.dataSchemaVersion = dataSchemaVersion
        settings.dietGoalModeRaw = dietGoalModeRaw
        settings.useCustomCalorieMultiplier = useCustomCalorieMultiplier ?? false
        settings.customCalorieMultiplier = customCalorieMultiplier ?? 1.0
        settings.proteinTargetStrategyRaw = proteinTargetStrategyRaw ?? ProteinTargetStrategy.macroRatio.rawValue
        settings.proteinTargetMultiplier = proteinTargetMultiplier ?? 1.2
        settings.languageRaw = languageRaw
        settings.appearanceRaw = appearanceRaw
        settings.nickname = nickname
        settings.avatarImageData = avatarImageData
        settings.selectedAIProviderRaw = selectedAIProviderRaw
        settings.selectedAIModel = selectedAIModel
        settings.mealPluginAIModel = mealPluginAIModel ?? ""
        settings.drinkPluginAIModel = drinkPluginAIModel ?? ""
        settings.supplementPluginAIModel = supplementPluginAIModel ?? ""
        settings.mealPluginAIProviderRaw = mealPluginAIProviderRaw ?? ""
        settings.drinkPluginAIProviderRaw = drinkPluginAIProviderRaw ?? ""
        settings.supplementPluginAIProviderRaw = supplementPluginAIProviderRaw ?? ""
        settings.isAIConfigured = isAIConfigured
        settings.genderRaw = genderRaw
        settings.age = age
        settings.heightCm = heightCm
        settings.weightKg = weightKg
        settings.activityLevelRaw = activityLevelRaw
        settings.isHealthKitEnabled = isHealthKitEnabled ?? false
        settings.useHealthKitForDynamicTDEE = useHealthKitForDynamicTDEE ?? false
        settings.dailyWaterGoalMl = dailyWaterGoalMl
        settings.defaultCupMl = defaultCupMl
        settings.defaultBottleMl = defaultBottleMl
        settings.isBreakfastReminderEnabled = isBreakfastReminderEnabled
        settings.breakfastReminderHour = breakfastReminderHour
        settings.isLunchReminderEnabled = isLunchReminderEnabled
        settings.lunchReminderHour = lunchReminderHour
        settings.isDinnerReminderEnabled = isDinnerReminderEnabled
        settings.dinnerReminderHour = dinnerReminderHour
        settings.weeklyWorkoutTargetCount = weeklyWorkoutTargetCount ?? 3
        settings.weeklyWorkoutTargetMinutes = weeklyWorkoutTargetMinutes ?? 150
        settings.isWorkoutTargetReminderEnabled = isWorkoutTargetReminderEnabled ?? false
        settings.isWorkoutRestReminderEnabled = isWorkoutRestReminderEnabled ?? false
        settings.isCloudSyncEnabled = isCloudSyncEnabled
        settings.hasCompletedOnboarding = hasCompletedOnboarding
        settings.updatedAt = .now
    }
}

nonisolated struct GoalRecord: Codable {
    let id: UUID
    let effectiveDate: Date
    let dailyCalories: Double
    let dailyProtein: Double
    let dailyCarbs: Double
    let dailyFat: Double
    let dailyFiber: Double
    let dailySodium: Double
    let dailySugar: Double
    let dailyCholesterol: Double
    let dailyCaffeine: Double?
    let dailyTeaPolyphenols: Double?
    let dailyCalcium: Double
    let dailyMagnesium: Double
    let dailyPotassium: Double
    let dailyIron: Double
    let dailyZinc: Double
    let dailyVitaminA: Double
    let dailyVitaminC: Double
    let dailyVitaminD: Double
    let dailyVitaminE: Double
    let dailyVitaminB1: Double
    let dailyVitaminB2: Double
    let dailyNiacin: Double
    let dailyVitaminB6: Double
    let dailyFolate: Double
    let dailyVitaminB12: Double

    init(_ goal: NutritionGoal) {
        id = goal.id
        effectiveDate = goal.effectiveDate
        dailyCalories = goal.dailyCalories
        dailyProtein = goal.dailyProtein
        dailyCarbs = goal.dailyCarbs
        dailyFat = goal.dailyFat
        dailyFiber = goal.dailyFiber
        dailySodium = goal.dailySodium
        dailySugar = goal.dailySugar
        dailyCholesterol = goal.dailyCholesterol
        dailyCaffeine = goal.dailyCaffeine
        dailyTeaPolyphenols = goal.dailyTeaPolyphenols
        dailyCalcium = goal.dailyCalcium
        dailyMagnesium = goal.dailyMagnesium
        dailyPotassium = goal.dailyPotassium
        dailyIron = goal.dailyIron
        dailyZinc = goal.dailyZinc
        dailyVitaminA = goal.dailyVitaminA
        dailyVitaminC = goal.dailyVitaminC
        dailyVitaminD = goal.dailyVitaminD
        dailyVitaminE = goal.dailyVitaminE
        dailyVitaminB1 = goal.dailyVitaminB1
        dailyVitaminB2 = goal.dailyVitaminB2
        dailyNiacin = goal.dailyNiacin
        dailyVitaminB6 = goal.dailyVitaminB6
        dailyFolate = goal.dailyFolate
        dailyVitaminB12 = goal.dailyVitaminB12
    }

    @MainActor
    func model() -> NutritionGoal {
        let goal = NutritionGoal(effectiveDate: effectiveDate, dailyCalories: dailyCalories, dailyProtein: dailyProtein, dailyCarbs: dailyCarbs, dailyFat: dailyFat, dailyFiber: dailyFiber, dailySodium: dailySodium, dailySugar: dailySugar, dailyCholesterol: dailyCholesterol, dailyCaffeine: dailyCaffeine ?? 400, dailyTeaPolyphenols: dailyTeaPolyphenols ?? 500, dailyCalcium: dailyCalcium, dailyMagnesium: dailyMagnesium, dailyPotassium: dailyPotassium, dailyIron: dailyIron, dailyZinc: dailyZinc, dailyVitaminA: dailyVitaminA, dailyVitaminC: dailyVitaminC, dailyVitaminD: dailyVitaminD, dailyVitaminE: dailyVitaminE, dailyVitaminB1: dailyVitaminB1, dailyVitaminB2: dailyVitaminB2, dailyNiacin: dailyNiacin, dailyVitaminB6: dailyVitaminB6, dailyFolate: dailyFolate, dailyVitaminB12: dailyVitaminB12)
        goal.id = id
        return goal
    }
}

nonisolated struct MealRecord: Codable {
    let id: UUID
    let date: Date
    let mealTypeRaw: String
    let photoData: Data?
    let photoThumbnail: Data?
    let note: String
    let sourceRaw: String
    let foodItems: [FoodItemRecord]

    init(_ meal: Meal) {
        id = meal.id
        date = meal.date
        mealTypeRaw = meal.mealTypeRaw
        photoData = meal.photoData
        photoThumbnail = meal.photoThumbnail
        note = meal.note
        sourceRaw = meal.sourceRaw
        foodItems = (meal.foodItems ?? []).map(FoodItemRecord.init)
    }

    @MainActor
    func model() -> Meal {
        let meal = Meal(date: date, mealType: MealType(rawValue: mealTypeRaw) ?? .lunch, photoData: photoData, photoThumbnail: photoThumbnail, note: note, source: MealSource(rawValue: sourceRaw) ?? .manual)
        meal.id = id
        return meal
    }
}

nonisolated struct FoodItemRecord: Codable {
    let id: UUID
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
    let nutritionDataBasisRaw: String
    let labelBaseAmount: Double?
    let labelBaseUnit: String?
    let packageNetAmount: Double?
    let packageNetUnit: String?
    let consumedAmount: Double?
    let consumedUnit: String?
    let nutritionDataNote: String?
    let sourceRaw: String

    init(_ item: FoodItem) {
        id = item.id
        name = item.name
        amount = item.amount
        unit = item.unit
        servingGrams = item.servingGrams
        calories = item.calories
        protein = item.protein
        carbs = item.carbs
        fat = item.fat
        fiber = item.fiber
        sodium = item.sodium
        sugar = item.sugar
        cholesterol = item.cholesterol
        caffeine = item.caffeine
        teaPolyphenols = item.teaPolyphenols
        calcium = item.calcium
        magnesium = item.magnesium
        potassium = item.potassium
        iron = item.iron
        zinc = item.zinc
        vitaminA = item.vitaminA
        vitaminC = item.vitaminC
        vitaminD = item.vitaminD
        vitaminE = item.vitaminE
        vitaminB1 = item.vitaminB1
        vitaminB2 = item.vitaminB2
        niacin = item.niacin
        vitaminB6 = item.vitaminB6
        folate = item.folate
        vitaminB12 = item.vitaminB12
        nutritionDataBasisRaw = item.nutritionDataBasisRaw
        labelBaseAmount = item.labelBaseAmount
        labelBaseUnit = item.labelBaseUnit
        packageNetAmount = item.packageNetAmount
        packageNetUnit = item.packageNetUnit
        consumedAmount = item.consumedAmount
        consumedUnit = item.consumedUnit
        nutritionDataNote = item.nutritionDataNote
        sourceRaw = item.sourceRaw
    }

    @MainActor
    func model() -> FoodItem {
        let item = FoodItem(name: name, amount: amount, unit: unit, servingGrams: servingGrams, calories: calories, protein: protein, carbs: carbs, fat: fat, fiber: fiber, sodium: sodium, sugar: sugar, cholesterol: cholesterol, caffeine: caffeine, teaPolyphenols: teaPolyphenols, calcium: calcium, magnesium: magnesium, potassium: potassium, iron: iron, zinc: zinc, vitaminA: vitaminA, vitaminC: vitaminC, vitaminD: vitaminD, vitaminE: vitaminE, vitaminB1: vitaminB1, vitaminB2: vitaminB2, niacin: niacin, vitaminB6: vitaminB6, folate: folate, vitaminB12: vitaminB12, nutritionDataBasis: NutritionDataBasis(rawValue: nutritionDataBasisRaw) ?? .direct, labelBaseAmount: labelBaseAmount, labelBaseUnit: labelBaseUnit, packageNetAmount: packageNetAmount, packageNetUnit: packageNetUnit, consumedAmount: consumedAmount, consumedUnit: consumedUnit, nutritionDataNote: nutritionDataNote, source: FoodSource(rawValue: sourceRaw) ?? .manual)
        item.id = id
        return item
    }
}

nonisolated struct WaterRecord: Codable {
    let id: UUID
    let date: Date
    let amount: Double
    let sourceMealID: UUID?

    init(_ log: WaterLog) {
        id = log.id
        date = log.date
        amount = log.amount
        sourceMealID = log.sourceMealID
    }

    @MainActor
    func model() -> WaterLog {
        let log = WaterLog(date: date, amount: amount, sourceMealID: sourceMealID)
        log.id = id
        return log
    }
}

nonisolated struct BowelRecord: Codable {
    let id: UUID
    let date: Date
    let bristolTypeRaw: String
    let note: String

    init(_ log: BowelLog) {
        id = log.id
        date = log.date
        bristolTypeRaw = log.bristolTypeRaw
        note = log.note
    }

    @MainActor
    func model() -> BowelLog {
        let log = BowelLog(
            date: date,
            bristolType: BristolStoolType(rawValue: bristolTypeRaw) ?? .normal,
            note: note
        )
        log.id = id
        return log
    }
}

nonisolated struct HabitRecord: Codable {
    let id: UUID
    let name: String
    let iconSymbol: String
    let colorHex: String
    let frequencyTypeRaw: String
    let frequencyCount: Int
    let targetCount: Double?
    let unitName: String?
    let reminderHour: Int?
    let reminderMinute: Int?
    let isArchived: Bool
    let logs: [HabitLogRecord]

    init(_ habit: Habit) {
        id = habit.id
        name = habit.name
        iconSymbol = habit.iconSymbol
        colorHex = habit.colorHex
        frequencyTypeRaw = habit.frequencyTypeRaw
        frequencyCount = habit.frequencyCount
        targetCount = habit.targetCount
        unitName = habit.unitName
        reminderHour = habit.reminderHour
        reminderMinute = habit.reminderMinute
        isArchived = habit.isArchived
        logs = (habit.logs ?? []).map(HabitLogRecord.init)
    }

    @MainActor
    func model() -> Habit {
        let habit = Habit(name: name, iconSymbol: iconSymbol, colorHex: colorHex, frequencyType: HabitFrequencyType(rawValue: frequencyTypeRaw) ?? .daily, frequencyCount: frequencyCount, targetCount: targetCount, unitName: unitName, reminderHour: reminderHour, reminderMinute: reminderMinute, isArchived: isArchived)
        habit.id = id
        return habit
    }
}

nonisolated struct HabitLogRecord: Codable {
    let id: UUID
    let date: Date
    let value: Double

    init(_ log: HabitLog) {
        id = log.id
        date = log.date
        value = log.value
    }

    @MainActor
    func model() -> HabitLog {
        let log = HabitLog(date: date, value: value)
        log.id = id
        return log
    }
}

nonisolated struct JournalRecord: Codable {
    let id: UUID
    let date: Date
    let moodRaw: String?
    let tags: [String]
    let content: String
    let photos: [JournalPhotoRecord]

    init(_ entry: JournalEntry) {
        id = entry.id
        date = entry.date
        moodRaw = entry.moodRaw
        tags = entry.tags
        content = entry.content
        photos = (entry.photos ?? []).map(JournalPhotoRecord.init)
    }

    @MainActor
    func model() -> JournalEntry {
        let entry = JournalEntry(date: date, mood: moodRaw.flatMap { Mood(rawValue: $0) }, tags: tags, content: content)
        entry.id = id
        return entry
    }
}

nonisolated struct JournalPhotoRecord: Codable {
    let id: UUID
    let photoData: Data
    let thumbnailData: Data
    let sortOrder: Int

    init(_ photo: JournalPhoto) {
        id = photo.id
        photoData = photo.photoData
        thumbnailData = photo.thumbnailData
        sortOrder = photo.sortOrder
    }

    @MainActor
    func model() -> JournalPhoto {
        let photo = JournalPhoto(photoData: photoData, thumbnailData: thumbnailData, sortOrder: sortOrder)
        photo.id = id
        return photo
    }
}

nonisolated struct WorkoutRecord: Codable {
    let id: UUID
    let workoutTypeRaw: String
    let startDate: Date
    let durationMinutes: Double
    let caloriesBurned: Double?
    let intensityRaw: String
    let isRestDay: Bool
    let sourceRaw: String
    let externalIdentifier: String?
    let note: String

    init(_ workout: WorkoutLog) {
        id = workout.id
        workoutTypeRaw = workout.workoutTypeRaw
        startDate = workout.startDate
        durationMinutes = workout.durationMinutes
        caloriesBurned = workout.caloriesBurned
        intensityRaw = workout.intensityRaw
        isRestDay = workout.isRestDay
        sourceRaw = workout.sourceRaw
        externalIdentifier = workout.externalIdentifier
        note = workout.note
    }

    @MainActor
    func model() -> WorkoutLog {
        let workout = WorkoutLog(
            workoutType: WorkoutType(rawValue: workoutTypeRaw) ?? .strength,
            startDate: startDate,
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned,
            intensity: WorkoutIntensity(rawValue: intensityRaw) ?? .moderate,
            isRestDay: isRestDay,
            source: WorkoutSource(rawValue: sourceRaw) ?? .manual,
            externalIdentifier: externalIdentifier,
            note: note
        )
        workout.id = id
        return workout
    }
}

nonisolated struct BodyMeasurementRecord: Codable {
    let id: UUID
    let date: Date
    let weightKg: Double?
    let bodyFatPercentage: Double?
    let sourceRaw: String
    let syncedToAppleHealth: Bool
    let externalIdentifier: String?
    let note: String

    init(_ measurement: BodyMeasurement) {
        id = measurement.id
        date = measurement.date
        weightKg = measurement.weightKg
        bodyFatPercentage = measurement.bodyFatPercentage
        sourceRaw = measurement.sourceRaw
        syncedToAppleHealth = measurement.syncedToAppleHealth
        externalIdentifier = measurement.externalIdentifier
        note = measurement.note
    }

    @MainActor
    func model() -> BodyMeasurement {
        let measurement = BodyMeasurement(
            date: date,
            weightKg: weightKg,
            bodyFatPercentage: bodyFatPercentage,
            source: BodyMeasurementSource(rawValue: sourceRaw) ?? .manual,
            syncedToAppleHealth: syncedToAppleHealth,
            externalIdentifier: externalIdentifier,
            note: note
        )
        measurement.id = id
        return measurement
    }
}

nonisolated struct UserFoodRecord: Codable {
    let id: UUID
    let brand: String?
    let name: String
    let servingNutritionJSON: String?
    let defaultAmount: Double
    let defaultUnit: String
    let defaultServingGrams: Double
    let caloriesPer100g: Double
    let proteinPer100g: Double?
    let carbsPer100g: Double?
    let fatPer100g: Double?
    let fiberPer100g: Double?
    let sodiumPer100g: Double?
    let sugarPer100g: Double?
    let cholesterolPer100g: Double?
    let caffeinePer100g: Double?
    let teaPolyphenolsPer100g: Double?
    let calciumPer100g: Double?
    let magnesiumPer100g: Double?
    let potassiumPer100g: Double?
    let ironPer100g: Double?
    let zincPer100g: Double?
    let vitaminAPer100g: Double?
    let vitaminCPer100g: Double?
    let vitaminDPer100g: Double?
    let vitaminEPer100g: Double?
    let vitaminB1Per100g: Double?
    let vitaminB2Per100g: Double?
    let niacinPer100g: Double?
    let vitaminB6Per100g: Double?
    let folatePer100g: Double?
    let vitaminB12Per100g: Double?
    let useCount: Int
    let lastUsedAt: Date?

    init(_ food: UserFood) {
        id = food.id
        brand = food.brand
        name = food.name
        servingNutritionJSON = food.servingNutritionJSON
        defaultAmount = food.defaultAmount
        defaultUnit = food.defaultUnit
        defaultServingGrams = food.defaultServingGrams
        caloriesPer100g = food.caloriesPer100g
        proteinPer100g = food.proteinPer100g
        carbsPer100g = food.carbsPer100g
        fatPer100g = food.fatPer100g
        fiberPer100g = food.fiberPer100g
        sodiumPer100g = food.sodiumPer100g
        sugarPer100g = food.sugarPer100g
        cholesterolPer100g = food.cholesterolPer100g
        caffeinePer100g = food.caffeinePer100g
        teaPolyphenolsPer100g = food.teaPolyphenolsPer100g
        calciumPer100g = food.calciumPer100g
        magnesiumPer100g = food.magnesiumPer100g
        potassiumPer100g = food.potassiumPer100g
        ironPer100g = food.ironPer100g
        zincPer100g = food.zincPer100g
        vitaminAPer100g = food.vitaminAPer100g
        vitaminCPer100g = food.vitaminCPer100g
        vitaminDPer100g = food.vitaminDPer100g
        vitaminEPer100g = food.vitaminEPer100g
        vitaminB1Per100g = food.vitaminB1Per100g
        vitaminB2Per100g = food.vitaminB2Per100g
        niacinPer100g = food.niacinPer100g
        vitaminB6Per100g = food.vitaminB6Per100g
        folatePer100g = food.folatePer100g
        vitaminB12Per100g = food.vitaminB12Per100g
        useCount = food.useCount
        lastUsedAt = food.lastUsedAt
    }

    @MainActor
    func model() -> UserFood {
        let food = UserFood(brand: brand ?? "", name: name, defaultAmount: defaultAmount, defaultUnit: defaultUnit, defaultServingGrams: defaultServingGrams, caloriesPer100g: caloriesPer100g, servingNutrition: [:], proteinPer100g: proteinPer100g, carbsPer100g: carbsPer100g, fatPer100g: fatPer100g, fiberPer100g: fiberPer100g, sodiumPer100g: sodiumPer100g, sugarPer100g: sugarPer100g, cholesterolPer100g: cholesterolPer100g, caffeinePer100g: caffeinePer100g, teaPolyphenolsPer100g: teaPolyphenolsPer100g, calciumPer100g: calciumPer100g, magnesiumPer100g: magnesiumPer100g, potassiumPer100g: potassiumPer100g, ironPer100g: ironPer100g, zincPer100g: zincPer100g, vitaminAPer100g: vitaminAPer100g, vitaminCPer100g: vitaminCPer100g, vitaminDPer100g: vitaminDPer100g, vitaminEPer100g: vitaminEPer100g, vitaminB1Per100g: vitaminB1Per100g, vitaminB2Per100g: vitaminB2Per100g, niacinPer100g: niacinPer100g, vitaminB6Per100g: vitaminB6Per100g, folatePer100g: folatePer100g, vitaminB12Per100g: vitaminB12Per100g)
        food.servingNutritionJSON = servingNutritionJSON ?? "{}"
        food.id = id
        food.useCount = useCount
        food.lastUsedAt = lastUsedAt
        return food
    }
}

nonisolated struct TemplateRecord: Codable {
    let id: UUID
    let name: String
    let mealTypeRaw: String
    let foodItemsJSON: String
    let useCount: Int
    let lastUsedAt: Date?

    init(_ template: MealTemplate) {
        id = template.id
        name = template.name
        mealTypeRaw = template.mealTypeRaw
        foodItemsJSON = template.foodItemsJSON
        useCount = template.useCount
        lastUsedAt = template.lastUsedAt
    }

    @MainActor
    func model() -> MealTemplate {
        let template = MealTemplate(name: name, mealType: MealType(rawValue: mealTypeRaw) ?? .breakfast)
        template.id = id
        template.foodItemsJSON = foodItemsJSON
        template.useCount = useCount
        template.lastUsedAt = lastUsedAt
        return template
    }
}

nonisolated struct ChatRecord: Codable {
    let id: UUID
    let role: String
    let content: String
    let providerRaw: String
    let toolName: String?
    let toolPayloadJSON: String?
    let createdMealID: UUID?
    let isLinkedDataDeleted: Bool
    let createdAt: Date

    init(_ message: AIChatMessage) {
        id = message.id
        role = message.role
        content = message.content
        providerRaw = message.providerRaw
        toolName = message.toolName
        toolPayloadJSON = message.toolPayloadJSON
        createdMealID = message.createdMealID
        isLinkedDataDeleted = message.isLinkedDataDeleted
        createdAt = message.createdAt
    }

    @MainActor
    func model() -> AIChatMessage {
        let message = AIChatMessage(role: role, content: content, provider: AIProvider(rawValue: providerRaw) ?? .claude, toolName: toolName, toolPayloadJSON: toolPayloadJSON, createdMealID: createdMealID)
        message.id = id
        message.isLinkedDataDeleted = isLinkedDataDeleted
        message.createdAt = createdAt
        return message
    }
}
