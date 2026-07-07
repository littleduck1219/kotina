import XCTest
@testable import Kotina

final class KiwiAnalyzerTests: XCTestCase {
    func testMissingModelPathThrowsInitializationError() {
        XCTAssertThrowsError(try KiwiAnalyzer(modelPath: "/missing/kiwi/model")) { error in
            XCTAssertEqual(error as? TextProcessingError, .localEngineUnavailable)
        }
    }

    func testOfficialModelAnalyzesTextWithValidRanges() throws {
        let modelPath = try ProcessInfo.processInfo.environment["KOTINA_KIWI_MODEL_PATH"]
            ?? XCTUnwrap(Bundle.main.url(forResource: "base", withExtension: nil)?.path)
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
}
