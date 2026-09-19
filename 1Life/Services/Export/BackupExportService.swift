import Foundation
import SwiftData

nonisolated enum BackupExportService {
    private static let supportedBackupVersion = 9
    private static let importableBackupVersions: Set<Int> = [5, 6, 7, 8, 9]

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

    /// Replaces the local store with the contents of a backup file.
    ///
    /// The payload is fully decoded and validated before any existing record is
    /// touched, and the replacement is buffered with autosave suspended so the only
    /// commit is the final `save()`; a payload that fails partway rolls the context
    /// back instead of leaving a half-emptied store behind.
    @MainActor
    static func importJSON(_ data: Data, into context: ModelContext, existingSettings: UserSettings?) throws -> BackupImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupFile.self, from: data)
        guard importableBackupVersions.contains(backup.version) else {
            throw ExportService.BackupError.invalidVersion(backup.version)
        }
        try BackupPayloadValidator.validate(backup)

        let summary = try overwrite(with: backup, into: context, existingSettings: existingSettings)
        DrinkLibraryIndex.shared.invalidate()
        SupplementLibraryIndex.shared.invalidate()
        return summary
    }

    @MainActor
    private static func overwrite(
        with backup: BackupFile,
        into context: ModelContext,
        existingSettings: UserSettings?
    ) throws -> BackupImportSummary {
        let previousAutosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = previousAutosave }

        do {
            try context.delete(model: Meal.self)
            try context.delete(model: FoodItem.self)
            try context.delete(model: UserFood.self)
            try context.delete(model: MealTemplate.self)
            try context.delete(model: WaterLog.self)
            try context.delete(model: Habit.self)
            try context.delete(model: HabitLog.self)
            try context.delete(model: JournalEntry.self)
            try context.delete(model: JournalPhoto.self)
            try context.delete(model: WorkoutLog.self)
            try context.delete(model: BodyMeasurement.self)
            try context.delete(model: BowelLog.self)
            try context.delete(model: NutritionGoal.self)
            try context.delete(model: AIChatMessage.self)
            try context.delete(model: SupplementRecord.self)
            try context.delete(model: DrinkRecord.self)

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
        } catch {
            // Nothing has been committed yet (autosave is off and this is the only save),
            // so rolling the context back leaves the previous library untouched.
            context.rollback()
            throw error
        }

        return BackupImportSummary(
            meals: backup.meals.count,
            waterLogs: backup.waterLogs.count,
            habits: backup.habits.count,
            journalEntries: backup.journalEntries.count,
            workouts: backup.workouts.count,
            bodyMeasurements: backup.bodyMeasurements.count,
            bowelLogs: backup.bowelLogs.count,
            userFoods: backup.userFoods.count,
            mealTemplates: backup.mealTemplates.count,
            chatMessages: backup.chatMessages.count,
            supplementRecords: backup.supplementRecords.count,
            drinkRecords: backup.drinkRecords.count
        )
    }
}

struct BackupImportSummary {
    let meals: Int
    let waterLogs: Int
    let habits: Int
    let journalEntries: Int
    let workouts: Int
    let bodyMeasurements: Int
    let bowelLogs: Int
    let userFoods: Int
    let mealTemplates: Int
    let chatMessages: Int
    let supplementRecords: Int
    let drinkRecords: Int

    var entityCount: Int {
        meals + waterLogs + habits + journalEntries + workouts + bodyMeasurements
            + bowelLogs + userFoods + mealTemplates + chatMessages + supplementRecords + drinkRecords
    }

    /// Counts the caller can quote back to the user, drinks included because the
    /// drink library was silently dropped from backups before version 8.
    var detailText: String {
        "餐食 \(meals) · 饮水 \(waterLogs) · 习惯 \(habits) · 日志 \(journalEntries) · 训练 \(workouts)"
            + " · 身体 \(bodyMeasurements) · 排便 \(bowelLogs) · 食物 \(userFoods) · 模板 \(mealTemplates)"
            + " · 对话 \(chatMessages) · 补剂 \(supplementRecords) · 饮品 \(drinkRecords)"
    }
}

enum BackupPayloadValidator {
    /// Structural checks that JSON typing can't express. Two records sharing an id would
    /// both persist (SwiftData has no unique constraint here) and then undo/delete by id
    /// would hit the wrong row. Non-numeric or unrepresentable values are already rejected
    /// by `JSONDecoder` itself.
    static func validate(_ backup: BackupFile) throws {
        let sections: [(String, [Any])] = [
            ("nutritionGoals", backup.nutritionGoals),
            ("meals", backup.meals),
            ("waterLogs", backup.waterLogs),
            ("habits", backup.habits),
            ("journalEntries", backup.journalEntries),
            ("workouts", backup.workouts),
            ("bodyMeasurements", backup.bodyMeasurements),
            ("bowelLogs", backup.bowelLogs),
            ("userFoods", backup.userFoods),
            ("mealTemplates", backup.mealTemplates),
            ("chatMessages", backup.chatMessages),
            ("supplementRecords", backup.supplementRecords),
            ("drinkRecords", backup.drinkRecords)
        ]

        for (name, records) in sections {
            var seenIDs = Set<UUID>()
            for record in records {
                guard let id = Mirror(reflecting: record).children.first(where: { $0.label == "id" })?.value as? UUID else {
                    continue
                }
                guard seenIDs.insert(id).inserted else {
                    throw ExportService.BackupError.corruptPayload("\(name) 中存在重复 id")
                }
            }
        }
    }
}
