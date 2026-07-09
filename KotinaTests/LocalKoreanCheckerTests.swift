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

    func testSpacerAddsGeneralSpacingCorrections() async throws {
        let spacer = StaticSpacer(map: ["오늘회의는 미뤄졌어요.": "오늘 회의는 미뤄졌어요."])

        let result = try await LocalKoreanChecker(spacer: spacer).check("오늘회의는 미뤄졌어요.")

        XCTAssertEqual(result.correctedText, "오늘 회의는 미뤄졌어요.")
        XCTAssertEqual(result.issues.count, 1)
    }

    func testRuleEditWinsOverOverlappingSpacingEdit() async throws {
        let spacer = StaticSpacer(map: ["안됩니다": "안 됩니다"])

        let result = try await LocalKoreanChecker(spacer: spacer).check("안됩니다")

        XCTAssertEqual(result.correctedText, "안 됩니다")
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertEqual(result.issues[0].reason, "부정의 뜻인 ‘안’은 뒤의 용언과 띄어 써요.")
    }
}

private struct StaticKoreanAnalyzer: KoreanAnalyzing {
    let tokens: [KiwiToken]

    func analyze(_ text: String) throws -> [KiwiToken] {
        tokens
    }
}

private struct StaticSpacer: KoreanSpacing {
    let map: [String: String]

    func spacedText(_ text: String) throws -> String {
        map[text] ?? text
    }
}
