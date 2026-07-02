import SwiftUI

enum AppIdentity {
    static let name = "Kotina"
}

@main
struct KotinaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Kotina 종료") {
                    appDelegate.terminate()
                }
                .keyboardShortcut("q")
            }
        }
    }
}
