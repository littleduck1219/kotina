import XCTest
@testable import Kotina

final class FloatingBarGeometryTests: XCTestCase {
    func testCollapsedContentFitsPanelExactly() {
        XCTAssertEqual(
            FloatingBarMetrics.contentWidth + FloatingBarMetrics.horizontalInset * 2,
            FloatingPanelLayout.width
        )
        XCTAssertEqual(
            FloatingBarMetrics.inputHeight + FloatingBarMetrics.verticalInset * 2,
            FloatingPanelLayout.collapsedHeight
        )
    }

    func testExpandedContentFitsPanelExactly() {
        XCTAssertEqual(
            FloatingBarMetrics.inputHeight
                + FloatingBarMetrics.resultHeight
                + FloatingBarMetrics.verticalInset * 2,
            FloatingPanelLayout.expandedHeight
        )
    }
}
