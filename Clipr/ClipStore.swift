import Foundation
import Combine
import AppKit
import GRDB

class ClipStore: ObservableObject {
    static let shared = ClipStore()

    @Published var clips: [ClipItem] = []
    @Published var isIncognito: Bool = false {
        didSet { NotificationCenter.default.post(name: .cliprIncognitoChanged, object: nil) }
    }
    @Published var searchQuery: String = ""
    @Published var selectedContentType: ContentType? = nil
    @Published var selectedSourceApp: String? = nil

    var filteredClips: [ClipItem] {
        var result = clips
        if let type = selectedContentType {
            result = result.filter { $0.contentType == type }
        }
        if let app = selectedSourceApp {
            result = result.filter { $0.sourceApp == app }
        }
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.textContent?.lowercased().contains(q) == true  ||
                $0.ocrText?.lowercased().contains(q)    == true  ||
                $0.urlTitle?.lowercased().contains(q)   == true  ||
                $0.filePath?.lowercased().contains(q)   == true
            }
        }
        return result
    }

    var availableSourceApps: [String] {
        Array(Set(clips.compactMap { $0.sourceApp })).sorted()
    }

    private init() {}

    // MARK: - Load

    func loadClips() {
        guard let db = DatabaseManager.shared.dbQueue else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let loaded = try db.read { db in
                    try ClipItem
                        .order(Column("isPinned").desc, Column("createdAt").desc)
                        .fetchAll(db)
                }
                DispatchQueue.main.async { self.clips = loaded }
            } catch {
                print("ClipStore: loadClips failed — \(error)")
            }
        }
    }

    // MARK: - Write

    func saveClip(_ clip: ClipItem) {
        guard let db = DatabaseManager.shared.dbQueue else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try db.write { db in try clip.save(db) }
                DispatchQueue.main.async {
                    // Insert after pinned clips so the list stays pinned-first
                    let insertAt = self.clips.firstIndex(where: { !$0.isPinned }) ?? 0
                    self.clips.insert(clip, at: insertAt)
                }
            } catch {
                print("ClipStore: saveClip failed — \(error)")
            }
        }
    }

    func clearAll() {
        guard let db = DatabaseManager.shared.dbQueue else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let imageFiles = self.clips.compactMap { $0.imageFilename }
                try db.write { db in try db.execute(sql: "DELETE FROM clips") }
                imageFiles.forEach { FileStore.shared.deleteImage(filename: $0) }
                NSPasteboard.general.clearContents()
                DispatchQueue.main.async { self.clips = [] }
            } catch {
                print("ClipStore: clearAll failed — \(error)")
            }
        }
    }

    func deleteClip(_ clip: ClipItem) {
        guard let db = DatabaseManager.shared.dbQueue else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try db.write { db in try clip.delete(db) }
                if let f = clip.imageFilename { FileStore.shared.deleteImage(filename: f) }
                DispatchQueue.main.async {
                    self.clips.removeAll { $0.id == clip.id }
                }
            } catch {
                print("ClipStore: deleteClip failed — \(error)")
            }
        }
    }

    func togglePin(_ clip: ClipItem) {
        var updated = clip
        updated.isPinned.toggle()
        guard let db = DatabaseManager.shared.dbQueue else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try db.write { db in try updated.save(db) }
                DispatchQueue.main.async {
                    if let idx = self.clips.firstIndex(where: { $0.id == clip.id }) {
                        self.clips[idx] = updated
                        self.clips.sort {
                            if $0.isPinned != $1.isPinned { return $0.isPinned }
                            return $0.createdAt > $1.createdAt
                        }
                    }
                }
            } catch {
                print("ClipStore: togglePin failed — \(error)")
            }
        }
    }

    func updateOCRText(clipId: String, ocrText: String) {
        guard let db = DatabaseManager.shared.dbQueue else { return }
        DispatchQueue.global(qos: .background).async {
            do {
                try db.write { db in
                    try db.execute(
                        sql: "UPDATE clips SET ocrText = ? WHERE id = ?",
                        arguments: [ocrText, clipId]
                    )
                }
                DispatchQueue.main.async {
                    if let idx = self.clips.firstIndex(where: { $0.id == clipId }) {
                        self.clips[idx].ocrText = ocrText
                    }
                }
            } catch {
                print("ClipStore: updateOCRText failed — \(error)")
            }
        }
    }

    // Called from MainGridView "New Note" button
    func createNote(text: String) {
        let clip = ClipItem(contentType: .text, textContent: text)
        saveClip(clip)
    }
}
