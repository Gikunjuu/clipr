import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared
    @State private var isRecording = false
    @State private var recordingMonitor: Any?
    @State private var showSaved = false

    private let expireOptions = [
        (0,  "Never"),
        (1,  "After 1 day"),
        (7,  "After 7 days"),
        (14, "After 14 days"),
        (30, "After 30 days"),
        (90, "After 90 days"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Hotkey
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Paste Hotkey")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Button {
                    isRecording ? stopRecording() : startRecording()
                } label: {
                    HStack(spacing: 8) {
                        Text(isRecording ? "Press any shortcut…" : settings.hotkeyDisplayString)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(isRecording ? Color.accentColor : .primary)
                        Spacer()
                        if isRecording {
                            Text("Cancel")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(isRecording ? 0.12 : 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(isRecording ? Color.accentColor : Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)

                Text("Click to record a new shortcut")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Divider().opacity(0.2)

            // Auto-expire
            VStack(alignment: .leading, spacing: 8) {
                Text("Auto-expire Clips")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    ForEach(expireOptions, id: \.0) { days, label in
                        Button {
                            settings.autoExpireDays = days
                            ClipStore.shared.runAutoExpire()
                            withAnimation { showSaved = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showSaved = false }
                            }
                        } label: {
                            HStack {
                                Text(label)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if settings.autoExpireDays == days {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(settings.autoExpireDays == days ? Color.accentColor.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if showSaved {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Saved")
                            .fontWeight(.medium)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Text("Pinned clips are never auto-deleted")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(width: 280)
        .onDisappear { stopRecording() }
    }

    // MARK: - Key recording

    private func startRecording() {
        isRecording = true
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection([.command, .shift, .control, .option])
            guard !flags.isEmpty else { return event }  // require at least one modifier
            let cgFlags = cgEventFlags(from: flags)
            SettingsStore.shared.hotkeyModifiers = Int(cgFlags.rawValue)
            SettingsStore.shared.hotkeyCode = Int(event.keyCode)
            GlobalHotkeyManager.shared.restart()
            self.stopRecording()
            return nil  // consume
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = recordingMonitor { NSEvent.removeMonitor(m) }
        recordingMonitor = nil
    }

    private func cgEventFlags(from nsFlags: NSEvent.ModifierFlags) -> CGEventFlags {
        var f = CGEventFlags()
        if nsFlags.contains(.command) { f.insert(.maskCommand) }
        if nsFlags.contains(.shift)   { f.insert(.maskShift) }
        if nsFlags.contains(.control) { f.insert(.maskControl) }
        if nsFlags.contains(.option)  { f.insert(.maskAlternate) }
        return f
    }
}
