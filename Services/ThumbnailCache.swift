import Foundation
import CoreGraphics
import CryptoKit
import ImageIO

final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let memoryCache = NSCache<NSString, CGImageWrapper>()
    private let maxL2SizeInBytes: Int = 500 * 1024 * 1024
    private let l2CacheDirectory: URL
    private let fileManager = FileManager.default
    private let lock = NSLock()

    final class CGImageWrapper {
        let image: CGImage
        let size: Int

        init(image: CGImage) {
            self.image = image
            self.size = image.width * image.height * 4
        }
    }

    private init() {
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50 * 1024 * 1024

        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        l2CacheDirectory = cachesDir.appendingPathComponent("com.mirrorimage.thumbnails", isDirectory: true)

        try? fileManager.createDirectory(at: l2CacheDirectory, withIntermediateDirectories: true)

        purgeL2CacheIfNeeded()
    }

    func image(for id: UUID, cacheKey: String) -> CGImage? {
        let keyStr = id.uuidString + cacheKey

        if let wrapper = memoryCache.object(forKey: keyStr as NSString) {
            return wrapper.image
        }

        guard let image = loadFromDisk(key: keyStr) else { return nil }

        let wrapper = CGImageWrapper(image: image)
        memoryCache.setObject(wrapper, forKey: keyStr as NSString, cost: wrapper.size)
        return image
    }

    func store(_ image: CGImage, for id: UUID, cacheKey: String) {
        let keyStr = id.uuidString + cacheKey
        let wrapper = CGImageWrapper(image: image)
        memoryCache.setObject(wrapper, forKey: keyStr as NSString, cost: wrapper.size)
        saveToDisk(image: image, key: keyStr)
    }

    func remove(for id: UUID, cacheKey: String) {
        let keyStr = id.uuidString + cacheKey
        memoryCache.removeObject(forKey: keyStr as NSString)
        removeFromDisk(key: keyStr)
    }

    func clearAll() {
        memoryCache.removeAllObjects()
        lock.lock()
        defer { lock.unlock() }
        try? fileManager.removeItem(at: l2CacheDirectory)
        try? fileManager.createDirectory(at: l2CacheDirectory, withIntermediateDirectories: true)
    }

    private func diskCacheURL(for key: String) -> URL {
        let hash = SHA256.hash(data: Data(key.utf8))
        let hexName = hash.compactMap { String(format: "%02x", $0) }.joined()
        return l2CacheDirectory.appendingPathComponent(hexName)
    }

    private func saveToDisk(image: CGImage, key: String) {
        lock.lock()
        defer { lock.unlock() }

        let url = diskCacheURL(for: key)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    private func loadFromDisk(key: String) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }

        let url = diskCacheURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)

        do {
            try fileManager.setAttributes(
                [.modificationDate: Date()],
                ofItemAtPath: url.path
            )
        } catch {}

        return image
    }

    private func removeFromDisk(key: String) {
        lock.lock()
        defer { lock.unlock() }
        let url = diskCacheURL(for: key)
        try? fileManager.removeItem(at: url)
    }

    private func purgeL2CacheIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: l2CacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: []
        ) else { return }

        let filesWithSize = contents.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = values.fileSize else { return nil }
            return (url, size, values.contentModificationDate ?? Date.distantPast)
        }

        let totalSize = filesWithSize.reduce(0) { $0 + $1.1 }
        if totalSize <= maxL2SizeInBytes { return }

        let sorted = filesWithSize.sorted { $0.2 < $1.2 }
        var bytesToRemove = totalSize - maxL2SizeInBytes
        for (url, size, _) in sorted {
            if bytesToRemove <= 0 { break }
            try? fileManager.removeItem(at: url)
            bytesToRemove -= size
        }
    }
}
