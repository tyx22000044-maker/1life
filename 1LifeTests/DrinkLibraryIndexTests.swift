import XCTest
import SwiftData
@testable import OneLife

@MainActor
final class DrinkLibraryIndexTests: XCTestCase {
    override func tearDown() {
        DrinkLibraryIndex.shared.invalidate()
        super.tearDown()
    }

    private func makeContext(records: [DrinkRecord]) throws -> ModelContext {
        let schema = Schema([DrinkRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        for record in records { context.insert(record) }
        try context.save()
        return context
    }

    func testMatchesExactSugarLevelVersion() throws {
        let records = [
            DrinkRecord(brand: "喜茶", productName: "多肉葡萄", sizeML: 650, sugarLevel: "无糖", calories: 300),
            DrinkRecord(brand: "喜茶", productName: "多肉葡萄", sizeML: 650, sugarLevel: "七分糖", calories: 380)
        ]
        let context = try makeContext(records: records)
        DrinkLibraryIndex.shared.invalidate()
        DrinkLibraryIndex.shared.rebuildIfNeeded(using: context)

        let match = DrinkLibraryIndex.shared.matchResult(text: "喝了杯喜茶多肉葡萄七分糖")
        XCTAssertEqual(match?.entry.sugarLevel, "七分糖")
        XCTAssertEqual(match?.kind, .exactVersion)
    }

    func testFallsBackToBaselineWhenExactSugarVersionMissing() throws {
        let records = [DrinkRecord(brand: "喜茶", productName: "多肉葡萄", sizeML: 650, sugarLevel: "无糖", calories: 300)]
        let context = try makeContext(records: records)
        DrinkLibraryIndex.shared.invalidate()
        DrinkLibraryIndex.shared.rebuildIfNeeded(using: context)

        let match = DrinkLibraryIndex.shared.matchResult(text: "喝了杯喜茶多肉葡萄五分糖")
        XCTAssertEqual(match?.entry.sugarLevel, "无糖")
        XCTAssertEqual(match?.kind, .baselineAdjusted)
    }

    func testNoMatchWhenProductNotMentioned() throws {
        let records = [DrinkRecord(brand: "喜茶", productName: "多肉葡萄", calories: 300)]
        let context = try makeContext(records: records)
        DrinkLibraryIndex.shared.invalidate()
        DrinkLibraryIndex.shared.rebuildIfNeeded(using: context)

        XCTAssertNil(DrinkLibraryIndex.shared.matchResult(text: "喝了瓶可乐"))
    }

    func testUniqueProductNameMatchesWithoutBrandMention() throws {
        let records = [DrinkRecord(brand: "喜茶", productName: "多肉葡萄", calories: 300)]
        let context = try makeContext(records: records)
        DrinkLibraryIndex.shared.invalidate()
        DrinkLibraryIndex.shared.rebuildIfNeeded(using: context)

        let match = DrinkLibraryIndex.shared.matchResult(text: "喝了杯多肉葡萄")
        XCTAssertEqual(match?.kind, .uniqueProduct)
        XCTAssertEqual(match?.entry.brand, "喜茶")
    }
}
