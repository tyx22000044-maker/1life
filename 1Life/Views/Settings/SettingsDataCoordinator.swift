import Foundation
import SwiftData
import UserNotifications

@MainActor
struct SettingsDataCoordinator {
    static func exportCSV(
        settings: UserSettings?,
        meals: [Meal],
        waterLogs: [WaterLog],
        workouts: [WorkoutLog],
        bodyMeasurements: [BodyMeasurement],
        bowelLogs: [BowelLog],
        granularity: ExportService.CSVGranularity
    ) throws -> URL {
        let csv = ExportService.exportCSV(
            settings: settings,
            meals: meals,
            waterLogs: waterLogs,
            workouts: workouts,
            bodyMeasurements: bodyMeasurements,
            bowelLogs: bowelLogs,
            granularity: granularity
        )
        let fileName = granularity == .detail ? "1Life_detail.csv" : "1Life_daily.csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try csv.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    static func defaultPDFRange(
        meals: [Meal],
        waterLogs: [WaterLog],
        workouts: [WorkoutLog],
        bodyMeasurements: [BodyMeasurement],
        bowelLogs: [BowelLog]
    ) -> ClosedRange<Date> {
        let calendar = Calendar.current
        var recordDates: [Date] = []
        recordDates.reserveCapacity(meals.count + waterLogs.count + workouts.count + bodyMeasurements.count + bowelLogs.count)
        recordDates.append(contentsOf: meals.map(\.date))
        recordDates.append(contentsOf: waterLogs.map(\.date))
        recordDates.append(contentsOf: workouts.map(\.startDate))
        recordDates.append(contentsOf: bodyMeasurements.map(\.date))
        recordDates.append(contentsOf: bowelLogs.map(\.date))

        let latestRecordDate = recordDates.max() ?? .now
        let end = calendar.startOfDay(for: latestRecordDate)
        let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        return start...end
    }

    static func dayCount(for dateRange: ClosedRange<Date>) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: dateRange.lowerBound)
        let end = calendar.startOfDay(for: dateRange.upperBound)
        return max((calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1, 1)
    }

    static func exportNutritionPDF(
        settings: UserSettings?,
        nutritionGoals: [NutritionGoal],
        meals: [Meal],
        waterLogs: [WaterLog],
        workouts: [WorkoutLog],
        bodyMeasurements: [BodyMeasurement],
        bowelLogs: [BowelLog],
        dateRange: ClosedRange<Date>
    ) throws -> URL {
        let data = try ExportService.exportNutritionPDF(
            settings: settings,
            nutritionGoals: nutritionGoals,
            meals: meals,
            waterLogs: waterLogs,
            workouts: workouts,
            bodyMeasurements: bodyMeasurements,
            bowelLogs: bowelLogs,
            dateRange: dateRange
        )
        let fileName = "1Life_report_\(dateRange.lowerBound.isoDateString)_to_\(dateRange.upperBound.isoDateString).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL, options: [.atomic])
        return tempURL
    }

    static func exportJSON(
        settings: UserSettings?,
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
        supplementRecords: [SupplementRecord] = []
    ) throws -> URL {
        let data = try ExportService.exportJSON(
            settings: settings,
            nutritionGoals: nutritionGoals,
            meals: meals,
            waterLogs: waterLogs,
            habits: habits,
            journalEntries: journalEntries,
            workouts: workouts,
            bodyMeasurements: bodyMeasurements,
            bowelLogs: bowelLogs,
            userFoods: userFoods,
            mealTemplates: mealTemplates,
            chatMessages: chatMessages,
            supplementRecords: supplementRecords
        )
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("1Life_backup.json")
        try data.write(to: tempURL, options: [.atomic])
        return tempURL
    }

    static func importJSON(from url: URL, into modelContext: ModelContext, existingSettings: UserSettings?) throws {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        try ExportService.importJSON(data, into: modelContext, existingSettings: existingSettings)
    }

    static func clearAllData(modelContext: ModelContext, currentSettings: UserSettings?) throws {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let configService = LocalAIConfigurationService()
        for provider in AIProvider.allCases {
            try? configService.deleteAPIKey(provider: provider)
        }

        try modelContext.delete(model: Meal.self)
        try modelContext.delete(model: FoodItem.self)
        try modelContext.delete(model: UserFood.self)
        try modelContext.delete(model: MealTemplate.self)
        try modelContext.delete(model: WaterLog.self)
        try modelContext.delete(model: Habit.self)
        try modelContext.delete(model: HabitLog.self)
        try modelContext.delete(model: JournalEntry.self)
        try modelContext.delete(model: JournalPhoto.self)
        try modelContext.delete(model: WorkoutLog.self)
        try modelContext.delete(model: BodyMeasurement.self)
        try modelContext.delete(model: BowelLog.self)
        try modelContext.delete(model: NutritionGoal.self)
        try modelContext.delete(model: AIChatMessage.self)
        try modelContext.delete(model: SupplementRecord.self)

        if let currentSettings {
            currentSettings.isAIConfigured = false
            currentSettings.isHealthKitEnabled = false
            currentSettings.useHealthKitForDynamicTDEE = false
            currentSettings.hasCompletedOnboarding = false
            currentSettings.updatedAt = .now
        }

        try modelContext.save()
    }
}
