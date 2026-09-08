import XCTest
@testable import OneLife

@MainActor
final class AIChatRecordDateResolverTests: XCTestCase {
    private let calendar = Calendar.current

    private func referenceDate() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 10
        components.hour = 14
        components.minute = 22
        return calendar.date(from: components)!
    }

    private func expected(base: Date, hour: Int, minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    func testDefaultsToNowWhenNoDayOrHourMentioned() {
        let now = referenceDate()
        let resolved = AIChatRecordDateResolver.date(from: "吃了一个苹果", now: now)
        let nowMinute = calendar.component(.minute, from: now)
        XCTAssertEqual(resolved, expected(base: now, hour: 14, minute: nowMinute))
    }

    func testYesterdayShiftsBaseDateBackOneDay() {
        let now = referenceDate()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let resolved = AIChatRecordDateResolver.date(from: "昨天吃了火锅", now: now)
        XCTAssertEqual(resolved, expected(base: yesterday, hour: 14, minute: 22))
    }

    func testDayBeforeYesterdayShiftsBaseDateBackTwoDays() {
        let now = referenceDate()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        let resolved = AIChatRecordDateResolver.date(from: "前天喝了奶茶", now: now)
        XCTAssertEqual(resolved, expected(base: twoDaysAgo, hour: 14, minute: 22))
    }

    func testExplicitHourTakesPriorityOverMealInference() {
        let now = referenceDate()
        let resolved = AIChatRecordDateResolver.date(from: "早上10点吃了鸡蛋", now: now)
        XCTAssertEqual(resolved, expected(base: now, hour: 10, minute: 22))
    }

    func testMealKeywordInfersHourWhenNoExplicitHour() {
        let now = referenceDate()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let resolved = AIChatRecordDateResolver.date(from: "昨晚吃了火锅", now: now)
        // "昨晚" both shifts the base date back one day and implies dinner hour (19:00).
        XCTAssertEqual(resolved, expected(base: yesterday, hour: 19, minute: 22))
    }

    func testBreakfastKeywordInfersHourEight() {
        let now = referenceDate()
        let resolved = AIChatRecordDateResolver.date(from: "早饭吃了三明治", now: now)
        XCTAssertEqual(resolved, expected(base: now, hour: 8, minute: 22))
    }
}
