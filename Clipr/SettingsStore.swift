import Foundation
import Combine
import Carbon.HIToolbox

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    // MARK: - Hotkey
    @Published var hotkeyCode: Int {
        didSet { UserDefaults.standard.set(hotkeyCode, forKey: "clipr.hotkeyCode") }
    }
    @Published var hotkeyModifiers: Int {
        didSet { UserDefaults.standard.set(hotkeyModifiers, forKey: "clipr.hotkeyModifiers") }
    }

    // MARK: - Auto-expire
    @Published var autoExpireDays: Int {
        didSet { UserDefaults.standard.set(autoExpireDays, forKey: "clipr.autoExpireDays") }
    }

    private init() {
        let code = UserDefaults.standard.integer(forKey: "clipr.hotkeyCode")
        hotkeyCode = code == 0 ? 9 : code  // default: V (keycode 9)
        let mods = UserDefaults.standard.integer(forKey: "clipr.hotkeyModifiers")
        // default: Cmd+Shift = maskCommand | maskShift
        hotkeyModifiers = mods == 0 ? (Int(CGEventFlags.maskCommand.rawValue) | Int(CGEventFlags.maskShift.rawValue)) : mods
        autoExpireDays = UserDefaults.standard.integer(forKey: "clipr.autoExpireDays") // 0 = off
    }

    var hotkeyDisplayString: String {
        var parts: [String] = []
        let mods = CGEventFlags(rawValue: UInt64(hotkeyModifiers))
        if mods.contains(.maskControl)   { parts.append("⌃") }
        if mods.contains(.maskAlternate) { parts.append("⌥") }
        if mods.contains(.maskShift)     { parts.append("⇧") }
        if mods.contains(.maskCommand)   { parts.append("⌘") }
        if let name = keyCodeName(hotkeyCode) { parts.append(name) }
        return parts.joined(separator: " ")
    }

    private func keyCodeName(_ code: Int) -> String? {
        // Map common keycodes to display strings
        let map: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M", 49: "Space",
            36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        return map[code]
    }
}
