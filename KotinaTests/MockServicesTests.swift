import XCTest
@testable import Kotina

final class MockServicesTests: XCTestCase {
    func testKnownSpellingSampleProducesCorrection() async throws {
        let result = try await MockSpellingChecker(delay: .zero)
            .check("오늘 회의는 몇일 뒤로 미뤄졌어요.")

        XCTAssertEqual(result.issues.map(\.suggestion), ["며칠"])
        XCTAssertEqual(result.correctedText, "오늘 회의는 며칠 뒤로 미뤄졌어요.")
    }

    func testTextWithoutKnownMistakeRemainsUnchanged() async throws {
        let source = "오늘 회의가 있습니다."
        let result = try await MockSpellingChecker(delay: .zero).check(source)

        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.correctedText, source)
    }

    func testKnownTranslationSampleProducesEnglish() async throws {
        let result = try await MockTranslator(delay: .zero)
            .translate("오늘 회의는 몇일 뒤로 미뤄졌어요.", direction: .koreanToEnglish)

        XCTAssertEqual(
            result.translatedText,
            "Today's meeting has been postponed for a few days."
        )
    }

    func testUnknownTranslationIsClearlyMarkedAsMock() async throws {
        let result = try await MockTranslator(delay: .zero).translate("새 문장", direction: .koreanToEnglish)

        XCTAssertEqual(result.translatedText, "[Mock translation] 새 문장")
        XCTAssertEqual(result.sourceLanguage, "ko")
        XCTAssertEqual(result.targetLanguage, "en")
    }
}
