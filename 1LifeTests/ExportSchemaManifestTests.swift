import XCTest
import SwiftData
@testable import OneLife

/// F-036: the main backup, the standalone library files and the SwiftData store each
/// kept a private version counter, so nothing in a user's data package said which
/// triple produced it. `ExportSchema` now names them in one place and every exported
/// backup stamps the versions, locale, time zone and entity counts it was written with.
@MainActor
final class ExportSchemaManifestTests: XCTestCase {
    private func makeStore() throws -> (ModelContainer, ModelContext) {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SettingsSchemaV2.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, container.mainContext)
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func testDeclaredVersionsAreInternallyConsistent() {
        XCTAssertTrue(
            ExportSchema.readableBackupVersions.contains(ExportSchema.backupVersion),
            "the version this app writes must be one this app can read back"
        )
        XCTAssertEqual(ExportSchema.libraryVersion, LibraryFileFormat.supportedVersion)
        XCTAssertEqual(ExportSchema.readableBackupVersions.sorted(), [5, 6, 7, 8, 9])
    }

    func testExportStampsProducerVersionsLocaleAndEntityCounts() throws {
        let data = try BackupExportService.exportJSON(
            settings: UserSettings(),
            nutritionGoals: [],
            meals: [Meal(mealType: .lunch)],
            waterLogs: [WaterLog(amount: 250), WaterLog(amount: 300)],
            habits: [],
            journalEntries: [],
            workouts: [],
            bodyMeasurements: [],
            bowelLogs: [],
            userFoods: [],
            mealTemplates: [],
            chatMessages: [],
            drinkRecords: [DrinkRecord(brand: "喜茶", productName: "多肉葡萄", calories: 320)]
        )
        let backup = try decoder().decode(BackupFile.self, from: data)
        let manifest = try XCTUnwrap(backup.manifest, "a freshly exported backup must say who wrote it")

        XCTAssertEqual(backup.version, ExportSchema.backupVersion)
        XCTAssertEqual(manifest.backupVersion, ExportSchema.backupVersion)
        XCTAssertEqual(manifest.dataSchemaVersion, UserSettings.currentDataSchemaVersion)
        XCTAssertEqual(manifest.libraryFormatVersion, LibraryFileFormat.supportedVersion)
        XCTAssertNotEqual(manifest.appVersion, "unknown")
        XCTAssertFalse(manifest.buildVersion.isEmpty)
        XCTAssertFalse(manifest.localeIdentifier.isEmpty)
        XCTAssertFalse(manifest.timeZoneIdentifier.isEmpty)
        XCTAssertEqual(manifest.entityCounts["meals"], 1)
        XCTAssertEqual(manifest.entityCounts["waterLogs"], 2)
        XCTAssertEqual(manifest.entityCounts["drinkRecords"], 1)
        XCTAssertEqual(manifest.entityCounts["habits"], 0)
    }

    func testVersionFiveGoldenFixtureStillImportsWithoutAManifest() throws {
        let (container, context) = try makeStore()
        try withExtendedLifetime(container) {
            let backup = try decoder().decode(
                BackupFile.self,
                from: Data(Self.versionFiveFixture.utf8)
            )
            XCTAssertNil(backup.manifest, "files written before the manifest existed must still decode")
            XCTAssertEqual(backup.drinkRecords.count, 0)

            let summary = try ExportService.importJSON(
                Data(Self.versionFiveFixture.utf8),
                into: context,
                existingSettings: nil
            )
            XCTAssertEqual(summary.meals, 1)
            XCTAssertEqual(summary.waterLogs, 1)
        }
    }

    func testVersionBeyondTheMatrixIsRefusedAndNamesWhatIsReadable() throws {
        let (container, context) = try makeStore()
        try withExtendedLifetime(container) {
            let future = Self.versionFiveFixture.replacingOccurrences(
                of: #"{"version":5,"exportedAt":"2025-01-02T03:04:05Z""#,
                with: #"{"version":10,"exportedAt":"2025-01-02T03:04:05Z""#
            )
            XCTAssertThrowsError(try ExportService.importJSON(Data(future.utf8), into: context, existingSettings: nil)) { error in
                guard case ExportService.BackupError.invalidVersion(let version) = error else {
                    return XCTFail("expected invalidVersion, got \(error)")
                }
                XCTAssertEqual(version, 10)
                for readable in ExportSchema.readableBackupVersions.sorted() {
                    XCTAssertTrue(error.localizedDescription.contains("\(readable)"), error.localizedDescription)
                }
            }
        }
    }

    /// A payload from the last release before drink records existed in the backup.
    private static let versionFiveFixture = #"""
    {"version":5,"exportedAt":"2025-01-02T03:04:05Z",
     "meals":[{"id":"22222222-2222-2222-2222-222222222222","date":"2025-01-02T03:04:05Z",
               "mealTypeRaw":"dinner","photoData":null,"photoThumbnail":null,"note":"旧备份",
               "sourceRaw":"manual","foodItems":[]}],
     "waterLogs":[{"id":"33333333-3333-3333-3333-333333333333","amount":330,"date":"2025-01-02T03:04:05Z"}]}
    """#
}
