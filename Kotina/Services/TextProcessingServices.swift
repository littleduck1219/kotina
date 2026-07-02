import Foundation

protocol SpellingChecking: Sendable {
    func check(_ text: String) async throws -> SpellingResult
}

protocol Translating: Sendable {
    func translate(_ text: String) async throws -> TranslationResult
}

enum TextProcessingError: LocalizedError, Equatable {
    case unavailable

    var errorDescription: String? {
        "지금은 처리할 수 없어요. 다시 시도해 주세요."
    }
}

