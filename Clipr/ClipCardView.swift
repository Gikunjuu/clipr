import SwiftUI

struct ClipCardView: View {
    let clip: ClipItem
    @EnvironmentObject var store: ClipStore
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            previewContent
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .clipped()
                .cornerRadius(8, corners: [.topLeft, .topRight])

            VStack(alignment: .leading, spacing: 3) {
                if let text = previewLabel, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                HStack {
                    if let app = clip.sourceApp {
                        Text(app)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(clip.createdAt, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(alignment: .topTrailing) {
            if clip.copyCount > 1 {
                Text(clip.copyCount > 99 ? "99+" : "\(clip.copyCount)×")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .padding(6)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    clip.isPinned ? Color.accentColor.opacity(0.7) : Color(NSColor.separatorColor).opacity(0.5),
                    lineWidth: clip.isPinned ? 1.5 : 0.5
                )
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.10 : 0.03), radius: isHovered ? 8 : 2, y: 2)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
        .contextMenu { contextMenu }
        .onTapGesture { NotchPanel.shared.pasteAndClose(clip) }
        .help("Click to paste · Right-click for options")
    }

    // MARK: - Preview

    @ViewBuilder
    var previewContent: some View {
        switch clip.contentType {
        case .image:
            if let fn = clip.imageFilename, let img = FileStore.shared.loadImage(filename: fn) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                iconPlaceholder("photo")
            }

        case .color:
            if let hex = clip.colorHex, let color = Color(hexString: hex) {
                ZStack {
                    color
                    Text(hex.uppercased())
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
            } else {
                iconPlaceholder("paintpalette")
            }

        case .url:
            VStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                Text(clip.urlTitle ?? clip.textContent ?? "")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))

        case .code:
            Text(clip.textContent ?? "")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.textBackgroundColor))

        case .filePath:
            VStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                Text(clip.filePath?.components(separatedBy: "\n").first ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))

        default:
            Text(clip.textContent ?? "")
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.controlBackgroundColor))
        }
    }

    @ViewBuilder
    func iconPlaceholder(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 28))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
    }

    var previewLabel: String? {
        switch clip.contentType {
        case .image:    return clip.ocrText.flatMap { $0.isEmpty ? nil : $0 }
        case .color:    return nil
        case .filePath: return clip.filePath?.components(separatedBy: "\n").first
        default:        return clip.textContent
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    var contextMenu: some View {
        Button("Copy") { copyToClipboard() }
        Button(clip.isPinned ? "Unpin" : "Pin to Top") { store.togglePin(clip) }
        Divider()
        Button("Delete", role: .destructive) { store.deleteClip(clip) }
    }

    // MARK: - Copy

    func copyToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch clip.contentType {
        case .image:
            if let fn = clip.imageFilename, let img = FileStore.shared.loadImage(filename: fn) {
                pb.writeObjects([img])
            }
        case .richText:
            if let rtf = clip.rtfData         { pb.setData(rtf, forType: .rtf) }
            else if let t = clip.textContent  { pb.setString(t, forType: .string) }
        case .filePath:
            if let paths = clip.filePath {
                let urls = paths.components(separatedBy: "\n").map { URL(fileURLWithPath: $0) as NSURL }
                pb.writeObjects(urls)
            }
        default:
            if let t = clip.textContent { pb.setString(t, forType: .string) }
        }
    }
}

// MARK: - Corner radius helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    static let topLeft     = RectCorner(rawValue: 1 << 0)
    static let topRight    = RectCorner(rawValue: 1 << 1)
    static let bottomLeft  = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let all: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: RectCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = corners.contains(.topLeft)     ? radius : 0
        let tr = corners.contains(.topRight)    ? radius : 0
        let bl = corners.contains(.bottomLeft)  ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                    radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                    radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                    radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                    radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Hex color init

extension Color {
    init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 3 || hex.count == 6 else { return nil }
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        var rgb: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgb) else { return nil }
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}
