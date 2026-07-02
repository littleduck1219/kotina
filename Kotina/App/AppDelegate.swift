import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: FloatingPanelController?
    private var model: FloatingBarViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let model = FloatingBarViewModel(
            spellingChecker: MockSpellingChecker(),
            translator: MockTranslator(),
            pasteboard: SystemPasteboardWriter(),
            applicationTerminator: SystemApplicationTerminator()
        )
        let panelController = FloatingPanelController(model: model)
        panelController.show()
        self.model = model
        self.panelController = panelController
    }

    func terminate() {
        model?.quit()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
