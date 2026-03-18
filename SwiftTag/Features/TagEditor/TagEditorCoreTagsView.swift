import SwiftUI

struct TagEditorCoreTagsView: View {
    var totalTracksBinding: Binding<String>?
    let isTotalTracksMixedSelection: Bool
    let hasTotalTracksMismatch: Bool
    let hasTotalTracksInternalDifference: Bool
    let totalTracksHoverMessage: String
    var totalDiscsBinding: Binding<String>?
    let hasTotalDiscsMismatch: Bool
    let totalDiscsHoverMessage: String
    let isSelectionEditable: Bool
    let isAlbumMetadataEditable: Bool
    let hasTotalTracksExternalDifference: Bool
    let hasTotalTracksExternallyModifiedDifference: Bool
    let hasTotalDiscsExternalDifference: Bool
    let hasTotalDiscsExternallyModifiedDifference: Bool
    let hasTotalDiscsInternalDifference: Bool

    let selectedNumberBinding: Binding<String>?
    let selectedDiscBinding: Binding<String>?
    let selectedGenreBinding: Binding<String>?
    let selectedArtistBinding: Binding<String>?
    let selectedComposerBinding: Binding<String>?
    let selectedLocationBinding: Binding<String>?
    let selectedDateBinding: Binding<String>?
    let selectedDescriptionsBinding: Binding<String>?
    let hasTrackNumberInternalDifference: Bool
    let hasTrackNumberExternalDifference: Bool
    let hasTrackNumberExternallyModifiedDifference: Bool
    let hasDiscNumberInternalDifference: Bool
    let hasDiscNumberExternalDifference: Bool
    let hasDiscNumberExternallyModifiedDifference: Bool
    let hasGenreInternalDifference: Bool
    let hasGenreExternalDifference: Bool
    let hasGenreExternallyModifiedDifference: Bool
    let hasArtistInternalDifference: Bool
    let hasArtistExternalDifference: Bool
    let hasArtistExternallyModifiedDifference: Bool
    let hasComposerInternalDifference: Bool
    let hasComposerExternalDifference: Bool
    let hasComposerExternallyModifiedDifference: Bool
    let hasLocationInternalDifference: Bool
    let hasLocationExternalDifference: Bool
    let hasLocationExternallyModifiedDifference: Bool
    let hasDateInternalDifference: Bool
    let hasDateExternalDifference: Bool
    let hasDateExternallyModifiedDifference: Bool
    let hasDescriptionInternalDifference: Bool
    let hasDescriptionExternalDifference: Bool
    let hasDescriptionExternallyModifiedDifference: Bool

    let positiveIntegerTransform: (Binding<String>) -> Binding<String>

    var body: some View {
        Group {
            HStack(spacing: 6) {
                Text("Number")
                if let selectedNumberBinding {
                    TextField("Number", text: positiveIntegerTransform(selectedNumberBinding))
                        .tagDiffStyle(
                            tag: .trackNumber,
                            hasTrackToTrackDifference: hasTrackNumberInternalDifference,
                            hasTrackToFileDifference: hasTrackNumberExternalDifference,
                            hasExternallyModifiedDifference: hasTrackNumberExternallyModifiedDifference
                        )
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .disabled(!isSelectionEditable)
                } else {
                    TextField("#", text: .constant(""))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .disabled(true)
                }

                Text("of")
                if let totalTracksBinding {
                    TextField("#", text: positiveIntegerTransform(totalTracksBinding))
                        .tagDiffStyle(
                            tag: .totalTracks,
                            hasTrackToTrackDifference: hasTotalTracksInternalDifference,
                            hasTrackToFileDifference: hasTotalTracksExternalDifference,
                            hasExternallyModifiedDifference: hasTotalTracksExternallyModifiedDifference,
                            showsMismatchWarning: hasTotalTracksMismatch
                        )
                        .fontWeight(isTotalTracksMixedSelection ? .bold : .regular)
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .help(totalTracksHoverMessage)
                        .padding(.trailing, 14)
                        .disabled(!isSelectionEditable)
                } else {
                    TextField("#", text: .constant(""))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .help(totalTracksHoverMessage)
                        .padding(.trailing, 14)
                        .disabled(true)
                }

                Text("Disc")
                if let selectedDiscBinding {
                    TextField("#", text: positiveIntegerTransform(selectedDiscBinding))
                        .tagDiffStyle(
                            tag: .discNumber,
                            hasTrackToTrackDifference: hasDiscNumberInternalDifference,
                            hasTrackToFileDifference: hasDiscNumberExternalDifference,
                            hasExternallyModifiedDifference: hasDiscNumberExternallyModifiedDifference
                        )
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .disabled(!isSelectionEditable)
                } else {
                    TextField("#", text: .constant(""))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .disabled(true)
                }

                Text("of")
                if let totalDiscsBinding {
                    TextField("#", text: positiveIntegerTransform(totalDiscsBinding))
                        .tagDiffStyle(
                            tag: .totalDiscs,
                            hasTrackToTrackDifference: hasTotalDiscsInternalDifference,
                            hasTrackToFileDifference: hasTotalDiscsExternalDifference,
                            hasExternallyModifiedDifference: hasTotalDiscsExternallyModifiedDifference,
                            showsMismatchWarning: hasTotalDiscsMismatch
                        )
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .help(totalDiscsHoverMessage)
                        .padding(.trailing, 40)
                        .disabled(!isAlbumMetadataEditable)
                } else {
                    TextField("#", text: .constant(""))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .help(totalDiscsHoverMessage)
                        .padding(.trailing, 40)
                        .disabled(true)
                }

                Text("Genre")
                if let selectedGenreBinding {
                    TextField("Genre", text: selectedGenreBinding)
                        .tagDiffStyle(
                            tag: .genre,
                            hasTrackToTrackDifference: hasGenreInternalDifference,
                            hasTrackToFileDifference: hasGenreExternalDifference,
                            hasExternallyModifiedDifference: hasGenreExternallyModifiedDifference
                        )
                        .disabled(!isSelectionEditable)
                } else {
                    TextField("Genre", text: .constant("Select track(s) to edit genre."))
                        .disabled(true)
                }
            }

            HStack {
                Text("Artist")
                if let selectedArtistBinding {
                    TextField("Artist", text: selectedArtistBinding)
                        .tagDiffStyle(
                            tag: .artist,
                            hasTrackToTrackDifference: hasArtistInternalDifference,
                            hasTrackToFileDifference: hasArtistExternalDifference,
                            hasExternallyModifiedDifference: hasArtistExternallyModifiedDifference
                        )
                        .disabled(!isSelectionEditable)
                } else {
                    TextField("Artist", text: .constant("Select track(s) to edit artist."))
                        .disabled(true)
                }
            }

            HStack {
                Text("Composer")
                if let selectedComposerBinding {
                    TextField("Composer", text: selectedComposerBinding)
                        .tagDiffStyle(
                            tag: .composer,
                            hasTrackToTrackDifference: hasComposerInternalDifference,
                            hasTrackToFileDifference: hasComposerExternalDifference,
                            hasExternallyModifiedDifference: hasComposerExternallyModifiedDifference
                        )
                        .disabled(!isSelectionEditable)
                } else {
                    TextField("Composer", text: .constant("Select track(s) to edit composer."))
                        .disabled(true)
                }
            }

            HStack {
                Text("Location")
                if let selectedLocationBinding {
                    TextField("Location", text: selectedLocationBinding)
                        .tagDiffStyle(
                            tag: .location,
                            hasTrackToTrackDifference: hasLocationInternalDifference,
                            hasTrackToFileDifference: hasLocationExternalDifference,
                            hasExternallyModifiedDifference: hasLocationExternallyModifiedDifference
                        )
                        .disabled(!isSelectionEditable)
                } else {
                    TextField("Location", text: .constant("Select track(s) to edit location."))
                        .disabled(true)
                }

                Text("Date")
                if let selectedDateBinding {
                    TextField("Date", text: selectedDateBinding)
                        .tagDiffStyle(
                            tag: .date,
                            hasTrackToTrackDifference: hasDateInternalDifference,
                            hasTrackToFileDifference: hasDateExternalDifference,
                            hasExternallyModifiedDifference: hasDateExternallyModifiedDifference
                        )
                        .frame(width: 130)
                        .disabled(!isSelectionEditable)
                } else {
                    TextField("Date", text: .constant(""))
                        .frame(width: 130)
                        .disabled(true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Description")
                if let selectedDescriptionsBinding {
                    TextEditor(text: selectedDescriptionsBinding)
                        .tagDiffStyle(
                            tag: .description,
                            hasTrackToTrackDifference: hasDescriptionInternalDifference,
                            hasTrackToFileDifference: hasDescriptionExternalDifference,
                            hasExternallyModifiedDifference: hasDescriptionExternallyModifiedDifference
                        )
                        .frame(minHeight: 60, idealHeight: 60)
                        .disabled(!isSelectionEditable)
                } else {
                    TextEditor(text: .constant("Select track(s) to edit description."))
                        .frame(minHeight: 60, idealHeight: 60)
                        .disabled(true)
                }
            }
            .padding(.top, 22)
            .frame(height: 60)
        }
    }
}
