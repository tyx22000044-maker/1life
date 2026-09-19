import XCTest
@testable import OneLife

/// Guards the invariant behind F-006: the request the app assembles must carry the
/// current user text exactly once. `AIChatViewModel` snapshots history *before* it
/// inserts the new user message; if that ever regresses, the provider receives the
/// same turn twice and may act on it twice.
@MainActor
final class AIPromptBuilderHistoryTests: XCTestCase {
    private let history = [
        AIChatHistoryItem(role: "user", content: "昨天吃了什么"),
        AIChatHistoryItem(role: "assistant", content: "昨天合计 1800kcal")
    ]

    func testChatPromptAppendsCurrentUserTextOnce() {
        let messages = AIPromptBuilder.makeMessages(text: "记录今天吃了苹果", history: history, context: nil)

        XCTAssertEqual(messages.filter { $0.content == "记录今天吃了苹果" }.count, 1)
        XCTAssertEqual(messages.last?.content, "记录今天吃了苹果")
        XCTAssertEqual(messages.count, history.count + 2, "system + 历史两条 + 当前输入")
    }

    func testIntentPromptAppendsCurrentUserTextOnce() {
        let messages = AIPromptBuilder.makeIntentMessages(text: "喝了两杯水", history: history, context: nil)

        XCTAssertEqual(messages.filter { $0.content == "喝了两杯水" }.count, 1)
        XCTAssertEqual(messages.last?.content, "喝了两杯水")
    }
}
