import XCTest
import SwiftData
@testable import OneLife

@MainActor
final class BackupImportAtomicityTests: XCTestCase {
    private func makeStore() throws -> (ModelContainer, ModelContext) {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SettingsSchemaV2.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, container.mainContext)
    }

    private func json(_ body: String) -> Data {
        Data(body.utf8)
    }

    /// Keeps the container alive for the duration of a test while handing back its context.
    private func withStore(_ body: (ModelContext) throws -> Void) throws {
        let (container, context) = try makeStore()
        try withExtendedLifetime(container) {
            try body(context)
        }
    }

    func testValidBackupReplacesDrinkLibraryAndReportsCounts() throws {
        try withStore { context in
            context.insert(DrinkRecord(brand: "旧品牌", productName: "旧饮品", calories: 100))
            context.insert(Meal(mealType: .lunch))
            try context.save()

            let summary = try ExportService.importJSON(
                json(#"""
                {
                  "version": 8,
                  "exportedAt": "2026-09-19T10:00:00Z",
                  "drinkRecords": [
                    {
                      "id": "11111111-1111-1111-1111-111111111111",
                      "brand": "喜茶",
                      "productName": "多肉葡萄",
                      "sizeML": 650,
                      "sugarLevel": "七分糖",
                      "toppings": "",
                      "calories": 320,
                      "protein": null,
                      "carbs": null,
                      "fat": null,
                      "sugar": null,
                      "sodium": null,
                      "caffeine": null,
                      "teaPolyphenols": null,
                      "sourceNote": "官方小程序",
                      "sourceDate": "2026-09-01T00:00:00Z",
                      "confidenceRaw": "高",
                      "createdAt": "2026-09-01T00:00:00Z",
                      "updatedAt": "2026-09-02T00:00:00Z"
                    }
                  ],
                  "meals": [
                    {
                      "id": "22222222-2222-2222-2222-222222222222",
                      "date": "2026-09-19T10:00:00Z",
                      "mealTypeRaw": "dinner",
                      "photoData": null,
                      "photoThumbnail": null,
                      "note": "",
                      "sourceRaw": "manual",
                      "foodItems": []
                    }
                  ]
                }
                """#),
                into: context,
                existingSettings: nil
            )

            XCTAssertEqual(summary.drinkRecords, 1)
            XCTAssertEqual(summary.meals, 1)
            let drinks = try context.fetch(FetchDescriptor<DrinkRecord>())
            XCTAssertEqual(drinks.count, 1)
            XCTAssertEqual(drinks.first?.brand, "喜茶")
            let meals = try context.fetch(FetchDescriptor<Meal>())
            XCTAssertEqual(meals.count, 1)
            XCTAssertEqual(meals.first?.mealType, .dinner)
        }
    }

    func testUnknownBackupVersionIsRejectedWithoutTouchingExistingData() throws {
        try withStore { context in
            context.insert(DrinkRecord(brand: "保留", productName: "保留饮品", calories: 50))
            try context.save()

            XCTAssertThrowsError(
                try ExportService.importJSON(
                    json(#"{"version": 999, "exportedAt": "2026-09-19T10:00:00Z", "drinkRecords": []}"#),
                    into: context,
                    existingSettings: nil
                )
            ) { error in
                guard case ExportService.BackupError.invalidVersion(let version) = error else {
                    return XCTFail("expected invalidVersion, got \(error)")
                }
                XCTAssertEqual(version, 999)
            }

            let drinks = try context.fetch(FetchDescriptor<DrinkRecord>())
            XCTAssertEqual(drinks.map(\.brand), ["保留"])
        }
    }

    func testDuplicateRecordIDsFailBeforeAnyDeletion() throws {
        try withStore { context in
            context.insert(DrinkRecord(brand: "保留", productName: "保留饮品", calories: 50))
            try context.save()

            let duplicated = """
            {
              "version": 8,
              "exportedAt": "2026-09-19T10:00:00Z",
              "drinkRecords": [
                \(drinkRecordJSON(id: "33333333-3333-3333-3333-333333333333")),
                \(drinkRecordJSON(id: "33333333-3333-3333-3333-333333333333"))
              ]
            }
            """

            XCTAssertThrowsError(
                try ExportService.importJSON(json(duplicated), into: context, existingSettings: nil)
            ) { error in
                guard case ExportService.BackupError.corruptPayload = error else {
                    return XCTFail("expected corruptPayload, got \(error)")
                }
            }

            let drinks = try context.fetch(FetchDescriptor<DrinkRecord>())
            XCTAssertEqual(drinks.map(\.brand), ["保留"], "被拒绝的导入不得删除本机已有数据")
        }
    }

    func testMalformedPayloadFailsBeforeAnyDeletion() throws {
        try withStore { context in
            context.insert(DrinkRecord(brand: "保留", productName: "保留饮品", calories: 50))
            try context.save()

            // calories must be a number; a string fails decoding after the version check.
            let broken = """
            {
              "version": 8,
              "exportedAt": "2026-09-19T10:00:00Z",
              "drinkRecords": [
                "not-a-record"
              ]
            }
            """

            XCTAssertThrowsError(try ExportService.importJSON(json(broken), into: context, existingSettings: nil))

            let drinks = try context.fetch(FetchDescriptor<DrinkRecord>())
            XCTAssertEqual(drinks.count, 1)
        }
    }

    private func drinkRecordJSON(id: String) -> String {
        """
        {
          "id": "\(id)",
          "brand": "喜茶",
          "productName": "多肉葡萄",
          "sizeML": 650,
          "sugarLevel": "",
          "toppings": "",
          "calories": 320,
          "protein": null,
          "carbs": null,
          "fat": null,
          "sugar": null,
          "sodium": null,
          "caffeine": null,
          "teaPolyphenols": null,
          "sourceNote": "",
          "sourceDate": "2026-09-01T00:00:00Z",
          "confidenceRaw": "中",
          "createdAt": "2026-09-01T00:00:00Z",
          "updatedAt": "2026-09-01T00:00:00Z"
        }
        """
    }
}
