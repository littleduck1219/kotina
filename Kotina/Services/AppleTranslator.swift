import Foundation
@preconcurrency import Translation

enum TranslationAvailabilityStatus: Sendable {
    case installed
    case supported
    case unsupported
}

protocol TranslationAvailabilityChecking: Sendable {
    func status() async -> TranslationAvailabilityStatus
}

struct SystemTranslationAvailabilityChecker: TranslationAvailabilityChecking {
    func status() async -> TranslationAvailabilityStatus {
        let status = await LanguageAvailability().status(
            from: Locale.Language(identifier: "ko"),
            to: Locale.Language(identifier: "en")
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

struct AppleTranslator: Translating {
    private let availability: any TranslationAvailabilityChecking
    let broker: TranslationSessionBroker

    init(
        availability: any TranslationAvailabilityChecking = SystemTranslationAvailabilityChecker(),
        broker: TranslationSessionBroker
    ) {
        self.availability = availability
        self.broker = broker
    }

    func resourceState() async -> TranslationResourceState {
        switch await availability.status() {
        case .installed:
            return .ready
        case .supported:
            return .needsPreparation
        case .unsupported:
            return .unavailable
        }
    }

    func prepareTranslation() async throws {
        guard await resourceState() != .unavailable else {
            throw TextProcessingError.translationUnavailable
        }
        try await broker.prepareTranslation()
    }

    func translate(_ text: String) async throws -> TranslationResult {
        switch await resourceState() {
        case .ready:
            return try await broker.translate(text)
        case .needsPreparation, .checking:
            throw TextProcessingError.translationNeedsPreparation
        case .unavailable:
            throw TextProcessingError.translationUnavailable
        }
    }

    @MainActor
    var configuration: TranslationSession.Configuration? {
        broker.configuration
    }

    @MainActor
    func handle(session: TranslationSession) async {
        await broker.handle(driver: AppleTranslationSessionDriver(session: session))
    }

    @MainActor
    func cancel() {
        broker.cancel()
    }
}

@MainActor
private final class AppleTranslationSessionDriver: TranslationSessionDriving {
    private let session: TranslationSession

    init(session: TranslationSession) {
        self.session = session
    }

    func prepareTranslation() async throws {
        try await session.prepareTranslation()
    }

    func translate(_ text: String) async throws -> TranslationResult {
        let response = try await session.translate(text)
        return TranslationResult(
            sourceLanguage: "ko",
            targetLanguage: "en",
            translatedText: response.targetText
        )
    }
}
