import Foundation

struct CorrectionEdit: Equatable, Sendable {
    let range: Range<String.Index>
    let replacement: String
    let reason: String
}

protocol KoreanCorrectionRule: Sendable {
    func edits(in text: String) -> [CorrectionEdit]
}
