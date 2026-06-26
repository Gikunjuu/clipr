import SwiftUI

struct QuickPasteView: View {
    @EnvironmentObject var store: ClipStore
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0

    let onSelect:  (ClipItem) -> Void
    let onDismiss: () -> Void

    private var results: [ClipItem] {
        let base = query.isEmpty
            ? Array(store.clips.prefix(60))
            : store.clips.filter { clip in
                let q = query.lowercased()
                return clip.textContent?.lowercased().contains(q) == true
                    || clip.ocrText?.lowercased().contains(q)    == true
                    || clip.urlTitle?.lowercased().contains(q)   == true
                    || clip.filePath?.lowercased().contains(q)   == true
            }.prefix(60).map { $0 }
        return base
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search header
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15))
                TextField("Search to paste…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .onChange(of: query) { _ in selectedIndex = 0 }
                    .onSubmit { commitSelection() }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Results
            if results.isEmpty {
                Text("No clips match \"\(query)\"")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(Array(results.enumerated()), id: \.element.id) { index, clip in
                        QuickPasteRow(clip: clip, isSelected: index == selectedIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(clip) }
                            .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
                            .listRowBackground(
                                index == selectedIndex
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                            )
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { proxy.scrollTo($0, anchor: .center) }
                }
            }

            Divider()

            // Keyboard hint footer
            HStack(spacing: 16) {
                label("↑↓", "navigate")
                label("↩", "paste")
                label("⎋", "dismiss")
                Spacer()
                Text("\(results.count) clips")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(width: 680, height: 460)
        .onKeyPress(.upArrow)    { selectedIndex = max(0, selectedIndex - 1);                  return .handled }
        .onKeyPress(.downArrow)  { selectedIndex = min(results.count - 1, selectedIndex + 1);  return .handled }
        .onKeyPress(.return)     { commitSelection();                                           return .handled }
        .onKeyPress(.escape)     { onDismiss();                                                 return .handled }
    }

    private func commitSelection() {
        guard selectedIndex < results.count else { return }
        onSelect(results[selectedIndex])
    }

    private func label(_ key: String, _ action: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 11, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
            Text(action)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Row

struct QuickPasteRow: View {
    let clip: ClipItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: clip.contentType.systemImage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            // Thumbnail for images
            if clip.contentType == .image,
               let fn = clip.imageFilename,
               let img = FileStore.shared.loadImage(filename: fn) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rowLabel)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                if let app = clip.sourceApp {
                    Text(app)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(clip.createdAt, style: .relative)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 3)
    }

    private var rowLabel: String {
        switch clip.contentType {
        case .image:    return clip.ocrText?.isEmpty == false ? clip.ocrText! : "Image"
        case .color:    return clip.colorHex?.uppercased() ?? "Color"
        case .filePath: return clip.filePath?.components(separatedBy: "\n").first ?? "File"
        default:        return clip.textContent ?? ""
        }
    }
}

// MARK: - NSVisualEffectView wrapper

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material     = material
        v.blendingMode = blendingMode
        v.state        = .active
        return v
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
