import SwiftUI

struct TagEditorView: View {
    var albumBinding: Binding<String>
    var albumArtistBinding: Binding<String>
    let isSaveOperationRunning: Bool
    let isAlbumMetadataEditable: Bool
    let hasAlbumExternalDifference: Bool
    let hasAlbumArtistExternalDifference: Bool
    let showsPictureDifferenceOverlay: Bool
    let frontCoverImage: Image
    let onFrontCoverDrop: ([NSItemProvider]) -> Bool
    let onFrontCoverTap: () -> Void

    let trackItems: [Track]
    var selectedTrackIDsBinding: Binding<Set<UUID>>
    let titleBindingForTrack: (UUID) -> Binding<String>?
    let statusPresentationForTrack: (UUID) -> TrackStatusPresentation?
    let isTrackLocked: (UUID) -> Bool
    let hasDeletedFile: (UUID) -> Bool
    let hasExternalTitleDifference: (UUID) -> Bool
    let onToggleTrackLocks: () -> Void
    let lockMenuTitle: String
    let canToggleTrackLocks: Bool

    let totalTracks: String
    let hasTotalTracksMismatch: Bool
    let totalTracksHoverMessage: String
    var totalDiscsBinding: Binding<String>
    let hasTotalDiscsMismatch: Bool
    let totalDiscsHoverMessage: String
    let isSelectionEditable: Bool
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

    var miscTagRowsBinding: Binding<[MiscTagRow]>
    var selectedMiscTagRowIDsBinding: Binding<Set<MiscTagRow.ID>>
    var focusedMiscTagKeyRowIDBinding: FocusState<MiscTagRow.ID?>.Binding
    let isMiscTagEditingEnabled: Bool
    let onAddMiscTagRow: () -> Void
    let onDeleteSelectedMiscTagRows: () -> Void
    let miscTagKeyBinding: (MiscTagRow.ID) -> Binding<String>?
    let miscTagValueBinding: (MiscTagRow.ID) -> Binding<String>?
    let isInvalidMiscTagKeyInput: (String, MiscTagRow.ID) -> Bool
    let hasExternalDifferenceForMiscTagRow: (MiscTagRow) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TagEditorAlbumView(
                albumBinding: albumBinding,
                albumArtistBinding: albumArtistBinding,
                isSaveOperationRunning: isSaveOperationRunning,
                isMetadataEditable: isAlbumMetadataEditable,
                hasAlbumExternalDifference: hasAlbumExternalDifference,
                hasAlbumArtistExternalDifference: hasAlbumArtistExternalDifference,
                showsPictureDifferenceOverlay: showsPictureDifferenceOverlay,
                frontCoverImage: frontCoverImage,
                onFrontCoverDrop: onFrontCoverDrop,
                onFrontCoverTap: onFrontCoverTap
            )

            TagEditorTrackFileView(
                trackItems: trackItems,
                selection: selectedTrackIDsBinding,
                titleBindingForTrack: titleBindingForTrack,
                statusPresentationForTrack: statusPresentationForTrack,
                isTrackLocked: isTrackLocked,
                hasDeletedFile: hasDeletedFile,
                hasExternalTitleDifference: hasExternalTitleDifference,
                onToggleLockSelection: onToggleTrackLocks,
                lockMenuTitle: lockMenuTitle,
                canToggleLockSelection: canToggleTrackLocks
            )

            TagEditorCoreTagsView(
                totalTracks: totalTracks,
                hasTotalTracksMismatch: hasTotalTracksMismatch,
                totalTracksHoverMessage: totalTracksHoverMessage,
                totalDiscsBinding: totalDiscsBinding,
                hasTotalDiscsMismatch: hasTotalDiscsMismatch,
                totalDiscsHoverMessage: totalDiscsHoverMessage,
                isSelectionEditable: isSelectionEditable,
                isAlbumMetadataEditable: isAlbumMetadataEditable,
                hasTotalTracksExternalDifference: hasTotalTracksExternalDifference,
                hasTotalDiscsExternalDifference: hasTotalDiscsExternalDifference,
                selectedNumberBinding: selectedNumberBinding,
                selectedDiscBinding: selectedDiscBinding,
                selectedGenreBinding: selectedGenreBinding,
                selectedArtistBinding: selectedArtistBinding,
                selectedComposerBinding: selectedComposerBinding,
                selectedLocationBinding: selectedLocationBinding,
                selectedDateBinding: selectedDateBinding,
                selectedDescriptionsBinding: selectedDescriptionsBinding,
                hasTrackNumberExternalDifference: hasTrackNumberExternalDifference,
                hasDiscNumberExternalDifference: hasDiscNumberExternalDifference,
                hasGenreExternalDifference: hasGenreExternalDifference,
                hasArtistExternalDifference: hasArtistExternalDifference,
                hasComposerExternalDifference: hasComposerExternalDifference,
                hasLocationExternalDifference: hasLocationExternalDifference,
                hasDateExternalDifference: hasDateExternalDifference,
                hasDescriptionExternalDifference: hasDescriptionExternalDifference,
                positiveIntegerTransform: positiveIntegerTransform
            )

            TagEditorMiscTagsView(
                rows: miscTagRowsBinding,
                selectedRowIDs: selectedMiscTagRowIDsBinding,
                focusedRowID: focusedMiscTagKeyRowIDBinding,
                isEditingEnabled: isMiscTagEditingEnabled,
                onAdd: onAddMiscTagRow,
                onDelete: onDeleteSelectedMiscTagRows,
                keyBindingForRow: miscTagKeyBinding,
                valueBindingForRow: miscTagValueBinding,
                isInvalidKeyInput: isInvalidMiscTagKeyInput,
                hasExternalDifferenceForRow: hasExternalDifferenceForMiscTagRow
            )
        }
    }
}
