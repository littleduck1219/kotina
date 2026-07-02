import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: FloatingPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let model = FloatingBarViewModel(
            spellingChecker: MockSpellingChecker(),
            translator: MockTranslator(),
            pasteboard: SystemPasteboardWriter()
        )
        let panelController = FloatingPanelController(model: model)
        panelController.show()
        self.panelController = panelController
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
