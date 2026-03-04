import SwiftUI

struct TagEditorView: View {
    var albumBinding: Binding<String>
    var albumArtistBinding: Binding<String>
    let frontCoverImage: Image
    let onFrontCoverDrop: ([NSItemProvider]) -> Bool
    let onFrontCoverTap: () -> Void

    let trackItems: [Track]
    var selectedTrackIDsBinding: Binding<Set<UUID>>
    let titleBindingForTrack: (UUID) -> Binding<String>?

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

    var miscTagRowsBinding: Binding<[MiscTagRow]>
    var selectedMiscTagRowIDsBinding: Binding<Set<MiscTagRow.ID>>
    var focusedMiscTagKeyRowIDBinding: FocusState<MiscTagRow.ID?>.Binding
    let onAddMiscTagRow: () -> Void
    let onDeleteSelectedMiscTagRows: () -> Void
    let miscTagKeyBinding: (MiscTagRow.ID) -> Binding<String>?
    let miscTagValueBinding: (MiscTagRow.ID) -> Binding<String>?
    let isInvalidMiscTagKeyInput: (String, MiscTagRow.ID) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TagEditorAlbumView(
                albumBinding: albumBinding,
                albumArtistBinding: albumArtistBinding,
                frontCoverImage: frontCoverImage,
                onFrontCoverDrop: onFrontCoverDrop,
                onFrontCoverTap: onFrontCoverTap
            )

            TagEditorTrackView(
                trackItems: trackItems,
                selection: selectedTrackIDsBinding,
                titleBindingForTrack: titleBindingForTrack
            )

            TagEditorTagFieldsView(
                totalTracks: totalTracks,
                hasTotalTracksMismatch: hasTotalTracksMismatch,
                totalTracksHoverMessage: totalTracksHoverMessage,
                totalDiscsBinding: totalDiscsBinding,
                hasTotalDiscsMismatch: hasTotalDiscsMismatch,
                totalDiscsHoverMessage: totalDiscsHoverMessage,
                selectedNumberBinding: selectedNumberBinding,
                selectedDiscBinding: selectedDiscBinding,
                selectedGenreBinding: selectedGenreBinding,
                selectedArtistBinding: selectedArtistBinding,
                selectedComposerBinding: selectedComposerBinding,
                selectedLocationBinding: selectedLocationBinding,
                selectedDateBinding: selectedDateBinding,
                selectedDescriptionsBinding: selectedDescriptionsBinding,
                positiveIntegerTransform: positiveIntegerTransform
            )

            TagEditorMiscTagsView(
                rows: miscTagRowsBinding,
                selectedRowIDs: selectedMiscTagRowIDsBinding,
                focusedRowID: focusedMiscTagKeyRowIDBinding,
                onAdd: onAddMiscTagRow,
                onDelete: onDeleteSelectedMiscTagRows,
                keyBindingForRow: miscTagKeyBinding,
                valueBindingForRow: miscTagValueBinding,
                isInvalidKeyInput: isInvalidMiscTagKeyInput
            )
        }
    }
}
