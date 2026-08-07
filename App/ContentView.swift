import SwiftUI

struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        switch coordinator.route {
        case .home:
            HomeView(viewModel: coordinator.homeViewModel)
        case .imageComparison(let allFiles, let selectedFiles):
            DiffView(allFiles: allFiles, selectedFiles: selectedFiles, mode: .image)
        case .videoComparison(let allFiles, let selectedFiles):
            DiffView(allFiles: allFiles, selectedFiles: selectedFiles, mode: .video)
        }
    }
}
