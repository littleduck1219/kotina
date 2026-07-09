import AppKit
import XCTest
@testable import Kotina

@MainActor
final class FloatingPanelTests: XCTestCase {
    func testPanelFloatsAcrossSpacesWithoutHidingOnDeactivate() {
        let panel = FloatingPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: FloatingPanelLayout.width,
                height: FloatingPanelLayout.collapsedHeight
            )
        )

        XCTAssertEqual(panel.level, .floating)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.stationary))
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertTrue(panel.becomesKeyOnlyIfNeeded)
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertFalse(panel.isMovableByWindowBackground)
    }

    func testExpandedFramePreservesTopEdge() {
        let collapsed = NSRect(
            x: 100,
            y: 800,
            width: FloatingPanelLayout.width,
            height: FloatingPanelLayout.collapsedHeight
        )

        let expanded = FloatingPanelLayout.frame(
            from: collapsed,
            targetHeight: FloatingPanelLayout.expandedHeight
        )

        XCTAssertEqual(expanded.maxY, collapsed.maxY)
        XCTAssertEqual(expanded.height, FloatingPanelLayout.expandedHeight)
        XCTAssertEqual(expanded.width, FloatingPanelLayout.width)
    }

    func testTopCenteredFrameUsesVisibleScreenBounds() {
        let screen = NSRect(x: 0, y: 0, width: 1_440, height: 900)

        let frame = FloatingPanelLayout.topCenteredFrame(
            screen: screen,
            panelSize: NSSize(
                width: FloatingPanelLayout.width,
                height: FloatingPanelLayout.collapsedHeight
            ),
            topInset: FloatingPanelLayout.topInset
        )

        XCTAssertEqual(frame.origin.x, (1_440 - FloatingPanelLayout.width) / 2)
        XCTAssertEqual(frame.maxY, 900 - FloatingPanelLayout.topInset)
    }
}
