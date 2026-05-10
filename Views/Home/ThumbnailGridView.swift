import SwiftUI

struct ThumbnailGridView: View {
    let files: [FileItem]
    let thumbnailImages: [UUID: CGImage]
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 4) {
                ForEach(files.prefix(30), id: \.id) { file in
                    ThumbnailCell(
                        file: file,
                        image: thumbnailImages[file.id],
                        isSelected: viewModel.selectedFileIDs.contains(file.id),
                        onToggle: { viewModel.toggleFileSelection(file.id) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(red: 0.14, green: 0.14, blue: 0.14))
    }
}

struct ThumbnailCell: View {
    let file: FileItem
    let image: CGImage?
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        ZStack {
            if let cgImage = image {
                Image(cgImage, scale: 2.0, label: Text(file.name))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipped()
                    .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 64, height: 64)
                    .cornerRadius(4)
                    .overlay(
                        Image(systemName: file.mediaType == .video ? "play.rectangle" : "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.15))
                    )
            }

            if isSelected {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 64, height: 64)
                    .cornerRadius(4)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .position(x: 56, y: 12)
            }
        }
        .frame(width: 64, height: 64)
        .onTapGesture {
            onToggle()
        }
    }
}
