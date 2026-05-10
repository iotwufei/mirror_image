import QuartzCore
import CoreGraphics
import AppKit

final class HistogramOverlay: CALayer {
    private let histogramCalculator = HistogramCalculator()
    private var histogramData: HistogramCalculator.HistogramData?
    private var isVisible: Bool = true

    override init() {
        super.init()
        backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
        cornerRadius = 6
        masksToBounds = true
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateSize(basedOn parentSize: CGSize) {
        let width = parentSize.width * 0.4
        let height = parentSize.height * 0.2
        frame = CGRect(
            x: 8,
            y: 8,
            width: max(width, 100),
            height: max(height, 40)
        )
    }

    func update(with image: CGImage) {
        Task { @MainActor in
            let data = await histogramCalculator.calculate(for: image)
            self.histogramData = data
            self.setNeedsDisplay()
        }
    }

    func update(with pixelBuffer: CVPixelBuffer) {
        Task { @MainActor in
            let data = await histogramCalculator.calculate(from: pixelBuffer)
            self.histogramData = data
            self.setNeedsDisplay()
        }
    }

    override func draw(in ctx: CGContext) {
        super.draw(in: ctx)

        guard let data = histogramData, data.binCount > 0 else {
            drawEmptyState(in: ctx)
            return
        }

        drawHistogramBins(data, in: ctx)
    }

    private func drawEmptyState(in ctx: CGContext) {
        let text = "Loading..."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.white.withAlphaComponent(0.5)
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        let point = CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        string.draw(at: point)
    }

    private func drawHistogramBins(_ data: HistogramCalculator.HistogramData, in ctx: CGContext) {
        let padding: CGFloat = 8
        let graphRect = bounds.insetBy(dx: padding, dy: padding)
        let binWidth = graphRect.width / CGFloat(data.binCount)

        // Draw luminance as white fill with low alpha
        drawGraph(data.luminance, in: graphRect, binWidth: binWidth, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.3), ctx: ctx)

        // Draw color channel lines
        drawGraphLine(data.red, in: graphRect, binWidth: binWidth, color: CGColor(red: 1, green: 0.3, blue: 0.3, alpha: 0.8), ctx: ctx)
        drawGraphLine(data.green, in: graphRect, binWidth: binWidth, color: CGColor(red: 0.3, green: 1, blue: 0.3, alpha: 0.8), ctx: ctx)
        drawGraphLine(data.blue, in: graphRect, binWidth: binWidth, color: CGColor(red: 0.3, green: 0.3, blue: 1, alpha: 0.8), ctx: ctx)

        // Draw luminance line
        drawGraphLine(data.luminance, in: graphRect, binWidth: binWidth, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.9), ctx: ctx)

        // Border
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
        ctx.setLineWidth(0.5)
        ctx.stroke(graphRect)
    }

    private func drawGraph(_ values: [Float], in rect: CGRect, binWidth: CGFloat, color: CGColor, ctx: CGContext) {
        ctx.setFillColor(color)
        let count = values.count
        for i in 0..<count {
            let barHeight = rect.height * CGFloat(values[i])
            let x = rect.minX + binWidth * CGFloat(i)
            let y = rect.maxY - barHeight
            let bar = CGRect(x: x, y: y, width: max(binWidth, 0.5), height: barHeight)
            ctx.fill(bar)
        }
    }

    private func drawGraphLine(_ values: [Float], in rect: CGRect, binWidth: CGFloat, color: CGColor, ctx: CGContext) {
        ctx.setStrokeColor(color)
        ctx.setLineWidth(0.8)
        ctx.beginPath()

        let count = values.count
        for i in 0..<count {
            let x = rect.minX + binWidth * (CGFloat(i) + 0.5)
            let y = rect.maxY - rect.height * CGFloat(values[i])

            if i == 0 {
                ctx.move(to: CGPoint(x: x, y: y))
            } else {
                ctx.addLine(to: CGPoint(x: x, y: y))
            }
        }

        ctx.strokePath()
    }
}
