import AppKit
import SwiftUI

// isMovableByWindowBackground 패널에서 창 이동을 가로채지 않고
// 드래그 델타를 전달하는 크기 조절 그립.
struct PanelResizeGrip: NSViewRepresentable {
    let onEvent: (PanelResizeEvent) -> Void

    func makeNSView(context: Context) -> GripView {
        GripView(onEvent: onEvent)
    }

    func updateNSView(_ view: GripView, context: Context) {
        view.onEvent = onEvent
    }

    @MainActor
    final class GripView: NSView {
        var onEvent: (PanelResizeEvent) -> Void
        private var startLocation: NSPoint?

        init(onEvent: @escaping (PanelResizeEvent) -> Void) {
            self.onEvent = onEvent
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override var mouseDownCanMoveWindow: Bool { false }

        // 비활성 패널에서 첫 클릭부터 그립이 받아야 창 이동으로 넘어가지 않는다.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(
                bounds,
                cursor: .frameResize(position: .bottomRight, directions: .all)
            )
        }

        override func mouseDown(with event: NSEvent) {
            // 창이 함께 움직여도 안정적이도록 화면 좌표 기준으로 계산한다.
            startLocation = NSEvent.mouseLocation
            onEvent(.began)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let startLocation else { return }
            let location = NSEvent.mouseLocation
            onEvent(.changed(
                width: location.x - startLocation.x,
                height: startLocation.y - location.y
            ))
        }

        override func mouseUp(with event: NSEvent) {
            startLocation = nil
            onEvent(.ended)
        }
    }
}
