import SwiftUI
import Combine

enum ZoomMode {
    case global
    case perImage(layerIndex: Int)
}

@MainActor
final class ComparisonViewModel: ObservableObject {
    @Published var groups: [ComparisonGroup] = []
    @Published var currentGroupIndex: Int = 0
    @Published var globalZoom: CGFloat = 1.0
    @Published var perImageZoom: [Int: CGFloat] = [:]
    @Published var panOffset: CGPoint = .zero
    @Published var isPlaying: Bool = false
    @Published var controlMode: VideoControlMode = .synchronized
    @Published var showHistogram: Bool = false
    @Published var layerVisibility: [Int: Bool] = [:]

    var currentGroup: ComparisonGroup? {
        guard currentGroupIndex >= 0, currentGroupIndex < groups.count else { return nil }
        return groups[currentGroupIndex]
    }

    var hasNextGroup: Bool {
        currentGroupIndex < groups.count - 1
    }

    var hasPrevGroup: Bool {
        currentGroupIndex > 0
    }

    func setupGroups(files: [FileItem]) {
        let groupSize = files.count
        groups = ComparisonGroup.buildGroups(from: files, groupSize: groupSize)
        currentGroupIndex = 0
        globalZoom = 1.0
        perImageZoom = [:]
        panOffset = .zero
        layerVisibility = [:]
        showHistogram = false
    }

    func setupGroups(allFiles: [FileItem], selectedFiles: [FileItem]) {
        let groupSize = selectedFiles.count
        groups = ComparisonGroup.buildGroups(from: allFiles, groupSize: groupSize)
        if let firstSelected = selectedFiles.first,
           let matchIdx = allFiles.firstIndex(where: { $0.id == firstSelected.id }) {
            currentGroupIndex = matchIdx / groupSize
        } else {
            currentGroupIndex = 0
        }
        globalZoom = 1.0
        perImageZoom = [:]
        panOffset = .zero
        layerVisibility = [:]
        showHistogram = false
    }

    func nextGroup() {
        guard hasNextGroup else { return }
        currentGroupIndex += 1
        globalZoom = 1.0
        perImageZoom = [:]
        panOffset = .zero
    }

    func prevGroup() {
        guard hasPrevGroup else { return }
        currentGroupIndex -= 1
        globalZoom = 1.0
        perImageZoom = [:]
        panOffset = .zero
    }

    func toggleLayerVisibility(index: Int) {
        let current = layerVisibility[index] ?? true
        layerVisibility[index] = !current
    }

    func isLayerVisible(_ index: Int) -> Bool {
        layerVisibility[index] ?? true
    }

    func resetZoom() {
        globalZoom = 1.0
        perImageZoom = [:]
        panOffset = .zero
    }

    func zoom(at layerIndex: Int?, factor: CGFloat) {
        if let index = layerIndex {
            let current = perImageZoom[index] ?? globalZoom
            let newZoom = max(0.1, min(50.0, current * factor))
            perImageZoom[index] = newZoom
        } else {
            let newZoom = max(0.1, min(50.0, globalZoom * factor))
            globalZoom = newZoom
        }
    }

    func pan(by delta: CGPoint) {
        panOffset = CGPoint(
            x: panOffset.x + delta.x,
            y: panOffset.y + delta.y
        )
    }
}
