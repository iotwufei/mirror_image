import SwiftUI

struct FileRowView: View {
    let file: FileItem
    let isSelected: Bool
    let thumbnail: CGImage?
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            thumbnailView
                .frame(width: 36, height: 36)
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(file.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)

                    if file.mediaType == .livePhoto {
                        Image(systemName: "livephoto")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                    }
                }

                HStack(spacing: 8) {
                    Text(file.formattedFileSize)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))

                    if let dimensions = file.dimensions {
                        Text("\(Int(dimensions.width))×\(Int(dimensions.height))")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    if let duration = file.duration {
                        Text(formatDuration(duration))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }

            Spacer()

            fileTypeBadge
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundForState)
    }

    private var thumbnailView: some View {
        Group {
            if let cgImage = thumbnail {
                Image(cgImage, scale: 2.0, label: Text(file.name))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                    Image(systemName: file.mediaType == .video ? "play.rectangle" : "photo")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.2))
                }
            }
        }
        .clipped()
    }

    private var fileTypeBadge: some View {
        Group {
            switch file.mediaType {
            case .video:
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.accentColor)
            case .livePhoto:
                Image(systemName: "livephoto")
                    .font(.system(size: 8))
                    .foregroundColor(.accentColor)
            default:
                EmptyView()
            }
        }
    }

    private var backgroundForState: some View {
        if isFocused {
            return Color.accentColor.opacity(0.15)
        } else if isSelected {
            return Color.accentColor.opacity(0.25)
        } else {
            return Color.clear
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
