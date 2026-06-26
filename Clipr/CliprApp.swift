import SwiftUI

@main
struct CliprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var clipStore = ClipStore.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView()
                .environmentObject(clipStore)
        } label: {
            Image(systemName: clipStore.isIncognito ? "eye.slash" : "doc.on.clipboard")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
    }
}
