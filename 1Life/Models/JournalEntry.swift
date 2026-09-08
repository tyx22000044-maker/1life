import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var date: Date
    var moodRaw: String?
    var tags: [String]
    var content: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \JournalPhoto.journalEntry)
    var photos: [JournalPhoto]?

    init(date: Date = .now,
         mood: Mood? = nil,
         tags: [String] = [],
         content: String = "") {
        self.id = UUID()
        self.date = date
        self.moodRaw = mood?.rawValue
        self.tags = tags
        self.content = content
        self.createdAt = .now
        self.updatedAt = .now
    }

    var mood: Mood? {
        get { moodRaw.flatMap { Mood(rawValue: $0) } }
        set { moodRaw = newValue?.rawValue }
    }

    var activityTags: [ActivityTag] {
        tags.compactMap { ActivityTag(rawValue: $0) }
    }

    var photoCount: Int {
        photos?.count ?? 0
    }
}
