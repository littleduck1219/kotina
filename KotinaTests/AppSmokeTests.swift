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
}
