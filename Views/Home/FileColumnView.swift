import SwiftUI

struct FileColumnView: View {
    let column: FileItemColumn
    let columnIndex: Int
    @ObservedObject var viewModel: HomeViewModel
    let columnWidth: CGFloat
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 0) {
            columnHeader

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(column.files.enumerated()), id: \.element.id) { rowIndex, file in
                        FileRowView(
                            file: file,
                            isSelected: viewModel.selectedFileIDs.contains(file.id),
                            thumbnail: viewModel.thumbnailImages[file.id],
                            isFocused: isRowFocused(rowIndex)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.fileListFocus = .column(columnIndex, rowIndex)
                            if NSEvent.modifierFlags.contains(.command) {
                                viewModel.toggleFileSelection(file.id)
                            } else {
                                viewModel.toggleFileSelection(file.id)
                            }
                        }
                        .onAppear {
                            viewModel.requestThumbnail(for: file)
                        }
                        .onDisappear {
                            viewModel.cancelThumbnail(for: file)
                        }

                        if rowIndex < column.files.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.04))
                                .frame(height: 1)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if !column.files.isEmpty {
                ThumbnailGridView(
                    files: column.files,
                    thumbnailImages: viewModel.thumbnailImages,
                    viewModel: viewModel
                )
                .frame(height: 80)
            }
        }
        .focusable()
        .onKeyPress(.space) {
            handleSpace()
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveFocus(rowDelta: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveFocus(rowDelta: 1)
            return .handled
        }
        .onKeyPress(.tab) {
            moveFocusToNextColumn()
            return .handled
        }
        .onKeyPress(KeyEquivalent("a")) {
            if NSEvent.modifierFlags.contains(.command) {
                viewModel.selectAllInCurrentColumn()
            }
            return .handled
        }
    }

    private func handleSpace() {
        if viewModel.selectedFileIDs.isEmpty {
            guard case let .column(col, row) = viewModel.fileListFocus,
                  col == columnIndex,
                  row < column.files.count else { return }
            let file = column.files[row]
            viewModel.toggleFileSelection(file.id)
        } else {
            let selected = viewModel.selectedFiles
            let all = viewModel.allFiles
            if !selected.isEmpty {
                coordinator.enterComparison(allFiles: all, selectedFiles: selected)
            }
        }
    }

    private var columnHeader: some View {
        HStack {
            Image(systemName: "folder.fill")
                .font(.system(size: 11))
                .foregroundColor(.accentColor.opacity(0.6))

            Text(column.folderName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            Spacer()

            Text("\(column.files.count) items")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(red: 0.14, green: 0.14, blue: 0.14))
    }

    private func isRowFocused(_ rowIndex: Int) -> Bool {
        if case let .column(col, row) = viewModel.fileListFocus {
            return col == columnIndex && row == rowIndex
        }
        return false
    }

    private func moveFocus(rowDelta: Int) {
        guard case let .column(col, row) = viewModel.fileListFocus, col == columnIndex else { return }
        let newRow = max(0, min(column.files.count - 1, row + rowDelta))
        viewModel.fileListFocus = .column(columnIndex, newRow)
    }

    private func moveFocusToNextColumn() {
        let nextCol = (columnIndex + 1) % viewModel.fileColumns.count
        viewModel.fileListFocus = .column(nextCol, 0)
    }
}
