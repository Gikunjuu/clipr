import Foundation
import GRDB

class DatabaseManager {
    static let shared = DatabaseManager()
    private(set) var dbQueue: DatabaseQueue?

    private init() {}

    func setup() {
        do {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let cliprDir = appSupport.appendingPathComponent("Clipr")
            try FileManager.default.createDirectory(at: cliprDir, withIntermediateDirectories: true)
            let dbURL = cliprDir.appendingPathComponent("clips.db")
            var config = Configuration()
            config.qos = .userInitiated
            dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)
            try migrate()
        } catch {
            fatalError("Clipr: database setup failed — \(error)")
        }
    }

    private func migrate() throws {
        guard let db = dbQueue else { return }
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "clips") { t in
                t.column("id", .text).primaryKey()
                t.column("contentType", .text).notNull()
                t.column("textContent", .text)
                t.column("rtfData", .blob)
                t.column("imageFilename", .text)
                t.column("filePath", .text)
                t.column("colorHex", .text)
                t.column("sourceApp", .text)
                t.column("sourceAppBundle", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("isPinned", .boolean).notNull().defaults(to: false)
                t.column("ocrText", .text)
                t.column("urlTitle", .text)
            }
            try db.create(index: "clips_createdAt",    on: "clips", columns: ["createdAt"])
            try db.create(index: "clips_contentType",  on: "clips", columns: ["contentType"])
            try db.create(index: "clips_isPinned",     on: "clips", columns: ["isPinned"])
        }

        try migrator.migrate(db)
    }
}
