import SwiftUI

struct FileColumnView: View {
    let column: FileItemColumn
    let columnIndex: Int
    @ObservedObject var viewModel: HomeViewModel
    let columnWidth: CGFloat
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var visibleStartIndex: Int = 0

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
                        .id(file.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.fileListFocus = .column(columnIndex, rowIndex)
                            if NSEvent.modifierFlags.contains(.shift) {
                                viewModel.shiftSelectFile(file.id)
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
                        .background(
                            GeometryReader { _ in
                                Color.clear
                                    .preference(key: VisibleRowPreferenceKey.self, value: Set([rowIndex]))
                            }
                        )

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
            .scrollPosition(id: scrollPositionBinding)
            .onPreferenceChange(VisibleRowPreferenceKey.self) { visibleRows in
                if let firstVisible = visibleRows.min() {
                    visibleStartIndex = firstVisible
                }
            }
            .onChange(of: viewModel.fileListFocus) { _, focus in
                guard case let .column(col, row) = focus,
                      col == columnIndex,
                      column.files.indices.contains(row) else { return }
                scrollPositionBinding.wrappedValue = column.files[row].id
            }
            .onChange(of: viewModel.columnScrollPositions[columnIndex]) { _, newValue in
                if let id = newValue, let row = column.files.firstIndex(where: { $0.id == id }) {
                    visibleStartIndex = row
                }
            }
            .onAppear {
                if let id = viewModel.columnScrollPositions[columnIndex],
                   let row = column.files.firstIndex(where: { $0.id == id }) {
                    visibleStartIndex = row
                }
            }

            if !column.files.isEmpty {
                ThumbnailGridView(
                    files: column.files,
                    thumbnailImages: viewModel.thumbnailImages,
                    viewModel: viewModel,
                    visibleStartIndex: visibleStartIndex
                )
                .frame(height: 80)
            }
        }
    }

    private var scrollPositionBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.columnScrollPositions[columnIndex] ?? nil },
            set: { viewModel.columnScrollPositions[columnIndex] = $0 }
        )
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

}
