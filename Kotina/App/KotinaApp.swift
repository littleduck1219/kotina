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
    }
}
