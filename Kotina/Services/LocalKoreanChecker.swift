import Foundation

struct LocalKoreanChecker: SpellingChecking {
    private let ruleEngine: KoreanRuleEngine
    private let diffBuilder: CorrectionDiffBuilder
    private let analyzer: (any KoreanAnalyzing)?
    private let spacingCorrector: SpacingCorrector?

    init(
        ruleEngine: KoreanRuleEngine = .standard,
        diffBuilder: CorrectionDiffBuilder = CorrectionDiffBuilder(),
        analyzer: (any KoreanAnalyzing)? = nil,
        spacer: (any KoreanSpacing)? = nil
    ) {
        self.ruleEngine = ruleEngine
        self.diffBuilder = diffBuilder
        self.analyzer = analyzer
        self.spacingCorrector = spacer.map(SpacingCorrector.init)
    }

    func check(_ text: String) async throws -> SpellingResult {
        let normalizedText = text.precomposedStringWithCanonicalMapping
        let evidence = try analyzer?.analyze(normalizedText)
        var edits = ruleEngine.edits(in: normalizedText, evidence: evidence)
        if let spacingCorrector {
            edits += spacingCorrector.edits(in: normalizedText)
        }
        return diffBuilder.makeResult(for: normalizedText, edits: edits)
    }
}
