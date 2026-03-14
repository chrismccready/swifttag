import SwiftUI

struct TagEditorCoreTagsView: View {
    let totalTracks: String
    let hasTotalTracksMismatch: Bool
    let totalTracksHoverMessage: String
    var totalDiscsBinding: Binding<String>
    let hasTotalDiscsMismatch: Bool
    let totalDiscsHoverMessage: String
    let isSelectionEditable: Bool
    let isAlbumMetadataEditable: Bool
    let hasTotalTracksExternalDifference: Bool
    let hasTotalDiscsExternalDifference: Bool

    let selectedNumberBinding: Binding<String>?
    let selectedDiscBinding: Binding<String>?
    let selectedGenreBinding: Binding<String>?
    let selectedArtistBinding: Binding<String>?
    let selectedComposerBinding: Binding<String>?
    let selectedLocationBinding: Binding<String>?
    let selectedDateBinding: Binding<Date>?
    let selectedDescriptionsBinding: Binding<String>?
    let hasTrackNumberExternalDifference: Bool
    let hasDiscNumberExternalDifference: Bool
    let hasGenreExternalDifference: Bool
    let hasArtistExternalDifference: Bool
    let hasComposerExternalDifference: Bool
    let hasLocationExternalDifference: Bool
    let hasDateExternalDifference: Bool
    let hasDescriptionExternalDifference: Bool

    let positiveIntegerTransform: (Binding<String>) -> Binding<String>

    var body: some View {
        Group {
            HStack(spacing: 6) {
                Text("Number")
                if let selectedNumberBinding {
                    TextField("Number", text: positiveIntegerTransform(selectedNumberBinding))
                        .externalDifferenceStyle(hasTrackNumberExternalDifference)
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
                Text(totalTracks)
                    .fontWeight(hasTotalTracksMismatch ? .bold : .regular)
                    .foregroundStyle(hasTotalTracksMismatch || hasTotalTracksExternalDifference ? .red : .primary)
                    .multilineTextAlignment(.center)
                    .if(hasTotalTracksExternalDifference) { view in view.italic() }
                    .help(totalTracksHoverMessage)
                    .padding(.trailing, 14)

                Text("Disc")
                if let selectedDiscBinding {
                    TextField("#", text: positiveIntegerTransform(selectedDiscBinding))
                        .externalDifferenceStyle(hasDiscNumberExternalDifference)
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
                TextField("#", text: positiveIntegerTransform(totalDiscsBinding))
                    .fontWeight(hasTotalDiscsMismatch ? .bold : .regular)
                    .foregroundStyle(hasTotalDiscsMismatch || hasTotalDiscsExternalDifference ? .red : .primary)
                    .if(hasTotalDiscsExternalDifference) { view in view.italic() }
                    .multilineTextAlignment(.center)
                    .frame(width: 30)
                    .help(totalDiscsHoverMessage)
                    .padding(.trailing, 40)
                    .disabled(!isAlbumMetadataEditable)

                Text("Genre")
                if let selectedGenreBinding {
                    TextField("Genre", text: selectedGenreBinding)
                        .externalDifferenceStyle(hasGenreExternalDifference)
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
                        .externalDifferenceStyle(hasArtistExternalDifference)
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
                        .externalDifferenceStyle(hasComposerExternalDifference)
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
                        .externalDifferenceStyle(hasLocationExternalDifference)
                        .disabled(!isSelectionEditable)
                } else {
                    TextField("Location", text: .constant("Select track(s) to edit location."))
                        .disabled(true)
                }

                Text("Date")
                if let selectedDateBinding {
                    TextField("Date", value: selectedDateBinding, format: .dateTime.year().month().day())
                        .externalDifferenceStyle(hasDateExternalDifference)
                        .frame(width: 130)
                        .disabled(!isSelectionEditable)
                } else {
                    TextField("Date", value: .constant(.now), format: .dateTime.year().month().day())
                        .frame(width: 130)
                        .disabled(true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Description")
                if let selectedDescriptionsBinding {
                    TextEditor(text: selectedDescriptionsBinding)
                        .font(hasDescriptionExternalDifference ? .body.italic() : .body)
                        .foregroundStyle(hasDescriptionExternalDifference ? .red : .primary)
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

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
