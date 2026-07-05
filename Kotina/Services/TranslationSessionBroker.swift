import Foundation
import Observation
import Translation

@MainActor
protocol TranslationSessionDriving: AnyObject {
    func prepareTranslation() async throws
    func translate(_ text: String) async throws -> TranslationResult
}

@MainActor
@Observable
final class TranslationSessionBroker {
    private(set) var configuration: TranslationSession.Configuration?

    private var pendingOperation: PendingOperation?
    private var executingOperation: PendingOperation?

    func prepareTranslation() async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                enqueue(.preparation(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancel(id: id)
            }
        }
    }

    func translate(_ text: String) async throws -> TranslationResult {
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                enqueue(.translation(id: id, text: text, continuation: continuation))
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
            case let .preparation(id, _):
                try await driver.prepareTranslation()
                finish(id: id, result: .preparation)
            case let .translation(id, text, _):
                let result = try await driver.translate(text)
                finish(id: id, result: .translation(result))
            }
        } catch {
            finish(id: operation.id, error: error)
        }
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
        requestSession()
    }

    private func requestSession() {
        if var configuration {
            configuration.invalidate()
            self.configuration = configuration
        } else {
            configuration = TranslationSession.Configuration(
                source: Locale.Language(identifier: "ko"),
                target: Locale.Language(identifier: "en")
            )
        }
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

private enum PendingResult {
    case preparation
    case translation(TranslationResult)
}

private enum PendingOperation {
    case preparation(
        id: UUID,
        continuation: CheckedContinuation<Void, any Error>
    )
    case translation(
        id: UUID,
        text: String,
        continuation: CheckedContinuation<TranslationResult, any Error>
    )

    var id: UUID {
        switch self {
        case let .preparation(id, _), let .translation(id, _, _):
            id
        }
    }

    func resume(returning result: PendingResult) {
        switch (self, result) {
        case let (.preparation(_, continuation), .preparation):
            continuation.resume()
        case let (.translation(_, _, continuation), .translation(result)):
            continuation.resume(returning: result)
        default:
            resume(throwing: TextProcessingError.unavailable)
        }
    }

    func resume(throwing error: any Error) {
        switch self {
        case let .preparation(_, continuation):
            continuation.resume(throwing: error)
        case let .translation(_, _, continuation):
            continuation.resume(throwing: error)
        }
    }
}
