import AppKit
import SwiftUI

// Dock과 같은 behind-window 블러 글라스 배경.
// 마우스 이벤트는 통과시켜 WindowDragGesture를 방해하지 않는다.
struct GlassBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = PassthroughVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.layer?.cornerRadius = cornerRadius
    }
}

private final class PassthroughVisualEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
