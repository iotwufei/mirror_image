import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Folders")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)

                Spacer()

                Button(action: { viewModel.addFolder() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Add Folder")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            if viewModel.rootFolders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.2))

                    Text("Add a folder to get started")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.rootFolders) { folder in
                            FolderRowView(
                                folder: folder,
                                isSelected: viewModel.selectedFolderIDs.contains(folder.id),
                                onToggle: { viewModel.toggleFolderSelection(folder.id) },
                                onRemove: { viewModel.removeFolder(folder.id) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
    }
}

struct FolderRowView: View {
    @ObservedObject var folder: FolderNode
    let isSelected: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    @State private var isHovered = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Toggle("", isOn: Binding<Bool>(
                    get: { isSelected },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.checkbox)
                .scaleEffect(0.8)

                if !folder.isLeaf {
                    Button(action: { toggleExpand() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 14)
                }

                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor.opacity(0.7))

                Text(folder.name)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if isHovered {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }

            if isExpanded && !folder.children.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(folder.children) { child in
                        FolderRowView(
                            folder: child,
                            isSelected: false,
                            onToggle: {},
                            onRemove: {}
                        )
                        .padding(.leading, 16)
                    }
                }
            }
        }
    }

    private func toggleExpand() {
        isExpanded.toggle()
        if isExpanded {
            folder.loadChildren()
        }
    }
}
