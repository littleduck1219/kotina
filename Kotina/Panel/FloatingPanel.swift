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
        // 서버 측 배경 드래그가 그립 리사이즈와 충돌하므로 끄고,
        // 창 이동은 컨텐츠의 WindowDragGesture가 담당한다.
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // 버튼·입력창·그립이 소비하지 않은 배경 클릭이 창까지 올라오면 창 이동을 시작한다.
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        performDrag(with: event)
    }
}

enum FloatingPanelLayout {
    static let width: CGFloat = 744
    static let collapsedHeight: CGFloat = 84
    static let expandedHeight: CGFloat = 280
    static let topInset: CGFloat = 12
    static let minWidth: CGFloat = 360
    static let maxWidth: CGFloat = 1_600
    static let minExpandedHeight: CGFloat = 140
    static let maxExpandedHeight: CGFloat = 700

    static func visibleFrame(from frame: NSRect, in screen: NSRect) -> NSRect {
        let width = min(frame.width, screen.width)
        let height = min(frame.height, screen.height)
        let x = min(max(frame.origin.x, screen.minX), screen.maxX - width)
        let y = min(max(frame.origin.y, screen.minY), screen.maxY - height)

        return NSRect(x: x, y: y, width: width, height: height)
    }

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
