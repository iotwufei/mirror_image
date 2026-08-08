import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
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
        .onKeyPress(.space) {
            return handleSpace() ? .handled : .ignored
        }
        .onKeyPress(.escape) {
            if !viewModel.selectedFileIDs.isEmpty {
                viewModel.selectedFileIDs.removeAll()
            }
            return .handled
        }
    }

    private func handleSpace() -> Bool {
        if viewModel.selectedFileIDs.isEmpty {
            if case let .column(col, row) = viewModel.fileListFocus,
               col < viewModel.fileColumns.count,
               row < viewModel.fileColumns[col].files.count {
                let file = viewModel.fileColumns[col].files[row]
                viewModel.toggleFileSelection(file.id)
                return true
            }
            return false
        } else {
            let all = viewModel.comparisonFiles()
            let selected = viewModel.selectedFiles
            if !selected.isEmpty {
                coordinator.enterComparison(allFiles: all, selectedFiles: selected)
                return true
            }
            return false
        }
    }
}
