import AppKit
import SwiftUI

// 패널이 키 창이 아니어도 첫 클릭부터 컨텐츠(버튼·배경 드래그)가 반응하게 한다.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class FloatingPanelController {
    let panel: FloatingPanel

    private var isExpanded = false
    private var expandedHeight = FloatingPanelLayout.expandedHeight
    private var resizeStartFrame: NSRect?
    private let injectedVisibleFrame: NSRect?
    private let fallbackVisibleFrame: NSRect

    init(model: FloatingBarViewModel, screenFrame: NSRect? = nil) {
        let visibleFrame = screenFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1_440, height: 900)
        injectedVisibleFrame = screenFrame
        fallbackVisibleFrame = visibleFrame
        let initialFrame = FloatingPanelLayout.topCenteredFrame(
            screen: visibleFrame,
            panelSize: NSSize(
                width: FloatingPanelLayout.width,
                height: FloatingPanelLayout.collapsedHeight
            ),
            topInset: FloatingPanelLayout.topInset
        )
        let panel = FloatingPanel(contentRect: initialFrame)
        self.panel = panel

        let rootView = FloatingBarView(
            model: model,
            expansionChanged: { [weak self] expanded in
                self?.setExpanded(expanded, animated: true)
            },
            stayOnTopChanged: { [weak panel] staysOnTop in
                panel?.level = staysOnTop ? .floating : .normal
            },
            resizeEvent: { [weak self] event in
                self?.handleResizeEvent(event)
            }
        )
        let hostingView = FirstMouseHostingView(rootView: rootView)
        // SwiftUI 최소 크기 제약이 창 크기를 되밀지 않도록 창 크기 관여를 끈다.
        hostingView.sizingOptions = []
        hostingView.frame = NSRect(origin: .zero, size: initialFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
    }

    func show() {
        keepPanelVisible()
        panel.orderFrontRegardless()
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        isExpanded = expanded
        let targetHeight = expanded ? expandedHeight : FloatingPanelLayout.collapsedHeight
        let frame = FloatingPanelLayout.visibleFrame(
            from: FloatingPanelLayout.frame(
                from: panel.frame,
                targetHeight: targetHeight
            ),
            in: currentVisibleFrame
        )

        guard animated else {
            panel.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    func setStaysOnTop(_ staysOnTop: Bool) {
        panel.level = staysOnTop ? .floating : .normal
    }

    // 그립 드래그로 너비와 높이를 각각 독립적으로 조절한다.
    // 접힘 상태에서는 높이를 고정하고 너비만 바꾼다.
    func handleResizeEvent(_ event: PanelResizeEvent) {
        switch event {
        case .began:
            resizeStartFrame = panel.frame
        case let .changed(deltaWidth, deltaHeight):
            guard let startFrame = resizeStartFrame else { return }
            let visibleFrame = currentVisibleFrame
            let width = min(
                max(startFrame.width + deltaWidth, FloatingPanelLayout.minWidth),
                min(FloatingPanelLayout.maxWidth, visibleFrame.width)
            )
            let height = isExpanded
                ? min(
                    max(startFrame.height + deltaHeight, FloatingPanelLayout.minExpandedHeight),
                    min(FloatingPanelLayout.maxExpandedHeight, visibleFrame.height)
                )
                : FloatingPanelLayout.collapsedHeight
            // 드래그 시작 시점의 왼쪽·위 가장자리에 고정해 리사이즈 중 위치가 움직이지 않게 한다.
            panel.setFrame(
                FloatingPanelLayout.visibleFrame(
                    from: NSRect(
                        x: startFrame.origin.x,
                        y: startFrame.maxY - height,
                        width: width,
                        height: height
                    ),
                    in: visibleFrame
                ),
                display: true
            )
        case .ended:
            resizeStartFrame = nil
            if isExpanded {
                expandedHeight = panel.frame.height
            }
        }
    }

    private var currentVisibleFrame: NSRect {
        injectedVisibleFrame
            ?? panel.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? fallbackVisibleFrame
    }

    private func keepPanelVisible() {
        let visibleFrame = currentVisibleFrame
        let frame = FloatingPanelLayout.visibleFrame(from: panel.frame, in: visibleFrame)
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
    }
}
