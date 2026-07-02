import XCTest
@testable import Kotina

final class AppSmokeTests: XCTestCase {
    func testApplicationNameIsKotina() {
        XCTAssertEqual(AppIdentity.name, "Kotina")
    }
}
