import Foundation

final class FolderNode: Identifiable, ObservableObject {
    let id: UUID
    let url: URL
    let name: String
    let path: String

    @Published var isSelected: Bool = false
    @Published var isExpanded: Bool = false
    @Published var children: [FolderNode] = []
    @Published var isLeaf: Bool = false

    private let fileManager = FileManager.default

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.path = url.path
        self.isLeaf = !FolderNode.hasSubdirectories(at: url)
    }

    func loadChildren() {
        guard !isLeaf else { return }
        let subdirs = FolderNode.subdirectories(at: url)
        children = subdirs.map { FolderNode(url: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        isLeaf = children.isEmpty
    }

    static func hasSubdirectories(at url: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return false }

        while let fileURL = enumerator.nextObject() as? URL {
            let resourceValues = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey])) ?? URLResourceValues()
            if resourceValues.isDirectory == true {
                return true
            }
            enumerator.skipDescendants()
        }
        return false
    }

    static func subdirectories(at url: URL) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.filter { url in
            guard let isDir = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory else { return false }
            return isDir
        }
    }
}

extension FolderNode: Hashable {
    static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
