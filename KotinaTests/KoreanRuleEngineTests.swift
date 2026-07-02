import XCTest
@testable import Kotina

final class KoreanRuleEngineTests: XCTestCase {
    func testStandardRulesProduceExpectedCorrections() {
        let fixtures: [(source: String, expected: String)] = [
            ("오늘 회의는 몇일 뒤로 미뤄졌어요.", "오늘 회의는 며칠 뒤로 미뤄졌어요."),
            ("몇일이 필요해요?", "며칠이 필요해요?"),
            ("몇일만 기다려 주세요.", "며칠만 기다려 주세요."),
            ("몇일 후에 만나요.", "며칠 후에 만나요."),
            ("이렇게 하면 되요.", "이렇게 하면 돼요."),
            ("지금 해도 되요!", "지금 해도 돼요!"),
            ("그러면 되요?", "그러면 돼요?"),
            ("지금은 안되요.", "지금은 안 돼요."),
            ("그건 안돼요.", "그건 안 돼요."),
            ("시간이 안되면 알려 주세요.", "시간이 안 되면 알려 주세요."),
            ("무리하면 안된다.", "무리하면 안 된다."),
            ("여기서는 안됩니다.", "여기서는 안 됩니다."),
            ("아직 안되는 기능이에요.", "아직 안 되는 기능이에요."),
            ("준비가 안되어 있어요.", "준비가 안 되어 있어요."),
            ("\u{C660} 일이에요?", "\u{C6EC} 일이에요?"),
            ("\u{C660}일인지 궁금해요.", "\u{C6EC}일인지 궁금해요."),
            ("\u{C660} 사람이 왔어요?", "\u{C6EC} 사람이 왔어요?"),
            ("\u{C660} 소리가 들려요.", "\u{C6EC} 소리가 들려요."),
            ("할수 있어요.", "할 수 있어요."),
            ("갈수 있어요.", "갈 수 있어요."),
            ("볼수 있어요.", "볼 수 있어요."),
            ("될수 있어요.", "될 수 있어요."),
            ("먹을수 있어요.", "먹을 수 있어요."),
            ("두  칸을 띄웠어요.", "두 칸을 띄웠어요."),
            ("세   칸도 하나로 줄여요.", "세 칸도 하나로 줄여요.")
        ]
        let engine = KoreanRuleEngine.standard
        let builder = CorrectionDiffBuilder()

        for fixture in fixtures {
            let result = builder.makeResult(
                for: fixture.source,
                edits: engine.edits(in: fixture.source)
            )
            XCTAssertEqual(result.correctedText, fixture.expected, fixture.source)
            XCTAssertFalse(result.issues.isEmpty, fixture.source)
        }
    }

    func testStandardRulesPreserveNormalText() {
        let inputs = [
            "오늘 회의가 있습니다.",
            "며칠 뒤에 만나요.",
            "이렇게 하면 돼요.",
            "지금은 안 돼요.",
            "시간이 안 되면 알려 주세요.",
            "그러면 안 됩니다.",
            "\u{C660}지 낯설지 않아요.",
            "웬일인지 조용하네요.",
            "할 수 있어요.",
            "갈 수 있습니다.",
            "볼 수 없어요.",
            "할수록 좋아요.",
            "갈수록 멀어져요.",
            "공백은 한 칸이에요.",
            "영어 text도 유지해요.",
            "숫자 123도 유지해요.",
            "이모지 🙂도 유지해요.",
            "URL https://example.com을 열어요.",
            "괄호(내용)를 유지해요.",
            "줄바꿈\n문장도 유지해요.",
            "탭\t문자도 유지해요.",
            "빈 규칙 밖의 표현은 그대로 둬요."
        ]
        let engine = KoreanRuleEngine.standard
        let builder = CorrectionDiffBuilder()

        for input in inputs {
            let result = builder.makeResult(for: input, edits: engine.edits(in: input))
            XCTAssertEqual(result.correctedText, input, input)
            XCTAssertTrue(result.issues.isEmpty, input)
        }
    }
}
