import AppKit
import SwiftUI
import ObjectiveC

// NSHostingView in macOS 26 calls windowDidLayout() → updateAnimatedWindowSize() → setFrame,
// which re-entrantly triggers _postWindowNeedsUpdateConstraints and crashes.
// We swizzle windowDidLayout to a no-op since we drive the frame manually.
private var swizzled = false
private func swizzleHostingViewIfNeeded() {
    guard !swizzled else { return }
    swizzled = true
    let cls: AnyClass = NSHostingView<AnyView>.self
    let sel = NSSelectorFromString("windowDidLayout")
    if let orig = class_getInstanceMethod(cls, sel) {
        let block: @convention(block) (AnyObject) -> Void = { _ in }
        let imp = imp_implementationWithBlock(block)
        method_setImplementation(orig, imp)
    }
}

class NotchPanel: NSWindow {
    static let shared = NotchPanel()

    private(set) var isExpanded = false
    private var lastCollapsedAt: Date = .distantPast  // debounce resignKey race
    private(set) var previousApp: NSRunningApplication?
    private let expandedWidth:  CGFloat = 860
    private let expandedHeight: CGFloat = 560
    private let pillWidth:      CGFloat = 160
    private let pillHeight:     CGFloat = 34

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
            styleMask:   [.borderless],
            backing:     .buffered,
            defer:       true
        )

        swizzleHostingViewIfNeeded()

        level                  = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        backgroundColor        = .clear
        isOpaque               = false
        hasShadow              = true
        isMovable              = false
        collectionBehavior     = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents     = false

        let root = NotchPanelView(panel: self)
            .environmentObject(ClipStore.shared)

        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions          = []
        hosting.autoresizingMask       = [.width, .height]
        contentView                    = hosting

        positionAtTop(expanded: false, animate: false)
        // Start hidden — menu bar icon is the trigger
    }

    // MARK: - Toggle

    func toggle() {
        isExpanded ? collapse() : expand()
    }

    func expand() {
        // If we just collapsed (< 0.35 s ago) it means the user clicked the menu bar
        // icon while the panel was open: resignKey fired collapse() first, then
        // togglePanel() fired expand(). Treat that as a "close" intent, not open.
        guard Date().timeIntervalSince(lastCollapsedAt) > 0.35 else { return }
        guard !isExpanded else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        isExpanded = true
        NotificationCenter.default.post(name: .notchPanelToggled, object: true)
        positionAtTop(expanded: true, animate: true)
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Concatenate multiple clips as text, paste, and close.
    func pasteMultipleAndClose(_ clips: [ClipItem]) {
        guard !clips.isEmpty else { return }

        let parts: [String] = clips.compactMap { clip in
            switch clip.contentType {
            case .image: return nil
            default:     return clip.textContent ?? clip.filePath
            }
        }

        ClipboardMonitor.shared.skipNextCapture = true
        let pb = NSPasteboard.general
        pb.clearContents()

        if parts.isEmpty {
            if let f = clips.first?.imageFilename, let img = FileStore.shared.loadImage(filename: f) {
                pb.writeObjects([img])
            }
        } else {
            pb.setString(parts.joined(separator: "\n\n"), forType: .string)
        }

        SoundManager.shared.play(.pasteFromPanel)
        collapse()
        sendPaste(to: previousApp)
    }

    /// Write clip to pasteboard, close the panel, reactivate the source app, and send Cmd+V.
    func pasteAndClose(_ clip: ClipItem) {
        ClipboardMonitor.shared.skipNextCapture = true
        let pb = NSPasteboard.general
        pb.clearContents()
        switch clip.contentType {
        case .image:
            if let f = clip.imageFilename, let img = FileStore.shared.loadImage(filename: f) {
                pb.writeObjects([img])
            }
        case .richText:
            if let rtf = clip.rtfData        { pb.setData(rtf, forType: .rtf) }
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

        SoundManager.shared.play(.pasteFromPanel)
        collapse()
        sendPaste(to: previousApp)
    }

    // MARK: - Paste delivery

    private func sendPaste(to target: NSRunningApplication?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            target?.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                if AXIsProcessTrusted() {
                    // Preferred: CGEventTap — works in all apps including Electron
                    let src  = CGEventSource(stateID: .hidSystemState)
                    let down = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
                    let up   = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
                    down?.flags = .maskCommand
                    up?.flags   = .maskCommand
                    down?.post(tap: .cgSessionEventTap)
                    up?.post(tap: .cgSessionEventTap)
                } else {
                    // Fallback: AppleScript keystroke (prompts for Automation permission once)
                    let appName = target?.localizedName ?? ""
                    let script = """
                        tell application "\(appName)" to activate
                        tell application "System Events" to keystroke "v" using command down
                        """
                    var err: NSDictionary?
                    NSAppleScript(source: script)?.executeAndReturnError(&err)
                }
            }
        }
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        lastCollapsedAt = Date()
        NotificationCenter.default.post(name: .notchPanelToggled, object: false)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration       = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
        })
    }

    // MARK: - Positioning

    private func positionAtTop(expanded: Bool, animate: Bool) {
        guard let screen = NSScreen.main else { return }
        let sw = screen.frame.width
        let sh = screen.frame.maxY

        let w = expanded ? expandedWidth  : pillWidth
        let h = expanded ? expandedHeight : pillHeight
        let x = (sw - w) / 2
        let y = sh - h

        let target = CGRect(x: x, y: y, width: w, height: h)
        if animate {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration       = 0.38
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.32, 1.28, 0.48, 1.0)
                animator().setFrame(target, display: true)
            }
        } else {
            setFrame(target, display: false)
        }
    }

    // MARK: - Key window / dismiss

    override func resignKey() {
        super.resignKey()
        if isExpanded { collapse() }
    }

    override var canBecomeKey: Bool  { true  }
    override var canBecomeMain: Bool { false }

    // Cmd+W / close events collapse the panel instead of destroying the window
    override func performClose(_ sender: Any?) { collapse() }
    override func close() { collapse() }
}
