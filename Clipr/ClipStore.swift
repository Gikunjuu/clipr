import Foundation
import Combine
import AppKit
import GRDB

class ClipStore: ObservableObject {
    static let shared = ClipStore()

    @Published var clips: [ClipItem] = []
    @Published var isIncognito: Bool = false {
        didSet {
            NotificationCenter.default.post(name: .cliprIncognitoChanged, object: nil)
            SoundManager.shared.play(isIncognito ? .incognitoOn : .incognitoOff)
        }
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
                self.backfillContentHashes(db: db)
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

    private func backfillContentHashes(db: DatabaseQueue) {
        do {
            let unhashedRows = try db.read { db in
                try ClipItem.filter(Column("contentHash") == nil).fetchAll(db)
            }
            guard !unhashedRows.isEmpty else { return }
            try db.write { db in
                for clip in unhashedRows {
                    let hash: String?
                    if let text = clip.textContent {
                        hash = ClipItem.hash(text: text)
                    } else if let data = clip.rtfData {
                        hash = ClipItem.hash(data: data)
                    } else if let filename = clip.imageFilename,
                              let data = FileStore.shared.loadImageData(filename: filename) {
                        hash = ClipItem.hash(data: data)
                    } else {
                        hash = nil
                    }
                    guard let h = hash else { continue }
                    // If another row already has this hash, keep the newer row and delete this one
                    if let existing = try ClipItem
                        .filter(Column("contentHash") == h)
                        .fetchOne(db) {
                        if existing.id != clip.id {
                            try db.execute(
                                sql: "UPDATE clips SET copyCount = copyCount + ?, createdAt = MAX(createdAt, ?) WHERE id = ?",
                                arguments: [clip.copyCount, clip.createdAt, existing.id]
                            )
                            try clip.delete(db)
                        }
                    } else {
                        try db.execute(
                            sql: "UPDATE clips SET contentHash = ?, firstCopiedAt = COALESCE(firstCopiedAt, createdAt) WHERE id = ?",
                            arguments: [h, clip.id]
                        )
                    }
                }
            }
            print("ClipStore: backfilled contentHash for \(unhashedRows.count) legacy rows")
        } catch {
            print("ClipStore: backfillContentHashes failed — \(error)")
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
                SoundManager.shared.play(.clipPinned)
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

    /// Called when an exact duplicate is detected. Bumps copy_count, updates createdAt,
    /// and moves the card to the top of the grid. Returns true if a duplicate was found.
    func promoteDuplicate(hash: String) -> Bool {
        guard let db = DatabaseManager.shared.dbQueue else { return false }
        var found = false
        DispatchQueue.global(qos: .userInitiated).sync {
            do {
                try db.write { db in
                    if let existing = try ClipItem
                        .filter(Column("contentHash") == hash)
                        .fetchOne(db) {
                        found = true
                        try db.execute(
                            sql: """
                                UPDATE clips
                                SET copyCount = copyCount + 1,
                                    createdAt = ?
                                WHERE id = ?
                                """,
                            arguments: [Date(), existing.id]
                        )
                        DispatchQueue.main.async {
                            if let idx = self.clips.firstIndex(where: { $0.id == existing.id }) {
                                var updated = self.clips.remove(at: idx)
                                updated.copyCount += 1
                                updated.createdAt  = Date()
                                // Insert at top (after pinned items)
                                let insertAt = self.clips.firstIndex(where: { !$0.isPinned }) ?? 0
                                self.clips.insert(updated, at: insertAt)
                            }
                        }
                    }
                }
            } catch {
                print("ClipStore: promoteDuplicate failed — \(error)")
            }
        }
        return found
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
