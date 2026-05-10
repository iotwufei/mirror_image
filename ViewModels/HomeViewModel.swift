import SwiftUI
import Combine
import AppKit

enum SidebarFocus: Hashable {
    case folder(FolderNode.ID)
}

enum FileListFocus: Hashable {
    case column(Int, Int)
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var rootFolders: [FolderNode] = []
    @Published var selectedFolderIDs: Set<UUID> = []
    @Published var filter: MediaFilter = .all
    @Published var fileColumns: [FileItemColumn] = []
    @Published var selectedFileIDs: Set<UUID> = []
    @Published var thumbnailImages: [UUID: CGImage] = [:]
    @Published var sidebarFocus: SidebarFocus?
    @Published var fileListFocus: FileListFocus?

    let fileBrowser = FileBrowserModel()
    let thumbnailGenerator = ThumbnailGenerator()
    let metadataProvider = MediaMetadataProvider()

    var activeFileCount: Int {
        fileColumns.flatMap { $0.files }.count
    }

    var selectedFiles: [FileItem] {
        fileColumns.flatMap { $0.files }.filter { selectedFileIDs.contains($0.id) }
    }

    var allFiles: [FileItem] {
        fileColumns.flatMap { $0.files }
    }

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard !rootFolders.contains(where: { $0.url == url }) else { return }

        let node = FolderNode(url: url)
        rootFolders.append(node)
        rootFolders.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        persistRootFolders()
        selectedFolderIDs.insert(node.id)
        refreshFileColumns()
    }

    func toggleFolderSelection(_ id: UUID) {
        if selectedFolderIDs.contains(id) {
            selectedFolderIDs.remove(id)
        } else {
            selectedFolderIDs.insert(id)
        }
        refreshFileColumns()
    }

    func toggleFileSelection(_ id: UUID) {
        if selectedFileIDs.contains(id) {
            selectedFileIDs.remove(id)
        } else {
            selectedFileIDs.insert(id)
        }
    }

    func selectAllInCurrentColumn() {
        guard case let .column(colIndex, _) = fileListFocus else { return }
        guard colIndex < fileColumns.count else { return }
        let column = fileColumns[colIndex]
        for file in column.files {
            selectedFileIDs.insert(file.id)
        }
    }

    func setFilter(_ newFilter: MediaFilter) {
        guard filter != newFilter else { return }
        filter = newFilter
        refreshFileColumns()
    }

    func refreshFileColumns() {
        let selectedFolders = rootFolders.filter { selectedFolderIDs.contains($0.id) }
        Task {
            var columns: [FileItemColumn] = []
            for folder in selectedFolders {
                let fileURLs = await fileBrowser.listFilteredFiles(in: folder.url, filter: filter)
                let items = fileURLs.map { FileItem(url: $0) }
                let resolvedItems = await resolveMetadata(for: items)
                columns.append(FileItemColumn(
                    folderName: folder.name,
                    files: resolvedItems
                ))
            }
            fileColumns = columns
            requestThumbnailsForVisible()
        }
    }

    func resolveMetadata(for items: [FileItem]) async -> [FileItem] {
        var resolved: [FileItem] = []
        for item in items {
            let metadata = await metadataProvider.extractMetadata(for: item.url)
            let resolvedItem = FileItem(
                url: item.url,
                dimensions: metadata.dimensions,
                duration: metadata.duration
            )
            resolved.append(resolvedItem)
        }
        return resolved
    }

    func requestThumbnailsForVisible() {
        Task {
            for column in fileColumns {
                for file in column.files.prefix(50) {
                    if let image = await thumbnailGenerator.generate(for: file) {
                        thumbnailImages[file.id] = image
                    }
                }
            }
        }
    }

    func requestThumbnail(for file: FileItem) {
        Task {
            if thumbnailImages[file.id] != nil { return }
            if let image = await thumbnailGenerator.generate(for: file) {
                thumbnailImages[file.id] = image
            }
        }
    }

    func cancelThumbnail(for file: FileItem) {
        Task {
            await thumbnailGenerator.cancel(for: file)
        }
    }

    func removeFolder(_ id: UUID) {
        rootFolders.removeAll { $0.id == id }
        selectedFolderIDs.remove(id)
        persistRootFolders()
        refreshFileColumns()
    }

    func loadPersistedFolders() {
        guard let data = UserDefaults.standard.data(forKey: "MirrorImage.rootFolders") else { return }
        guard let urls = try? JSONDecoder().decode([URL].self, from: data) else { return }
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        rootFolders = existing.map { FolderNode(url: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        for folder in rootFolders {
            selectedFolderIDs.insert(folder.id)
        }
        refreshFileColumns()
    }

    private func persistRootFolders() {
        let urls = rootFolders.map { $0.url }
        guard let data = try? JSONEncoder().encode(urls) else { return }
        UserDefaults.standard.set(data, forKey: "MirrorImage.rootFolders")
    }
}

struct FileItemColumn: Identifiable {
    let id = UUID()
    let folderName: String
    let files: [FileItem]
}
