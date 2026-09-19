import Foundation

struct AIChatRecordDateResolver {
    static func date(from text: String, now: Date = .now) -> Date {
        let calendar = Calendar.current
        let base: Date
        if text.contains("前天") || text.contains("前日") {
            base = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        } else if text.contains("昨天") || text.contains("昨晚") || text.contains("昨日") || text.contains("昨天晚上") {
            base = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        } else {
            base = now
        }

        if let explicit = explicitClockTime(in: text) {
            var components = calendar.dateComponents([.year, .month, .day], from: base)
            components.hour = explicit.hour
            components.minute = explicit.minute
            components.second = 0
            return calendar.date(from: components) ?? base
        }

        let inferredHour = parsedMealHour(from: text) ?? calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        return calendar.date(bySettingHour: inferredHour, minute: minute, second: 0, of: base) ?? base
    }

    private static func parsedMealHour(from text: String) -> Int? {
        if text.contains("早餐") || text.contains("早饭") || text.contains("早上") { return 8 }
        if text.contains("午餐") || text.contains("午饭") || text.contains("中午") { return 12 }
        if text.contains("晚餐") || text.contains("晚饭") || text.contains("晚上") || text.contains("昨晚")
            || text.contains("今晚") || text.contains("夜里") { return 19 }
        if text.contains("夜宵") || text.contains("宵夜") { return 22 }
        return nil
    }

    /// Reads “下午3点”“七点半”“昨天 10 时 15 分” into a 24-hour clock time.
    /// Returns nil when the text carries no explicit hour, so meal-keyword inference
    /// still applies.
    static func explicitClockTime(in text: String) -> (hour: Int, minute: Int)? {
        let pattern = #"([0-9]{1,2}|[一二三四五六七八九十两]{1,3})\s*[点时時]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: fullRange),
              let valueRange = Range(match.range(at: 1), in: text),
              let matchRange = Range(match.range, in: text) else { return nil }

        guard let rawHour = ChineseNumber.double(in: String(text[valueRange])) else { return nil }
        let prefix = String(text[text.startIndex..<matchRange.lowerBound])
        let suffix = String(text[matchRange.upperBound...]).prefix(4)

        var hour = Int(rawHour)
        if Int(rawHour) >= 1 && Int(rawHour) <= 12 {
            hour = applyMeridiem(Int(rawHour), prefix: prefix)
        }
        guard (0...23).contains(hour) else { return nil }

        return (hour, parsedMinute(suffix))
    }

    private static func applyMeridiem(_ hour: Int, prefix: String) -> Int {
        if prefix.contains("中午") { return 12 }
        if prefix.contains("凌晨") || prefix.contains("半夜") { return hour % 12 }
        if prefix.contains("早上") || prefix.contains("上午") || prefix.contains("早晨") { return hour % 12 }
        if prefix.contains("下午") || prefix.contains("傍晚") || prefix.contains("晚上")
            || prefix.contains("夜里") || prefix.contains("晚间") {
            return hour % 12 + 12
        }
        return hour
    }

    private static func parsedMinute(_ suffix: some StringProtocol) -> Int {
        let tail = String(suffix)
        if tail.hasPrefix("半") { return 30 }
        if tail.hasPrefix("一刻") { return 15 }
        if tail.hasPrefix("两刻") || tail.hasPrefix("二刻") { return 30 }
        if tail.hasPrefix("三刻") { return 45 }
        let minutePattern = #"^([0-9]{1,2}|[一二三四五六七八九十]+)\s*分"#
        if let range = tail.range(of: minutePattern, options: .regularExpression) {
            let captured = String(tail[range])
                .replacingOccurrences(of: "分", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let minute = ChineseNumber.double(in: captured), (0...59).contains(Int(minute)) {
                return Int(minute)
            }
        }
        return 0
    }
}
