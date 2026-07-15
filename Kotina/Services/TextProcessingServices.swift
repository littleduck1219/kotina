import Foundation

protocol SpellingChecking: Sendable {
    func check(_ text: String) async throws -> SpellingResult
}

protocol Translating: Sendable {
    func translate(_ text: String, direction: TranslationDirection) async throws -> TranslationResult
}

protocol TranslationProcessing: Translating {
    func resourceState(for direction: TranslationDirection) async -> TranslationResourceState
    func prepareTranslation(for direction: TranslationDirection) async throws
}

enum TranslationResourceState: Equatable, Sendable {
    case checking
    case needsPreparation
    case ready
    case unavailable
}

enum TextProcessingError: LocalizedError, Equatable {
    case unavailable
    case localEngineUnavailable
    case translationNeedsPreparation
    case translationUnavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "지금은 처리할 수 없어요. 다시 시도해 주세요."
        case .localEngineUnavailable:
            "로컬 맞춤법 엔진을 준비하지 못했어요. 앱을 다시 설치해 주세요."
        case .translationNeedsPreparation:
            "번역 모델을 먼저 준비해 주세요."
        case .translationUnavailable:
            "이 기기에서는 이 번역 방향을 사용할 수 없어요."
        }
    }
}
