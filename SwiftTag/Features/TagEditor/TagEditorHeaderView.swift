import AppKit
import SwiftUI

struct TagEditorHeaderView: View {
    var albumBinding: Binding<String>
    var albumArtistBinding: Binding<String>
    let frontCoverImage: Image
    let onFrontCoverDrop: ([NSItemProvider]) -> Bool
    let onFrontCoverTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Album")
                    TextField("Album", text: albumBinding)
                        .accessibilityIdentifier("albumTextField")
                }

                HStack {
                    Text("Album Artist")
                    TextField("Album Artist", text: albumArtistBinding)
                        .accessibilityIdentifier("albumArtistTextField")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            AlbumArtWellView(
                image: frontCoverImage,
                dimension: 60,
                onDropProviders: onFrontCoverDrop
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onFrontCoverTap()
            }
            .help("Click to edit album art or drag and drop an image to set album Front Cover.")
            .accessibilityIdentifier("albumArtImageWell")
        }
    }
}
