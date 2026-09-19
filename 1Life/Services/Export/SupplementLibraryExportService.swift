import Foundation
import SwiftData

// MARK: - 补剂知识库 JSON 导出/导入

nonisolated enum SupplementLibraryExportService {
    static func exportJSON(_ records: [SupplementRecord]) throws -> Data {
        let file = SupplementLibraryBackupFile(
            version: 1,
            exportedAt: .now,
            records: records.map(SupplementLibraryBackupRecord.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    /// 按去重键（品牌+商品+剂型+规格）跳过已有版本，只导入新增
    @MainActor
    static func importJSON(_ data: Data, into context: ModelContext, existingRecords: [SupplementRecord]) throws -> (imported: Int, skipped: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(SupplementLibraryBackupFile.self, from: data)
        try LibraryFileFormat.validate(kind: "补剂库", version: file.version)
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

nonisolated private struct SupplementLibraryBackupFile: Codable {
    let version: Int
    let exportedAt: Date
    let records: [SupplementLibraryBackupRecord]
}

nonisolated private struct SupplementLibraryBackupRecord: Codable {
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
    let confidence: String

    init(_ record: SupplementRecord) {
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
        confidence = record.confidence.rawValue
    }

    func model() -> SupplementRecord {
        SupplementRecord(
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            productName: productName.trimmingCharacters(in: .whitespacesAndNewlines),
            form: form.trimmingCharacters(in: .whitespacesAndNewlines),
            servingSize: servingSize.trimmingCharacters(in: .whitespacesAndNewlines),
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
            confidence: SupplementConfidence(rawValue: confidence) ?? .medium
        )
    }
}
