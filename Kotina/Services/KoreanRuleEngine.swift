import Foundation

struct KoreanRuleEngine: Sendable {
    static let standard = KoreanRuleEngine(rules: [
        LiteralRule(
            target: "몇일",
            replacement: "며칠",
            reason: "날짜의 수를 물을 때는 ‘며칠’로 적어요."
        ),
        NegativeDoRule(),
        LiteralRule(
            target: "되요",
            replacement: "돼요",
            reason: "‘되어요’의 준말은 ‘돼요’예요."
        ),
        WaenRule(),
        DependentSuRule(),
        RepeatedSpaceRule()
    ])

    private let rules: [any KoreanCorrectionRule]

    init(rules: [any KoreanCorrectionRule]) {
        self.rules = rules
    }

    func edits(in text: String) -> [CorrectionEdit] {
        rules.flatMap { $0.edits(in: text) }
    }
}

private struct LiteralRule: KoreanCorrectionRule {
    let target: String
    let replacement: String
    let reason: String

    func edits(in text: String) -> [CorrectionEdit] {
        var edits: [CorrectionEdit] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let range = text.range(
                  of: target,
                  range: searchStart..<text.endIndex
              ) {
            edits.append(CorrectionEdit(range: range, replacement: replacement, reason: reason))
            searchStart = range.upperBound
        }
        return edits
    }
}

private struct NegativeDoRule: KoreanCorrectionRule {
    private let replacements: [(target: String, replacement: String)] = [
        ("안됩니다", "안 됩니다"),
        ("안되어", "안 되어"),
        ("안되는", "안 되는"),
        ("안되면", "안 되면"),
        ("안된다", "안 된다"),
        ("안되요", "안 돼요"),
        ("안돼요", "안 돼요")
    ]

    func edits(in text: String) -> [CorrectionEdit] {
        replacements.flatMap { replacement in
            LiteralRule(
                target: replacement.target,
                replacement: replacement.replacement,
                reason: "부정의 뜻인 ‘안’은 뒤의 용언과 띄어 써요."
            ).edits(in: text)
        }
    }
}

private struct WaenRule: KoreanCorrectionRule {
    private let wrong: Character = "\u{C660}"
    private let correct = "\u{C6EC}"

    func edits(in text: String) -> [CorrectionEdit] {
        var edits: [CorrectionEdit] = []
        var index = text.startIndex

        while index < text.endIndex {
            let nextIndex = text.index(after: index)
            if text[index] == wrong {
                let isWaenji = nextIndex < text.endIndex && text[nextIndex] == "지"
                if !isWaenji {
                    edits.append(CorrectionEdit(
                        range: index..<nextIndex,
                        replacement: correct,
                        reason: "‘어찌 된’의 뜻은 ‘웬’으로 적어요."
                    ))
                }
            }
            index = nextIndex
        }
        return edits
    }
}

private struct DependentSuRule: KoreanCorrectionRule {
    private let modifierEndings = Set("할갈볼될울릴줄살낼칠을실킬먹읽받찾있없쓸")

    func edits(in text: String) -> [CorrectionEdit] {
        var edits: [CorrectionEdit] = []
        var index = text.startIndex

        while index < text.endIndex {
            let nextIndex = text.index(after: index)
            if text[index] == "수", index > text.startIndex {
                let previousIndex = text.index(before: index)
                let isSurokEnding = nextIndex < text.endIndex && text[nextIndex] == "록"
                if modifierEndings.contains(text[previousIndex]), !isSurokEnding {
                    edits.append(CorrectionEdit(
                        range: index..<nextIndex,
                        replacement: " 수",
                        reason: "의존 명사 ‘수’는 앞말과 띄어 써요."
                    ))
                }
            }
            index = nextIndex
        }
        return edits
    }
}

private struct RepeatedSpaceRule: KoreanCorrectionRule {
    func edits(in text: String) -> [CorrectionEdit] {
        var edits: [CorrectionEdit] = []
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == " " else {
                index = text.index(after: index)
                continue
            }

            let runStart = index
            repeat {
                index = text.index(after: index)
            } while index < text.endIndex && text[index] == " "

            if text.distance(from: runStart, to: index) > 1 {
                edits.append(CorrectionEdit(
                    range: runStart..<index,
                    replacement: " ",
                    reason: "연속된 공백은 한 칸으로 줄였어요."
                ))
            }
        }
        return edits
    }
}
