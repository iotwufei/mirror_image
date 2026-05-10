import Foundation

struct ComparisonGroup: Identifiable, Equatable {
    let id: UUID
    let files: [FileItem]
    let index: Int

    init(files: [FileItem], index: Int) {
        self.id = UUID()
        self.files = files
        self.index = index
    }

    var count: Int { files.count }

    static func buildGroups(from files: [FileItem], groupSize: Int) -> [ComparisonGroup] {
        let cappedSize = min(groupSize, 20)
        let cappedFiles = Array(files.prefix(1000))
        return stride(from: 0, to: cappedFiles.count, by: cappedSize)
            .enumerated()
            .map { (index, start) in
                let end = min(start + cappedSize, cappedFiles.count)
                return ComparisonGroup(files: Array(cappedFiles[start..<end]), index: index)
            }
    }
}
