import AVFoundation
import QuartzCore
import AppKit

final class VideoLayerController: NSObject {
    private var players: [AVPlayer] = []
    private var playerLayers: [AVPlayerLayer] = []
    private var playerLooper: Any?
    private var timeObservers: [Any] = []

    var controlMode: VideoControlMode = .synchronized
    var isPlaying: Bool { !players.isEmpty && players.allSatisfy { $0.rate > 0 } }

    func createLayers(for urls: [URL], frames: [CGRect]) -> [AVPlayerLayer] {
        cleanup()

        var layers: [AVPlayerLayer] = []
        for (index, url) in urls.enumerated() {
            let player = AVPlayer(url: url)
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill
            layer.frame = index < frames.count ? frames[index] : .zero
            layer.masksToBounds = true

            player.isMuted = false

            players.append(player)
            layers.append(layer)
        }

        playerLayers = layers
        return layers
    }

    func addToSuperlayer(for layers: [AVPlayerLayer], parent: CALayer) {
        for layer in layers {
            parent.addSublayer(layer)
        }
    }

    func playAll() {
        let cmTime = CMTime.zero
        for player in players {
            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
            player.play()
        }
    }

    func pauseAll() {
        for player in players {
            player.pause()
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pauseAll()
        } else {
            if players.allSatisfy({ $0.currentTime() == CMTime.zero || $0.currentTime() == $0.currentItem?.duration }) {
                playAll()
            } else {
                for player in players { player.play() }
            }
        }
    }

    func seekAll(to time: CMTime) {
        for player in players {
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func seekAll(by seconds: Double) {
        for player in players {
            let current = player.currentTime()
            let newTime = CMTimeAdd(current, CMTimeMakeWithSeconds(seconds, preferredTimescale: 600))
            let duration = player.currentItem?.duration ?? .zero
            let clamped = CMTimeMinimum(CMTimeMaximum(newTime, .zero), duration)
            player.seek(to: clamped, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func setRate(_ rate: Float, for playerIndex: Int) {
        guard playerIndex < players.count else { return }
        players[playerIndex].rate = rate
    }

    func seek(to time: CMTime, playerIndex: Int) {
        guard playerIndex < players.count else { return }
        players[playerIndex].seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func layer(for index: Int) -> AVPlayerLayer? {
        guard index < playerLayers.count else { return nil }
        return playerLayers[index]
    }

    func player(for index: Int) -> AVPlayer? {
        guard index < players.count else { return nil }
        return players[index]
    }

    func setLayerFrames(_ frames: [CGRect]) {
        for (index, frame) in frames.enumerated() {
            guard index < playerLayers.count else { break }
            playerLayers[index].frame = frame
        }
    }

    func syncAllToFastestPlayer() {
        guard !players.isEmpty else { return }
        var maxTime = CMTime.zero
        for player in players {
            let time = player.currentTime()
            if CMTimeCompare(time, maxTime) > 0 {
                maxTime = time
            }
        }
        seekAll(to: maxTime)
    }

    func cleanup() {
        for observer in timeObservers {
            if let player = players.first {
                player.removeTimeObserver(observer)
            }
        }
        timeObservers.removeAll()

        for player in players {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        players.removeAll()

        for layer in playerLayers {
            layer.player = nil
            layer.removeFromSuperlayer()
        }
        playerLayers.removeAll()
    }
}
