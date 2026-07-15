import XCTest
@testable import Kotina

final class LocalQwenTranslatorTests: XCTestCase {
    func testFindsBundledRuntimeInLlamaDirectory() throws {
        XCTAssertNoThrow(try LocalQwenTranslator(bundle: .main))
    }

    func testExtractsTaggedTranslation() {
        XCTAssertEqual(LocalQwenTranslator.translation(in: "<translation>Hello</translation>"), "Hello")
    }

    func testUsesShortDirectionSpecificInstruction() {
        XCTAssertEqual(
            LocalQwenTranslator.instructions(for: .koreanToEnglish),
            "Translate this Korean marketing headline into concise, natural English marketing copy. Preserve the core meaning, including the cost burden and question. Do not translate word-for-word or add claims. Return only the English translation."
        )
    }

    func testNormalizesDecomposedKoreanBeforeTranslation() {
        let decomposed = "비용이 감당이 안 되시나요?".decomposedStringWithCanonicalMapping
        XCTAssertEqual(LocalQwenTranslator.normalizedInput(decomposed), "비용이 감당이 안 되시나요?")
    }

    func testNormalizesLineBreaksBeforeTranslation() {
        XCTAssertEqual(
            LocalQwenTranslator.normalizedInput("AI 도입했는데,\n비용이 감당이 안 되시나요?"),
            "AI 도입했는데, 비용이 감당이 안 되시나요?"
        )
    }

    func testDetectsKoreanInDecomposedInputWithEnglishAcronym() {
        let decomposed = "AI 도입했는데, 비용이 감당이 안 되시나요?".decomposedStringWithCanonicalMapping
        XCTAssertEqual(TranslationDirection.detected(from: decomposed), .koreanToEnglish)
    }

    func testExtractsPlainCliTranslationAfterPrompt() {
        XCTAssertEqual(
            LocalQwenTranslator.translation(in: "> source text\nIf AI is introduced, can you afford the cost?\n\nExiting..."),
            "If AI is introduced, can you afford the cost?"
        )
    }
}
