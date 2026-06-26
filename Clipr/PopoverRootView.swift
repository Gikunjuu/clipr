import SwiftUI
import AppKit

struct PopoverRootView: View {
    @EnvironmentObject var store: ClipStore
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            typeFilterBar
            Divider().opacity(0.3)
            clipGrid
        }
        .frame(width: 860, height: 560)
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            // Search
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

            // Clip count
            Text("\(store.filteredClips.count)")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.tertiary)

            // Source app picker
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
                .help("Filter by app")
            }

            // Incognito toggle
            Button {
                store.isIncognito.toggle()
            } label: {
                Image(systemName: store.isIncognito ? "eye.slash.fill" : "eye")
                    .font(.system(size: 14))
                    .foregroundStyle(store.isIncognito ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(store.isIncognito ? "Incognito on — tap to resume capture" : "Enable incognito")

            // New note
            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("New note clip")
            .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                NoteInputView(text: .constant("")) { text in
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        store.createNote(text: text)
                    }
                    showSettings = false
                }
            }

            // Quit
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit Clipr")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Type filter bar

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TypeChip(label: "All", count: store.clips.count,
                         isSelected: store.selectedContentType == nil) {
                    store.selectedContentType = nil
                }
                ForEach(ContentType.allCases) { type in
                    let count = store.clips.filter { $0.contentType == type }.count
                    if count > 0 {
                        TypeChip(label: type.displayName, count: count,
                                 isSelected: store.selectedContentType == type) {
                            store.selectedContentType =
                                store.selectedContentType == type ? nil : type
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Grid

    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 230), spacing: 16)]

    private var clipGrid: some View {
        Group {
            if store.filteredClips.isEmpty {
                emptyState
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: store.isIncognito ? "eye.slash" : "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(store.isIncognito ? "Capture paused" : "Nothing copied yet")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text(store.isIncognito
                 ? "Toggle incognito off to resume capture."
                 : "Copy anything and it will appear here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - TypeChip with count badge

struct TypeChip: View {
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

// MARK: - Inline NoteInputView used in popover

private struct NoteInputView: View {
    @Binding var text: String
    @State private var draft = ""
    let onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New note").font(.headline)
            TextEditor(text: $draft)
                .font(.system(size: 13))
                .frame(width: 280, height: 100)
                .border(Color(NSColor.separatorColor))
            HStack {
                Spacer()
                Button("Save") { onSave(draft) }
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(14)
    }
}
