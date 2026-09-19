import Foundation

/// Parse results for meal sentences repeat inside one session — the same "喝了拿铁" typed
/// twice should not cost two round trips. The cache behind that used to grow without a
/// bound or any way to drop stale entries, so a long session with many distinct sentences
/// kept every parsed meal alive. It is now LRU-capped and scoped: a different provider,
/// model or record day invalidates everything, because a result parsed by another model —
/// or stamped for yesterday — must never be replayed.
@MainActor
struct AIChatMealResultCache {
    static let defaultCapacity = 64

    private let capacity: Int
    private var scope: String?
    private var entries: [String: AIChatIntentResult] = [:]
    private var recency: [String] = []

    init(capacity: Int = AIChatMealResultCache.defaultCapacity) {
        self.capacity = max(capacity, 1)
    }

    var count: Int { entries.count }

    mutating func result(forScope requestScope: String, key: String) -> AIChatIntentResult? {
        guard scope == requestScope, let found = entries[key] else { return nil }
        promote(key)
        return found
    }

    mutating func store(_ result: AIChatIntentResult, forScope requestScope: String, key: String) {
        if scope != requestScope {
            scope = requestScope
            entries.removeAll()
            recency.removeAll()
        }
        promote(key)
        entries[key] = result
        while recency.count > capacity {
            entries.removeValue(forKey: recency.removeFirst())
        }
    }

    private mutating func promote(_ key: String) {
        recency.removeAll { $0 == key }
        recency.append(key)
    }
}
