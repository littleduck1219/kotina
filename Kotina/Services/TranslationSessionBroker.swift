import Foundation
import Observation
@preconcurrency import Translation

@MainActor
protocol TranslationSessionDriving: AnyObject {
    func prepareTranslation() async throws
    func translate(_ text: String, direction: TranslationDirection) async throws -> TranslationResult
}

@MainActor
@Observable
final class TranslationSessionBroker {
    private(set) var configuration: TranslationSession.Configuration?
    private var configurationDirection: TranslationDirection?

    private var pendingOperation: PendingOperation?
    private var executingOperation: PendingOperation?

    func prepareTranslation(for direction: TranslationDirection) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                enqueue(.preparation(id: id, direction: direction, continuation: continuation))
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancel(id: id)
            }
        }
    }

    func translate(_ text: String, direction: TranslationDirection) async throws -> TranslationResult {
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                enqueue(.translation(id: id, text: text, direction: direction, continuation: continuation))
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancel(id: id)
            }
        }
    }

    func handle(driver: any TranslationSessionDriving) async {
        guard let operation = pendingOperation else { return }
        pendingOperation = nil
        executingOperation = operation

        do {
            switch operation {
            case let .preparation(id, _, _):
                try await driver.prepareTranslation()
                finish(id: id, result: .preparation)
            case let .translation(id, text, direction, _):
                let result = try await driver.translate(text, direction: direction)
                finish(id: id, result: .translation(result))
            }
        } catch {
            finish(id: operation.id, error: error)
        }
    }

    func handle(session: TranslationSession) async {
        await handle(driver: AppleTranslationSessionDriver(session: session))
    }

    func cancel() {
        cancelCurrentOperation()
    }

    private func enqueue(_ operation: PendingOperation) {
        guard !Task.isCancelled else {
            operation.resume(throwing: CancellationError())
            return
        }

        cancelCurrentOperation()
        pendingOperation = operation
        requestSession(for: operation.direction)
    }

    private func requestSession(for direction: TranslationDirection) {
        if configurationDirection != direction || configuration == nil {
            configuration = makeConfiguration(for: direction)
            configurationDirection = direction
        } else if var configuration {
            configuration.invalidate()
            self.configuration = configuration
        }
    }

    private func makeConfiguration(for direction: TranslationDirection) -> TranslationSession.Configuration {
        let source = Locale.Language(identifier: direction.sourceLanguageCode)
        let target = Locale.Language(identifier: direction.targetLanguageCode)
        if #available(macOS 26.4, *) {
            return TranslationSession.Configuration(
                source: source,
                target: target,
                preferredStrategy: .highFidelity
            )
        }
        return TranslationSession.Configuration(source: source, target: target)
    }

    private func cancelCurrentOperation() {
        pendingOperation?.resume(throwing: CancellationError())
        executingOperation?.resume(throwing: CancellationError())
        pendingOperation = nil
        executingOperation = nil
    }

    private func cancel(id: UUID) {
        if pendingOperation?.id == id {
            pendingOperation?.resume(throwing: CancellationError())
            pendingOperation = nil
        }
        if executingOperation?.id == id {
            executingOperation?.resume(throwing: CancellationError())
            executingOperation = nil
        }
    }

    private func finish(id: UUID, result: PendingResult) {
        guard let operation = executingOperation, operation.id == id else { return }
        executingOperation = nil
        operation.resume(returning: result)
    }

    private func finish(id: UUID, error: any Error) {
        guard let operation = executingOperation, operation.id == id else { return }
        executingOperation = nil
        operation.resume(throwing: error)
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

    func translate(_ text: String, direction: TranslationDirection) async throws -> TranslationResult {
        let response = try await session.translate(text)
        return TranslationResult(
            sourceLanguage: direction.sourceLanguageCode,
            targetLanguage: direction.targetLanguageCode,
            translatedText: response.targetText
        )
    }
}

private enum PendingResult {
    case preparation
    case translation(TranslationResult)
}

private enum PendingOperation {
    case preparation(
        id: UUID,
        direction: TranslationDirection,
        continuation: CheckedContinuation<Void, any Error>
    )
    case translation(
        id: UUID,
        text: String,
        direction: TranslationDirection,
        continuation: CheckedContinuation<TranslationResult, any Error>
    )

    var id: UUID {
        switch self {
        case let .preparation(id, _, _), let .translation(id, _, _, _):
            id
        }
    }

    var direction: TranslationDirection {
        switch self {
        case let .preparation(_, direction, _), let .translation(_, _, direction, _):
            direction
        }
    }

    func resume(returning result: PendingResult) {
        switch (self, result) {
        case let (.preparation(_, _, continuation), .preparation):
            continuation.resume()
        case let (.translation(_, _, _, continuation), .translation(result)):
            continuation.resume(returning: result)
        default:
            resume(throwing: TextProcessingError.unavailable)
        }
    }

    func resume(throwing error: any Error) {
        switch self {
        case let .preparation(_, _, continuation):
            continuation.resume(throwing: error)
        case let .translation(_, _, _, continuation):
            continuation.resume(throwing: error)
        }
    }
}
