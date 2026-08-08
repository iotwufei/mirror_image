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
        // Downsample before analysis so huge photos don't blow up memory or
        // take forever; 1024px is far beyond histogram resolution anyway.
        let maxDimension: CGFloat = 1024
        let scale = min(1.0, maxDimension / CGFloat(max(image.width, image.height)))
        let width = max(1, Int(CGFloat(image.width) * scale))
        let height = max(1, Int(CGFloat(image.height) * scale))

        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return HistogramData(luminance: [], red: [], green: [], blue: [], binCount: 256)
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // premultipliedLast + byteOrder32Big yields R,G,B,A byte order.
        var redBins = [Int](repeating: 0, count: 256)
        var greenBins = [Int](repeating: 0, count: 256)
        var blueBins = [Int](repeating: 0, count: 256)

        var offset = 0
        while offset < pixelData.count {
            redBins[Int(pixelData[offset])] += 1
            greenBins[Int(pixelData[offset + 1])] += 1
            blueBins[Int(pixelData[offset + 2])] += 1
            offset += 4
        }

        let maxValue = max(redBins.max() ?? 1, greenBins.max() ?? 1, blueBins.max() ?? 1)

        guard maxValue > 0 else {
            return HistogramData(luminance: [], red: [], green: [], blue: [], binCount: 256)
        }

        let red = redBins.map { Float($0) / Float(maxValue) }
        let green = greenBins.map { Float($0) / Float(maxValue) }
        let blue = blueBins.map { Float($0) / Float(maxValue) }

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
