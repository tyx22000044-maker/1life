import Foundation
import SwiftData

@Model
final class BodyMeasurement {
    var id: UUID
    var date: Date
    var weightKg: Double?
    var bodyFatPercentage: Double?
    var sourceRaw: String = BodyMeasurementSource.manual.rawValue
    var syncedToAppleHealth: Bool = false
    var externalIdentifier: String?
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        date: Date = .now,
        weightKg: Double? = nil,
        bodyFatPercentage: Double? = nil,
        source: BodyMeasurementSource = .manual,
        syncedToAppleHealth: Bool = false,
        externalIdentifier: String? = nil,
        note: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercentage = bodyFatPercentage
        self.sourceRaw = source.rawValue
        self.syncedToAppleHealth = syncedToAppleHealth
        self.externalIdentifier = externalIdentifier
        self.note = note
        self.createdAt = .now
        self.updatedAt = .now
    }

    var source: BodyMeasurementSource {
        get { BodyMeasurementSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
