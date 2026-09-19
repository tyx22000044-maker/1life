import XCTest
@testable import OneLife

/// F-034: `AIVisionRequest` exposed a single-`image` convenience and an `image` shortcut
/// that indexed `images[0]`, so an empty list compiled fine and crashed at runtime.
@MainActor
final class AIVisionRequestTests: XCTestCase {
    private func attachment(_ byte: UInt8) -> AIImageAttachment {
        AIImageAttachment(data: Data([byte]), mediaType: "image/jpeg")
    }

    private let message = AIClientMessage(role: .user, content: "识别这张照片")

    func testEmptyImageListIsRefusedAtConstruction() {
        XCTAssertThrowsError(
            try AIVisionRequest(messages: [message], images: [], model: "vision-model", apiKey: "k")
        ) { error in
            XCTAssertTrue(error is AIVisionRequestError)
            XCTAssertEqual(error.localizedDescription, "视觉请求至少需要一张图片。")
        }
    }

    func testMoreThanTheLimitIsCappedRatherThanRejected() throws {
        let request = try AIVisionRequest(
            messages: [message],
            images: (0..<12).map { attachment(UInt8($0)) },
            model: "vision-model",
            apiKey: "k",
            timeoutInterval: 120
        )
        XCTAssertEqual(request.images.count, 6, "服务商上限仍是 6 张")
        XCTAssertEqual(request.timeoutInterval, 120)
    }

    func testSingleImageSurvivesWithoutAnIndexingShortcut() throws {
        let request = try AIVisionRequest(
            messages: [message],
            images: [attachment(7)],
            model: "vision-model",
            apiKey: "k"
        )
        XCTAssertEqual(request.images.count, 1)
        XCTAssertEqual(request.images.first?.data, Data([7]))
        XCTAssertEqual(request.images.first?.mediaType, "image/jpeg")
    }
}
