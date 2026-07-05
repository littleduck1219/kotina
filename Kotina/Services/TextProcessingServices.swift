import Foundation

protocol SpellingChecking: Sendable {
    func check(_ text: String) async throws -> SpellingResult
}

protocol Translating: Sendable {
    func translate(_ text: String) async throws -> TranslationResult
}

enum TextProcessingError: LocalizedError, Equatable {
    case unavailable
    case localEngineUnavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "지금은 처리할 수 없어요. 다시 시도해 주세요."
        case .localEngineUnavailable:
            "로컬 맞춤법 엔진을 준비하지 못했어요. 앱을 다시 설치해 주세요."
        }
    }
}
