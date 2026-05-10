import AppKit
import QuartzCore
import AVFoundation

final class ComparisonView: NSView {
    private var clipLayers: [CALayer] = []
    private var imageLayers: [CALayer] = []
    private var videoLayers: [AVPlayerLayer] = []
    private var histogramOverlays: [HistogramOverlay] = []
    private var currentGroup: ComparisonGroup?
    private let layoutEngine = LayoutEngine()
    private let zoomController = ZoomController()
    private let imageController = ImageLayerController()
    private var isDragging = false
    private var lastDragPoint: CGPoint = .zero
    private var dragLayerIndex: Int? = nil
    private var showHistograms: Bool = false
    private var pendingImages: [(CGImage, CGSize)] = []

    var onGroupNavigation: ((Bool) -> Void)?
    var onToggleHistogram: (() -> Void)?
    var onToggleLayerVisibility: ((Int) -> Void)?
    var onExit: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .black
        setupGestureRecognizers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(self)
        }
    }

    func loadGroup(_ group: ComparisonGroup) {
        clearAllLayers()
        currentGroup = group
        pendingImages = []
        dragLayerIndex = nil
        zoomController.reset()
        needsLayout = true
    }

    func clearAllLayers() {
        imageLayers.forEach {
            $0.contents = nil
            $0.removeFromSuperlayer()
        }
        imageLayers.removeAll()
        clipLayers.forEach { $0.removeFromSuperlayer() }
        clipLayers.removeAll()
        videoLayers.forEach {
            $0.player?.pause()
            $0.player = nil
            $0.removeFromSuperlayer()
        }
        videoLayers.removeAll()
        histogramOverlays.forEach { $0.removeFromSuperlayer() }
        histogramOverlays.removeAll()
    }

    func toggleHistograms() {
        showHistograms.toggle()
        for overlay in histogramOverlays {
            overlay.isHidden = !showHistograms
        }
    }

    func updateHistogram(at index: Int, with image: CGImage) {
        guard index < histogramOverlays.count else { return }
        histogramOverlays[index].update(with: image)
    }

    func updateHistogram(at index: Int, with pixelBuffer: CVPixelBuffer) {
        guard index < histogramOverlays.count else { return }
        histogramOverlays[index].update(with: pixelBuffer)
    }

    func applyImageLayout(images: [(CGImage, CGSize)]) {
        pendingImages = images
        relayoutLayers()
    }

    private func relayoutLayers() {
        guard !pendingImages.isEmpty else { return }

        let parentBounds = bounds
        guard parentBounds.width > 0, parentBounds.height > 0 else { return }

        let count = pendingImages.count
        let frames = layoutEngine.frames(for: count, in: parentBounds)

        clipLayers.forEach { $0.removeFromSuperlayer() }
        clipLayers.removeAll()
        imageLayers.forEach { $0.removeFromSuperlayer() }
        imageLayers.removeAll()
        histogramOverlays.forEach { $0.removeFromSuperlayer() }
        histogramOverlays.removeAll()

        for (index, (image, _)) in pendingImages.enumerated() {
            guard index < frames.count else { break }
            let clipFrame = frames[index]

            let clipLayer = CALayer()
            clipLayer.frame = clipFrame
            clipLayer.masksToBounds = true
            clipLayer.backgroundColor = nil
            self.layer?.addSublayer(clipLayer)
            clipLayers.append(clipLayer)

            let imageLayer = imageController.createLayer(
                with: image,
                frame: clipLayer.bounds
            )
            clipLayer.addSublayer(imageLayer)
            imageLayers.append(imageLayer)

            let histogram = HistogramOverlay()
            histogram.updateSize(basedOn: clipLayer.bounds.size)
            histogram.isHidden = !showHistograms
            histogram.update(with: image)
            clipLayer.addSublayer(histogram)
            histogramOverlays.append(histogram)
        }
    }

    override func layout() {
        super.layout()
        relayoutLayers()
        applyLayerTransforms()
    }

    func applyZoom(layerIndex: Int? = nil, factor: CGFloat? = nil) {
        zoomController.zoom(factor: factor ?? 1.0)
        applyLayerTransforms()
    }

    private func applyLayerTransforms() {
        for (index, layer) in imageLayers.enumerated() {
            guard index < clipLayers.count else { continue }
            let zoom = zoomController.scale(for: index)
            var pan = zoomController.totalPan(for: index)

            if zoom <= 1.0 {
                pan = .zero
            } else {
                let clipSize = clipLayers[index].bounds.size
                let excessW = clipSize.width * (zoom - 1) / 2
                let excessH = clipSize.height * (zoom - 1) / 2
                pan.x = max(-excessW, min(excessW, pan.x))
                pan.y = max(-excessH, min(excessH, pan.y))
            }

            var transform = CATransform3DIdentity
            transform = CATransform3DTranslate(transform, pan.x / zoom, pan.y / zoom, 0)
            transform = CATransform3DScale(transform, zoom, zoom, 1)
            layer.transform = transform
        }
        for layer in videoLayers {
            let zoom = zoomController.globalScale
            let pan = zoomController.globalPan
            var transform = CATransform3DIdentity
            transform = CATransform3DTranslate(transform, pan.x / zoom, pan.y / zoom, 0)
            transform = CATransform3DScale(transform, zoom, zoom, 1)
            layer.transform = transform
        }
    }

    func resetZoom() {
        zoomController.reset()
        let identity = CATransform3DIdentity
        imageLayers.forEach { $0.transform = identity }
        videoLayers.forEach { $0.transform = identity }
    }

    func setLayerVisibility(_ visible: Bool, at index: Int) {
        guard index < clipLayers.count else { return }
        clipLayers[index].isHidden = !visible
    }

    override var isFlipped: Bool { true }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        needsLayout = true
    }

    private func setupGestureRecognizers() {
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        addGestureRecognizer(clickGesture)
    }

    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            isDragging = true
            lastDragPoint = gesture.location(in: self)
            let isCmd = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
            if isCmd {
                for (index, layer) in clipLayers.enumerated() {
                    if layer.frame.contains(lastDragPoint) {
                        dragLayerIndex = index
                        break
                    }
                }
            }
        case .changed:
            let current = gesture.location(in: self)
            let delta = CGPoint(x: current.x - lastDragPoint.x, y: current.y - lastDragPoint.y)
            if let index = dragLayerIndex {
                var pan = zoomController.perLayerPan[index] ?? .zero
                pan.x += delta.x
                pan.y += delta.y
                zoomController.perLayerPan[index] = pan
            } else {
                zoomController.pan(by: delta)
            }
            applyLayerTransforms()
            lastDragPoint = current
        case .ended:
            isDragging = false
            dragLayerIndex = nil
        default:
            break
        }
    }

    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        let point = gesture.location(in: self)
        for (index, layer) in videoLayers.enumerated() {
            if layer.frame.contains(point) {
                onToggleLayerVisibility?(index)
                return
            }
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let factor: CGFloat = 1.0 + event.scrollingDeltaY / 500.0
        let mousePoint = convert(event.locationInWindow, from: nil)

        if event.modifierFlags.contains(.command) {
            for (index, layer) in clipLayers.enumerated() {
                if layer.frame.contains(mousePoint) {
                    let prevZoom = zoomController.scale(for: index)
                    zoomController.zoom(at: index, factor: factor)
                    let newZoom = zoomController.scale(for: index)
                    guard prevZoom > 0 else { continue }
                    let scaleDelta = newZoom / prevZoom

                    var perPan = zoomController.perLayerPan[index] ?? .zero
                    let cx = layer.frame.midX - mousePoint.x
                    let cy = layer.frame.midY - mousePoint.y
                    perPan.x += cx * (1 - scaleDelta)
                    perPan.y += cy * (1 - scaleDelta)
                    zoomController.perLayerPan[index] = perPan

                    applyLayerTransforms()
                    return
                }
            }
        } else {
            applyZoom(factor: factor)
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 49:
            onGroupNavigation?(true)

        case 11:
            onGroupNavigation?(false)

        case 4:
            onToggleHistogram?()

        case 18...29:
            let index = Int(event.keyCode) - 18
            onToggleLayerVisibility?(index)

        case 53:
            onExit?()

        default:
            super.keyDown(with: event)
        }
    }
}
