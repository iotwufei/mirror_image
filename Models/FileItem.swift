import Foundation
import CoreGraphics
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let path: String
    let fileSize: Int64
    let modificationDate: Date
    let mediaType: MediaType
    let dimensions: CGSize?
    let duration: TimeInterval?

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.path = url.path
        self.mediaType = FileItem.resolveMediaType(from: url)

        let resourceValues = (try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])) ?? URLResourceValues()
        self.fileSize = Int64(resourceValues.fileSize ?? 0)
        self.modificationDate = resourceValues.contentModificationDate ?? Date.distantPast
        self.dimensions = nil
        self.duration = nil
    }

    init(url: URL, dimensions: CGSize?, duration: TimeInterval?) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.path = url.path
        self.mediaType = FileItem.resolveMediaType(from: url)

        let resourceValues = (try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])) ?? URLResourceValues()
        self.fileSize = Int64(resourceValues.fileSize ?? 0)
        self.modificationDate = resourceValues.contentModificationDate ?? Date.distantPast
        self.dimensions = dimensions
        self.duration = duration
    }

    private static func resolveMediaType(from url: URL) -> MediaType {
        let ext = url.pathExtension.lowercased()
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "tif", "cr2", "nef", "arw", "psd", "gif", "bmp"]
        let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]

        if videoExtensions.contains(ext) {
            return .video
        }
        if imageExtensions.contains(ext) {
            return .image
        }
        return .unknown
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var cacheKey: String {
        "\(path):\(Int(modificationDate.timeIntervalSince1970))"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}
