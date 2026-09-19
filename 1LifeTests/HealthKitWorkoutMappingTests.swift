import XCTest
@testable import OneLife

/// F-035: the HealthKit import used to floor every session at one whole minute, so a
/// 30-second drill was stored as 60 seconds of exercise. The mapping is pure, so it is
/// tested without a HealthKit store.
@MainActor
final class HealthKitWorkoutMappingTests: XCTestCase {
    private func minutes(_ seconds: TimeInterval) -> Double {
        HealthKitService.durationMinutes(fromSeconds: seconds)
    }

    func testSubMinuteSessionsKeepTheirRealLength() {
        XCTAssertEqual(minutes(10), 0.2, accuracy: 0.0001)
        XCTAssertEqual(minutes(30), 0.5, accuracy: 0.0001)
        XCTAssertEqual(minutes(40), 0.7, accuracy: 0.0001)
    }

    func testNothingIsStoredAsZeroOnceTheClockHasTicked() {
        XCTAssertEqual(minutes(1), 0.1, accuracy: 0.0001)
        XCTAssertEqual(minutes(3), 0.1, accuracy: 0.0001)
    }

    func testWholeAndHalfMinutesRoundWithoutDrift() {
        XCTAssertEqual(minutes(60), 1, accuracy: 0.0001)
        XCTAssertEqual(minutes(90), 1.5, accuracy: 0.0001)
        XCTAssertEqual(minutes(45 * 60), 45, accuracy: 0.0001)
        XCTAssertEqual(minutes(2 * 60 * 60), 120, accuracy: 0.0001)
    }

    func testZeroLengthSampleStaysZero() {
        XCTAssertEqual(minutes(0), 0, accuracy: 0.0001)
        XCTAssertEqual(minutes(-30), 0, accuracy: 0.0001)
    }
}
