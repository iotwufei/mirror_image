import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var sidebarWidth: CGFloat = 240

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: viewModel)
                .frame(width: sidebarWidth)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1)

            VStack(spacing: 0) {
                FilterBarView(filter: $viewModel.filter) { newFilter in
                    viewModel.setFilter(newFilter)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                ContentArea(viewModel: viewModel)
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .onAppear {
            viewModel.loadPersistedFolders()
        }
        .onKeyPress(.space) {
            handleSpace()
            return .handled
        }
        .onKeyPress(.escape) {
            if viewModel.selectedFileIDs.isEmpty {
                viewModel.selectedFileIDs.removeAll()
            }
            return .handled
        }
    }

    private func handleSpace() {
        if viewModel.selectedFileIDs.isEmpty {
            if case let .column(col, row) = viewModel.fileListFocus,
               col < viewModel.fileColumns.count,
               row < viewModel.fileColumns[col].files.count {
                let file = viewModel.fileColumns[col].files[row]
                viewModel.toggleFileSelection(file.id)
            }
        } else {
            let selected = viewModel.selectedFiles
            let all = viewModel.allFiles
            if !selected.isEmpty {
                coordinator.enterComparison(allFiles: all, selectedFiles: selected)
            }
        }
    }
}
