import SwiftUI
import AppKit

struct ImageDiffView: NSViewRepresentable {
    @ObservedObject var viewModel: ComparisonViewModel

    func makeNSView(context: Context) -> ComparisonView {
        let view = ComparisonView()

        view.onZoomChanged = { zoom in
            viewModel.globalZoom = zoom
        }

        return view
    }

    func updateNSView(_ nsView: ComparisonView, context: Context) {
        if context.coordinator.showHistogram != viewModel.showHistogram {
            nsView.toggleHistograms()
            context.coordinator.showHistogram = viewModel.showHistogram
        }

        guard let group = viewModel.currentGroup else { return }

        let groupChanged = context.coordinator.lastGroupIndex != viewModel.currentGroupIndex
        guard groupChanged else { return }
        context.coordinator.lastGroupIndex = viewModel.currentGroupIndex
        context.coordinator.loadTask?.cancel()

        let files = group.files
        let groupID = group.id
        context.coordinator.loadTask = Task { @MainActor in
            var images: [(CGImage, CGSize)] = []
            for file in files {
                guard !Task.isCancelled else { return }
                if let cgImage = await Self.decodePreview(from: file.url) {
                    let size = CGSize(width: cgImage.width, height: cgImage.height)
                    images.append((cgImage, size))
                }
            }

            guard !Task.isCancelled, viewModel.currentGroup?.id == groupID else { return }
            guard !images.isEmpty else { return }

            nsView.loadGroup(group)
            nsView.applyImageLayout(images: images)

            for (index, _) in files.enumerated() {
                let isVisible = viewModel.isLayerVisible(index)
                nsView.setLayerVisibility(isVisible, at: index)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(showHistogram: viewModel.showHistogram)
    }

    private nonisolated static func decodePreview(from url: URL) async -> CGImage? {
        await Task.detached(priority: .userInitiated) {
            ImageLayerController().loadPreviewImage(from: url)
        }.value
    }

    class Coordinator: NSObject {
        var showHistogram: Bool
        var lastGroupIndex: Int = -1
        var loadTask: Task<Void, Never>?

        init(showHistogram: Bool) {
            self.showHistogram = showHistogram
        }
    }
}
