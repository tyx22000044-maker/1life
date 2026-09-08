import Foundation
import SwiftData

nonisolated enum ExportService {
    enum CSVGranularity {
        case detail
        case dailySummary
    }

    enum BackupError: LocalizedError {
        case invalidVersion(Int)

        var errorDescription: String? {
            switch self {
            case .invalidVersion(let version):
                return "不支持的备份版本：\(version)"
            }
        }
    }

    enum PDFExportError: LocalizedError {
        case invalidDateRange
        case emptyDrinkSelection
        case emptySupplementSelection

        var errorDescription: String? {
            switch self {
            case .invalidDateRange:
                return "请选择有效的导出日期范围。"
            case .emptyDrinkSelection:
                return "请至少选择一个要导出的饮品。"
            case .emptySupplementSelection:
                return "请至少选择一个要导出的补剂。"
            }
        }
    }

    static func exportCSV(
        settings: UserSettings?,
        meals: [Meal],
        waterLogs: [WaterLog],
        workouts: [WorkoutLog],
        bodyMeasurements: [BodyMeasurement],
        bowelLogs: [BowelLog],
        granularity: CSVGranularity
    ) -> String {
        CSVExportService.exportCSV(
            settings: settings,
            meals: meals,
            waterLogs: waterLogs,
            workouts: workouts,
            bodyMeasurements: bodyMeasurements,
            bowelLogs: bowelLogs,
            granularity: granularity
        )
    }

    @MainActor
    static func exportNutritionPDF(
        settings: UserSettings?,
        nutritionGoals: [NutritionGoal],
        meals: [Meal],
        waterLogs: [WaterLog],
        workouts: [WorkoutLog],
        bodyMeasurements: [BodyMeasurement],
        bowelLogs: [BowelLog],
        dateRange: ClosedRange<Date>
    ) throws -> Data {
        try NutritionPDFExportService.exportNutritionPDF(
            settings: settings,
            nutritionGoals: nutritionGoals,
            meals: meals,
            waterLogs: waterLogs,
            workouts: workouts,
            bodyMeasurements: bodyMeasurements,
            bowelLogs: bowelLogs,
            dateRange: dateRange
        )
    }

    static func exportMealTemplatesJSON(_ templates: [MealTemplate]) throws -> Data {
        try MealTemplateExportService.exportJSON(templates)
    }

    @MainActor
    static func importMealTemplatesJSON(_ data: Data, into context: ModelContext, existingTemplates: [MealTemplate]) throws -> Int {
        try MealTemplateExportService.importJSON(data, into: context, existingTemplates: existingTemplates)
    }

    static func exportDrinkLibraryJSON(_ records: [DrinkRecord]) throws -> Data {
        try DrinkLibraryExportService.exportJSON(records)
    }

    @MainActor
    static func importDrinkLibraryJSON(_ data: Data, into context: ModelContext, existingRecords: [DrinkRecord]) throws -> (imported: Int, skipped: Int) {
        try DrinkLibraryExportService.importJSON(data, into: context, existingRecords: existingRecords)
    }

    @MainActor
    static func exportDrinkLibraryPDF(records: [DrinkRecord]) throws -> Data {
        try NutritionPDFExportService.exportDrinkLibraryPDF(records: records)
    }

    static func exportSupplementLibraryJSON(_ records: [SupplementRecord]) throws -> Data {
        try SupplementLibraryExportService.exportJSON(records)
    }

    @MainActor
    static func importSupplementLibraryJSON(_ data: Data, into context: ModelContext, existingRecords: [SupplementRecord]) throws -> (imported: Int, skipped: Int) {
        try SupplementLibraryExportService.importJSON(data, into: context, existingRecords: existingRecords)
    }

    @MainActor
    static func exportSupplementLibraryPDF(records: [SupplementRecord]) throws -> Data {
        try NutritionPDFExportService.exportSupplementLibraryPDF(records: records)
    }

}

// MARK: - JSON Backup

extension ExportService {
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
                           supplementRecords: [SupplementRecord] = []) throws -> Data {
        try BackupExportService.exportJSON(
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
    }

    @MainActor
    static func importJSON(_ data: Data, into context: ModelContext, existingSettings: UserSettings?) throws {
        try BackupExportService.importJSON(data, into: context, existingSettings: existingSettings)
    }
}
