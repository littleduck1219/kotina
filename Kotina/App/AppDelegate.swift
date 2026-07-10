import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: FloatingPanelController?
    private var model: FloatingBarViewModel?
    private var statusItem: NSStatusItem?

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
        setUpStatusItem()
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

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "checkmark.seal", accessibilityDescription: "Kotina")
        item.button?.toolTip = "Kotina"

        let menu = NSMenu()
        let showItem = NSMenuItem(
            title: "Kotina 보이기",
            action: #selector(showPanelFromStatusItem),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Kotina 종료",
            action: #selector(quitFromStatusItem),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu
        statusItem = item
    }

    @objc private func showPanelFromStatusItem() {
        panelController?.show()
    }

    @objc private func quitFromStatusItem() {
        model?.quit()
    }
}
