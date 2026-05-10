import SwiftUI
import AVFoundation

struct VideoDiffView: NSViewRepresentable {
    @ObservedObject var viewModel: ComparisonViewModel
    let files: [FileItem]

    private let videoController = VideoLayerController()

    func makeNSView(context: Context) -> ComparisonView {
        let view = ComparisonView()

        view.onGroupNavigation = { forward in
            if forward {
                viewModel.nextGroup()
            } else {
                viewModel.prevGroup()
            }
        }
        view.onToggleHistogram = {
            viewModel.showHistogram.toggle()
        }
        view.onToggleLayerVisibility = { index in
            viewModel.toggleLayerVisibility(index: index)
            view.setLayerVisibility(viewModel.isLayerVisible(index), at: index)
        }
        view.onExit = {
            NSApp.keyWindow?.close()
        }

        return view
    }

    func updateNSView(_ nsView: ComparisonView, context: Context) {
        guard let group = viewModel.currentGroup else { return }

        nsView.loadGroup(group)

        let urls = group.files.map { $0.url }
        let bounds = nsView.bounds
        let layout = ComparisonViewLayout.default
        let frames = layout.frames(for: urls.count, in: bounds)

        let layers = videoController.createLayers(for: urls, frames: frames)

        let parentLayer = nsView.layer!
        for layer in layers {
            parentLayer.addSublayer(layer)
        }

        for (index, _) in group.files.enumerated() {
            let isVisible = viewModel.isLayerVisible(index)
            nsView.setLayerVisibility(isVisible, at: index)
        }
    }

    func dismantleNSView(_ nsView: ComparisonView, coordinator: Void) {
        videoController.cleanup()
    }

    func playAllVideos() {
        videoController.playAll()
    }

    func pauseAllVideos() {
        videoController.pauseAll()
    }

    func togglePlayPause() {
        videoController.togglePlayPause()
    }

    func seekAllVideos(by seconds: Double) {
        videoController.seekAll(by: seconds)
    }

    func triggerAlignment() async {
        let assets: [AVAsset] = files.map { AVAsset(url: $0.url) }
        let engine = AudioAlignmentEngine()

        do {
            let result = try await engine.align(assets: assets)
            videoController.seekAll(to: result.offset)
        } catch {
            print("Audio alignment failed: \(error.localizedDescription)")
        }
    }
}
