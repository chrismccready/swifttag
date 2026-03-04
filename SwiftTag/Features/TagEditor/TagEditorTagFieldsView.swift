import SwiftUI

struct TagEditorTagFieldsView: View {
    let totalTracks: String
    let hasTotalTracksMismatch: Bool
    let totalTracksHoverMessage: String
    var totalDiscsBinding: Binding<String>
    let hasTotalDiscsMismatch: Bool
    let totalDiscsHoverMessage: String

    let selectedNumberBinding: Binding<String>?
    let selectedDiscBinding: Binding<String>?
    let selectedGenreBinding: Binding<String>?
    let selectedArtistBinding: Binding<String>?
    let selectedComposerBinding: Binding<String>?
    let selectedLocationBinding: Binding<String>?
    let selectedDateBinding: Binding<Date>?
    let selectedDescriptionsBinding: Binding<String>?

    let positiveIntegerTransform: (Binding<String>) -> Binding<String>

    var body: some View {
        Group {
            HStack(spacing: 6) {
                Text("Number")
                if let selectedNumberBinding {
                    TextField("Number", text: positiveIntegerTransform(selectedNumberBinding))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                } else {
                    TextField("#", text: .constant(""))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .disabled(true)
                }
                Text("of")
                Text(totalTracks)
                    .fontWeight(hasTotalTracksMismatch ? .bold : .regular)
                    .foregroundStyle(hasTotalTracksMismatch ? .red : .primary)
                    .multilineTextAlignment(.center)
                    .help(totalTracksHoverMessage)
                    .padding(.trailing, 14)

                Text("Disc")
                if let selectedDiscBinding {
                    TextField("#", text: positiveIntegerTransform(selectedDiscBinding))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                } else {
                    TextField("#", text: .constant(""))
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                        .disabled(true)
                }
                Text("of")
                TextField("#", text: positiveIntegerTransform(totalDiscsBinding))
                    .fontWeight(hasTotalDiscsMismatch ? .bold : .regular)
                    .foregroundStyle(hasTotalDiscsMismatch ? .red : .primary)
                    .multilineTextAlignment(.center)
                    .frame(width: 30)
                    .help(totalDiscsHoverMessage)
                    .padding(.trailing, 40)

                Text("Genre")
                if let selectedGenreBinding {
                    TextField("Genre", text: selectedGenreBinding)
                } else {
                    TextField("Genre", text: .constant("Select track(s) to edit genre."))
                        .disabled(true)
                }
            }

            HStack {
                Text("Artist")
                if let selectedArtistBinding {
                    TextField("Artist", text: selectedArtistBinding)
                } else {
                    TextField("Artist", text: .constant("Select track(s) to edit artist."))
                        .disabled(true)
                }
            }

            HStack {
                Text("Composer")
                if let selectedComposerBinding {
                    TextField("Composer", text: selectedComposerBinding)
                } else {
                    TextField("Composer", text: .constant("Select track(s) to edit composer."))
                        .disabled(true)
                }
            }

            HStack {
                Text("Location")
                if let selectedLocationBinding {
                    TextField("Location", text: selectedLocationBinding)
                } else {
                    TextField("Location", text: .constant("Select track(s) to edit location."))
                        .disabled(true)
                }

                Text("Date")
                if let selectedDateBinding {
                    TextField("Date", value: selectedDateBinding, format: .dateTime.year().month().day())
                        .frame(width: 130)
                } else {
                    TextField("Date", value: .constant(.now), format: .dateTime.year().month().day())
                        .frame(width: 130)
                        .disabled(true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                    if let selectedDescriptionsBinding {
                        TextEditor(text: selectedDescriptionsBinding)
                            .frame(minHeight: 60, idealHeight: 60)
                    } else {
                        TextEditor(text: .constant("Select track(s) to edit description."))
                            .frame(minHeight: 60, idealHeight: 60)
                            .disabled(true)
                    }
                }
            }
            .frame(height: 60)
        }
    }
}
