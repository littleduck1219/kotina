import Foundation

struct LocalKoreanChecker: SpellingChecking {
    private let ruleEngine: KoreanRuleEngine
    private let diffBuilder: CorrectionDiffBuilder
    private let analyzer: (any KoreanAnalyzing)?

    init(
        ruleEngine: KoreanRuleEngine = .standard,
        diffBuilder: CorrectionDiffBuilder = CorrectionDiffBuilder(),
        analyzer: (any KoreanAnalyzing)? = nil
    ) {
        self.ruleEngine = ruleEngine
        self.diffBuilder = diffBuilder
        self.analyzer = analyzer
    }

    func check(_ text: String) async throws -> SpellingResult {
        let normalizedText = text.precomposedStringWithCanonicalMapping
        let evidence = try analyzer?.analyze(normalizedText)
        return diffBuilder.makeResult(
            for: normalizedText,
            edits: ruleEngine.edits(in: normalizedText, evidence: evidence)
        )
    }
}
