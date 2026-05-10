import SwiftUI
import AppKit

struct ImageDiffView: NSViewRepresentable {
    @ObservedObject var viewModel: ComparisonViewModel
    let files: [FileItem]

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
        if context.coordinator.showHistogram != viewModel.showHistogram {
            nsView.toggleHistograms()
            context.coordinator.showHistogram = viewModel.showHistogram
        }

        guard let group = viewModel.currentGroup else { return }

        var images: [(CGImage, CGSize)] = []
        let controller = ImageLayerController()

        for file in group.files {
            if let cgImage = controller.loadImage(from: file.url) {
                let size = CGSize(width: cgImage.width, height: cgImage.height)
                images.append((cgImage, size))
            }
        }

        guard !images.isEmpty else { return }

        nsView.loadGroup(group)
        nsView.applyImageLayout(images: images)

        for (index, _) in group.files.enumerated() {
            let isVisible = viewModel.isLayerVisible(index)
            nsView.setLayerVisibility(isVisible, at: index)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(showHistogram: viewModel.showHistogram)
    }

    class Coordinator: NSObject {
        var showHistogram: Bool

        init(showHistogram: Bool) {
            self.showHistogram = showHistogram
        }
    }
}
