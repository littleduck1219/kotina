import Foundation
@preconcurrency import Translation

enum TranslationAvailabilityStatus: Sendable {
    case installed
    case supported
    case unsupported
}

protocol TranslationAvailabilityChecking: Sendable {
    func status(for direction: TranslationDirection) async -> TranslationAvailabilityStatus
}

struct SystemTranslationAvailabilityChecker: TranslationAvailabilityChecking {
    func status(for direction: TranslationDirection) async -> TranslationAvailabilityStatus {
        let status = await LanguageAvailability().status(
            from: Locale.Language(identifier: direction.sourceLanguageCode),
            to: Locale.Language(identifier: direction.targetLanguageCode)
        )
        switch status {
        case .installed:
            return .installed
        case .supported:
            return .supported
        case .unsupported:
            return .unsupported
        @unknown default:
            return .unsupported
        }
    }
}

struct AppleTranslator: TranslationProcessing {
    private let availability: any TranslationAvailabilityChecking
    private let refiner: any TranslationRefining
    let broker: TranslationSessionBroker

    init(
        availability: any TranslationAvailabilityChecking = SystemTranslationAvailabilityChecker(),
        broker: TranslationSessionBroker,
        refiner: any TranslationRefining = OnDeviceTranslationRefiner()
    ) {
        self.availability = availability
        self.broker = broker
        self.refiner = refiner
    }

    func resourceState(for direction: TranslationDirection) async -> TranslationResourceState {
        switch await availability.status(for: direction) {
        case .installed:
            return .ready
        case .supported:
            return .needsPreparation
        case .unsupported:
            return .unavailable
        }
    }

    func prepareTranslation(for direction: TranslationDirection) async throws {
        guard await resourceState(for: direction) != .unavailable else {
            throw TextProcessingError.translationUnavailable
        }
        try await broker.prepareTranslation(for: direction)
    }

    func translate(_ text: String, direction: TranslationDirection) async throws -> TranslationResult {
        switch await resourceState(for: direction) {
        case .ready:
            let translation = try await broker.translate(text, direction: direction)
            return await refiner.refine(
                sourceText: text,
                translation: translation,
                direction: direction
            )
        case .needsPreparation, .checking:
            throw TextProcessingError.translationNeedsPreparation
        case .unavailable:
            throw TextProcessingError.translationUnavailable
        }
    }

}
