import AppKit
import SwiftUI

// Floating panel shown on Ctrl+Cmd+V from any app.
// Records the frontmost app before appearing, then restores it and pastes on selection.
class QuickPastePanel: NSPanel {
    static let shared = QuickPastePanel()

    private var previousApp: NSRunningApplication?

    private init() {
        super.init(
            contentRect:  NSRect(x: 0, y: 0, width: 680, height: 460),
            styleMask:    [.titled, .closable, .fullSizeContentView],
            backing:      .buffered,
            defer:        false
        )
        isFloatingPanel             = true
        level                       = .floating
        titleVisibility             = .hidden
        titlebarAppearsTransparent  = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed        = false
        hasShadow                   = true
        backgroundColor             = .clear
        isOpaque                    = false

        let view = QuickPasteView(
            onSelect:  { [weak self] clip in self?.paste(clip) },
            onDismiss: { [weak self] in self?.dismiss() }
        ).environmentObject(ClipStore.shared)

        contentViewController = NSHostingController(rootView: AnyView(view))
    }

    func toggle() {
        isVisible ? dismiss() : show()
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        orderOut(nil)
    }

    private func paste(_ clip: ClipItem) {
        // Write chosen clip to pasteboard
        let pb = NSPasteboard.general
        pb.clearContents()
        switch clip.contentType {
        case .image:
            if let f = clip.imageFilename, let img = FileStore.shared.loadImage(filename: f) {
                pb.writeObjects([img])
            }
        case .richText:
            if let rtf = clip.rtfData       { pb.setData(rtf, forType: .rtf) }
            else if let t = clip.textContent { pb.setString(t, forType: .string) }
        case .filePath:
            if let paths = clip.filePath {
                let urls = paths.components(separatedBy: "\n")
                    .map { URL(fileURLWithPath: $0) as NSURL }
                pb.writeObjects(urls)
            }
        default:
            if let t = clip.textContent { pb.setString(t, forType: .string) }
        }

        dismiss()

        // Give macOS time to process the panel close, then reactivate previous app and send Cmd+V
        let target = previousApp
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            target?.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                let src   = CGEventSource(stateID: .hidSystemState)
                let down  = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
                let up    = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
                down?.flags = .maskCommand
                up?.flags   = .maskCommand
                down?.post(tap: .cgSessionEventTap)
                up?.post(tap: .cgSessionEventTap)
            }
        }
    }
}
