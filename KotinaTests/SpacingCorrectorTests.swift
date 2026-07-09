import XCTest
@testable import Kotina

final class SpacingCorrectorTests: XCTestCase {
    private let diffBuilder = CorrectionDiffBuilder()

    func testInsertsMissingSpaces() {
        let corrector = SpacingCorrector(spacer: StubSpacer(map: [
            "밥을먹었다": "밥을 먹었다"
        ]))

        let text = "밥을먹었다"
        let result = diffBuilder.makeResult(for: text, edits: corrector.edits(in: text))

        XCTAssertEqual(result.correctedText, "밥을 먹었다")
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertEqual(result.issues[0].original, "을먹")
        XCTAssertEqual(result.issues[0].suggestion, "을 먹")
    }

    func testRemovesWronglyInsertedSpace() {
        let corrector = SpacingCorrector(spacer: StubSpacer(map: [
            "그럴 수 밖에 없다": "그럴 수밖에 없다"
        ]))

        let text = "그럴 수 밖에 없다"
        let result = diffBuilder.makeResult(for: text, edits: corrector.edits(in: text))

        XCTAssertEqual(result.correctedText, "그럴 수밖에 없다")
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertEqual(result.issues[0].original, "수 밖")
        XCTAssertEqual(result.issues[0].suggestion, "수밖")
    }

    func testMergesAdjacentSpacingFixesIntoOneEdit() {
        let corrector = SpacingCorrector(spacer: StubSpacer(map: [
            "나는바 보입니다.": "나는 바보입니다."
        ]))

        let text = "나는바 보입니다."
        let result = diffBuilder.makeResult(for: text, edits: corrector.edits(in: text))

        XCTAssertEqual(result.correctedText, "나는 바보입니다.")
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertEqual(result.issues[0].original, "는바 보")
        XCTAssertEqual(result.issues[0].suggestion, "는 바보")
    }

    func testBailsOutWhenContentDiverges() {
        let corrector = SpacingCorrector(spacer: StubSpacer(map: [
            "됬다": "됐다"
        ]))

        XCTAssertTrue(corrector.edits(in: "됬다").isEmpty)
    }

    func testCorrectsEachLineIndependently() {
        let corrector = SpacingCorrector(spacer: StubSpacer(map: [
            "밥을먹었다": "밥을 먹었다",
            "됬다": "됐다"
        ]))

        let text = "밥을먹었다\n됬다"
        let result = diffBuilder.makeResult(for: text, edits: corrector.edits(in: text))

        XCTAssertEqual(result.correctedText, "밥을 먹었다\n됬다")
    }

    func testPreservesLeadingAndTrailingSpaces() {
        let corrector = SpacingCorrector(spacer: StubSpacer(map: [
            "안녕": "안녕"
        ]))

        XCTAssertTrue(corrector.edits(in: " 안녕 ").isEmpty)
    }

    func testAlreadyCorrectTextProducesNoEdits() {
        let corrector = SpacingCorrector(spacer: StubSpacer(map: [
            "밥을 먹었다": "밥을 먹었다"
        ]))

        XCTAssertTrue(corrector.edits(in: "밥을 먹었다").isEmpty)
    }
}

private struct StubSpacer: KoreanSpacing {
    let map: [String: String]

    func spacedText(_ text: String) throws -> String {
        map[text] ?? text
    }
}
