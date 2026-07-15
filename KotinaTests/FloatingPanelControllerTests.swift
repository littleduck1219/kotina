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
        XCTAssertEqual(
            controller.panel.frame.origin.x,
            (1_440 - FloatingPanelLayout.width) / 2
        )
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

    func testExpansionKeepsAnOffscreenPanelVisible() {
        let controller = FloatingPanelController(
            model: makeModel(),
            screenFrame: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        controller.panel.setFrame(
            NSRect(x: 200, y: 880, width: 500, height: FloatingPanelLayout.collapsedHeight),
            display: false
        )

        controller.setExpanded(true, animated: false)

        XCTAssertLessThanOrEqual(controller.panel.frame.maxY, 900)
        XCTAssertGreaterThanOrEqual(controller.panel.frame.minY, 0)
    }

    func testCollapsedGripDragChangesWidthOnly() {
        let controller = FloatingPanelController(
            model: makeModel(),
            screenFrame: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        let initialTop = controller.panel.frame.maxY

        controller.handleResizeEvent(.began)
        controller.handleResizeEvent(.changed(width: 150, height: 80))
        controller.handleResizeEvent(.ended)

        XCTAssertEqual(controller.panel.frame.width, FloatingPanelLayout.width + 150)
        XCTAssertEqual(controller.panel.frame.height, FloatingPanelLayout.collapsedHeight)
        XCTAssertEqual(controller.panel.frame.maxY, initialTop)
    }

    func testExpandedGripDragAdjustsWidthAndHeightIndependently() {
        let controller = FloatingPanelController(
            model: makeModel(),
            screenFrame: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        controller.setExpanded(true, animated: false)

        controller.handleResizeEvent(.began)
        controller.handleResizeEvent(.changed(width: -100, height: 120))
        controller.handleResizeEvent(.ended)

        XCTAssertEqual(controller.panel.frame.width, FloatingPanelLayout.width - 100)
        XCTAssertEqual(controller.panel.frame.height, FloatingPanelLayout.expandedHeight + 120)
    }

    func testUserResizedExpandedHeightIsRemembered() {
        let controller = FloatingPanelController(
            model: makeModel(),
            screenFrame: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        controller.setExpanded(true, animated: false)

        controller.handleResizeEvent(.began)
        controller.handleResizeEvent(.changed(width: 0, height: 140))
        controller.handleResizeEvent(.ended)

        controller.setExpanded(false, animated: false)
        XCTAssertEqual(controller.panel.frame.height, FloatingPanelLayout.collapsedHeight)

        controller.setExpanded(true, animated: false)
        XCTAssertEqual(
            controller.panel.frame.height,
            FloatingPanelLayout.expandedHeight + 140
        )
    }

    func testGripDragClampsToLimits() {
        let controller = FloatingPanelController(
            model: makeModel(),
            screenFrame: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        controller.setExpanded(true, animated: false)

        controller.handleResizeEvent(.began)
        controller.handleResizeEvent(.changed(width: -5_000, height: 5_000))
        controller.handleResizeEvent(.ended)

        XCTAssertEqual(controller.panel.frame.width, FloatingPanelLayout.minWidth)
        XCTAssertEqual(controller.panel.frame.height, FloatingPanelLayout.maxExpandedHeight)
    }

    func testGripDragKeepsPanelInsideVisibleScreen() {
        let controller = FloatingPanelController(
            model: makeModel(),
            screenFrame: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        controller.panel.setFrame(
            NSRect(x: 1_300, y: 800, width: 500, height: FloatingPanelLayout.collapsedHeight),
            display: false
        )

        controller.handleResizeEvent(.began)
        controller.handleResizeEvent(.changed(width: -5_000, height: 0))
        controller.handleResizeEvent(.ended)

        XCTAssertGreaterThanOrEqual(controller.panel.frame.minX, 0)
        XCTAssertLessThanOrEqual(controller.panel.frame.maxX, 1_440)
        XCTAssertEqual(controller.panel.frame.width, FloatingPanelLayout.minWidth)
    }

    func testStaysOnTopToggleAdjustsWindowLevel() {
        let controller = FloatingPanelController(
            model: makeModel(),
            screenFrame: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        )

        XCTAssertEqual(controller.panel.level, .floating)

        controller.setStaysOnTop(false)
        XCTAssertEqual(controller.panel.level, .normal)

        controller.setStaysOnTop(true)
        XCTAssertEqual(controller.panel.level, .floating)
    }

    private func makeModel() -> FloatingBarViewModel {
        FloatingBarViewModel(
            spellingChecker: MockSpellingChecker(delay: .zero),
            translator: MockTranslator(delay: .zero),
            translationBroker: TranslationSessionBroker(),
            pasteboard: RecordingPasteboardWriter(),
            applicationTerminator: RecordingApplicationTerminator(),
            debounce: .zero
        )
    }
}
