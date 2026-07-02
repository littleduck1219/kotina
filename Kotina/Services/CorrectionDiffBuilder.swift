import Foundation

struct CorrectionDiffBuilder: Sendable {
    func makeResult(for text: String, edits: [CorrectionEdit]) -> SpellingResult {
        let acceptedEdits = nonoverlappingEdits(edits)
        let issues = acceptedEdits.map { edit in
            SpellingIssue(
                range: characterRange(edit.range, in: text),
                original: String(text[edit.range]),
                suggestion: edit.replacement,
                reason: edit.reason
            )
        }

        var correctedText = text
        for edit in acceptedEdits.reversed() {
            correctedText.replaceSubrange(edit.range, with: edit.replacement)
        }

        return SpellingResult(
            originalText: text,
            issues: issues,
            correctedText: correctedText
        )
    }

    private func nonoverlappingEdits(_ edits: [CorrectionEdit]) -> [CorrectionEdit] {
        let sortedEdits = edits.sorted { left, right in
            if left.range.lowerBound == right.range.lowerBound {
                return left.range.upperBound > right.range.upperBound
            }
            return left.range.lowerBound < right.range.lowerBound
        }

        var accepted: [CorrectionEdit] = []
        for edit in sortedEdits {
            guard let previous = accepted.last else {
                accepted.append(edit)
                continue
            }
            guard edit.range.lowerBound >= previous.range.upperBound else { continue }
            accepted.append(edit)
        }
        return accepted
    }

    private func characterRange(
        _ range: Range<String.Index>,
        in text: String
    ) -> Range<Int> {
        let lowerBound = text.distance(from: text.startIndex, to: range.lowerBound)
        let upperBound = text.distance(from: text.startIndex, to: range.upperBound)
        return lowerBound..<upperBound
    }
}
