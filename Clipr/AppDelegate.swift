import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        DatabaseManager.shared.setup()
        ClipStore.shared.loadClips()
        ClipboardMonitor.shared.start()
        GlobalHotkeyManager.shared.start()
    }
}
