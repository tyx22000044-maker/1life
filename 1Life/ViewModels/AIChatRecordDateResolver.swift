import Foundation

struct AIChatRecordDateResolver {
    static func date(from text: String, now: Date = .now) -> Date {
        let calendar = Calendar.current
        let base: Date
        if text.contains("前天") {
            base = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        } else if text.contains("昨天") || text.contains("昨晚") || text.contains("昨日") {
            base = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        } else {
            base = now
        }
        let hour = parsedHour(from: text) ?? parsedMealHour(from: text) ?? calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }

    private static func parsedMealHour(from text: String) -> Int? {
        if text.contains("早餐") || text.contains("早饭") || text.contains("早上") { return 8 }
        if text.contains("午餐") || text.contains("午饭") || text.contains("中午") { return 12 }
        if text.contains("晚餐") || text.contains("晚饭") || text.contains("晚上") || text.contains("昨晚") { return 19 }
        if text.contains("夜宵") || text.contains("宵夜") { return 22 }
        return nil
    }

    private static func parsedHour(from text: String) -> Int? {
        if let range = text.range(of: #"\d{1,2}\s*(点|时)"#, options: .regularExpression) {
            let raw = text[range].filter(\.isNumber)
            if let hour = Int(raw), (0...23).contains(hour) { return hour }
        }
        return nil
    }
}
