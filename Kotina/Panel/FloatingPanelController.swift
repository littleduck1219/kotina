import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
    let panel: FloatingPanel

    init(model: FloatingBarViewModel, screenFrame: NSRect? = nil) {
        let visibleFrame = screenFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1_440, height: 900)
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

        let rootView = FloatingBarView(model: model) { [weak panel] expanded in
            guard let panel else { return }
            Self.resize(panel: panel, expanded: expanded, animated: true)
        }
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: initialFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        Self.resize(panel: panel, expanded: expanded, animated: animated)
    }

    private static func resize(panel: FloatingPanel, expanded: Bool, animated: Bool) {
        let targetHeight = expanded
            ? FloatingPanelLayout.expandedHeight
            : FloatingPanelLayout.collapsedHeight
        let frame = FloatingPanelLayout.frame(
            from: panel.frame,
            targetHeight: targetHeight
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
}

