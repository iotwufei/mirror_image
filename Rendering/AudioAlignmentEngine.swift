import AVFoundation
import Accelerate
import Foundation

final class AudioAlignmentEngine {
    struct AlignmentResult {
        let offset: CMTime
        let confidence: Float
    }

    enum AlignmentError: LocalizedError {
        case noAudioTrack
        case insufficientData
        case lowConfidence(String)

        var errorDescription: String? {
            switch self {
            case .noAudioTrack: return "One or more videos have no audio track"
            case .insufficientData: return "Not enough audio data for alignment"
            case .lowConfidence(let msg): return "Cannot align: \(msg)"
            }
        }
    }

    private let targetSampleRate: Double = 16000
    private let minimumConfidence: Float = 0.3
    private let silenceThreshold: Float = 0.01
    private let fftSize: Int = 2048
    private let featureVectorSize: Int = 32

    func align(assets: [AVAsset]) async throws -> AlignmentResult {
        guard assets.count >= 2 else {
            throw AlignmentError.insufficientData
        }

        var pcmBuffers: [[Float]] = []
        for asset in assets {
            let buffer = try await extractAudioPCM(from: asset)
            pcmBuffers.append(buffer)
        }

        let pairs = stride(from: 0, to: pcmBuffers.count - 1, by: 1).map { (pcmBuffers[$0], pcmBuffers[$0 + 1]) }

        var totalOffset: Float = 0
        var totalConfidence: Float = 0
        var pairCount: Float = 0

        for (bufferA, bufferB) in pairs {
            let (offset, confidence) = correlate(bufferA, bufferB)
            totalOffset += offset
            totalConfidence += confidence
            pairCount += 1
        }

        let avgConfidence = totalConfidence / pairCount
        guard avgConfidence >= minimumConfidence else {
            throw AlignmentError.lowConfidence("NCC peak \(String(format: "%.3f", avgConfidence)) below threshold \(minimumConfidence)")
        }

        let avgOffset = Double(totalOffset / pairCount) / targetSampleRate
        let cmOffset = CMTimeMakeWithSeconds(avgOffset, preferredTimescale: 600)

        return AlignmentResult(offset: cmOffset, confidence: avgConfidence)
    }

    private func extractAudioPCM(from asset: AVAsset) async throws -> [Float] {
        guard let audioTrack = try? await asset.loadTracks(withMediaCharacteristic: .audible).first else {
            throw AlignmentError.noAudioTrack
        }

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: targetSampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        var samples: [Float] = []

        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

            guard let data = dataPointer, length > 0 else { continue }

            let sampleCount = length / 2
            let int16Data = data.withMemoryRebound(to: Int16.self, capacity: sampleCount) { $0 }
            let floatSamples = UnsafeBufferPointer(start: int16Data, count: sampleCount).map { Float($0) / 32768.0 }
            samples.append(contentsOf: floatSamples)

            if samples.count > 30 * Int(targetSampleRate) {
                break
            }
        }

        reader.cancelReading()
        return samples
    }

    private func correlate(_ signalA: [Float], _ signalB: [Float]) -> (offset: Float, confidence: Float) {
        let featuresA = extractFeatures(signalA)
        let featuresB = extractFeatures(signalB)

        guard featuresA.count > 0, featuresB.count > 0 else { return (0, 0) }

        let (offset, peak) = normalizedCrossCorrelation(featuresA, featuresB)

        return (offset, peak)
    }

    private func extractFeatures(_ signal: [Float]) -> [Float] {
        let nonSilent = signal.filter { abs($0) > silenceThreshold }
        guard nonSilent.count > fftSize else { return [] }

        let log2n = vDSP_Length(log2(Float(fftSize)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }

        defer { vDSP_destroy_fftsetup(fftSetup) }

        var features: [Float] = []

        let hopSize = fftSize / 2
        var position = 0

        while position + fftSize <= signal.count {
            let chunk = Array(signal[position..<position + fftSize])

            var realPart = chunk
            var imagPart = [Float](repeating: 0, count: fftSize / 2)

            realPart.withUnsafeMutableBufferPointer { realPtr in
                imagPart.withUnsafeMutableBufferPointer { imagPtr in
                    var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    let temp = UnsafePointer(realPtr.baseAddress!).withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { $0 }
                    vDSP_ctoz(temp, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

                    let magnitude = UnsafeMutablePointer<Float>.allocate(capacity: fftSize / 2)
                    defer { magnitude.deallocate() }
                    vDSP_zvmags(&splitComplex, 1, magnitude, 1, vDSP_Length(fftSize / 2))

                    var peakIndices: [Int] = []
                    var peakMagnitudes: [Float] = []

                    for i in 1..<(fftSize / 2 - 1) {
                        let mag = magnitude[i]
                        if mag > magnitude[i - 1] && mag > magnitude[i + 1] && mag > 0 {
                            peakIndices.append(i)
                            peakMagnitudes.append(mag)
                        }
                    }

                    let sorted = zip(peakIndices, peakMagnitudes).sorted { $0.1 > $1.1 }
                        .prefix(featureVectorSize)

                    for (_, mag) in sorted {
                        features.append(mag)
                    }
                }
            }

            position += hopSize
        }

        let maxFeature = features.max() ?? 1
        if maxFeature > 0 {
            features = features.map { $0 / maxFeature }
        }

        return features
    }

    private func normalizedCrossCorrelation(_ a: [Float], _ b: [Float]) -> (offset: Float, confidence: Float) {
        guard !a.isEmpty, !b.isEmpty else { return (0, 0) }

        let len = min(a.count, b.count, featureVectorSize * 10)
        let sa = Array(a.prefix(len))
        let sb = Array(b.prefix(len))

        var meanA: Float = 0
        var meanB: Float = 0
        vDSP_meanv(sa, 1, &meanA, vDSP_Length(len))
        vDSP_meanv(sb, 1, &meanB, vDSP_Length(len))

        var normA = [Float](repeating: 0, count: len)
        var normB = [Float](repeating: 0, count: len)
        var negMeanA = -meanA
        var negMeanB = -meanB

        vDSP_vsadd(sa, 1, &negMeanA, &normA, 1, vDSP_Length(len))
        vDSP_vsadd(sb, 1, &negMeanB, &normB, 1, vDSP_Length(len))

        var stdA: Float = 0
        var stdB: Float = 0
        vDSP_svesq(normA, 1, &stdA, vDSP_Length(len))
        vDSP_svesq(normB, 1, &stdB, vDSP_Length(len))
        stdA = sqrt(stdA / Float(len))
        stdB = sqrt(stdB / Float(len))

        guard stdA > 0, stdB > 0 else { return (0, 0) }

        var invStdA = 1.0 / stdA
        var invStdB = 1.0 / stdB
        vDSP_vsmul(normA, 1, &invStdA, &normA, 1, vDSP_Length(len))
        vDSP_vsmul(normB, 1, &invStdB, &normB, 1, vDSP_Length(len))

        let searchRange = len / 4
        var bestOffset: Int = 0
        var bestValue: Float = -1

        for offset in -searchRange...searchRange {
            let aStart = max(0, -offset)
            let bStart = max(0, offset)
            let overlapCount = len - abs(offset)

            guard overlapCount > 0 else { continue }

            let aSlice = normA[aStart..<aStart + overlapCount]
            let bSlice = normB[bStart..<bStart + overlapCount]
            var dotProd: Float = 0
            aSlice.withUnsafeBufferPointer { aPtr in
                bSlice.withUnsafeBufferPointer { bPtr in
                    vDSP_dotpr(aPtr.baseAddress!, 1, bPtr.baseAddress!, 1, &dotProd, vDSP_Length(overlapCount))
                }
            }

            let ncc = dotProd / Float(overlapCount)

            if ncc > bestValue {
                bestValue = ncc
                bestOffset = offset
            }
        }

        return (Float(bestOffset), bestValue)
    }
}
