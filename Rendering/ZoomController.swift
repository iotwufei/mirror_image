import CoreGraphics
import QuartzCore

final class ZoomController {
    var globalScale: CGFloat = 1.0
    var perLayerScale: [Int: CGFloat] = [:]
    var globalPan: CGPoint = .zero
    var perLayerPan: [Int: CGPoint] = [:]

    private let minZoom: CGFloat = 0.1
    private let maxZoom: CGFloat = 50.0

    func zoom(factor: CGFloat) {
        let oldScale = globalScale
        globalScale = max(minZoom, min(maxZoom, globalScale * factor))
        guard oldScale > 0 else { return }
        let ratio = globalScale / oldScale
        for key in perLayerScale.keys {
            if let current = perLayerScale[key] {
                perLayerScale[key] = max(minZoom, min(maxZoom, current * ratio))
            }
        }
    }

    func zoom(at layerIndex: Int, factor: CGFloat) {
        let current = perLayerScale[layerIndex] ?? globalScale
        perLayerScale[layerIndex] = max(minZoom, min(maxZoom, current * factor))
    }

    func scale(for layerIndex: Int) -> CGFloat {
        perLayerScale[layerIndex] ?? globalScale
    }

    func pan(by delta: CGPoint) {
        globalPan.x += delta.x
        globalPan.y += delta.y
    }

    func totalPan(for layerIndex: Int) -> CGPoint {
        let per = perLayerPan[layerIndex] ?? .zero
        return CGPoint(x: globalPan.x + per.x, y: globalPan.y + per.y)
    }

    func reset() {
        globalScale = 1.0
        perLayerScale = [:]
        globalPan = .zero
        perLayerPan = [:]
    }
}
