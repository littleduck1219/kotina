import AppKit

@MainActor
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum FloatingPanelLayout {
    static let width: CGFloat = 720
    static let collapsedHeight: CGFloat = 64
    static let expandedHeight: CGFloat = 360
    static let topInset: CGFloat = 12

    static func frame(from currentFrame: NSRect, targetHeight: CGFloat) -> NSRect {
        NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.maxY - targetHeight,
            width: currentFrame.width,
            height: targetHeight
        )
    }

    static func topCenteredFrame(
        screen: NSRect,
        panelSize: NSSize,
        topInset: CGFloat
    ) -> NSRect {
        NSRect(
            x: screen.midX - panelSize.width / 2,
            y: screen.maxY - topInset - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
    }
}
