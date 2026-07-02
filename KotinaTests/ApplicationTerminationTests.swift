import XCTest
@testable import Kotina

@MainActor
final class ApplicationTerminationTests: XCTestCase {
    func testQuitClearsWorkAndTerminatesApplication() {
        let terminator = RecordingApplicationTerminator()
        let model = FloatingBarViewModel(
            spellingChecker: ImmediateSpellingChecker(
                result: .init(originalText: "", issues: [], correctedText: "")
            ),
            translator: ImmediateTranslator(
                result: .init(sourceLanguage: "ko", targetLanguage: "en", translatedText: "")
            ),
            pasteboard: RecordingPasteboardWriter(),
            applicationTerminator: terminator,
            debounce: .seconds(10)
        )
        model.sourceText = "진행 중인 문장"

        model.quit()

        XCTAssertEqual(terminator.callCount, 1)
        XCTAssertEqual(model.sourceText, "")
        XCTAssertEqual(model.spellingPhase, .idle)
        XCTAssertEqual(model.translationPhase, .idle)
    }
}
