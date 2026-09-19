import XCTest
@testable import OneLife

/// F-033: the stable-meal cache used to be an unbounded dictionary that only ever grew
/// while a session kept typing new sentences.
@MainActor
final class AIChatMealResultCacheTests: XCTestCase {
    private func meal(_ name: String) -> AIChatIntentResult {
        .addMeal(AIParsedMeal(
            mealType: .lunch,
            items: [AIParsedFoodItem(name: name, amount: 100, unit: "g", calories: 200)],
            note: ""
        ))
    }

    private func calories(_ result: AIChatIntentResult?) -> Double? {
        guard case .addMeal(let parsed)? = result else { return nil }
        return parsed.items.first?.calories
    }

    func testStoredSentenceIsServedBack() {
        var cache = AIChatMealResultCache(capacity: 4)
        cache.store(meal("拿铁"), forScope: "openai|gpt|2026-09-19", key: "喝了拿铁")
        XCTAssertEqual(calories(cache.result(forScope: "openai|gpt|2026-09-19", key: "喝了拿铁")), 200)
    }

    func testUnknownScopeAndKeyMiss() {
        var cache = AIChatMealResultCache(capacity: 4)
        cache.store(meal("拿铁"), forScope: "scope-a", key: "喝了拿铁")
        XCTAssertNil(cache.result(forScope: "scope-b", key: "喝了拿铁"))
        XCTAssertNil(cache.result(forScope: "scope-a", key: "喝了美式"))
    }

    func testScopeChangeDropsEverythingTheOldModelParsed() {
        var cache = AIChatMealResultCache(capacity: 8)
        cache.store(meal("拿铁"), forScope: "openai|gpt-4o|2026-09-19", key: "喝了拿铁")
        cache.store(meal("美式"), forScope: "openai|gpt-4o|2026-09-19", key: "喝了美式")

        cache.store(meal("澳白"), forScope: "deepseek|deepseek-chat|2026-09-19", key: "喝了澳白")

        XCTAssertEqual(cache.count, 1)
        XCTAssertNil(cache.result(forScope: "openai|gpt-4o|2026-09-19", key: "喝了拿铁"))
        XCTAssertNotNil(cache.result(forScope: "deepseek|deepseek-chat|2026-09-19", key: "喝了澳白"))
    }

    func testCapacityIsEnforcedAndTheLeastRecentlyUsedSentenceIsEvicted() {
        var cache = AIChatMealResultCache(capacity: 3)
        for index in 0..<3 {
            cache.store(meal("菜\(index)"), forScope: "scope", key: "key-\(index)")
        }
        XCTAssertEqual(cache.count, 3)

        cache.store(meal("第四道"), forScope: "scope", key: "key-3")

        XCTAssertEqual(cache.count, 3)
        XCTAssertNil(cache.result(forScope: "scope", key: "key-0"))
        XCTAssertNotNil(cache.result(forScope: "scope", key: "key-3"))
    }

    func testReadingAnEntryProtectsItFromTheNextEviction() {
        var cache = AIChatMealResultCache(capacity: 2)
        cache.store(meal("一"), forScope: "scope", key: "a")
        cache.store(meal("二"), forScope: "scope", key: "b")
        XCTAssertNotNil(cache.result(forScope: "scope", key: "a"))

        cache.store(meal("三"), forScope: "scope", key: "c")

        XCTAssertNotNil(cache.result(forScope: "scope", key: "a"), "刚被读到的句子不该先被丢掉")
        XCTAssertNil(cache.result(forScope: "scope", key: "b"))
    }

    func testSessionDefaultsStayInsideTheBound() {
        var cache = AIChatMealResultCache()
        for index in 0..<500 {
            cache.store(meal("菜\(index)"), forScope: "scope", key: "key-\(index)")
        }
        XCTAssertLessThanOrEqual(cache.count, AIChatMealResultCache.defaultCapacity)
    }

    func testZeroCapacityStillHoldsTheNewestEntry() {
        var cache = AIChatMealResultCache(capacity: 0)
        cache.store(meal("拿铁"), forScope: "scope", key: "a")
        XCTAssertEqual(cache.count, 1)
        XCTAssertNotNil(cache.result(forScope: "scope", key: "a"))
    }
}
