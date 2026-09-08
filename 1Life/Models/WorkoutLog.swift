import Foundation
import SwiftData

@Model
final class WorkoutLog {
    var id: UUID
    var workoutTypeRaw: String
    var startDate: Date
    var durationMinutes: Double
    var caloriesBurned: Double?
    var intensityRaw: String
    var isRestDay: Bool
    var sourceRaw: String
    var externalIdentifier: String?
    var note: String
    var averageHeartRate: Double?
    var distanceMeters: Double?
    var createdAt: Date
    var updatedAt: Date

    init(workoutType: WorkoutType = .strength,
         startDate: Date = .now,
         durationMinutes: Double = 30,
         caloriesBurned: Double? = nil,
         intensity: WorkoutIntensity = .moderate,
         isRestDay: Bool = false,
         source: WorkoutSource = .manual,
         externalIdentifier: String? = nil,
         note: String = "",
         averageHeartRate: Double? = nil,
         distanceMeters: Double? = nil) {
        self.id = UUID()
        self.workoutTypeRaw = workoutType.rawValue
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.intensityRaw = intensity.rawValue
        self.isRestDay = isRestDay
        self.sourceRaw = source.rawValue
        self.externalIdentifier = externalIdentifier
        self.note = note
        self.averageHeartRate = averageHeartRate
        self.distanceMeters = distanceMeters
        self.createdAt = .now
        self.updatedAt = .now
    }

    var workoutType: WorkoutType {
        get { WorkoutType(rawValue: workoutTypeRaw) ?? .strength }
        set { workoutTypeRaw = newValue.rawValue }
    }

    var intensity: WorkoutIntensity {
        get { WorkoutIntensity(rawValue: intensityRaw) ?? .moderate }
        set { intensityRaw = newValue.rawValue }
    }

    var source: WorkoutSource {
        get { WorkoutSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
