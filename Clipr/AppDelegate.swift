import AppKit
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DatabaseManager.shared.setup()
        ClipStore.shared.loadClips()
        ClipboardMonitor.shared.start()
        GlobalHotkeyManager.shared.start()

        setupStatusItem()
        DispatchQueue.main.async { _ = NotchPanel.shared }

        // Prompt for Accessibility if not yet granted — needed for paste simulation
        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipr")
        button.image?.isTemplate = true
        button.action = #selector(togglePanel)
        button.sendAction(on: [.leftMouseUp])
        button.target = self

        // Right-click shows a small options menu
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Clipr", action: #selector(togglePanel), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled ? .on : .off
        loginItem.tag = 42  // find it later for state refresh
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Clipr", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Attach right-click menu while left-click still calls togglePanel
        statusItem?.menu = nil  // menu must be nil for left-click action to fire
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Store menu for right-click handling
        self.optionsMenu = menu

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

    private var optionsMenu: NSMenu?

    @objc private func togglePanel(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            NotchPanel.shared.toggle(); return
        }
        if event.type == .rightMouseUp {
            // Refresh login-item checkmark before showing menu
            if let item = optionsMenu?.item(withTag: 42) {
                item.state = isLaunchAtLoginEnabled ? .on : .off
            }
            statusItem?.menu = optionsMenu
            statusItem?.button?.performClick(nil)
            // Clear menu so next left-click still calls togglePanel
            DispatchQueue.main.async { self.statusItem?.menu = nil }
        } else {
            NotchPanel.shared.toggle()
        }
    }

    // MARK: - Launch at Login

    private var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if isLaunchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("AppDelegate: launch-at-login toggle failed — \(error)")
        }
    }
}
