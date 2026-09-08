import Foundation
import SwiftData

@Model
final class JournalPhoto {
    var id: UUID
    @Attribute(.externalStorage) var photoData: Data
    var thumbnailData: Data
    var sortOrder: Int
    var createdAt: Date

    var journalEntry: JournalEntry?

    init(photoData: Data,
         thumbnailData: Data,
         sortOrder: Int = 0) {
        self.id = UUID()
        self.photoData = photoData
        self.thumbnailData = thumbnailData
        self.sortOrder = sortOrder
        self.createdAt = .now
    }
}
