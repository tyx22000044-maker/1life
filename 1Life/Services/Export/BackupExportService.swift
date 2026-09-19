import Foundation
import SwiftData

nonisolated enum BackupExportService {
    private static let supportedBackupVersion = 8
    private static let importableBackupVersions: Set<Int> = [5, 6, 7, 8]

    static func exportJSON(settings: UserSettings?,
                           nutritionGoals: [NutritionGoal],
                           meals: [Meal],
                           waterLogs: [WaterLog],
                           habits: [Habit],
                           journalEntries: [JournalEntry],
                           workouts: [WorkoutLog],
                           bodyMeasurements: [BodyMeasurement],
                           bowelLogs: [BowelLog],
                           userFoods: [UserFood],
                           mealTemplates: [MealTemplate],
                           chatMessages: [AIChatMessage],
                           supplementRecords: [SupplementRecord] = [],
                           drinkRecords: [DrinkRecord] = []) throws -> Data {
        let backup = BackupFile(
            version: supportedBackupVersion,
            exportedAt: .now,
            settings: settings.map(SettingsRecord.init),
            nutritionGoals: nutritionGoals.map(GoalRecord.init),
            meals: meals.map(MealRecord.init),
            waterLogs: waterLogs.map(WaterRecord.init),
            habits: habits.map(HabitRecord.init),
            journalEntries: journalEntries.map(JournalRecord.init),
            workouts: workouts.map(WorkoutRecord.init),
            bodyMeasurements: bodyMeasurements.map(BodyMeasurementRecord.init),
            bowelLogs: bowelLogs.map(BowelRecord.init),
            userFoods: userFoods.map(UserFoodRecord.init),
            mealTemplates: mealTemplates.map(TemplateRecord.init),
            chatMessages: chatMessages.map(ChatRecord.init),
            supplementRecords: supplementRecords.map(SupplementRecordBackupRecord.init),
            drinkRecords: drinkRecords.map(DrinkRecordBackupRecord.init)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    @MainActor
    static func importJSON(_ data: Data, into context: ModelContext, existingSettings: UserSettings?) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupFile.self, from: data)
        guard importableBackupVersions.contains(backup.version) else {
            throw ExportService.BackupError.invalidVersion(backup.version)
        }

        try? context.delete(model: Meal.self)
        try? context.delete(model: FoodItem.self)
        try? context.delete(model: UserFood.self)
        try? context.delete(model: MealTemplate.self)
        try? context.delete(model: WaterLog.self)
        try? context.delete(model: Habit.self)
        try? context.delete(model: HabitLog.self)
        try? context.delete(model: JournalEntry.self)
        try? context.delete(model: JournalPhoto.self)
        try? context.delete(model: WorkoutLog.self)
        try? context.delete(model: BodyMeasurement.self)
        try? context.delete(model: BowelLog.self)
        try? context.delete(model: NutritionGoal.self)
        try? context.delete(model: AIChatMessage.self)
        try? context.delete(model: SupplementRecord.self)
        try? context.delete(model: DrinkRecord.self)

        if let record = backup.settings {
            let settings = existingSettings ?? UserSettings()
            record.apply(to: settings)
            if existingSettings == nil {
                context.insert(settings)
            }
        }

        for goalRecord in backup.nutritionGoals {
            context.insert(goalRecord.model())
        }

        for mealRecord in backup.meals {
            let meal = mealRecord.model()
            context.insert(meal)
            for itemRecord in mealRecord.foodItems {
                let item = itemRecord.model()
                item.meal = meal
                context.insert(item)
            }
        }

        for waterRecord in backup.waterLogs {
            context.insert(waterRecord.model())
        }

        for habitRecord in backup.habits {
            let habit = habitRecord.model()
            context.insert(habit)
            for logRecord in habitRecord.logs {
                let log = logRecord.model()
                log.habit = habit
                context.insert(log)
            }
        }

        for journalRecord in backup.journalEntries {
            let entry = journalRecord.model()
            context.insert(entry)
            for photoRecord in journalRecord.photos {
                let photo = photoRecord.model()
                photo.journalEntry = entry
                context.insert(photo)
            }
        }

        for workoutRecord in backup.workouts {
            context.insert(workoutRecord.model())
        }

        for bodyMeasurementRecord in backup.bodyMeasurements {
            context.insert(bodyMeasurementRecord.model())
        }

        for bowelRecord in backup.bowelLogs {
            context.insert(bowelRecord.model())
        }

        for userFoodRecord in backup.userFoods {
            context.insert(userFoodRecord.model())
        }

        for templateRecord in backup.mealTemplates {
            context.insert(templateRecord.model())
        }

        for chatRecord in backup.chatMessages {
            context.insert(chatRecord.model())
        }

        for supplementRecord in backup.supplementRecords {
            context.insert(supplementRecord.model())
        }

        for drinkRecord in backup.drinkRecords {
            context.insert(drinkRecord.model())
        }

        try context.save()
        DrinkLibraryIndex.shared.invalidate()
        SupplementLibraryIndex.shared.invalidate()
    }
}
