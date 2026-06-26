import AppKit

class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var timer: Timer?

    private init() {}

    func start() {
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private

    private func poll() {
        guard !ClipStore.shared.isIncognito else { return }
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        let frontApp  = NSWorkspace.shared.frontmostApplication
        let appName   = frontApp?.localizedName
        let appBundle = frontApp?.bundleIdentifier

        if let bundle = appBundle, isExcluded(bundle) { return }

        // Snapshot pasteboard items on the main thread, process off-main
        let pbItems = pb.pasteboardItems ?? []
        DispatchQueue.global(qos: .userInitiated).async {
            self.capture(pbItems: pbItems, sourceApp: appName, sourceBundle: appBundle)
        }
    }

    private func isExcluded(_ bundle: String) -> Bool {
        let list = UserDefaults.standard.stringArray(forKey: "clipr.excludedBundles") ?? []
        return list.contains(bundle)
    }

    private func capture(pbItems: [NSPasteboardItem], sourceApp: String?, sourceBundle: String?) {
        let pb = NSPasteboard.general
        guard let clip = buildClip(pb: pb, sourceApp: sourceApp, sourceBundle: sourceBundle)
        else { return }

        // Skip sensitive data
        guard !SensitiveDataFilter.shared.shouldSkip(clip) else { return }

        // Skip if content is identical to the most recent clip
        if let last = ClipStore.shared.clips.first,
           last.textContent != nil && last.textContent == clip.textContent { return }

        ClipStore.shared.saveClip(clip)

        // Fire OCR for images asynchronously
        if clip.contentType == .image,
           let filename = clip.imageFilename,
           let image = FileStore.shared.loadImage(filename: filename) {
            OCRService.shared.extractText(from: image, clipId: clip.id)
        }
    }

    private func buildClip(pb: NSPasteboard, sourceApp: String?, sourceBundle: String?) -> ClipItem? {

        // --- Image ---
        if let image = NSImage(pasteboard: pb) {
            guard let filename = FileStore.shared.saveImage(image) else { return nil }
            return ClipItem(contentType: .image, imageFilename: filename,
                           sourceApp: sourceApp, sourceAppBundle: sourceBundle)
        }

        // --- File URLs ---
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty {
            let paths = urls.map(\.path).joined(separator: "\n")
            return ClipItem(contentType: .filePath, textContent: paths, filePath: paths,
                           sourceApp: sourceApp, sourceAppBundle: sourceBundle)
        }

        // --- RTF ---
        if let rtfData = pb.data(forType: .rtf) {
            let plain = NSAttributedString(rtf: rtfData, documentAttributes: nil)?.string ?? ""
            let type  = detectType(plain)
            return ClipItem(
                contentType: type == .text ? .richText : type,
                textContent: plain,
                rtfData: rtfData,
                colorHex: type == .color ? plain : nil,
                sourceApp: sourceApp, sourceAppBundle: sourceBundle
            )
        }

        // --- Plain text ---
        if let text = pb.string(forType: .string), !text.isEmpty {
            let type = detectType(text)
            return ClipItem(
                contentType: type,
                textContent: text,
                colorHex: type == .color ? text : nil,
                sourceApp: sourceApp, sourceAppBundle: sourceBundle
            )
        }

        return nil
    }

    // MARK: - Content-type detection

    private static let hexColorRegex = try! NSRegularExpression(
        pattern: #"^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#)

    private static let codeKeywords: [String] = [
        "func ", "def ", "class ", "import ", "var ", "let ", "const ",
        "if (", "for (", "while (", "return ", "public ", "private ",
        "struct ", "enum ", "->", "=>", "#!/"
    ]

    private func detectType(_ text: String) -> ContentType {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return .text }

        // Hex color
        let range = NSRange(t.startIndex..., in: t)
        if Self.hexColorRegex.firstMatch(in: t, range: range) != nil { return .color }

        // URL
        if let url = URL(string: t),
           url.scheme == "http" || url.scheme == "https",
           url.host != nil { return .url }

        // Code heuristic: multi-line with keyword density
        let lines = t.components(separatedBy: .newlines)
        if lines.count > 2 {
            let hits = lines.filter { line in
                Self.codeKeywords.contains { line.contains($0) }
            }.count
            if hits >= 2 || (t.contains("{") && t.contains("}")) { return .code }
        }

        return .text
    }
}
