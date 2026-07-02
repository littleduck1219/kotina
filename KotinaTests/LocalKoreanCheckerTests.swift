import XCTest
@testable import Kotina

final class LocalKoreanCheckerTests: XCTestCase {
    func testCheckReturnsRuleBasedResultWithoutMockLabel() async throws {
        let result = try await LocalKoreanChecker().check("몇일 안되요")

        XCTAssertEqual(result.originalText, "몇일 안되요")
        XCTAssertEqual(result.correctedText, "며칠 안 돼요")
        XCTAssertEqual(result.issues.count, 2)
        XCTAssertFalse(result.issues.contains { $0.reason.localizedCaseInsensitiveContains("mock") })
    }

    func testCheckNormalizesInputToNFC() async throws {
        let decomposed = "한글".decomposedStringWithCanonicalMapping

        let result = try await LocalKoreanChecker().check(decomposed)

        XCTAssertEqual(result.originalText, "한글")
        XCTAssertEqual(result.correctedText, "한글")
    }
}
