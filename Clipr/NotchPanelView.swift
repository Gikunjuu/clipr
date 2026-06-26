import SwiftUI
import AppKit

struct NotchPanelView: View {
    @EnvironmentObject var store: ClipStore
    weak var panel: NotchPanel?

    @State private var showContent = false

    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 230), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            if showContent {
                header
                typeFilterBar
                Divider().opacity(0.25)
                clipGrid
            } else {
                // Collapsed pill label
                HStack(spacing: 7) {
                    Image(systemName: store.isIncognito ? "eye.slash" : "doc.on.clipboard")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Clipr")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: showContent ? 20 : 20))
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .notchPanelToggled)) { note in
            let expanded = note.object as? Bool ?? false
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                showContent = expanded
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("Search clips…", text: $store.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !store.searchQuery.isEmpty {
                    Button { store.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            Text("\(store.filteredClips.count)")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.tertiary)

            if !store.availableSourceApps.isEmpty {
                Menu {
                    Button("All Apps") { store.selectedSourceApp = nil }
                    Divider()
                    ForEach(store.availableSourceApps, id: \.self) { app in
                        Button(app) { store.selectedSourceApp = app }
                    }
                } label: {
                    Image(systemName: "app.badge")
                        .font(.system(size: 14))
                        .foregroundStyle(store.selectedSourceApp != nil ? Color.accentColor : .secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Button(role: .destructive) { store.clearAll() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear all clips")

            Button { store.isIncognito.toggle() } label: {
                Image(systemName: store.isIncognito ? "eye.slash.fill" : "eye")
                    .font(.system(size: 14))
                    .foregroundStyle(store.isIncognito ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(store.isIncognito ? "Incognito on" : "Enable incognito")

            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "power")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit Clipr")
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Type filter chips

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                NotchTypeChip(label: "All", count: store.clips.count,
                              isSelected: store.selectedContentType == nil) {
                    store.selectedContentType = nil
                }
                ForEach(ContentType.allCases) { type in
                    let count = store.clips.filter { $0.contentType == type }.count
                    if count > 0 {
                        NotchTypeChip(label: type.displayName, count: count,
                                      isSelected: store.selectedContentType == type) {
                            store.selectedContentType =
                                store.selectedContentType == type ? nil : type
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Clip grid

    private var clipGrid: some View {
        Group {
            if store.filteredClips.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: store.isIncognito ? "eye.slash" : "doc.on.clipboard")
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)
                    Text(store.isIncognito ? "Capture paused" : "Nothing copied yet")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(store.isIncognito
                         ? "Toggle incognito off to resume."
                         : "Copy anything and it will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.filteredClips) { clip in
                            ClipCardView(clip: clip)
                                .environmentObject(store)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let notchPanelToggled    = Notification.Name("clipr.notchPanelToggled")
    static let cliprIncognitoChanged = Notification.Name("clipr.incognitoChanged")
}

// MARK: - Type chip

private struct NotchTypeChip: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : Color.white.opacity(0.08))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
