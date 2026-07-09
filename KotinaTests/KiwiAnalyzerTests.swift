import XCTest
@testable import Kotina

final class KiwiAnalyzerTests: XCTestCase {
    func testMissingModelPathThrowsInitializationError() {
        XCTAssertThrowsError(try KiwiAnalyzer(modelPath: "/missing/kiwi/model")) { error in
            XCTAssertEqual(error as? TextProcessingError, .localEngineUnavailable)
        }
    }

    private func officialModelPath() throws -> String {
        try ProcessInfo.processInfo.environment["KOTINA_KIWI_MODEL_PATH"]
            ?? XCTUnwrap(Bundle.main.url(forResource: "base", withExtension: nil)?.path)
    }

    func testOfficialModelAnalyzesTextWithValidRanges() throws {
        let modelPath = try officialModelPath()
        let text = "아버지가방에들어가신다"
        let analyzer = try KiwiAnalyzer(modelPath: modelPath)

        let tokens = try analyzer.analyze(text)

        XCTAssertFalse(tokens.isEmpty)
        for token in tokens {
            XCTAssertFalse(token.form.isEmpty)
            XCTAssertFalse(token.tag.isEmpty)
            XCTAssertGreaterThan(token.range.upperBound, token.range.lowerBound)
            XCTAssertGreaterThanOrEqual(token.range.lowerBound, text.startIndex)
            XCTAssertLessThanOrEqual(token.range.upperBound, text.endIndex)
        }
    }

    func testSpacedTextRestoresStandardSpacing() throws {
        let analyzer = try KiwiAnalyzer(modelPath: officialModelPath())

        XCTAssertEqual(try analyzer.spacedText("할수있다"), "할 수 있다")
        XCTAssertEqual(try analyzer.spacedText("밥을먹었다"), "밥을 먹었다")
    }

    func testSpacedTextKeepsAlreadyCorrectSentence() throws {
        let analyzer = try KiwiAnalyzer(modelPath: officialModelPath())
        let text = "오늘 회의는 며칠 뒤로 미뤄졌어요."

        XCTAssertEqual(try analyzer.spacedText(text), text)
    }

    func testCheckerRemovesWrongSpaceInsideGreeting() async throws {
        let analyzer = try KiwiAnalyzer(modelPath: officialModelPath())
        let checker = LocalKoreanChecker(analyzer: analyzer, spacer: analyzer)

        let result = try await checker.check("안녕 하세요")

        XCTAssertEqual(result.correctedText, "안녕하세요")
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertEqual(result.issues[0].original, "녕 하")
        XCTAssertEqual(result.issues[0].suggestion, "녕하")
    }

    func testCheckerKeepsCorrectGreetingUntouched() async throws {
        let analyzer = try KiwiAnalyzer(modelPath: officialModelPath())
        let checker = LocalKoreanChecker(analyzer: analyzer, spacer: analyzer)

        let result = try await checker.check("안녕하세요")

        XCTAssertEqual(result.correctedText, "안녕하세요")
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testCheckerFixesMisplacedSpaceInsideWord() async throws {
        let analyzer = try KiwiAnalyzer(modelPath: officialModelPath())
        let checker = LocalKoreanChecker(analyzer: analyzer, spacer: analyzer)

        let result = try await checker.check("나는바 보입니다.")

        XCTAssertEqual(result.correctedText, "나는 바보입니다.")
        XCTAssertEqual(result.issues.count, 1)
    }

    func testCheckerWithKiwiSpacerCorrectsRunTogetherSentence() async throws {
        let analyzer = try KiwiAnalyzer(modelPath: officialModelPath())
        let checker = LocalKoreanChecker(analyzer: analyzer, spacer: analyzer)

        let result = try await checker.check("오늘회의는몇시에시작하나요")

        XCTAssertEqual(
            result.correctedText.filter { $0 != " " },
            "오늘회의는몇시에시작하나요"
        )
        XCTAssertGreaterThan(result.correctedText.filter { $0 == " " }.count, 0)
    }
}
