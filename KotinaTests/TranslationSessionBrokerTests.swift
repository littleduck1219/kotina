import XCTest
@testable import Kotina

@MainActor
final class TranslationSessionBrokerTests: XCTestCase {
    func testSupportedAvailabilityNeedsPreparation() async {
        let translator = AppleTranslator(
            availability: FixedTranslationAvailability(status: .supported),
            broker: TranslationSessionBroker()
        )

        let state = await translator.resourceState()
        XCTAssertEqual(state, .needsPreparation)
    }

    func testInstalledAvailabilityIsReady() async {
        let translator = AppleTranslator(
            availability: FixedTranslationAvailability(status: .installed),
            broker: TranslationSessionBroker()
        )

        let state = await translator.resourceState()
        XCTAssertEqual(state, .ready)
    }

    func testUnsupportedAvailabilityIsUnavailable() async {
        let translator = AppleTranslator(
            availability: FixedTranslationAvailability(status: .unsupported),
            broker: TranslationSessionBroker()
        )

        let state = await translator.resourceState()
        XCTAssertEqual(state, .unavailable)
    }

    func testPreparationCompletesThroughDriver() async throws {
        let broker = TranslationSessionBroker()
        let driver = RecordingTranslationSessionDriver()
        let preparation = Task { try await broker.prepareTranslation() }
        await waitForConfiguration(on: broker)

        await broker.handle(driver: driver)
        try await preparation.value

        XCTAssertEqual(driver.preparationCount, 1)
        XCTAssertEqual(driver.translatedTexts, [])
    }

    func testTranslationReturnsDriverResult() async throws {
        let expected = TranslationResult(
            sourceLanguage: "ko",
            targetLanguage: "en",
            translatedText: "Hello"
        )
        let broker = TranslationSessionBroker()
        let driver = RecordingTranslationSessionDriver(result: expected)
        let translation = Task { try await broker.translate("안녕") }
        await waitForConfiguration(on: broker)

        await broker.handle(driver: driver)
        let result = try await translation.value

        XCTAssertEqual(result, expected)
        XCTAssertEqual(driver.translatedTexts, ["안녕"])
    }

    func testNewRequestCancelsStaleRequest() async throws {
        let expected = TranslationResult(
            sourceLanguage: "ko",
            targetLanguage: "en",
            translatedText: "New"
        )
        let broker = TranslationSessionBroker()
        let first = Task { try await broker.translate("이전") }
        await waitForConfiguration(on: broker)
        let firstVersion = broker.configuration?.version

        let second = Task { try await broker.translate("최신") }
        await waitForConfigurationChange(on: broker, from: firstVersion)

        do {
            _ = try await first.value
            XCTFail("이전 요청은 취소되어야 합니다.")
        } catch is CancellationError {
        }

        let driver = RecordingTranslationSessionDriver(result: expected)
        await broker.handle(driver: driver)

        let secondResult = try await second.value
        XCTAssertEqual(secondResult, expected)
        XCTAssertEqual(driver.translatedTexts, ["최신"])
    }

    func testCancelledPreparationKeepsNeedsPreparationState() async {
        let broker = TranslationSessionBroker()
        let translator = AppleTranslator(
            availability: FixedTranslationAvailability(status: .supported),
            broker: broker
        )
        let preparation = Task { try await translator.prepareTranslation() }
        await waitForConfiguration(on: broker)

        preparation.cancel()

        do {
            try await preparation.value
            XCTFail("취소된 준비 요청은 성공하면 안 됩니다.")
        } catch is CancellationError {
        } catch {
            XCTFail("예상하지 못한 오류: \(error)")
        }
        let state = await translator.resourceState()
        XCTAssertEqual(state, .needsPreparation)
    }

    private func waitForConfiguration(on broker: TranslationSessionBroker) async {
        for _ in 0..<100 where broker.configuration == nil {
            await Task.yield()
        }
        XCTAssertNotNil(broker.configuration)
    }

    private func waitForConfigurationChange(
        on broker: TranslationSessionBroker,
        from version: Int?
    ) async {
        for _ in 0..<100 where broker.configuration?.version == version {
            await Task.yield()
        }
        XCTAssertNotEqual(broker.configuration?.version, version)
    }
}

private struct FixedTranslationAvailability: TranslationAvailabilityChecking {
    let status: TranslationAvailabilityStatus

    func status() async -> TranslationAvailabilityStatus {
        status
    }
}

@MainActor
private final class RecordingTranslationSessionDriver: TranslationSessionDriving {
    private(set) var preparationCount = 0
    private(set) var translatedTexts: [String] = []
    private let result: TranslationResult

    init(result: TranslationResult = .init(
        sourceLanguage: "ko",
        targetLanguage: "en",
        translatedText: ""
    )) {
        self.result = result
    }

    func prepareTranslation() async throws {
        preparationCount += 1
    }

    func translate(_ text: String) async throws -> TranslationResult {
        translatedTexts.append(text)
        return result
    }
}
