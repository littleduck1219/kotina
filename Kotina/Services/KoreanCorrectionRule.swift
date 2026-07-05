import Foundation

enum CorrectionRuleKind: Sendable {
    case lexical
    case negativeSpacing
    case waen
    case dependentNounSu
    case whitespace
}

struct CorrectionEdit: Equatable, Sendable {
    let range: Range<String.Index>
    let replacement: String
    let reason: String
    let ruleKind: CorrectionRuleKind

    init(
        range: Range<String.Index>,
        replacement: String,
        reason: String,
        ruleKind: CorrectionRuleKind = .lexical
    ) {
        self.range = range
        self.replacement = replacement
        self.reason = reason
        self.ruleKind = ruleKind
    }
}

protocol KoreanCorrectionRule: Sendable {
    func edits(in text: String) -> [CorrectionEdit]
}
