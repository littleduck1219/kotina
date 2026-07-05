import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: FloatingPanelController?
    private var model: FloatingBarViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let dependencies: ProductionDependencies
        do {
            dependencies = try ProductionDependencies.make(bundle: .main)
        } catch {
            NSLog("Kotina 초기화 실패: %@", error.localizedDescription)
            NSApp.terminate(nil)
            return
        }

        let model = FloatingBarViewModel(
            spellingChecker: dependencies.spellingChecker,
            translator: dependencies.translator,
            translationBroker: dependencies.translationBroker,
            pasteboard: dependencies.pasteboard,
            applicationTerminator: dependencies.applicationTerminator
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
