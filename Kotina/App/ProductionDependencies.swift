import Foundation

@MainActor
struct ProductionDependencies {
    let spellingChecker: any SpellingChecking
    let translator: any TranslationProcessing
    let translationBroker: TranslationSessionBroker
    let pasteboard: any PasteboardWriting
    let applicationTerminator: any ApplicationTerminating

    static func make(bundle: Bundle) throws -> ProductionDependencies {
        guard let modelURL = bundle.url(forResource: "base", withExtension: nil) else {
            throw TextProcessingError.localEngineUnavailable
        }

        let analyzer = try KiwiAnalyzer(modelPath: modelURL.path)
        let broker = TranslationSessionBroker()
        return ProductionDependencies(
            spellingChecker: LocalKoreanChecker(analyzer: analyzer),
            translator: AppleTranslator(broker: broker),
            translationBroker: broker,
            pasteboard: SystemPasteboardWriter(),
            applicationTerminator: SystemApplicationTerminator()
        )
    }
}
