import Foundation
import CoreImage
import CoreGraphics
import Accelerate
import AVFoundation

actor HistogramCalculator {
    private var cachedResults: [UUID: HistogramData] = [:]
    private let maxCachedResults = 50

    struct HistogramData: Sendable {
        let luminance: [Float]
        let red: [Float]
        let green: [Float]
        let blue: [Float]
        let binCount: Int
    }

    func calculate(for image: CGImage) async -> HistogramData {
        guard let format = vImage_CGImageFormat(cgImage: image),
              var sourceBuffer = try? vImage_Buffer(cgImage: image, format: format) else {
            return HistogramData(luminance: [], red: [], green: [], blue: [], binCount: 256)
        }
        defer { sourceBuffer.free() }

        var redBins = [vImagePixelCount](repeating: 0, count: 256)
        var greenBins = [vImagePixelCount](repeating: 0, count: 256)
        var blueBins = [vImagePixelCount](repeating: 0, count: 256)
        var alphaBins = [vImagePixelCount](repeating: 0, count: 256)

        var localError: vImage_Error = kvImageNoError
        redBins.withUnsafeMutableBufferPointer { rPtr in
            greenBins.withUnsafeMutableBufferPointer { gPtr in
                blueBins.withUnsafeMutableBufferPointer { bPtr in
                    alphaBins.withUnsafeMutableBufferPointer { aPtr in
                        var ptrs: [UnsafeMutablePointer<vImagePixelCount>?] = [
                            rPtr.baseAddress,
                            gPtr.baseAddress,
                            bPtr.baseAddress,
                            aPtr.baseAddress,
                        ]
                        localError = vImageHistogramCalculation_ARGB8888(
                            &sourceBuffer,
                            &ptrs,
                            vImage_Flags(kvImageNoFlags)
                        )
                    }
                }
            }
        }

        if localError != kvImageNoError {
            return HistogramData(luminance: [], red: [], green: [], blue: [], binCount: 256)
        }

        let maxR = redBins.max() ?? 1
        let maxG = greenBins.max() ?? 1
        let maxB = blueBins.max() ?? 1
        let maxValue: Float = Float(max(max(maxR, maxG), maxB))

        guard maxValue > 0 else {
            return HistogramData(luminance: [], red: [], green: [], blue: [], binCount: 256)
        }

        let luminance = (0..<256).map { i -> Float in
            let r = Float(redBins[i]) / maxValue
            let g = Float(greenBins[i]) / maxValue
            let b = Float(blueBins[i]) / maxValue
            return (0.2126 * r + 0.7152 * g + 0.0722 * b)
        }

        let red = redBins.map { Float($0) / maxValue }
        let green = greenBins.map { Float($0) / maxValue }
        let blue = blueBins.map { Float($0) / maxValue }

        return HistogramData(luminance: luminance, red: red, green: green, blue: blue, binCount: 256)
    }

    func calculate(from pixelBuffer: CVPixelBuffer) async -> HistogramData {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else {
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
