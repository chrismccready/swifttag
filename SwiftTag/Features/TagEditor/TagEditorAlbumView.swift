import AppKit
import SwiftUI

struct TagEditorAlbumView: View {
    var albumBinding: Binding<String>?
    var albumArtistBinding: Binding<String>?
    let isSaveOperationRunning: Bool
    let isMetadataEditable: Bool
    let isArtworkEditable: Bool
    let isAlbumMixedSelection: Bool
    let isAlbumArtistMixedSelection: Bool
    let hasAlbumInternalDifference: Bool
    let hasAlbumExternalDifference: Bool
    let hasAlbumExternallyModifiedDifference: Bool
    let hasAlbumArtistInternalDifference: Bool
    let hasAlbumArtistExternalDifference: Bool
    let hasAlbumArtistExternallyModifiedDifference: Bool
    let showsPictureDifferenceOverlay: Bool
    let frontCoverImage: Image
    let onFrontCoverDrop: ([NSItemProvider]) -> Bool
    let onFrontCoverTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Album")
                    if let albumBinding {
                        TextField("Album", text: albumBinding)
                            .tagDiffStyle(
                                tag: .album,
                                hasTrackToTrackDifference: hasAlbumInternalDifference,
                                hasTrackToFileDifference: hasAlbumExternalDifference,
                                hasExternallyModifiedDifference: hasAlbumExternallyModifiedDifference
                            )
                            .fontWeight(isAlbumMixedSelection ? .bold : .regular)
                            .disabled(!isMetadataEditable)
                            .accessibilityIdentifier("albumTextField")
                    } else {
                        TextField("Album", text: .constant("Select track(s) to edit album."))
                            .disabled(true)
                            .accessibilityIdentifier("albumTextField")
                    }
                }

                HStack {
                    Text("Album Artist")
                    if let albumArtistBinding {
                        TextField("Album Artist", text: albumArtistBinding)
                            .tagDiffStyle(
                                tag: .albumArtist,
                                hasTrackToTrackDifference: hasAlbumArtistInternalDifference,
                                hasTrackToFileDifference: hasAlbumArtistExternalDifference,
                                hasExternallyModifiedDifference: hasAlbumArtistExternallyModifiedDifference
                            )
                            .fontWeight(isAlbumArtistMixedSelection ? .bold : .regular)
                            .disabled(!isMetadataEditable)
                            .accessibilityIdentifier("albumArtistTextField")
                    } else {
                        TextField("Album Artist", text: .constant("Select track(s) to edit album artist."))
                            .disabled(true)
                            .accessibilityIdentifier("albumArtistTextField")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            AlbumArtWellView(
                image: frontCoverImage,
                dimension: 60,
                onDropProviders: onFrontCoverDrop,
                isEnabled: isArtworkEditable && !isSaveOperationRunning,
                showsExternalDifferenceOverlay: showsPictureDifferenceOverlay
            )
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                guard isArtworkEditable, !isSaveOperationRunning else {
                    return
                }
                onFrontCoverTap()
            }
            .contextMenu {
                Button("Show Picture Browser") {
                    onFrontCoverTap()
                }
                .disabled(!isArtworkEditable || isSaveOperationRunning)
            }
            .help("Double-click to edit album art or drag and drop an image to set album Front Cover.")
            .accessibilityIdentifier("albumArtImageWell")
        }
    }
}
