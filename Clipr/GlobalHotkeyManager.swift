import AppKit
import Carbon.HIToolbox

// CGEventTap for global Cmd+Shift+V quick-paste hotkey.
// Requires the user to grant Accessibility access in System Settings > Privacy & Security.
// We prompt on first launch; CGEventTap is created once access is confirmed.
class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var trustPollTimer: Timer?

    private var hotkeyCode: CGKeyCode  { CGKeyCode(SettingsStore.shared.hotkeyCode) }
    private var hotkeyFlags: CGEventFlags { CGEventFlags(rawValue: UInt64(SettingsStore.shared.hotkeyModifiers)) }

    private init() {}

    func start() {
        if AXIsProcessTrusted() {
            createTap()
        } else {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
            // The user may take a while to grant access in System Settings, so keep
            // polling instead of checking once. A single delayed check can miss the
            // grant entirely and never create the tap for the rest of the session.
            trustPollTimer?.invalidate()
            trustPollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self.trustPollTimer = nil
                    self.createTap()
                }
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
        // Holding the combo down fires repeat keyDown events. Without this check
        // each repeat calls toggle() again, so the panel flips open/closed
        // rapidly for as long as the key is held, which reads as "unreliable."
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        guard !isRepeat else { return nil }
        DispatchQueue.main.async { QuickPastePanel.shared.toggle() }
        return nil // consume the event
    }

    func restart() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap = nil; runLoopSource = nil
        createTap()
    }

    deinit {
        trustPollTimer?.invalidate()
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
    }
}
