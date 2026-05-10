import SwiftUI

struct ContentArea: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        if viewModel.fileColumns.isEmpty {
            emptyState
        } else {
            multiColumnView
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.15))

            VStack(spacing: 8) {
                Text("No folders selected")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                Text("Select one or more folders in the sidebar\nto browse images and videos")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.25))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var multiColumnView: some View {
        GeometryReader { geometry in
            let totalColumns = viewModel.fileColumns.count
            let availableWidth = geometry.size.width
            let columnWidth = availableWidth / CGFloat(max(totalColumns, 1))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(viewModel.fileColumns.enumerated()), id: \.element.id) { index, column in
                        FileColumnView(
                            column: column,
                            columnIndex: index,
                            viewModel: viewModel,
                            columnWidth: columnWidth
                        )
                        .frame(width: columnWidth)

                        if index < viewModel.fileColumns.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1)
                        }
                    }
                }
            }
            .focusable()
            .onKeyPress(.space) {
                handleSpace()
                return .handled
            }
        }
    }

    private func handleSpace() {
        if !viewModel.selectedFileIDs.isEmpty {
            let selected = viewModel.selectedFiles
            let all = viewModel.allFiles
            if !selected.isEmpty {
                coordinator.enterComparison(allFiles: all, selectedFiles: selected)
            }
        }
    }
}
