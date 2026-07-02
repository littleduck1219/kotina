import Foundation

struct LocalKoreanChecker: SpellingChecking {
    private let ruleEngine: KoreanRuleEngine
    private let diffBuilder: CorrectionDiffBuilder

    init(
        ruleEngine: KoreanRuleEngine = .standard,
        diffBuilder: CorrectionDiffBuilder = CorrectionDiffBuilder()
    ) {
        self.ruleEngine = ruleEngine
        self.diffBuilder = diffBuilder
    }

    func check(_ text: String) async throws -> SpellingResult {
        let normalizedText = text.precomposedStringWithCanonicalMapping
        return diffBuilder.makeResult(
            for: normalizedText,
            edits: ruleEngine.edits(in: normalizedText)
        )
    }
}
