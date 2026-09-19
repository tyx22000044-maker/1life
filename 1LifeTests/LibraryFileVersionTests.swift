import XCTest
import SwiftData
@testable import OneLife

/// The standalone library files carry their own `version`, and importing used to ignore it:
/// an unknown layout would then decode partially and silently fill gaps with defaults.
@MainActor
final class LibraryFileVersionTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SettingsSchemaV2.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container.mainContext
    }

    private func json(_ version: Int, array: String) -> Data {
        Data(#"{"version":\#(version),"exportedAt":"2026-09-01T00:00:00Z","\#(array)":[]}"#.utf8)
    }

    func testUnknownTemplateLibraryVersionIsRefused() throws {
        let context = try makeContext()

        XCTAssertThrowsError(try MealTemplateExportService.importJSON(json(999, array: "templates"), into: context, existingTemplates: [])) { error in
            guard case ExportService.BackupError.unsupportedFileVersion(let kind, let version) = error else {
                return XCTFail("expected unsupportedFileVersion, got \(error)")
            }
            XCTAssertEqual(kind, "模板库")
            XCTAssertEqual(version, 999)
        }

        XCTAssertEqual(try MealTemplateExportService.importJSON(json(1, array: "templates"), into: context, existingTemplates: []), 0)
    }

    func testUnknownDrinkLibraryVersionIsRefused() throws {
        let context = try makeContext()

        XCTAssertThrowsError(try DrinkLibraryExportService.importJSON(json(2, array: "records"), into: context, existingRecords: []))
        XCTAssertNoThrow(try DrinkLibraryExportService.importJSON(json(1, array: "records"), into: context, existingRecords: []))
    }

    func testUnknownSupplementLibraryVersionIsRefused() throws {
        let context = try makeContext()

        XCTAssertThrowsError(try SupplementLibraryExportService.importJSON(json(7, array: "records"), into: context, existingRecords: []))
        XCTAssertNoThrow(try SupplementLibraryExportService.importJSON(json(1, array: "records"), into: context, existingRecords: []))
    }
}
