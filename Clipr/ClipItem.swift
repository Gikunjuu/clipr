import Foundation
import CryptoKit
import GRDB

enum ContentType: String, Codable, CaseIterable, Identifiable {
    case text      = "text"
    case richText  = "rich_text"
    case url       = "url"
    case image     = "image"
    case filePath  = "file_path"
    case code      = "code"
    case color     = "color"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text:     return "Text"
        case .richText: return "Rich Text"
        case .url:      return "Links"
        case .image:    return "Images"
        case .filePath: return "Files"
        case .code:     return "Code"
        case .color:    return "Colors"
        }
    }

    var systemImage: String {
        switch self {
        case .text:     return "doc.text"
        case .richText: return "doc.richtext"
        case .url:      return "link"
        case .image:    return "photo"
        case .filePath: return "folder"
        case .code:     return "chevron.left.forwardslash.chevron.right"
        case .color:    return "paintpalette"
        }
    }
}

struct ClipItem: Identifiable, Codable, FetchableRecord, PersistableRecord {
    var id: String
    var contentType: ContentType
    var textContent: String?
    var rtfData: Data?
    var imageFilename: String?
    var filePath: String?
    var colorHex: String?
    var sourceApp: String?
    var sourceAppBundle: String?
    var createdAt: Date
    var isPinned: Bool
    var ocrText: String?
    var urlTitle: String?
    // Duplicate detection
    var contentHash: String?
    var copyCount: Int
    var firstCopiedAt: Date

    static let databaseTableName = "clips"

    enum CodingKeys: String, CodingKey {
        case id, contentType, textContent, rtfData, imageFilename
        case filePath, colorHex, sourceApp, sourceAppBundle
        case createdAt, isPinned, ocrText, urlTitle
        case contentHash, copyCount, firstCopiedAt
    }

    init(
        id: String = UUID().uuidString,
        contentType: ContentType,
        textContent: String? = nil,
        rtfData: Data? = nil,
        imageFilename: String? = nil,
        filePath: String? = nil,
        colorHex: String? = nil,
        sourceApp: String? = nil,
        sourceAppBundle: String? = nil,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        ocrText: String? = nil,
        urlTitle: String? = nil,
        contentHash: String? = nil,
        copyCount: Int = 1,
        firstCopiedAt: Date = Date()
    ) {
        self.id            = id
        self.contentType   = contentType
        self.textContent   = textContent
        self.rtfData       = rtfData
        self.imageFilename = imageFilename
        self.filePath      = filePath
        self.colorHex      = colorHex
        self.sourceApp     = sourceApp
        self.sourceAppBundle = sourceAppBundle
        self.createdAt     = createdAt
        self.isPinned      = isPinned
        self.ocrText       = ocrText
        self.urlTitle      = urlTitle
        self.contentHash   = contentHash
        self.copyCount     = copyCount
        self.firstCopiedAt = firstCopiedAt
    }
}

// MARK: - Content hashing

extension ClipItem {
    /// SHA-256 of normalised text content (trimmed, NFC Unicode).
    static func hash(text: String) -> String {
        let normalised = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping   // NFC
        let data = Data(normalised.utf8)
        return SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    /// SHA-256 of raw data (for images, files).
    static func hash(data: Data) -> String {
        SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
