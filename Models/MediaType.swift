import Foundation

enum MediaType: Equatable {
    case image
    case video
    case livePhoto
    case unknown
}

enum MediaFilter: String, CaseIterable {
    case all = "All"
    case images = "Images"
    case videos = "Videos"

    func accepts(_ type: MediaType) -> Bool {
        switch self {
        case .all: return type != .unknown
        case .images: return type == .image || type == .livePhoto
        case .videos: return type == .video || type == .livePhoto
        }
    }
}

enum VideoControlMode {
    case synchronized
    case independent(layerIndex: Int)
}
