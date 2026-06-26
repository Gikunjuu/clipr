import AppKit
import Carbon.HIToolbox

// CGEventTap for global Ctrl+Cmd+V quick-paste hotkey.
// Requires the user to grant Accessibility access in System Settings > Privacy & Security.
// We prompt on first launch; CGEventTap is created once access is confirmed.
class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // V = key code 9
    private let hotkeyCode: CGKeyCode  = 9
    private let hotkeyFlags: CGEventFlags = [.maskControl, .maskCommand]

    private init() {}

    func start() {
        if AXIsProcessTrusted() {
            createTap()
        } else {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
            // Re-try after the user (hopefully) grants access
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                if AXIsProcessTrusted() { self?.createTap() }
            }
        }
    }

    private func createTap() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        // C-convention callback — captures self via userInfo pointer
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard type == .keyDown, let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let mgr = Unmanaged<GlobalHotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            return mgr.handle(event: event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = eventTap else {
            print("GlobalHotkeyManager: tapCreate failed — Accessibility permission may be missing")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let src = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(event: CGEvent) -> Unmanaged<CGEvent>? {
        let code  = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskControl, .maskCommand, .maskShift, .maskAlternate])
        guard code == hotkeyCode, flags == hotkeyFlags else {
            return Unmanaged.passUnretained(event)
        }
        DispatchQueue.main.async { QuickPastePanel.shared.toggle() }
        return nil // consume the event
    }

    deinit {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
    }
}
