enum TranslationDirection: String, CaseIterable, Sendable {
    case koreanToEnglish
    case englishToKorean

    var sourceLanguageCode: String {
        self == .koreanToEnglish ? "ko" : "en"
    }

    var targetLanguageCode: String {
        self == .koreanToEnglish ? "en" : "ko"
    }

    var label: String {
        self == .koreanToEnglish ? "한국어 → 영어" : "영어 → 한국어"
    }

    var targetLanguageName: String {
        self == .koreanToEnglish ? "영어" : "한국어"
    }

    static func detected(from text: String) -> Self? {
        let normalized = text.precomposedStringWithCanonicalMapping
        if normalized.unicodeScalars.contains(where: { (0xAC00...0xD7A3).contains($0.value) }) {
            return .koreanToEnglish
        }
        return normalized.range(of: #"[A-Za-z]"#, options: .regularExpression) == nil ? nil : .englishToKorean
    }
}

struct TranslationResult: Equatable, Sendable {
    let sourceLanguage: String
    let targetLanguage: String
    let translatedText: String
}
