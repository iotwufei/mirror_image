import QuartzCore
import CoreGraphics
import AppKit

final class ImageLayerController {
    func loadImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldAllowFloat: true,
        ]
        return CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
    }

    func createLayer(with image: CGImage, frame targetFrame: CGRect) -> CALayer {
        let layer = CALayer()
        layer.contents = image
        layer.contentsGravity = .resizeAspectFill
        layer.masksToBounds = true
        layer.frame = targetFrame
        layer.edgeAntialiasingMask = [.layerLeftEdge, .layerRightEdge, .layerTopEdge, .layerBottomEdge]
        return layer
    }

    func createModalLayer(for image: CGImage, frame targetFrame: CGRect) -> CATiledLayer {
        let layer = CATiledLayer()
        layer.contents = image
        layer.contentsGravity = .resizeAspect
        layer.masksToBounds = true
        layer.frame = targetFrame
        layer.tileSize = CGSize(width: 512, height: 512)
        layer.levelsOfDetail = 4
        layer.levelsOfDetailBias = 2
        layer.edgeAntialiasingMask = [.layerLeftEdge, .layerRightEdge, .layerTopEdge, .layerBottomEdge]
        return layer
    }

    func cleanupLayer(_ layer: CALayer) {
        layer.contents = nil
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }
}
