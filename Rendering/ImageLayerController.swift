import QuartzCore
import CoreGraphics
import AppKit

final class ImageLayerController {
    /// Decodes a downsampled preview so large images don't block the main
    /// thread or exhaust memory during comparison.
    func loadPreviewImage(from url: URL, maxPixelSize: CGFloat = 2048) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    func createLayer(with image: CGImage, frame targetFrame: CGRect) -> CALayer {
        let layer = CALayer()
        layer.contents = image
        layer.contentsGravity = .resizeAspect
        layer.masksToBounds = true
        layer.frame = targetFrame
        layer.edgeAntialiasingMask = [.layerLeftEdge, .layerRightEdge, .layerTopEdge, .layerBottomEdge]
        return layer
    }
}
