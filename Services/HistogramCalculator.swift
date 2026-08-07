import Foundation
import CoreImage
import CoreGraphics
import Accelerate
import AVFoundation

actor HistogramCalculator {
    private var cachedResults: [UUID: HistogramData] = [:]
    private let maxCachedResults = 50
    private lazy var ciContext = CIContext()

    struct HistogramData: Sendable {
        let luminance: [Float]
        let red: [Float]
        let green: [Float]
        let blue: [Float]
        let binCount: Int
    }

    func calculate(for image: CGImage) async -> HistogramData {
        let ciImage = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIAreaHistogram") else {
            return HistogramData(luminance: [], red: [], green: [], blue: [], binCount: 256)
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: ciImage.extent), forKey: kCIInputExtentKey)
        filter.setValue(256, forKey: "inputCount")
        filter.setValue(1.0, forKey: "inputScale")
        guard let output = filter.outputImage else {
            return HistogramData(luminance: [], red: [], green: [], blue: [], binCount: 256)
        }

        var histogramData = [Float](repeating: 0, count: 256 * 4)
        histogramData.withUnsafeMutableBytes { buffer in
            ciContext.render(
                output,
                toBitmap: buffer.baseAddress!,
                rowBytes: 256 * 4 * MemoryLayout<Float>.size,
                bounds: CGRect(x: 0, y: 0, width: 256, height: 1),
                format: .RGBAf,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
        }

        var maxValue: Float = 0
        for i in 0..<256 {
            maxValue = max(
                maxValue,
                histogramData[i * 4],
                histogramData[i * 4 + 1],
                histogramData[i * 4 + 2]
            )
        }

        guard maxValue > 0 else {
            return HistogramData(luminance: [], red: [], green: [], blue: [], binCount: 256)
        }

        let red = (0..<256).map { histogramData[$0 * 4] / maxValue }
        let green = (0..<256).map { histogramData[$0 * 4 + 1] / maxValue }
        let blue = (0..<256).map { histogramData[$0 * 4 + 2] / maxValue }

        let luminance = (0..<256).map { i -> Float in
            return 0.2126 * red[i] + 0.7152 * green[i] + 0.0722 * blue[i]
        }

        return HistogramData(luminance: luminance, red: red, green: green, blue: blue, binCount: 256)
    }

    func calculate(from pixelBuffer: CVPixelBuffer) async -> HistogramData {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return HistogramData(luminance: [], red: [], green: [], blue: [], binCount: 256)
        }
        return await calculate(for: cgImage)
    }

    func updateVideoHistogram(for id: UUID, using playerItem: AVPlayerItem?) async -> HistogramData? {
        guard let playerItem = playerItem else { return nil }
        guard let output = playerItem.outputs.compactMap({ $0 as? AVPlayerItemVideoOutput }).first else { return nil }

        let itemTime = playerItem.currentTime()
        guard output.hasNewPixelBuffer(forItemTime: itemTime) else { return nil }

        guard let buffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) else { return nil }

        let data = await calculate(from: buffer)
        if cachedResults.count >= maxCachedResults {
            let firstKey = cachedResults.keys.first!
            cachedResults.removeValue(forKey: firstKey)
        }
        cachedResults[id] = data
        return data
    }
}
