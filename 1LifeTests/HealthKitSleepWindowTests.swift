import XCTest
@testable import OneLife

/// Sleep window maths lives in the HealthKit service but is pure, so it is tested
/// without a HealthKit store.
// Sleep window maths lives with the HealthKit service but is pure, so it is tested here
// to avoid a second test target file for three cases.
@MainActor
final class HealthKitSleepMathsTests: XCTestCase {
    private let calendar = Calendar.current

    private func day(_ offset: Int, hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 10 + offset
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    func testOverlappingStageSamplesAreCountedOnce() {
        let window = (start: day(-1, hour: 18), end: day(0, hour: 12))
        let samples: [(start: Date, end: Date)] = [
            (day(-1, hour: 23), day(0, hour: 7)),      // whole night
            (day(-1, hour: 23, minute: 30), day(0, hour: 1, minute: 30)), // deep stage inside it
            (day(0, hour: 6), day(0, hour: 8))         // partial overlap at the end
        ]

        let hours = HealthKitService.sleepSeconds(in: window, samples: samples) / 3600
        XCTAssertEqual(hours, 9, accuracy: 0.001, "23:00→次日08:00，重叠不重复相加")
    }

    func testSamplesAreClippedToTheNightWindow() {
        let window = (start: day(-1, hour: 18), end: day(0, hour: 12))
        let samples: [(start: Date, end: Date)] = [
            (day(-2, hour: 20), day(-1, hour: 20)),   // 18:00 之前的一半不计入
            (day(0, hour: 11), day(0, hour: 23))      // 12:00 之后的部分不计入
        ]

        let hours = HealthKitService.sleepSeconds(in: window, samples: samples) / 3600
        XCTAssertEqual(hours, 3, accuracy: 0.001, "窗口两端各裁掉 1 小时")
    }

    func testSamplesOutsideTheWindowAreIgnored() {
        let window = (start: day(-1, hour: 18), end: day(0, hour: 12))
        let hours = HealthKitService.sleepSeconds(in: window, samples: [(day(1, hour: 9), day(1, hour: 15))])

        XCTAssertEqual(hours, 0, accuracy: 0.001)
    }
}
