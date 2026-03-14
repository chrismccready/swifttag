import AppKit
import SwiftUI

struct TagEditorAlbumView: View {
    var albumBinding: Binding<String>
    var albumArtistBinding: Binding<String>
    let isSaveOperationRunning: Bool
    let isMetadataEditable: Bool
    let hasAlbumExternalDifference: Bool
    let hasAlbumArtistExternalDifference: Bool
    let showsPictureDifferenceOverlay: Bool
    let frontCoverImage: Image
    let onFrontCoverDrop: ([NSItemProvider]) -> Bool
    let onFrontCoverTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Album")
                    TextField("Album", text: albumBinding)
                        .externalDifferenceStyle(hasAlbumExternalDifference)
                        .disabled(!isMetadataEditable)
                        .accessibilityIdentifier("albumTextField")
                }

                HStack {
                    Text("Album Artist")
                    TextField("Album Artist", text: albumArtistBinding)
                        .externalDifferenceStyle(hasAlbumArtistExternalDifference)
                        .disabled(!isMetadataEditable)
                        .accessibilityIdentifier("albumArtistTextField")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            AlbumArtWellView(
                image: frontCoverImage,
                dimension: 60,
                onDropProviders: onFrontCoverDrop,
                isEnabled: isMetadataEditable && !isSaveOperationRunning,
                showsExternalDifferenceOverlay: showsPictureDifferenceOverlay
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard isMetadataEditable, !isSaveOperationRunning else {
                    return
                }
                onFrontCoverTap()
            }
            .help("Click to edit album art or drag and drop an image to set album Front Cover.")
            .accessibilityIdentifier("albumArtImageWell")
        }
    }
}

private extension View {
    @ViewBuilder
    func externalDifferenceStyle(_ isHighlighted: Bool) -> some View {
        if isHighlighted {
            self
                .foregroundStyle(.red)
                .italic()
        } else {
            self
        }
    }
}
