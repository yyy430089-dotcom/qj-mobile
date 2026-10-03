// 在 iOS 模拟器中走真实 C ABI、Swift 解码和异步队列。
import XCTest

final class EngineClientTests: XCTestCase {
    private func client() -> EngineClient { EngineClient(resourceBundle: Bundle(for: Self.self)) }

    private func perform(_ client: EngineClient, _ action: [String: Any]) throws -> EngineFrame {
        let completed = expectation(description: "Engine action")
        var frame: EngineFrame?
        client.perform(action) { result in frame = result; completed.fulfill() }
        wait(for: [completed], timeout: 10)
        return try XCTUnwrap(frame)
    }

    func testChineseThenEnglishAnnotation() throws {
        let engine = client()
        let query = try perform(engine, ["action": "input", "text": "kaifa"])
        let index = try XCTUnwrap(query.candidates.firstIndex { $0.text == "开发" })
        XCTAssertNil(query.candidates[index].annotation)
        let annotated = try perform(engine, ["action": "annotate", "revision": query.revision])
        XCTAssertEqual(annotated.revision, query.revision)
        XCTAssertNotNil(annotated.candidates[index].annotation)
        let committed = try perform(engine, ["action": "choose", "revision": query.revision, "index": index])
        XCTAssertEqual(committed.committed, "开发")
        XCTAssertEqual(committed.input, "")
    }

    func testPartialCommitAndRejectedStaleSelection() throws {
        let engine = client()
        let old = try perform(engine, ["action": "input", "text": "kaifa"])
        let query = try perform(engine, ["action": "input", "text": "zhe"])
        let stale = try perform(engine, ["action": "choose", "revision": old.revision, "index": 0])
        XCTAssertTrue(stale.committed.isEmpty)
        XCTAssertNotNil(stale.error)
        let index = try XCTUnwrap(query.candidates.firstIndex { $0.text == "开发" })
        let partial = try perform(engine, ["action": "choose", "revision": query.revision, "index": index])
        XCTAssertEqual(partial.committed, "开发")
        XCTAssertEqual(partial.input, "zhe")
        let last = try perform(engine, ["action": "space"])
        XCTAssertEqual(last.committed, "者")
    }

    func testRapidCommandsKeepTheirOrder() {
        let engine = client()
        let complete = expectation(description: "Ordered callbacks")
        complete.expectedFulfillmentCount = 7
        var received: [String] = []
        let commands: [[String: Any]] = ["k", "a", "i", "f", "a"].map { ["action": "input", "text": $0] }
            + [["action": "backspace"], ["action": "input", "text": "a"]]
        for command in commands {
            engine.perform(command) { frame in
                XCTAssertNotNil(frame)
                XCTAssertTrue(Thread.isMainThread)
                received.append(frame?.input ?? "unavailable")
                complete.fulfill()
            }
        }
        wait(for: [complete], timeout: 15)
        XCTAssertEqual(received, ["k", "ka", "kai", "kaif", "kaifa", "kaif", "kaifa"])
    }
}
