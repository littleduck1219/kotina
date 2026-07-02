import XCTest
@testable import Kotina

final class CorrectionDiffBuilderTests: XCTestCase {
    func testAppliesEditsFromOriginalRangesAndBuildsCharacterOffsets() {
        let source = "🙂 몇일  뒤"
        let dayRange = source.range(of: "몇일")!
        let spacesRange = source.range(of: "  ")!
        let edits = [
            CorrectionEdit(range: spacesRange, replacement: " ", reason: "연속 공백"),
            CorrectionEdit(range: dayRange, replacement: "며칠", reason: "날짜 표현")
        ]

        let result = CorrectionDiffBuilder().makeResult(for: source, edits: edits)

        XCTAssertEqual(result.correctedText, "🙂 며칠 뒤")
        XCTAssertEqual(result.issues.map(\.range), [2..<4, 4..<6])
        XCTAssertEqual(result.issues.map(\.original), ["몇일", "  "])
    }

    func testRejectsLaterOverlappingEdit() {
        let source = "안되요"
        let wholeRange = source.startIndex..<source.endIndex
        let suffixRange = source.index(after: source.startIndex)..<source.endIndex
        let edits = [
            CorrectionEdit(range: wholeRange, replacement: "안 돼요", reason: "부정 표현"),
            CorrectionEdit(range: suffixRange, replacement: "돼요", reason: "준말")
        ]

        let result = CorrectionDiffBuilder().makeResult(for: source, edits: edits)

        XCTAssertEqual(result.correctedText, "안 돼요")
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertEqual(result.issues.first?.reason, "부정 표현")
    }
}
