import Foundation
import Combine

private final class FSEventsBox {
    let onChange: ([URL]) -> Void

    init(onChange: @escaping ([URL]) -> Void) {
        self.onChange = onChange
    }
}

actor FileBrowserModel {
    private let fileManager = FileManager.default
    private let supportedImageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "tif", "cr2", "nef", "arw", "psd", "gif", "bmp"]
    private let supportedVideoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]
    private var fseventStream: FSEventStreamRef?
    private var monitoringBox: FSEventsBox?

    nonisolated let fileDiscoveryPublisher = PassthroughSubject<[URL], Never>()

    func listFiles(in directory: URL) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.filter { fileURL in
            guard let isFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile else { return false }
            guard isFile else { return false }
            let ext = fileURL.pathExtension.lowercased()
            return supportedImageExtensions.contains(ext) || supportedVideoExtensions.contains(ext)
        }.sorted { a, b in
            a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
        }
    }

    func listFilteredFiles(in directory: URL, filter: MediaFilter) -> [URL] {
        return listFiles(in: directory).filter { url in
            let mediaType = FileItem.resolveMediaType(from: url)
            return filter.accepts(mediaType)
        }
    }

    func detectLivePhotoPair(for heicURL: URL) -> URL? {
        let movURL = heicURL.deletingPathExtension().appendingPathExtension("mov")
        if fileManager.fileExists(atPath: movURL.path) {
            return movURL
        }

        let heicName = heicURL.deletingPathExtension().lastPathComponent
        let movName = heicName + ".mov"
        let parentDir = heicURL.deletingPathExtension().deletingLastPathComponent()
        let altMovURL = parentDir.appendingPathComponent(movName)
        if fileManager.fileExists(atPath: altMovURL.path) {
            return altMovURL
        }

        return nil
    }

    func scanDirectoryTree(at url: URL) -> FolderNode {
        return FolderNode(url: url)
    }

    func startMonitoring(directories: [URL]) {
        stopMonitoring()
        guard !directories.isEmpty else { return }

        let paths = directories.map { $0.path }

        let box = FSEventsBox { [weak self] urls in
            self?.fileDiscoveryPublisher.send(urls)
        }
        monitoringBox = box

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(box).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)

        fseventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (_, info, _, eventPaths, _, _) in
                guard let info else { return }
                let box = Unmanaged<FSEventsBox>.fromOpaque(info).takeUnretainedValue()
                guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
                box.onChange(paths.map { URL(fileURLWithPath: $0) })
            },
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            flags
        )

        if let stream = fseventStream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    func stopMonitoring() {
        if let stream = fseventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            fseventStream = nil
        }
        if let box = monitoringBox {
            Unmanaged.passUnretained(box).release()
            monitoringBox = nil
        }
    }

    var supportedExtensions: Set<String> {
        supportedImageExtensions.union(supportedVideoExtensions)
    }
}
