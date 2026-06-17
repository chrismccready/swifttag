import SwiftUI

struct TagEditorView: View {
    var albumBinding: Binding<String>?
    var albumArtistBinding: Binding<String>?
    let isSaveOperationRunning: Bool
    let isAlbumMetadataEditable: Bool
    let isSelectedAlbumMetadataEditable: Bool
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

    let trackItems: [Track]
    var selectedTrackIDsBinding: Binding<Set<UUID>>
    var showsFingerprintColumnBinding: Binding<Bool>
    var showsDurationColumnBinding: Binding<Bool>
    let titleBindingForTrack: (UUID) -> Binding<String>?
    let statusPresentationForTrack: (UUID) -> TrackStatusPresentation?
    let isTrackLocked: (UUID) -> Bool
    let hasDeletedFile: (UUID) -> Bool
    let hasTrackToTrackTitleDifference: (UUID) -> Bool
    let hasTrackToFileTitleDifference: (UUID) -> Bool
    let hasExternallyModifiedTitleDifference: (UUID) -> Bool
    let onToggleTrackLocks: () -> Void
    let lockMenuTitle: String
    let canToggleTrackLocks: Bool
    let trackTableSortMode: TrackTableSortMode
    let onSortTracks: () -> Void
    let sortTracksMenuTitle: String
    let canSortTracks: Bool
    let onSetTrackNumbers: () -> Void
    let setTrackNumbersMenuTitle: String
    let canSetTrackNumbers: Bool
    let onSetTrackNumbersByDisc: () -> Void
    let setTrackNumbersByDiscMenuTitle: String
    let canSetTrackNumbersByDisc: Bool
    let onSetTrackTotalToCount: () -> Void
    let setTrackTotalMenuTitle: String
    let canSetTrackTotal: Bool
    var onSetTrackTotalByDisc: () -> Void = {}
    var setTrackTotalByDiscMenuTitle: String = "Set Track Total by Disc (0)"
    var canSetTrackTotalByDisc: Bool = false
    let onAddFlacFiles: () -> Void
    let onAddReadOnlyFlacFiles: () -> Void
    let canAddFlacFiles: Bool
    let onReloadSelectedTracks: () -> Void
    let reloadSelectedTracksTitle: String
    let canReloadSelectedTracks: Bool
    let onRemoveSelectedTracks: () -> Void
    let removeSelectedTracksTitle: String
    let canRemoveSelectedTracks: Bool
    let onDropFlacFiles: ([NSItemProvider]) -> Bool

    var totalTracksBinding: Binding<String>?
    let isTotalTracksMixedSelection: Bool
    let hasTotalTracksMismatch: Bool
    let hasTotalTracksInternalDifference: Bool
    let totalTracksHoverMessage: String
    var totalDiscsBinding: Binding<String>?
    let hasTotalDiscsMismatch: Bool
    let totalDiscsHoverMessage: String
    let isSelectionEditable: Bool
    let hasTotalTracksExternalDifference: Bool
    let hasTotalTracksExternallyModifiedDifference: Bool
    let hasTotalDiscsExternalDifference: Bool
    let hasTotalDiscsExternallyModifiedDifference: Bool
    let hasTotalDiscsInternalDifference: Bool
    let selectedNumberBinding: Binding<String>?
    let selectedDiscBinding: Binding<String>?
    let compilationState: CompilationToggleState
    let isCompilationEditable: Bool
    let onSetCompilationEnabled: (Bool) -> Void
    let selectedGenreBinding: Binding<String>?
    let selectedArtistBinding: Binding<String>?
    let selectedComposerBinding: Binding<String>?
    let selectedLocationBinding: Binding<String>?
    let selectedDateBinding: Binding<String>?
    let selectedDescriptionsBinding: Binding<String>?
    let selectedCommentsBinding: Binding<String>?
    let hasTrackNumberInternalDifference: Bool
    let hasTrackNumberExternalDifference: Bool
    let hasTrackNumberExternallyModifiedDifference: Bool
    let hasDiscNumberInternalDifference: Bool
    let hasDiscNumberExternalDifference: Bool
    let hasDiscNumberExternallyModifiedDifference: Bool
    let hasCompilationInternalDifference: Bool
    let hasCompilationExternalDifference: Bool
    let hasCompilationExternallyModifiedDifference: Bool
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
    let hasCommentInternalDifference: Bool
    let hasCommentExternalDifference: Bool
    let hasCommentExternallyModifiedDifference: Bool
    let isTrackTotalAutoUpdateEnabled: Bool
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
    let hasInternalDifferenceForMiscTagRow: (MiscTagRow) -> Bool
    let hasExternalDifferenceForMiscTagRow: (MiscTagRow) -> Bool
    let hasExternallyModifiedDifferenceForMiscTagRow: (MiscTagRow) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TagEditorAlbumView(
                albumBinding: albumBinding,
                albumArtistBinding: albumArtistBinding,
                isSaveOperationRunning: isSaveOperationRunning,
                isMetadataEditable: isSelectedAlbumMetadataEditable,
                isArtworkEditable: isAlbumMetadataEditable,
                isAlbumMixedSelection: isAlbumMixedSelection,
                isAlbumArtistMixedSelection: isAlbumArtistMixedSelection,
                hasAlbumInternalDifference: hasAlbumInternalDifference,
                hasAlbumExternalDifference: hasAlbumExternalDifference,
                hasAlbumExternallyModifiedDifference: hasAlbumExternallyModifiedDifference,
                hasAlbumArtistInternalDifference: hasAlbumArtistInternalDifference,
                hasAlbumArtistExternalDifference: hasAlbumArtistExternalDifference,
                hasAlbumArtistExternallyModifiedDifference: hasAlbumArtistExternallyModifiedDifference,
                showsPictureDifferenceOverlay: showsPictureDifferenceOverlay,
                frontCoverImage: frontCoverImage,
                onFrontCoverDrop: onFrontCoverDrop,
                onFrontCoverTap: onFrontCoverTap
            )

            TagEditorTrackFileView(
                trackItems: trackItems,
                selection: selectedTrackIDsBinding,
                showsFingerprintColumn: showsFingerprintColumnBinding,
                showsDurationColumn: showsDurationColumnBinding,
                titleBindingForTrack: titleBindingForTrack,
                statusPresentationForTrack: statusPresentationForTrack,
                isTrackLocked: isTrackLocked,
                hasDeletedFile: hasDeletedFile,
                hasTrackToTrackTitleDifference: hasTrackToTrackTitleDifference,
                hasTrackToFileTitleDifference: hasTrackToFileTitleDifference,
                hasExternallyModifiedTitleDifference: hasExternallyModifiedTitleDifference,
                onToggleLockSelection: onToggleTrackLocks,
                lockMenuTitle: lockMenuTitle,
                canToggleLockSelection: canToggleTrackLocks,
                sortMode: trackTableSortMode,
                onSortTracks: onSortTracks,
                sortTracksMenuTitle: sortTracksMenuTitle,
                canSortTracks: canSortTracks,
                onSetTrackNumbers: onSetTrackNumbers,
                setTrackNumbersMenuTitle: setTrackNumbersMenuTitle,
                canSetTrackNumbers: canSetTrackNumbers,
                onSetTrackNumbersByDisc: onSetTrackNumbersByDisc,
                setTrackNumbersByDiscMenuTitle: setTrackNumbersByDiscMenuTitle,
                canSetTrackNumbersByDisc: canSetTrackNumbersByDisc,
                onSetTrackTotalToCount: onSetTrackTotalToCount,
                setTrackTotalMenuTitle: setTrackTotalMenuTitle,
                canSetTrackTotal: canSetTrackTotal,
                onSetTrackTotalByDisc: onSetTrackTotalByDisc,
                setTrackTotalByDiscMenuTitle: setTrackTotalByDiscMenuTitle,
                canSetTrackTotalByDisc: canSetTrackTotalByDisc,
                onAddFlacFiles: onAddFlacFiles,
                onAddReadOnlyFlacFiles: onAddReadOnlyFlacFiles,
                canAddFlacFiles: canAddFlacFiles,
                onReloadSelectedTracks: onReloadSelectedTracks,
                reloadSelectedTracksTitle: reloadSelectedTracksTitle,
                canReloadSelectedTracks: canReloadSelectedTracks,
                onRemoveSelectedTracks: onRemoveSelectedTracks,
                removeSelectedTracksTitle: removeSelectedTracksTitle,
                canRemoveSelectedTracks: canRemoveSelectedTracks,
                onDropFlacFiles: onDropFlacFiles
            )

            TagEditorCoreTagsView(
                totalTracksBinding: totalTracksBinding,
                isTotalTracksMixedSelection: isTotalTracksMixedSelection,
                hasTotalTracksMismatch: hasTotalTracksMismatch,
                hasTotalTracksInternalDifference: hasTotalTracksInternalDifference,
                totalTracksHoverMessage: totalTracksHoverMessage,
                totalDiscsBinding: totalDiscsBinding,
                hasTotalDiscsMismatch: hasTotalDiscsMismatch,
                totalDiscsHoverMessage: totalDiscsHoverMessage,
                isSelectionEditable: isSelectionEditable,
                isAlbumMetadataEditable: isAlbumMetadataEditable,
                hasTotalTracksExternalDifference: hasTotalTracksExternalDifference,
                hasTotalTracksExternallyModifiedDifference: hasTotalTracksExternallyModifiedDifference,
                hasTotalDiscsExternalDifference: hasTotalDiscsExternalDifference,
                hasTotalDiscsExternallyModifiedDifference: hasTotalDiscsExternallyModifiedDifference,
                hasTotalDiscsInternalDifference: hasTotalDiscsInternalDifference,
                selectedNumberBinding: selectedNumberBinding,
                selectedDiscBinding: selectedDiscBinding,
                compilationState: compilationState,
                isCompilationEditable: isCompilationEditable,
                onSetCompilationEnabled: onSetCompilationEnabled,
                selectedGenreBinding: selectedGenreBinding,
                selectedArtistBinding: selectedArtistBinding,
                selectedComposerBinding: selectedComposerBinding,
                selectedLocationBinding: selectedLocationBinding,
                selectedDateBinding: selectedDateBinding,
                selectedDescriptionsBinding: selectedDescriptionsBinding,
                selectedCommentsBinding: selectedCommentsBinding,
                hasTrackNumberInternalDifference: hasTrackNumberInternalDifference,
                hasTrackNumberExternalDifference: hasTrackNumberExternalDifference,
                hasTrackNumberExternallyModifiedDifference: hasTrackNumberExternallyModifiedDifference,
                hasDiscNumberInternalDifference: hasDiscNumberInternalDifference,
                hasDiscNumberExternalDifference: hasDiscNumberExternalDifference,
                hasDiscNumberExternallyModifiedDifference: hasDiscNumberExternallyModifiedDifference,
                hasCompilationInternalDifference: hasCompilationInternalDifference,
                hasCompilationExternalDifference: hasCompilationExternalDifference,
                hasCompilationExternallyModifiedDifference: hasCompilationExternallyModifiedDifference,
                hasGenreInternalDifference: hasGenreInternalDifference,
                hasGenreExternalDifference: hasGenreExternalDifference,
                hasGenreExternallyModifiedDifference: hasGenreExternallyModifiedDifference,
                hasArtistInternalDifference: hasArtistInternalDifference,
                hasArtistExternalDifference: hasArtistExternalDifference,
                hasArtistExternallyModifiedDifference: hasArtistExternallyModifiedDifference,
                hasComposerInternalDifference: hasComposerInternalDifference,
                hasComposerExternalDifference: hasComposerExternalDifference,
                hasComposerExternallyModifiedDifference: hasComposerExternallyModifiedDifference,
                hasLocationInternalDifference: hasLocationInternalDifference,
                hasLocationExternalDifference: hasLocationExternalDifference,
                hasLocationExternallyModifiedDifference: hasLocationExternallyModifiedDifference,
                hasDateInternalDifference: hasDateInternalDifference,
                hasDateExternalDifference: hasDateExternalDifference,
                hasDateExternallyModifiedDifference: hasDateExternallyModifiedDifference,
                hasDescriptionInternalDifference: hasDescriptionInternalDifference,
                hasDescriptionExternalDifference: hasDescriptionExternalDifference,
                hasDescriptionExternallyModifiedDifference: hasDescriptionExternallyModifiedDifference,
                hasCommentInternalDifference: hasCommentInternalDifference,
                hasCommentExternalDifference: hasCommentExternalDifference,
                hasCommentExternallyModifiedDifference: hasCommentExternallyModifiedDifference,
                onSetTrackTotalToCount: onSetTrackTotalToCount,
                setTrackTotalMenuTitle: setTrackTotalMenuTitle,
                canSetTrackTotal: canSetTrackTotal,
                onSetTrackTotalByDisc: onSetTrackTotalByDisc,
                setTrackTotalByDiscMenuTitle: setTrackTotalByDiscMenuTitle,
                canSetTrackTotalByDisc: canSetTrackTotalByDisc,
                isTrackTotalAutoUpdateEnabled: isTrackTotalAutoUpdateEnabled,
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
                hasInternalDifferenceForRow: hasInternalDifferenceForMiscTagRow,
                hasExternalDifferenceForRow: hasExternalDifferenceForMiscTagRow,
                hasExternallyModifiedDifferenceForRow: hasExternallyModifiedDifferenceForMiscTagRow
            )
        }
    }
}
