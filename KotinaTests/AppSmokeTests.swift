import XCTest
@testable import Kotina

final class AppSmokeTests: XCTestCase {
    func testApplicationNameIsKotina() {
        XCTAssertEqual(AppIdentity.name, "Kotina")
    }

    func testMinimumSystemVersionIsMacOS15() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String,
            "15.0"
        )
    }

    @MainActor
    func testProductionDependenciesUseLocalServices() throws {
        let dependencies = try ProductionDependencies.make(bundle: .main)
        let spellingType = String(reflecting: type(of: dependencies.spellingChecker))
        let translationType = String(reflecting: type(of: dependencies.translator))

        XCTAssertTrue(spellingType.contains("LocalKoreanChecker"), spellingType)
        XCTAssertTrue(translationType.contains("LocalQwenTranslator"), translationType)
        XCTAssertFalse(spellingType.contains("Mock"), spellingType)
        XCTAssertFalse(translationType.contains("Mock"), translationType)

    }

    @MainActor
    func testProductionProofreadingUsesBundledKiwiAndRules() async throws {
        let dependencies = try ProductionDependencies.make(bundle: .main)

        let corrected = try await dependencies.spellingChecker.check("몇일 안되요")
        let preserved = try await dependencies.spellingChecker.check("새 문장")

        XCTAssertEqual(corrected.correctedText, "며칠 안 돼요")
        XCTAssertEqual(preserved.correctedText, "새 문장")
        XCTAssertTrue(preserved.issues.isEmpty)
    }
}
