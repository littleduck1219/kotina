import CryptoKit
import Foundation

struct LocalQwenTranslator: TranslationProcessing {
    private static let modelURL = URL(string: "https://huggingface.co/bartowski/Qwen_Qwen3-4B-GGUF/resolve/cb76885dc66d50759b207c5a48c4e78dfa00c638/Qwen_Qwen3-4B-Q4_K_M.gguf?download=true")!
    private static let modelChecksum = "9ecd0326f69f82fada904bf06e8a9d6f9874198c0f0bedfe9d370141aa47d901"

    private let runtimeURL: URL
    private let installedModelURL: URL

    init(bundle: Bundle) throws {
        guard let runtimeURL = bundle.url(forResource: "llama-cli", withExtension: nil, subdirectory: "Llama") else {
            throw TextProcessingError.localEngineUnavailable
        }
        self.runtimeURL = runtimeURL
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.installedModelURL = appSupport
            .appendingPathComponent("Kotina/Models", isDirectory: true)
            .appendingPathComponent("Qwen_Qwen3-4B-Q4_K_M.gguf")
    }

    func resourceState(for direction: TranslationDirection) async -> TranslationResourceState {
        guard FileManager.default.isExecutableFile(atPath: runtimeURL.path) else { return .unavailable }
        return FileManager.default.fileExists(atPath: installedModelURL.path) ? .ready : .needsPreparation
    }

    func prepareTranslation(for direction: TranslationDirection) async throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: installedModelURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let (temporaryURL, _) = try await URLSession.shared.download(from: Self.modelURL)
        defer { try? fileManager.removeItem(at: temporaryURL) }
        guard try Self.sha256(of: temporaryURL) == Self.modelChecksum else {
            throw TextProcessingError.unavailable
        }

        try? fileManager.removeItem(at: installedModelURL)
        try fileManager.moveItem(at: temporaryURL, to: installedModelURL)
    }

    func translate(_ text: String, direction: TranslationDirection) async throws -> TranslationResult {
        guard await resourceState(for: direction) == .ready else {
            throw TextProcessingError.translationNeedsPreparation
        }

        let output = try await run(text: Self.normalizedInput(text), direction: direction)
        guard let translatedText = Self.translation(in: output) else {
            throw TextProcessingError.unavailable
        }
        return TranslationResult(
            sourceLanguage: direction.sourceLanguageCode,
            targetLanguage: direction.targetLanguageCode,
            translatedText: translatedText
        )
    }

    private func run(text: String, direction: TranslationDirection) async throws -> String {
        let promptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kotina-prompt-\(UUID().uuidString).txt")
        try Data(text.utf8).write(to: promptURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: promptURL) }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = runtimeURL
            process.currentDirectoryURL = runtimeURL.deletingLastPathComponent()
            process.arguments = [
                "--model", installedModelURL.path,
                "--gpu-layers", "all",
                "--ctx-size", "2048",
                "--predict", "128",
                "--temp", "0",
                "--no-display-prompt",
                "--no-perf",
                "--log-disable",
                "--conversation",
                "--single-turn",
                "--reasoning", "off",
                "--system-prompt", Self.instructions(for: direction),
                "--file", promptURL.path
            ]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { process in
                let data = output.fileHandleForReading.readDataToEndOfFile()
                guard process.terminationStatus == 0 else {
                    continuation.resume(throwing: TextProcessingError.unavailable)
                    return
                }
                continuation.resume(returning: String(decoding: data, as: UTF8.self))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static func instructions(for direction: TranslationDirection) -> String {
        switch direction {
        case .koreanToEnglish:
            "Translate this Korean marketing headline into concise, natural English marketing copy. Preserve the core meaning, including the cost burden and question. Do not translate word-for-word or add claims. Return only the English translation."
        case .englishToKorean:
            "Translate this English sentence into Korean. Return only the Korean translation."
        }
    }

    static func normalizedInput(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .precomposedStringWithCanonicalMapping
    }

    static func translation(in output: String) -> String? {
        if let start = output.range(of: "<translation>"),
           let end = output.range(of: "</translation>", range: start.upperBound..<output.endIndex) {
            let text = output[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }

        let lines = output.components(separatedBy: .newlines)
        guard let promptLine = lines.lastIndex(where: { $0.hasPrefix("> ") }) else { return nil }
        return lines[(promptLine + 1)...]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("[") && $0 != "Exiting..." }
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
