import Foundation

struct MockSpellingChecker: SpellingChecking {
    let delay: Duration

    init(delay: Duration = .milliseconds(180)) {
        self.delay = delay
    }

    func check(_ text: String) async throws -> SpellingResult {
        try await Task.sleep(for: delay)

        guard let mistakeRange = text.range(of: "몇일") else {
            return SpellingResult(
                originalText: text,
                issues: [],
                correctedText: text
            )
        }

        let offset = text.distance(from: text.startIndex, to: mistakeRange.lowerBound)
        let issue = SpellingIssue(
            range: offset..<(offset + 2),
            original: "몇일",
            suggestion: "며칠",
            reason: "날짜를 나타낼 때는 ‘며칠’로 적어요."
        )

        return SpellingResult(
            originalText: text,
            issues: [issue],
            correctedText: text.replacingOccurrences(of: "몇일", with: "며칠")
        )
    }
}

