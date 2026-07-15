import Foundation
import Observation
import Translation

enum ProcessingMode: String, CaseIterable, Sendable {
    case spelling
    case translation
}

enum TextSizeOption: String, CaseIterable, Sendable {
    case small
    case medium
    case large

    var label: String {
        switch self {
        case .small: "작게"
        case .medium: "중간"
        case .large: "크게"
        }
    }

    var factor: CGFloat {
        switch self {
        case .small: 0.85
        case .medium: 1
        case .large: 1.2
        }
    }
}

enum LoadPhase<Value: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case success(Value)
    case failure(String)
}

enum TranslationPhase: Equatable, Sendable {
    case idle
    case checkingResources
    case needsPreparation
    case preparing
    case translating
    case success(TranslationResult)
    case failure(String)
    case unavailable
}

@MainActor
@Observable
final class FloatingBarViewModel {
    var sourceText = "" {
        didSet { sourceDidChange() }
    }

    private(set) var mode: ProcessingMode = .spelling
    private(set) var translationDirection: TranslationDirection = .koreanToEnglish
    var staysOnTop = true
    var textSize: TextSizeOption = .medium {
        didSet { defaults.set(textSize.rawValue, forKey: Self.textSizeKey) }
    }
    private(set) var spellingPhase: LoadPhase<SpellingResult> = .idle
    private(set) var translationPhase: TranslationPhase = .idle
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
    private let translator: any TranslationProcessing
    private let translationBroker: TranslationSessionBroker
    private let pasteboard: any PasteboardWriting
    private let applicationTerminator: any ApplicationTerminating
    private let debounce: Duration
    private let defaults: UserDefaults
    private static let textSizeKey = "kotina.textSize"

    private var requestID = UUID()
    private var debounceTask: Task<Void, Never>?
    private var spellingTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?
    private var copyMessageTask: Task<Void, Never>?

    init(
        spellingChecker: any SpellingChecking,
        translator: any TranslationProcessing,
        translationBroker: TranslationSessionBroker,
        pasteboard: any PasteboardWriting,
        applicationTerminator: any ApplicationTerminating,
        debounce: Duration = .milliseconds(300),
        defaults: UserDefaults = .standard
    ) {
        self.spellingChecker = spellingChecker
        self.translator = translator
        self.translationBroker = translationBroker
        self.pasteboard = pasteboard
        self.applicationTerminator = applicationTerminator
        self.debounce = debounce
        self.defaults = defaults
        if let rawTextSize = defaults.string(forKey: Self.textSizeKey),
           let savedTextSize = TextSizeOption(rawValue: rawTextSize) {
            self.textSize = savedTextSize
        }
    }

    func clear() {
        updateSourceText("")
    }

    func updateSourceText(_ text: String) {
        sourceText = text
        sourceDidChange()
    }

    func toggleMode() {
        mode = mode == .spelling ? .translation : .spelling
    }

    func shutdown() {
        cancelProcessing()
        copyMessageTask?.cancel()
        requestID = UUID()
        sourceText = ""
        validationMessage = nil
        copyMessage = nil
        spellingPhase = .idle
        translationPhase = .idle
    }

    func quit() {
        shutdown()
        applicationTerminator.terminate()
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
        translationPhase = .checkingResources
        startTranslation(text: text, requestID: requestID)
    }

    func prepareTranslation() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validationMessage == nil,
              !text.isEmpty,
              translationPhase == .needsPreparation else { return }

        translationTask?.cancel()
        translationPhase = .preparing
        let service = translator
        let currentID = requestID
        let direction = translationDirection
        translationTask = Task { [weak self] in
            do {
                try await service.prepareTranslation(for: direction)
                try Task.checkCancellation()
                await self?.processTranslation(
                    text: text,
                    requestID: currentID,
                    service: service
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishTranslation(.failure(error.localizedDescription), requestID: currentID)
            }
        }
    }

    var translationConfiguration: TranslationSession.Configuration? {
        translationBroker.configuration
    }

    func handleTranslationSession(_ session: TranslationSession) async {
        await translationBroker.handle(session: session)
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

        if let detectedDirection = TranslationDirection.detected(from: text) {
            translationDirection = detectedDirection
        }

        guard text.count <= 5_000 else {
            spellingPhase = .idle
            translationPhase = .idle
            validationMessage = "5,000자 이하로 입력해 주세요."
            return
        }

        spellingPhase = .loading
        translationPhase = .checkingResources
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
            await self?.processTranslation(
                text: text,
                requestID: requestID,
                service: service
            )
        }
    }

    private func processTranslation(
        text: String,
        requestID: UUID,
        service: any TranslationProcessing
    ) async {
        let direction = translationDirection
        let state = await service.resourceState(for: direction)
        guard !Task.isCancelled, self.requestID == requestID else { return }

        switch state {
        case .checking:
            finishTranslation(.checkingResources, requestID: requestID)
        case .needsPreparation:
            finishTranslation(.needsPreparation, requestID: requestID)
        case .unavailable:
            finishTranslation(.unavailable, requestID: requestID)
        case .ready:
            finishTranslation(.translating, requestID: requestID)
            do {
                let result = try await service.translate(text, direction: direction)
                guard !Task.isCancelled else { return }
                finishTranslation(.success(result), requestID: requestID)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                finishTranslation(.failure(error.localizedDescription), requestID: requestID)
            }
        }
    }

    private func finishSpelling(_ phase: LoadPhase<SpellingResult>, requestID: UUID) {
        guard self.requestID == requestID else { return }
        spellingPhase = phase
    }

    private func finishTranslation(_ phase: TranslationPhase, requestID: UUID) {
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
        translationBroker.cancel()
    }
}
