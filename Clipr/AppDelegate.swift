import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DatabaseManager.shared.setup()
        ClipStore.shared.loadClips()
        ClipboardMonitor.shared.start()
        GlobalHotkeyManager.shared.start()

        setupStatusItem()
        // Defer panel creation until after the run loop is live
        DispatchQueue.main.async { _ = NotchPanel.shared }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipr")
        button.image?.isTemplate = true
        button.action = #selector(togglePanel)
        button.target = self

        // Update icon when incognito changes
        NotificationCenter.default.addObserver(
            forName: .cliprIncognitoChanged,
            object: nil,
            queue: .main
        ) { [weak button] _ in
            let name = ClipStore.shared.isIncognito ? "eye.slash" : "doc.on.clipboard"
            button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Clipr")
            button?.image?.isTemplate = true
        }
    }

    @objc private func togglePanel() {
        NotchPanel.shared.toggle()
    }
}
