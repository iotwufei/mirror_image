import SwiftUI
import AVFoundation

struct DiffView: View {
    @StateObject private var viewModel = ComparisonViewModel()
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var alignmentMessage: String?
    @State private var showAlignmentError = false

    let allFiles: [FileItem]
    let selectedFiles: [FileItem]
    let mode: ComparisonMode
    let videoController = VideoLayerController()

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ZStack {
                Color.black

                switch mode {
                case .image:
                    ImageDiffView(viewModel: viewModel, files: allFiles)
                case .video:
                    VideoDiffView(viewModel: viewModel, files: allFiles, videoController: videoController)
                }
            }

            bottomBar
        }
        .background(Color.black)
        .onAppear {
            viewModel.setupGroups(allFiles: allFiles, selectedFiles: selectedFiles)
            DispatchQueue.main.async {
                if let window = NSApp.keyWindow, !window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }
            }
        }
        .onKeyPress(.space) {
            if mode == .video {
                viewModel.isPlaying.toggle()
            } else {
                viewModel.nextGroup()
            }
            return .handled
        }
        .onKeyPress(KeyEquivalent("b")) {
            viewModel.prevGroup()
            return .handled
        }
        .onKeyPress(KeyEquivalent("h")) {
            viewModel.showHistogram.toggle()
            return .handled
        }
        .onKeyPress(KeyEquivalent("i")) {
            viewModel.showInfo.toggle()
            return .handled
        }
        .onKeyPress(.escape) {
            if let window = NSApp.keyWindow, window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
            coordinator.exitComparison()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            if mode == .video {
                videoController.seekAll(by: -5)
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if mode == .video {
                videoController.seekAll(by: 5)
            }
            return .handled
        }
        .onKeyPress(KeyEquivalent("q")) {
            if mode == .video {
                Task { await triggerAudioAlignment() }
            }
            return .handled
        }
        .onChange(of: viewModel.isPlaying) { _, playing in
            if mode == .video {
                if playing {
                    videoController.playAll()
                } else {
                    videoController.pauseAll()
                }
            }
        }
        .overlay(alignment: .center) {
            if let message = alignmentMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(6)
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.showInfo, let group = viewModel.currentGroup {
                infoOverlay(for: group)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { coordinator.exitComparison() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)

            Spacer()

            if let group = viewModel.currentGroup {
                Text("Group \(group.index + 1) of \(viewModel.groups.count)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            HStack(spacing: 12) {
                if mode == .video {
                    Button(action: { viewModel.isPlaying.toggle() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }

                Text("\(Int(viewModel.globalZoom * 100))%")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
    }

    private var bottomBar: some View {
        HStack {
            Text(keyboardHints)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))

            Spacer()

            if viewModel.showHistogram {
                Text("Histogram On")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
    }

    private var keyboardHints: String {
        if mode == .video {
            return "Space: Play/Pause  |  \u{2190}\u{2192}: Seek  |  B: Prev  |  Cmd+Space: Next  |  Q: Align  |  H: Histogram  |  I: Info  |  Esc: Exit"
        } else {
            return "Space: Next  |  B: Prev  |  1-9: Toggle  |  H: Histogram  |  I: Info  |  Esc: Exit  |  Scroll: Zoom  |  Cmd+Scroll: Solo Zoom"
        }
    }

    @ViewBuilder
    private func infoOverlay(for group: ComparisonGroup) -> some View {
        GeometryReader { geometry in
            let frames = ComparisonViewLayout.default.frames(for: group.files.count, in: CGRect(origin: .zero, size: geometry.size))
            ForEach(Array(group.files.enumerated()), id: \.element.id) { index, file in
                if index < frames.count {
                    let frame = frames[index]
                    ZStack(alignment: .topLeading) {
                        Color.clear
                        VStack(alignment: .leading, spacing: 1) {
                            Text(file.name)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                if let dims = file.dimensions {
                                    Text("\(Int(dims.width))\u{00D7}\(Int(dims.height))")
                                }
                                Text(file.formattedFileSize)
                                if let cam = file.cameraModel {
                                    Text(cam)
                                        .lineLimit(1)
                                }
                            }
                            .font(.system(size: 10))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(4)
                        .padding(8)
                    }
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func triggerAudioAlignment() async {
        alignmentMessage = "Analyzing audio..."
        let assets = allFiles.map { AVAsset(url: $0.url) }
        let engine = AudioAlignmentEngine()

        do {
            let result = try await engine.align(assets: assets)
            videoController.seekAll(to: result.offset)
            alignmentMessage = "Aligned (confidence: \(String(format: "%.2f", result.confidence)))"
        } catch {
            alignmentMessage = "Cannot align: \(error.localizedDescription)"
            showAlignmentError = true
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        withAnimation {
            alignmentMessage = nil
        }
    }
}
