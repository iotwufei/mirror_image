import Foundation
import CoreGraphics
import AVFoundation
import ImageIO

actor MediaMetadataProvider {

    func extractMetadata(for url: URL) async -> (dimensions: CGSize?, duration: TimeInterval?, cameraModel: String?) {
        let ext = url.pathExtension.lowercased()
        let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]

        if videoExtensions.contains(ext) {
            return await extractVideoMetadata(for: url)
        } else {
            return await extractImageMetadata(for: url)
        }
    }

    private func extractImageMetadata(for url: URL) async -> (CGSize?, TimeInterval?, String?) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return (nil, nil, nil)
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return (nil, nil, nil)
        }

        let width = properties[kCGImagePropertyPixelWidth] as? Int
        let height = properties[kCGImagePropertyPixelHeight] as? Int
        let dimensions: CGSize? = (width != nil && height != nil) ? CGSize(width: width!, height: height!) : nil

        var cameraModel: String? = nil
        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            let make = tiff[kCGImagePropertyTIFFMake] as? String
            let model = tiff[kCGImagePropertyTIFFModel] as? String
            if let make, let model {
                cameraModel = model.hasPrefix(make) ? model : "\(make) \(model)"
            } else {
                cameraModel = model ?? make
            }
        }

        return (dimensions, nil, cameraModel)
    }

    private func extractVideoMetadata(for url: URL) async -> (CGSize?, TimeInterval?, String?) {
        let asset = AVAsset(url: url)

        guard let videoTrack = try? await asset.loadTracks(withMediaCharacteristic: .visual).first else {
            return (nil, nil, nil)
        }

        let duration = try? await asset.load(.duration)
        let naturalSize = try? await videoTrack.load(.naturalSize)

        let dimensions: CGSize? = naturalSize.map { CGSize(width: $0.width, height: $0.height) }
        let durationSeconds: TimeInterval? = duration.map { CMTimeGetSeconds($0) }

        return (dimensions, durationSeconds, nil)
    }

    func extractLivePhotoVideoURL(from heicURL: URL) -> URL? {
        guard heicURL.pathExtension.lowercased() == "heic" else { return nil }

        let movURL = heicURL.deletingPathExtension().appendingPathExtension("mov")
        if FileManager.default.fileExists(atPath: movURL.path) {
            return movURL
        }

        return nil
    }
}
