import Foundation

struct SpellingIssue: Equatable, Sendable {
    let range: Range<Int>
    let original: String
    let suggestion: String
    let reason: String
}

struct SpellingResult: Equatable, Sendable {
    let originalText: String
    let issues: [SpellingIssue]
    let correctedText: String
}

