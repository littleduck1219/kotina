import SwiftUI

enum AppIdentity {
    static let name = "Kotina"
}

@main
struct KotinaApp: App {
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
