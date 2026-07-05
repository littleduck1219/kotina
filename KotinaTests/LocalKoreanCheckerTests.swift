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

    func testMorphologyEvidenceAllowsDependentNounSuCorrection() async throws {
        let text = "할수 있어요."
        let suRange = text.range(of: "수")!
        let analyzer = StaticKoreanAnalyzer(tokens: [
            KiwiToken(form: "수", tag: "NNB", range: suRange, typoCost: 0)
        ])

        let result = try await LocalKoreanChecker(analyzer: analyzer).check(text)

        XCTAssertEqual(result.correctedText, "할 수 있어요.")
    }

    func testMorphologyEvidenceRejectsNonDependentSuCandidate() async throws {
        let text = "할수 있어요."
        let suRange = text.range(of: "수")!
        let analyzer = StaticKoreanAnalyzer(tokens: [
            KiwiToken(form: "수", tag: "EC", range: suRange, typoCost: 0)
        ])

        let result = try await LocalKoreanChecker(analyzer: analyzer).check(text)

        XCTAssertEqual(result.correctedText, text)
        XCTAssertTrue(result.issues.isEmpty)
    }
}

private struct StaticKoreanAnalyzer: KoreanAnalyzing {
    let tokens: [KiwiToken]

    func analyze(_ text: String) throws -> [KiwiToken] {
        tokens
    }
}
