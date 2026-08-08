import SwiftUI

enum HomeKeyAction: Equatable {
    case space
    case clearSelection
    case moveFocus(Int)
    case nextColumn
    case selectAll
}

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var sidebarWidth: CGFloat = 240
    @State private var keyMonitor: Any?

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
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleKey(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard let action = Self.resolveKeyAction(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags
        ) else { return false }

        switch action {
        case .space:
            handleSpace()
        case .clearSelection:
            if !viewModel.selectedFileIDs.isEmpty {
                viewModel.selectedFileIDs.removeAll()
            }
        case .moveFocus(let rowDelta):
            viewModel.moveFocus(rowDelta: rowDelta)
        case .nextColumn:
            viewModel.moveFocusToNextColumn()
        case .selectAll:
            viewModel.selectAllInFocusedColumn()
        }
        return true
    }

    static func resolveKeyAction(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) -> HomeKeyAction? {
        switch keyCode {
        case 49: // Space
            return .space
        case 53: // Esc
            return .clearSelection
        case 126: // Up arrow
            return .moveFocus(-1)
        case 125: // Down arrow
            return .moveFocus(1)
        case 48: // Tab
            return .nextColumn
        case 0: // A
            return modifiers.contains(.command) ? .selectAll : nil
        default:
            return nil
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
            let all = viewModel.comparisonFiles()
            let selected = viewModel.selectedFiles
            if !selected.isEmpty {
                coordinator.enterComparison(allFiles: all, selectedFiles: selected)
            }
        }
    }
}
