import Foundation

struct MockTranslator: TranslationProcessing {
    let delay: Duration

    init(delay: Duration = .milliseconds(240)) {
        self.delay = delay
    }

    func resourceState() async -> TranslationResourceState {
        .ready
    }

    func prepareTranslation() async throws {
    }

    func translate(_ text: String) async throws -> TranslationResult {
        try await Task.sleep(for: delay)

        let translatedText: String
        if text == "오늘 회의는 몇일 뒤로 미뤄졌어요." {
            translatedText = "Today's meeting has been postponed for a few days."
        } else {
            translatedText = "[Mock translation] \(text)"
        }

        return TranslationResult(
            sourceLanguage: "ko",
            targetLanguage: "en",
            translatedText: translatedText
        )
    }
}
