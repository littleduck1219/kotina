import XCTest
@testable import Kotina

@MainActor
final class FloatingBarViewModelTests: XCTestCase {
    func testWhitespaceKeepsPanelCollapsed() async {
        let model = makeModel()

        model.sourceText = "   "
        await Task.yield()

        XCTAssertFalse(model.isExpanded)
        XCTAssertEqual(model.spellingPhase, .idle)
        XCTAssertEqual(model.translationPhase, .idle)
    }

    func testLongInputShowsValidationWithoutProcessing() async {
        let model = makeModel()

        model.sourceText = String(repeating: "가", count: 5_001)
        await Task.yield()

        XCTAssertEqual(model.validationMessage, "5,000자 이하로 입력해 주세요.")
        XCTAssertEqual(model.spellingPhase, .idle)
        XCTAssertEqual(model.translationPhase, .idle)
        XCTAssertTrue(model.isExpanded)
    }

    func testValidInputLoadsBothResultsAndExpands() async {
        let spelling = SpellingResult(
            originalText: "몇일",
            issues: [.init(range: 0..<2, original: "몇일", suggestion: "며칠", reason: "표준어")],
            correctedText: "며칠"
        )
        let translation = TranslationResult(
            sourceLanguage: "ko",
            targetLanguage: "en",
            translatedText: "A few days"
        )
        let model = makeModel(
            spelling: ImmediateSpellingChecker(result: spelling),
            translator: ImmediateTranslator(result: translation)
        )

        model.sourceText = "몇일"

        await eventually {
            model.spellingPhase == .success(spelling)
                && model.translationPhase == .success(translation)
        }
        XCTAssertTrue(model.isExpanded)
    }

    func testOlderResponseCannotOverwriteNewerInput() async {
        let model = makeModel(spelling: NonCooperativeSpellingChecker())

        model.sourceText = "오래된 문장"
        await Task.yield()
        model.sourceText = "최신 문장"

        await eventually {
            model.currentSpellingResult?.correctedText == "최신 문장"
        }
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.currentSpellingResult?.correctedText, "최신 문장")
    }

    func testSpellingFailureDoesNotDiscardTranslation() async {
        let translation = TranslationResult(
            sourceLanguage: "ko",
            targetLanguage: "en",
            translatedText: "Translation survives"
        )
        let model = makeModel(
            spelling: FailingSpellingChecker(),
            translator: ImmediateTranslator(result: translation)
        )

        model.sourceText = "문장"

        await eventually {
            model.translationPhase == .success(translation)
        }
        guard case .failure = model.spellingPhase else {
            return XCTFail("맞춤법 탭은 실패 상태여야 합니다.")
        }
    }

    func testCopyCorrectedTextReportsSuccess() async {
        let pasteboard = RecordingPasteboardWriter()
        let result = SpellingResult(originalText: "몇일", issues: [], correctedText: "며칠")
        let model = makeModel(
            spelling: ImmediateSpellingChecker(result: result),
            pasteboard: pasteboard
        )
        model.sourceText = "몇일"
        await eventually { model.currentSpellingResult != nil }

        model.copyCorrectedText()

        XCTAssertEqual(pasteboard.values, ["며칠"])
        XCTAssertEqual(model.copyMessage, "복사했어요")
    }

    func testCopyFailureReportsFailure() async {
        let pasteboard = RecordingPasteboardWriter(succeeds: false)
        let result = TranslationResult(sourceLanguage: "ko", targetLanguage: "en", translatedText: "Hello")
        let model = makeModel(
            translator: ImmediateTranslator(result: result),
            pasteboard: pasteboard
        )
        model.sourceText = "안녕"
        await eventually { model.currentTranslationResult != nil }

        model.copyTranslation()

        XCTAssertEqual(pasteboard.values, ["Hello"])
        XCTAssertEqual(model.copyMessage, "복사하지 못했어요")
    }

    func testRetrySpellingRecoversCurrentText() async {
        let result = SpellingResult(originalText: "몇일", issues: [], correctedText: "며칠")
        let checker = RecoveringSpellingChecker(result: result)
        let model = makeModel(spelling: checker)
        model.sourceText = "몇일"
        await eventually {
            if case .failure = model.spellingPhase { return true }
            return false
        }

        model.retrySpelling()

        await eventually { model.spellingPhase == .success(result) }
    }

    func testRetryTranslationRecoversCurrentText() async {
        let result = TranslationResult(sourceLanguage: "ko", targetLanguage: "en", translatedText: "Hello")
        let service = RecoveringTranslator(result: result)
        let model = makeModel(translator: service)
        model.sourceText = "안녕"
        await eventually {
            if case .failure = model.translationPhase { return true }
            return false
        }

        model.retryTranslation()

        await eventually { model.translationPhase == .success(result) }
    }

    func testClearCancelsWorkAndCollapsesPanel() async {
        let model = makeModel(spelling: NonCooperativeSpellingChecker())
        model.sourceText = "오래된 문장"
        await Task.yield()

        model.clear()

        XCTAssertEqual(model.sourceText, "")
        XCTAssertFalse(model.isExpanded)
        XCTAssertEqual(model.spellingPhase, .idle)
        XCTAssertEqual(model.translationPhase, .idle)
    }

    private func makeModel(
        spelling: any SpellingChecking = ImmediateSpellingChecker(
            result: .init(originalText: "", issues: [], correctedText: "")
        ),
        translator: any Translating = ImmediateTranslator(
            result: .init(sourceLanguage: "ko", targetLanguage: "en", translatedText: "")
        ),
        pasteboard: RecordingPasteboardWriter = RecordingPasteboardWriter()
    ) -> FloatingBarViewModel {
        FloatingBarViewModel(
            spellingChecker: spelling,
            translator: translator,
            pasteboard: pasteboard,
            debounce: .zero
        )
    }

    private func eventually(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition(), clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(condition())
    }
}
