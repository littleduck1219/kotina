import AppKit
import SwiftUI
import XCTest
@testable import Kotina

@MainActor
final class FloatingPanelControllerTests: XCTestCase {
    func testControllerStartsCollapsedAtTopCenter() {
        let controller = FloatingPanelController(
            model: makeModel(),
            screenFrame: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )

        XCTAssertEqual(controller.panel.frame.width, FloatingPanelLayout.width)
        XCTAssertEqual(controller.panel.frame.height, FloatingPanelLayout.collapsedHeight)
        XCTAssertEqual(controller.panel.frame.origin.x, 360)
        XCTAssertEqual(controller.panel.frame.maxY, 888)
        XCTAssertTrue(controller.panel.contentView is NSHostingView<FloatingBarView>)
    }

    func testExpansionPreservesTopEdge() {
        let controller = FloatingPanelController(
            model: makeModel(),
            screenFrame: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        let initialTop = controller.panel.frame.maxY

        controller.setExpanded(true, animated: false)

        XCTAssertEqual(controller.panel.frame.height, FloatingPanelLayout.expandedHeight)
        XCTAssertEqual(controller.panel.frame.maxY, initialTop)
    }

    private func makeModel() -> FloatingBarViewModel {
        FloatingBarViewModel(
            spellingChecker: MockSpellingChecker(delay: .zero),
            translator: MockTranslator(delay: .zero),
            pasteboard: RecordingPasteboardWriter(),
            debounce: .zero
        )
    }
}
