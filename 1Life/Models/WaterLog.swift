import Foundation
import SwiftData

@Model
final class WaterLog {
    var id: UUID
    var date: Date
    var amount: Double
    var createdAt: Date

    init(date: Date = .now, amount: Double = 250) {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.createdAt = .now
    }
}

@Model
final class BowelLog {
    var id: UUID
    var date: Date
    var bristolTypeRaw: String
    var note: String
    var createdAt: Date

    init(date: Date = .now, bristolType: BristolStoolType = .normal, note: String = "") {
        self.id = UUID()
        self.date = date
        self.bristolTypeRaw = bristolType.rawValue
        self.note = note
        self.createdAt = .now
    }

    var bristolType: BristolStoolType {
        get { BristolStoolType(rawValue: bristolTypeRaw) ?? .normal }
        set { bristolTypeRaw = newValue.rawValue }
    }
}
