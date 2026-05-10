import SwiftUI

enum ComparisonMode: Equatable {
    case image
    case video
}

@MainActor
final class AppCoordinator: ObservableObject {
    enum Route: Equatable {
        case home
        case imageComparison(allFiles: [FileItem], selectedFiles: [FileItem])
        case videoComparison(allFiles: [FileItem], selectedFiles: [FileItem])
    }

    @Published var route: Route = .home

    func enterComparison(allFiles: [FileItem], selectedFiles: [FileItem]) {
        guard !selectedFiles.isEmpty else { return }
        let mode: ComparisonMode = selectedFiles.allSatisfy({ $0.mediaType == .video }) ? .video : .image
        if mode == .video {
            route = .videoComparison(allFiles: allFiles, selectedFiles: selectedFiles)
        } else {
            route = .imageComparison(allFiles: allFiles, selectedFiles: selectedFiles)
        }
    }

    func exitComparison() {
        route = .home
    }
}
