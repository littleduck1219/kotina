import Foundation

protocol KoreanSpacing: Sendable {
    func spacedText(_ text: String) throws -> String
}

struct SpacingCorrector: Sendable {
    private let spacer: any KoreanSpacing

    init(spacer: any KoreanSpacing) {
        self.spacer = spacer
    }

    func edits(in text: String) -> [CorrectionEdit] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .flatMap(lineEdits(in:))
    }

    private func lineEdits(in line: Substring) -> [CorrectionEdit] {
        // 입력 중인 줄 앞뒤 공백은 교정 대상에서 제외한다.
        let core = trimmedCore(of: line)
        guard !core.isEmpty,
              let spaced = try? spacer.spacedText(String(core)),
              core.filter({ $0 != " " }) == spaced.filter({ $0 != " " }) else {
            return []
        }
        return alignmentEdits(original: core, spaced: spaced)
    }

    private func trimmedCore(of line: Substring) -> Substring {
        guard let first = line.firstIndex(where: { $0 != " " }),
              let last = line.lastIndex(where: { $0 != " " }) else {
            return line[line.startIndex..<line.startIndex]
        }
        return line[first...last]
    }

    private func alignmentEdits(original: Substring, spaced: String) -> [CorrectionEdit] {
        guard let rawEdits = minimalEdits(original: original, spaced: spaced) else {
            return []
        }
        return mergedEdits(rawEdits, original: original, spaced: spaced)
    }

    private struct RawSpacingEdit {
        var originalRange: Range<String.Index>
        var spacedRange: Range<String.Index>
        var insertsSpace: Bool
        var removesSpace: Bool
    }

    private func minimalEdits(original: Substring, spaced: String) -> [RawSpacingEdit]? {
        var edits: [RawSpacingEdit] = []
        var originalIndex = original.startIndex
        var spacedIndex = spaced.startIndex

        while originalIndex < original.endIndex {
            if spacedIndex < spaced.endIndex, original[originalIndex] == spaced[spacedIndex] {
                originalIndex = original.index(after: originalIndex)
                spacedIndex = spaced.index(after: spacedIndex)
                continue
            }

            if original[originalIndex] == " " {
                let runStart = originalIndex
                repeat {
                    originalIndex = original.index(after: originalIndex)
                } while originalIndex < original.endIndex && original[originalIndex] == " "
                edits.append(RawSpacingEdit(
                    originalRange: runStart..<originalIndex,
                    spacedRange: spacedIndex..<spacedIndex,
                    insertsSpace: false,
                    removesSpace: true
                ))
                continue
            }

            if spacedIndex < spaced.endIndex, spaced[spacedIndex] == " " {
                let runStart = spacedIndex
                repeat {
                    spacedIndex = spaced.index(after: spacedIndex)
                } while spacedIndex < spaced.endIndex && spaced[spacedIndex] == " "
                edits.append(RawSpacingEdit(
                    originalRange: originalIndex..<originalIndex,
                    spacedRange: runStart..<spacedIndex,
                    insertsSpace: true,
                    removesSpace: false
                ))
                continue
            }

            // 공백 외 내용이 달라지면 해당 줄의 띄어쓰기 교정을 포기한다.
            return nil
        }
        return edits
    }

    private func mergedEdits(
        _ rawEdits: [RawSpacingEdit],
        original: Substring,
        spaced: String
    ) -> [CorrectionEdit] {
        // 한 글자 이내로 붙어 있는 교정은 하나로 합쳐 서로 겹치지 않게 만든다.
        var groups: [RawSpacingEdit] = []
        for edit in rawEdits {
            if var lastGroup = groups.last,
               original.distance(
                   from: lastGroup.originalRange.upperBound,
                   to: edit.originalRange.lowerBound
               ) <= 1 {
                lastGroup.originalRange = lastGroup.originalRange.lowerBound..<edit.originalRange.upperBound
                lastGroup.spacedRange = lastGroup.spacedRange.lowerBound..<edit.spacedRange.upperBound
                lastGroup.insertsSpace = lastGroup.insertsSpace || edit.insertsSpace
                lastGroup.removesSpace = lastGroup.removesSpace || edit.removesSpace
                groups[groups.count - 1] = lastGroup
            } else {
                groups.append(edit)
            }
        }

        return groups.map { group in
            // 공백만 바꾸면 화면에서 보이지 않으므로 앞뒤 글자를 포함해 표시한다.
            let lowerBound = original.index(before: group.originalRange.lowerBound)
            let upperBound = original.index(after: group.originalRange.upperBound)
            let spacedLowerBound = spaced.index(before: group.spacedRange.lowerBound)
            let spacedUpperBound = spaced.index(after: group.spacedRange.upperBound)
            return CorrectionEdit(
                range: lowerBound..<upperBound,
                replacement: String(spaced[spacedLowerBound..<spacedUpperBound]),
                reason: spacingReason(for: group),
                ruleKind: .spacing
            )
        }
    }

    private func spacingReason(for edit: RawSpacingEdit) -> String {
        switch (edit.insertsSpace, edit.removesSpace) {
        case (true, true):
            "표준 띄어쓰기에 맞게 고쳐 썼어요."
        case (true, false):
            "표준 띄어쓰기에 따라 띄어 써요."
        default:
            "표준 띄어쓰기에 따라 앞말과 붙여 써요."
        }
    }
}
