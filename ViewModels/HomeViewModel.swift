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
    @Published var columnScrollPositions: [Int: UUID?] = [:]

    let fileBrowser = FileBrowserModel()
    let thumbnailGenerator = ThumbnailGenerator()
    let metadataProvider = MediaMetadataProvider()
    private var cancellables: Set<AnyCancellable> = []
    private var selectionAnchorID: UUID?
    private var folderSelectionAnchorID: UUID?
    private var refreshGeneration = 0

    init() {
        fileBrowser.fileDiscoveryPublisher
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshFileColumns()
                }
            }
            .store(in: &cancellables)
        loadPersistedFolders()
    }

    var activeFileCount: Int {
        fileColumns.flatMap { $0.files }.count
    }

    var allFiles: [FileItem] {
        fileColumns.flatMap { $0.files }
    }

    var interleavedFiles: [FileItem] {
        guard !fileColumns.isEmpty else { return [] }
        let maxCount = fileColumns.map(\.files.count).max() ?? 0
        var result: [FileItem] = []
        for i in 0..<maxCount {
            for col in fileColumns where i < col.files.count {
                result.append(col.files[i])
            }
        }
        return result
    }

    var selectedColumnCount: Int {
        var count = 0
        for col in fileColumns {
            if col.files.contains(where: { selectedFileIDs.contains($0.id) }) {
                count += 1
            }
        }
        return count
    }

    func comparisonFiles() -> [FileItem] {
        if selectedColumnCount > 1 {
            return interleavedFiles.filter { selectedFileIDs.contains($0.id) }
        }
        return allFiles.filter { selectedFileIDs.contains($0.id) }
    }

    func selectFile(_ id: UUID) {
        selectionAnchorID = id
        selectedFileIDs = [id]
    }

    func shiftSelectFile(_ id: UUID) {
        guard let anchor = selectionAnchorID,
              let anchorLocation = fileLocation(of: anchor),
              let targetLocation = fileLocation(of: id),
              anchorLocation.column == targetLocation.column else {
            selectFile(id)
            return
        }
        let column = fileColumns[anchorLocation.column].files
        let start = min(anchorLocation.row, targetLocation.row)
        let end = max(anchorLocation.row, targetLocation.row)
        selectedFileIDs = Set(column[start...end].map(\.id))
    }

    private func fileLocation(of id: UUID) -> (column: Int, row: Int)? {
        for (columnIndex, column) in fileColumns.enumerated() {
            if let row = column.files.firstIndex(where: { $0.id == id }) {
                return (columnIndex, row)
            }
        }
        return nil
    }

    func selectFolder(_ id: UUID) {
        folderSelectionAnchorID = id
        selectedFolderIDs = [id]
        refreshFileColumns()
    }

    func shiftSelectFolder(_ id: UUID) {
        let flat = flattenedFolderOrder()
        guard let anchor = folderSelectionAnchorID,
              let anchorIndex = flat.firstIndex(where: { $0.id == anchor }),
              let targetIndex = flat.firstIndex(where: { $0.id == id }) else {
            selectFolder(id)
            return
        }
        let range = flat[min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)]
        selectedFolderIDs = Set(range.map(\.id))
        refreshFileColumns()
    }

    private func flattenedFolderOrder() -> [FolderNode] {
        var result: [FolderNode] = []
        for root in rootFolders {
            result.append(root)
            result.append(contentsOf: root.flattenedDescendants())
        }
        return result
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
        folderSelectionAnchorID = id
        refreshFileColumns()
    }

    func toggleFileSelection(_ id: UUID) {
        if selectedFileIDs.contains(id) {
            selectedFileIDs.remove(id)
        } else {
            selectedFileIDs.insert(id)
        }
        selectionAnchorID = id
    }

    func selectAllInColumn(_ columnIndex: Int) {
        guard columnIndex < fileColumns.count else { return }
        for file in fileColumns[columnIndex].files {
            selectedFileIDs.insert(file.id)
        }
    }

    func setFilter(_ newFilter: MediaFilter) {
        filter = newFilter
        refreshFileColumns()
    }

    func refreshFileColumns() {
        refreshGeneration += 1
        let generation = refreshGeneration
        let selectedFolders = selectedFolderIDs.compactMap { folderNode(withID: $0) }
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
            guard generation == refreshGeneration else { return }
            fileColumns = columns
            let visibleIDs = Set(columns.flatMap(\.files).map(\.id))
            selectedFileIDs.formIntersection(visibleIDs)
            pruneColumnScrollPositions(for: columns)
            await fileBrowser.startMonitoring(directories: selectedFolders.map(\.url))
            requestThumbnailsForVisible()
        }
    }

    func folderNode(withID id: UUID) -> FolderNode? {
        for root in rootFolders {
            if root.id == id { return root }
            if let found = root.descendant(withID: id) { return found }
        }
        return nil
    }

    private func pruneColumnScrollPositions(for columns: [FileItemColumn]) {
        for (index, column) in columns.enumerated() {
            if let saved = columnScrollPositions[index],
               let savedID = saved,
               !column.files.contains(where: { $0.id == savedID }) {
                columnScrollPositions[index] = nil
            }
        }
        let staleKeys = columnScrollPositions.keys.filter { $0 >= columns.count }
        for key in staleKeys {
            columnScrollPositions.removeValue(forKey: key)
        }
    }

    func resolveMetadata(for items: [FileItem]) async -> [FileItem] {
        await withTaskGroup(of: (Int, (CGSize?, TimeInterval?, String?)).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    let metadata = await self.metadataProvider.extractMetadata(for: item.url)
                    return (index, metadata)
                }
            }

            var resolved = [FileItem?](repeating: nil, count: items.count)
            for await (index, metadata) in group {
                let item = items[index]
                resolved[index] = FileItem(
                    url: item.url,
                    dimensions: metadata.0,
                    duration: metadata.1,
                    cameraModel: metadata.2
                )
            }
            return resolved.compactMap { $0 }
        }
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
        if let index = rootFolders.firstIndex(where: { $0.id == id }) {
            rootFolders.remove(at: index)
        } else {
            for root in rootFolders {
                if root.removeChild(withID: id) { break }
            }
        }
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
