import SwiftUI
import AVFoundation

struct VideoDiffView: NSViewRepresentable {
    @ObservedObject var viewModel: ComparisonViewModel
    let files: [FileItem]
    let videoController: VideoLayerController

    func makeNSView(context: Context) -> ComparisonView {
        let view = ComparisonView()

        view.onToggleLayerVisibility = { index in
            viewModel.toggleLayerVisibility(index: index)
            view.setLayerVisibility(viewModel.isLayerVisible(index), at: index)
        }
        view.onZoomChanged = { zoom in
            viewModel.globalZoom = zoom
        }

        return view
    }

    func updateNSView(_ nsView: ComparisonView, context: Context) {
        guard let group = viewModel.currentGroup else { return }

        let groupChanged = context.coordinator.lastGroupIndex != viewModel.currentGroupIndex
        guard groupChanged else { return }
        context.coordinator.lastGroupIndex = viewModel.currentGroupIndex

        let urls = group.files.map { $0.url }
        nsView.loadVideoGroup(group, urls: urls, controller: videoController)

        for (index, _) in group.files.enumerated() {
            let isVisible = viewModel.isLayerVisible(index)
            nsView.setLayerVisibility(isVisible, at: index)
        }
    }

    func dismantleNSView(_ nsView: ComparisonView, coordinator: Coordinator) {
        videoController.cleanup()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var lastGroupIndex: Int = -1
    }
}
