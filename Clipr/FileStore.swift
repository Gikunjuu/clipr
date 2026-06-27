import AppKit

class FileStore {
    static let shared = FileStore()
    private let imagesDir: URL

    private init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        imagesDir = appSupport.appendingPathComponent("Clipr/Images")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
    }

    func saveImage(_ image: NSImage) -> String? {
        guard let tiff   = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png    = bitmap.representation(using: .png, properties: [:]) else { return nil }
        let filename = UUID().uuidString + ".png"
        let url = imagesDir.appendingPathComponent(filename)
        do {
            try png.write(to: url)
            return filename
        } catch {
            return nil
        }
    }

    func loadImage(filename: String) -> NSImage? {
        let url = imagesDir.appendingPathComponent(filename)
        return NSImage(contentsOf: url)
    }

    func loadImageData(filename: String) -> Data? {
        let url = imagesDir.appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    func deleteImage(filename: String) {
        let url = imagesDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
