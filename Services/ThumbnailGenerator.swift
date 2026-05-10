import Foundation
import CoreGraphics
import ImageIO
import QuickLookThumbnailing
import CryptoKit

actor ThumbnailGenerator {
    private let maxConcurrentTasks = 4
    private var activeTasks: [UUID: Task<CGImage?, Error>] = [:]
    private var runningCount = 0
    private let cache = ThumbnailCache.shared

    func generate(for file: FileItem) async -> CGImage? {
        if let cached = cache.image(for: file.id, cacheKey: file.cacheKey) {
            return cached
        }

        if activeTasks[file.id] != nil {
            return try? await activeTasks[file.id]?.value
        }

        let task = Task<CGImage?, Error> {
            defer { runningCount -= 1 }

            let image = try await generateImage(for: file)
            if let cgImage = image {
                cache.store(cgImage, for: file.id, cacheKey: file.cacheKey)
            }
            return image
        }

        activeTasks[file.id] = task

        while runningCount >= maxConcurrentTasks {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        runningCount += 1

        let result = try? await task.value
        activeTasks[file.id] = nil
        return result
    }

    func cancel(for file: FileItem) {
        activeTasks[file.id]?.cancel()
        activeTasks[file.id] = nil
    }

    private func generateImage(for file: FileItem) async throws -> CGImage? {
        let ext = file.url.pathExtension.lowercased()
        let rawExtensions: Set<String> = ["cr2", "nef", "arw", "dng", "orf", "rw2"]

        if rawExtensions.contains(ext) {
            return try await generateRawPreview(for: file.url)
        }

        return try await generateSystemThumbnail(for: file.url)
    }

    private func generateSystemThumbnail(for url: URL) async throws -> CGImage? {
        let size = CGSize(width: 256, height: 256)
        let scale = 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        request.iconMode = false

        return try await withCheckedThrowingContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: thumbnail?.cgImage)
                }
            }
        }
    }

    private func generateRawPreview(for url: URL) async throws -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: 512,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
