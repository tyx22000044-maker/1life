import Foundation
import SwiftData

@Model
final class Habit {
    var id: UUID
    var name: String
    var iconSymbol: String
    var colorHex: String
    var frequencyTypeRaw: String = HabitFrequencyType.daily.rawValue
    var frequencyCount: Int
    var targetCount: Double?
    var unitName: String?
    var reminderHour: Int?
    var reminderMinute: Int?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog]?

    init(name: String,
         iconSymbol: String = "checkmark.circle.fill",
         colorHex: String = "3B82F6",
         frequencyType: HabitFrequencyType = .daily,
         frequencyCount: Int = 1,
         targetCount: Double? = nil,
         unitName: String? = nil,
         reminderHour: Int? = nil,
         reminderMinute: Int? = nil,
         isArchived: Bool = false) {
        self.id = UUID()
        self.name = name
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.frequencyTypeRaw = frequencyType.rawValue
        self.frequencyCount = frequencyCount
        self.targetCount = targetCount
        self.unitName = unitName
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.isArchived = isArchived
        self.createdAt = .now
        self.updatedAt = .now
    }

    var frequencyType: HabitFrequencyType {
        get { HabitFrequencyType(rawValue: frequencyTypeRaw) ?? .daily }
        set { frequencyTypeRaw = newValue.rawValue }
    }

    var isQuantityBased: Bool {
        targetCount != nil && targetCount! > 1
    }
}
