import Foundation
import SwiftData

@Model
final class HabitLog {
    var id: UUID
    var date: Date
    var value: Double
    var createdAt: Date

    var habit: Habit?

    init(date: Date = .now, value: Double = 1) {
        self.id = UUID()
        self.date = date
        self.value = value
        self.createdAt = .now
    }
}
