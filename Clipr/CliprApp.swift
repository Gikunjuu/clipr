import SwiftUI

@main
struct CliprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No scenes — UI is entirely driven by AppDelegate's NSStatusItem + NotchPanel
        Settings { EmptyView() }
    }
}
