import Foundation
@testable import Kotina

struct ImmediateSpellingChecker: SpellingChecking {
    let result: SpellingResult

    func check(_ text: String) async throws -> SpellingResult {
        result
    }
}

struct ImmediateTranslator: TranslationProcessing {
    let result: TranslationResult

    func resourceState() async -> TranslationResourceState {
        .ready
    }

    func prepareTranslation() async throws {
    }

    func translate(_ text: String) async throws -> TranslationResult {
        result
    }
}

struct FailingSpellingChecker: SpellingChecking {
    func check(_ text: String) async throws -> SpellingResult {
        throw TextProcessingError.unavailable
    }
}

struct NonCooperativeSpellingChecker: SpellingChecking {
    func check(_ text: String) async throws -> SpellingResult {
        let delay: Duration = text == "오래된 문장" ? .milliseconds(80) : .milliseconds(5)
        try? await Task.sleep(for: delay)
        return SpellingResult(originalText: text, issues: [], correctedText: text)
    }
}

actor RecoveringSpellingChecker: SpellingChecking {
    private var attempts = 0
    private let result: SpellingResult

    init(result: SpellingResult) {
        self.result = result
    }

    func check(_ text: String) async throws -> SpellingResult {
        attempts += 1
        if attempts == 1 {
            throw TextProcessingError.unavailable
        }
        return result
    }
}

actor RecoveringTranslator: TranslationProcessing {
    private var attempts = 0
    private let result: TranslationResult

    init(result: TranslationResult) {
        self.result = result
    }

    func resourceState() async -> TranslationResourceState {
        .ready
    }

    func prepareTranslation() async throws {
    }

    func translate(_ text: String) async throws -> TranslationResult {
        attempts += 1
        if attempts == 1 {
            throw TextProcessingError.unavailable
        }
        return result
    }
}

actor ResourceAwareTranslator: TranslationProcessing {
    private var state: TranslationResourceState
    private let stateAfterPreparation: TranslationResourceState
    private let result: TranslationResult
    private(set) var preparationCount = 0
    private(set) var translatedTexts: [String] = []

    init(
        state: TranslationResourceState,
        stateAfterPreparation: TranslationResourceState = .ready,
        result: TranslationResult = .init(
            sourceLanguage: "ko",
            targetLanguage: "en",
            translatedText: "Hello"
        )
    ) {
        self.state = state
        self.stateAfterPreparation = stateAfterPreparation
        self.result = result
    }

    func resourceState() async -> TranslationResourceState {
        state
    }

    func prepareTranslation() async throws {
        preparationCount += 1
        state = stateAfterPreparation
    }

    func translate(_ text: String) async throws -> TranslationResult {
        translatedTexts.append(text)
        return result
    }
}

@MainActor
final class RecordingPasteboardWriter: PasteboardWriting {
    let succeeds: Bool
    private(set) var values: [String] = []

    init(succeeds: Bool = true) {
        self.succeeds = succeeds
    }

    func write(_ text: String) -> Bool {
        values.append(text)
        return succeeds
    }
}

@MainActor
final class RecordingApplicationTerminator: ApplicationTerminating {
    private(set) var callCount = 0

    func terminate() {
        callCount += 1
    }
}
