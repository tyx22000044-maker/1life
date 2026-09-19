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

/// Ranges for human body metrics, shared by manual input, the AI decoder and the
/// HealthKit write path so no entry point can persist an impossible value.
nonisolated enum BodyMeasurementLimits {
    static let weightKg: ClosedRange<Double> = 20...350
    static let heightCm: ClosedRange<Double> = 80...260
    static let bodyFatPercent: ClosedRange<Double> = 1...70
    static let ageYears: ClosedRange<Int> = 10...100

    static func validatedWeight(_ value: Double?) -> Double? { inside(value, weightKg) }
    static func validatedHeight(_ value: Double?) -> Double? { inside(value, heightCm) }
    static func validatedBodyFat(_ value: Double?) -> Double? { inside(value, bodyFatPercent) }

    static func validatedAge(_ value: Int?) -> Int? {
        guard let value, ageYears.contains(value) else { return nil }
        return value
    }

    /// Non-nil input that fails validation means the user typed something impossible,
    /// which is different from leaving the field empty.
    static func outOfRangeNotice(weight: Double?, height: Double?, age: Int?, bodyFat: Double?) -> String? {
        var problems: [String] = []
        if let weight, validatedWeight(weight) == nil { problems.append("体重应为 \\(Int(weightKg.lowerBound))-\(Int(weightKg.upperBound)) kg") }
        if let height, validatedHeight(height) == nil { problems.append("身高应为 \\(Int(heightCm.lowerBound))-\(Int(heightCm.upperBound)) cm") }
        if let age, validatedAge(age) == nil { problems.append("年龄应为 \\(ageYears.lowerBound)-\(ageYears.upperBound) 岁") }
        if let bodyFat, validatedBodyFat(bodyFat) == nil { problems.append("体脂应为 \\(Int(bodyFatPercent.lowerBound))-\(Int(bodyFatPercent.upperBound))%") }
        guard !problems.isEmpty else { return nil }
        return "数值超出合理范围：" + problems.joined(separator: "；") + "。已忽略越界数值。"
    }

    private static func inside(_ value: Double?, _ range: ClosedRange<Double>) -> Double? {
        guard let value, value.isFinite, range.contains(value) else { return nil }
        return value
    }
}
