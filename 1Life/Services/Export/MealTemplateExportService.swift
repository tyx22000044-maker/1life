import Foundation
import SwiftData

nonisolated enum MealTemplateExportService {
    static func exportJSON(_ templates: [MealTemplate]) throws -> Data {
        let file = TemplateBackupFile(
            version: 1,
            exportedAt: .now,
            templates: templates.map(TemplateRecord.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    @MainActor
    static func importJSON(_ data: Data, into context: ModelContext, existingTemplates: [MealTemplate]) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(TemplateBackupFile.self, from: data)
        try LibraryFileFormat.validate(kind: "模板库", version: file.version)
        var existingNames = Set(existingTemplates.map(\.name))
        var importedCount = 0

        for record in file.templates {
            let template = record.model()
            template.id = UUID()
            template.name = uniqueTemplateName(record.name, existingNames: existingNames)
            existingNames.insert(template.name)
            template.createdAt = .now
            template.updatedAt = .now
            context.insert(template)
            importedCount += 1
        }

        try context.save()
        return importedCount
    }

    private static func uniqueTemplateName(_ baseName: String, existingNames: Set<String>) -> String {
        let trimmed = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "导入模板" : trimmed
        guard existingNames.contains(base) else { return base }
        var index = 2
        while existingNames.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }
}

// MARK: - 饮品知识库 JSON 导出/导入

nonisolated enum DrinkLibraryExportService {
    static func exportJSON(_ records: [DrinkRecord]) throws -> Data {
        let file = DrinkLibraryBackupFile(
            version: 1,
            exportedAt: .now,
            records: records.map(DrinkLibraryBackupRecord.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    /// 按去重键（品牌+商品+规格+糖度+小料）跳过已有版本，只导入新增
    @MainActor
    static func importJSON(_ data: Data, into context: ModelContext, existingRecords: [DrinkRecord]) throws -> (imported: Int, skipped: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(DrinkLibraryBackupFile.self, from: data)
        try LibraryFileFormat.validate(kind: "饮品库", version: file.version)
        var existingKeys = Set(existingRecords.map(\.dedupeKey))
        var imported = 0
        var skipped = 0

        for backup in file.records {
            let record = backup.model()
            guard !record.brand.isEmpty || !record.productName.isEmpty else {
                skipped += 1
                continue
            }
            if existingKeys.contains(record.dedupeKey) {
                skipped += 1
                continue
            }
            existingKeys.insert(record.dedupeKey)
            context.insert(record)
            imported += 1
        }

        try context.save()
        return (imported, skipped)
    }
}

nonisolated private struct DrinkLibraryBackupFile: Codable {
    let version: Int
    let exportedAt: Date
    let records: [DrinkLibraryBackupRecord]
}

nonisolated private struct DrinkLibraryBackupRecord: Codable {
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
    let confidence: String

    init(_ record: DrinkRecord) {
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
        confidence = record.confidence.rawValue
    }

    func model() -> DrinkRecord {
        DrinkRecord(
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            productName: productName.trimmingCharacters(in: .whitespacesAndNewlines),
            sizeML: sizeML,
            sugarLevel: sugarLevel.trimmingCharacters(in: .whitespacesAndNewlines),
            toppings: toppings.trimmingCharacters(in: .whitespacesAndNewlines),
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
            confidence: DrinkConfidence(rawValue: confidence) ?? .medium
        )
    }
}
