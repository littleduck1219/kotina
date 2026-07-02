import Foundation
import Observation

enum ResultTab: String, CaseIterable, Sendable {
    case spelling
    case translation
}

enum LoadPhase<Value: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case success(Value)
    case failure(String)
}

@MainActor
@Observable
final class FloatingBarViewModel {
    var sourceText = "" {
        didSet { sourceDidChange() }
    }

    var selectedTab: ResultTab = .spelling
    private(set) var spellingPhase: LoadPhase<SpellingResult> = .idle
    private(set) var translationPhase: LoadPhase<TranslationResult> = .idle
    private(set) var validationMessage: String?
    private(set) var copyMessage: String?

    var currentSpellingResult: SpellingResult? {
        guard case let .success(result) = spellingPhase else { return nil }
        return result
    }

    var currentTranslationResult: TranslationResult? {
        guard case let .success(result) = translationPhase else { return nil }
        return result
    }

    var isExpanded: Bool {
        validationMessage != nil || spellingPhase != .idle || translationPhase != .idle
    }

    private let spellingChecker: any SpellingChecking
    private let translator: any Translating
    private let pasteboard: any PasteboardWriting
    private let debounce: Duration

    private var requestID = UUID()
    private var debounceTask: Task<Void, Never>?
    private var spellingTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?
    private var copyMessageTask: Task<Void, Never>?

    init(
        spellingChecker: any SpellingChecking,
        translator: any Translating,
        pasteboard: any PasteboardWriting,
        debounce: Duration = .milliseconds(300)
    ) {
        self.spellingChecker = spellingChecker
        self.translator = translator
        self.pasteboard = pasteboard
        self.debounce = debounce
    }

    func clear() {
        sourceText = ""
    }

    func retrySpelling() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validationMessage == nil, !text.isEmpty else { return }
        spellingTask?.cancel()
        spellingPhase = .loading
        startSpelling(text: text, requestID: requestID)
    }

    func retryTranslation() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validationMessage == nil, !text.isEmpty else { return }
        translationTask?.cancel()
        translationPhase = .loading
        startTranslation(text: text, requestID: requestID)
    }

    func copyCorrectedText() {
        guard let text = currentSpellingResult?.correctedText else { return }
        reportCopyResult(pasteboard.write(text))
    }

    func copyTranslation() {
        guard let text = currentTranslationResult?.translatedText else { return }
        reportCopyResult(pasteboard.write(text))
    }

    private func sourceDidChange() {
        cancelProcessing()
        requestID = UUID()
        validationMessage = nil
        copyMessage = nil

        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            spellingPhase = .idle
            translationPhase = .idle
            return
        }

        guard text.count <= 5_000 else {
            spellingPhase = .idle
            translationPhase = .idle
            validationMessage = "5,000자 이하로 입력해 주세요."
            return
        }

        spellingPhase = .loading
        translationPhase = .loading
        let currentID = requestID
        debounceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: debounce)
                try Task.checkCancellation()
            } catch {
                return
            }
            guard requestID == currentID else { return }
            startSpelling(text: text, requestID: currentID)
            startTranslation(text: text, requestID: currentID)
        }
    }

    private func startSpelling(text: String, requestID: UUID) {
        let checker = spellingChecker
        spellingTask = Task { [weak self] in
            do {
                let result = try await checker.check(text)
                guard !Task.isCancelled else { return }
                self?.finishSpelling(.success(result), requestID: requestID)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishSpelling(.failure(error.localizedDescription), requestID: requestID)
            }
        }
    }

    private func startTranslation(text: String, requestID: UUID) {
        let service = translator
        translationTask = Task { [weak self] in
            do {
                let result = try await service.translate(text)
                guard !Task.isCancelled else { return }
                self?.finishTranslation(.success(result), requestID: requestID)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishTranslation(.failure(error.localizedDescription), requestID: requestID)
            }
        }
    }

    private func finishSpelling(_ phase: LoadPhase<SpellingResult>, requestID: UUID) {
        guard self.requestID == requestID else { return }
        spellingPhase = phase
    }

    private func finishTranslation(_ phase: LoadPhase<TranslationResult>, requestID: UUID) {
        guard self.requestID == requestID else { return }
        translationPhase = phase
    }

    private func reportCopyResult(_ succeeded: Bool) {
        copyMessageTask?.cancel()
        copyMessage = succeeded ? "복사했어요" : "복사하지 못했어요"
        copyMessageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.copyMessage = nil
        }
    }

    private func cancelProcessing() {
        debounceTask?.cancel()
        spellingTask?.cancel()
        translationTask?.cancel()
    }
}
