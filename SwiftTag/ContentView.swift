//
//  ContentView.swift
//  SwiftTag
//
//  Created by Christopher McCready on 2/24/26.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    private enum DestructiveAction {
        case loadFiles
        case reloadSelectedTracks
        case removeSelectedTracks
    }

    private enum SwiftTagDocumentSaveDestinationMode {
        case rememberedOrPrompt
        case rememberedOnly
        case promptForNewDocument
    }

    private enum DeletedSwiftTagDocumentRecoveryChoice {
        case saveNewDocument
        case recreateOriginal
        case cancel
    }

    private enum SwiftTagDocumentSaveFlowError: LocalizedError {
        case uiTestForcedFailure
        case failedToResolveSecurityScopedDocument(path: String)
        case failedToAccessSecurityScopedDocument(path: String)

        var errorDescription: String? {
            switch self {
            case .uiTestForcedFailure:
                return "Simulated SwiftTag document save failure."
            case let .failedToResolveSecurityScopedDocument(path):
                return "Failed to resolve security-scoped access for \(path). Reopen the document and try again."
            case let .failedToAccessSecurityScopedDocument(path):
                return "Failed to access \(path) for saving."
            }
        }
    }

    private struct TrackMonitoringReferenceKey: Equatable {
        let id: UUID
        let sourceFilePath: String?
        let securityScopedBookmarkData: Data?
    }

    private struct DestructiveAlertContext {
        let title: String
        let message: String
        let confirmTitle: String
        let action: DestructiveAction
    }

    @Binding private var sessionValue: EditorSessionValue
    private let albumArtTypes: [AlbumArtType] = [
        AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
        AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover),
        AlbumArtType(flacPictureType: 5, flacDescription: "Leaflet page", navigationLinkName: "Leaflet", slot: .leaflet),
        AlbumArtType(flacPictureType: 6, flacDescription: "Media", navigationLinkName: "Media", slot: .media),
        AlbumArtType(flacPictureType: 7, flacDescription: "Lead artist/lead performer/soloist", navigationLinkName: "Lead Artist", slot: .leadArtist),
        AlbumArtType(flacPictureType: 8, flacDescription: "Artist/performer", navigationLinkName: "Artist", slot: .artist),
        AlbumArtType(flacPictureType: 9, flacDescription: "Conductor", navigationLinkName: "Conductor", slot: .conductor),
        AlbumArtType(flacPictureType: 10, flacDescription: "Band/Orchestra", navigationLinkName: "Band", slot: .band),
        AlbumArtType(flacPictureType: 11, flacDescription: "Composer", navigationLinkName: "Composer", slot: .composer),
        AlbumArtType(flacPictureType: 12, flacDescription: "Lyricist/text writer", navigationLinkName: "Lyricist", slot: .lyricist),
        AlbumArtType(flacPictureType: 13, flacDescription: "Recording location", navigationLinkName: "Recording Studio or Location", slot: .recordingStudioOrLocation),
        AlbumArtType(flacPictureType: 14, flacDescription: "During recording", navigationLinkName: "Recording Session", slot: .recordingSession),
        AlbumArtType(flacPictureType: 15, flacDescription: "During performance", navigationLinkName: "Performance", slot: .performance),
        AlbumArtType(flacPictureType: 16, flacDescription: "Movie/video capture", navigationLinkName: "Capture from Movie or Video", slot: .captureFromMovieOrVideo),
        AlbumArtType(flacPictureType: 17, flacDescription: "Bright coloured fish", navigationLinkName: "Bright(ly) Colored Fish", slot: .brightlyColoredFish),
        AlbumArtType(flacPictureType: 18, flacDescription: "Illustration", navigationLinkName: "Illustration", slot: .illustration),
        AlbumArtType(flacPictureType: 19, flacDescription: "Band/artist logotype", navigationLinkName: "Band Logo", slot: .bandLogo),
        AlbumArtType(flacPictureType: 20, flacDescription: "Publisher/studio logotype", navigationLinkName: "Publisher Logo", slot: .publisherLogo),
        AlbumArtType(flacPictureType: 1, flacDescription: "32x32 pixels file icon (PNG only)", navigationLinkName: "32x32 PNG Icon", slot: .pngIcon),
        AlbumArtType(flacPictureType: 2, flacDescription: "Other file icon", navigationLinkName: "Other Icon", slot: .otherIcon),
        AlbumArtType(flacPictureType: 0, flacDescription: "Other", navigationLinkName: "Other", slot: .other)
    ]

    @State private var isTomlSheetPresented: Bool = false
    @State private var isFlacImporterPresented: Bool = false
    @State private var pendingImporterLockedState: Bool = false
    @State private var pendingImporterAddsFiles: Bool = false
    @State private var isImportErrorPresented: Bool = false
    @State private var isSaveErrorPresented: Bool = false
    @State private var isSaveNewSwiftTagDocumentPromptPresented: Bool = false
    @State private var isDestructiveAlertPresented: Bool = false
    @State private var isAlbumArtSheetPresented: Bool = false
    @State private var askToSaveNewSwiftTagDocumentOk: Bool = true
    @State private var importErrorMessage: String = ""
    @State private var saveErrorMessage: String = ""
    @State private var destructiveAlertContext: DestructiveAlertContext?
    @State private var pendingDestructiveAction: (() -> Void)?
    @State private var viewModel: TagEditorViewModel = .init()
    @State private var albumArtViewModel: AlbumArtViewModel = .init()
    @State private var saveStatusState: SaveStatusState?
    @State private var isSaveStatusVisible: Bool = false
    @State private var isSaveOperationRunning: Bool = false
    @State private var hasPerformedInitialUITestSetup: Bool = false
    @State private var didPerformUITestPostSaveReferenceMutation: Bool = false
    @State private var loadedReopenRecordID: UUID?
    @State private var uiTestFileActionTask: Task<Void, Never>?
    @State private var trackFileMonitor: TrackFileMonitor = .init()
    @State private var swiftTagDocumentMonitor: SwiftTagDocumentMonitor = .init()
    @FocusState private var focusedMiscTagKeyRowID: MiscTagRow.ID?
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SaveSettingsKey.defaultSavePayload) private var defaultSavePayloadRawValue: String = SaveSettingsDefaults.defaultSavePayload.rawValue
    @AppStorage(SaveSettingsKey.defaultSaveScope) private var defaultSaveScopeRawValue: String = SaveSettingsDefaults.defaultSaveScope.rawValue
    @AppStorage(SaveSettingsKey.saveReferencedSwiftTagDocument) private var saveReferencedSwiftTagDocument: Bool = SaveSettingsDefaults.saveReferencedSwiftTagDocument
    @AppStorage(SaveSettingsKey.askToSaveNewSwiftTagDocument) private var askToSaveNewSwiftTagDocument: Bool = SaveSettingsDefaults.askToSaveNewSwiftTagDocument
    @AppStorage(SaveSettingsKey.zeroPadTrackNumber) private var zeroPadTrackNumber: Bool = SaveSettingsDefaults.zeroPadTrackNumber
    @AppStorage(SaveSettingsKey.trackCountKeyStrategy) private var trackCountKeyStrategyRawValue: String = SaveSettingsDefaults.trackCountKeyStrategy.rawValue
    @AppStorage(SaveSettingsKey.zeroPadDiscNumber) private var zeroPadDiscNumber: Bool = SaveSettingsDefaults.zeroPadDiscNumber
    @AppStorage(SaveSettingsKey.discCountKeyStrategy) private var discCountKeyStrategyRawValue: String = SaveSettingsDefaults.discCountKeyStrategy.rawValue
    @AppStorage(SaveSettingsKey.autoUpdateTrackTotal) private var autoUpdateTrackTotal: Bool = SaveSettingsDefaults.autoUpdateTrackTotal
    @AppStorage(SaveSettingsKey.applyCompilationToAllTracks) private var applyCompilationToAllTracks: Bool = SaveSettingsDefaults.applyCompilationToAllTracks
    @AppStorage(SaveSettingsKey.saveFrontCoverToAllTracks) private var saveFrontCoverToAllTracks: Bool = SaveSettingsDefaults.saveFrontCoverToAllTracks
    @AppStorage(SaveSettingsKey.saveAllPicturesToAllTracks) private var saveAllPicturesToAllTracks: Bool = SaveSettingsDefaults.saveAllPicturesToAllTracks
    @AppStorage(FeedbackSettingsKey.themePreference) private var themePreferenceRawValue: String = FeedbackSettingsDefaults.themePreference.rawValue
    @AppStorage(FeedbackSettingsKey.showTrackFingerprintColumn) private var showTrackFingerprintColumn: Bool = FeedbackSettingsDefaults.showTrackFingerprintColumn
    @AppStorage(FeedbackSettingsKey.formatOnTrackTotalMismatch) private var formatOnTrackTotalMismatch: Bool = FeedbackSettingsDefaults.formatOnTrackTotalMismatch
    @AppStorage(FeedbackSettingsKey.formatOnDiscTotalMismatch) private var formatOnDiscTotalMismatch: Bool = FeedbackSettingsDefaults.formatOnDiscTotalMismatch

    private var totalDiscs: String {
        get { viewModel.totalDiscs }
        set { viewModel.totalDiscs = newValue }
    }

    private var selectedTrackIDs: Set<UUID> {
        get { viewModel.selectedTrackIDs }
        set { viewModel.selectedTrackIDs = newValue }
    }

    private var miscTagRows: [MiscTagRow] {
        get { viewModel.miscTagRows }
        set { viewModel.miscTagRows = newValue }
    }

    private var selectedMiscTagRowIDs: Set<MiscTagRow.ID> {
        get { viewModel.selectedMiscTagRowIDs }
        set { viewModel.selectedMiscTagRowIDs = newValue }
    }

    private var trackItems: [Track] {
        get { viewModel.trackItems }
        set { viewModel.trackItems = newValue }
    }

    private var trackMonitoringReferenceKeys: [TrackMonitoringReferenceKey] {
        viewModel.trackItems.map { track in
            TrackMonitoringReferenceKey(
                id: track.id,
                sourceFilePath: track.sourceFileURL?.standardizedFileURL.path,
                securityScopedBookmarkData: track.securityScopedBookmarkData
            )
        }
    }

    private var themePreference: AppThemePreference {
        AppThemePreference(rawValue: themePreferenceRawValue) ?? FeedbackSettingsDefaults.themePreference
    }

    private var trackCountKeyStrategy: TrackCountKeyStrategy {
        TrackCountKeyStrategy(rawValue: trackCountKeyStrategyRawValue) ?? SaveSettingsDefaults.trackCountKeyStrategy
    }

    private var discCountKeyStrategy: DiscCountKeyStrategy {
        DiscCountKeyStrategy(rawValue: discCountKeyStrategyRawValue) ?? SaveSettingsDefaults.discCountKeyStrategy
    }

    private var albumBinding: Binding<String>? {
        viewModel.selectedAlbumBinding()
    }

    private var albumArtistBinding: Binding<String>? {
        viewModel.selectedAlbumArtistBinding()
    }

    private var totalTracksBinding: Binding<String>? {
        viewModel.selectedTotalTracksBinding()
    }

    private var totalDiscsBinding: Binding<String>? {
        viewModel.selectedTotalDiscsBinding()
    }

    private var selectedTrackIDsBinding: Binding<Set<UUID>> {
        Binding(
            get: { viewModel.selectedTrackIDs },
            set: { viewModel.selectedTrackIDs = $0 }
        )
    }

    private var miscTagRowsBinding: Binding<[MiscTagRow]> {
        Binding(
            get: { viewModel.miscTagRows },
            set: { viewModel.miscTagRows = $0 }
        )
    }

    private var selectedMiscTagRowIDsBinding: Binding<Set<MiscTagRow.ID>> {
        Binding(
            get: { viewModel.selectedMiscTagRowIDs },
            set: { viewModel.selectedMiscTagRowIDs = $0 }
        )
    }


    private func titleBinding(for trackID: UUID) -> Binding<String>? {
        viewModel.titleBinding(for: trackID)
    }

    private func tagBinding(for trackID: UUID, tagName: String) -> Binding<String>? {
        viewModel.tagBinding(for: trackID, tagName: tagName)
    }

    private func selectedTagBinding(tagName: String) -> Binding<String>? {
        viewModel.selectedTagBinding(tagName: tagName)
    }

    private var selectedDateBinding: Binding<String>? {
        viewModel.selectedDateTextBinding()
    }

    private var selectedArtistBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.artist)
    }

    private var selectedComposerBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.composer)
    }

    private var selectedLocationBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.location)
    }

    private var selectedDescriptionsBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.description)
    }

    private var selectedNumberBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.trackNumber)
    }

    private var selectedDiscBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.discNumber)
    }

    private var compilationTrackIDs: Set<UUID> {
        viewModel.compilationTrackIDs(applyToAllTracks: applyCompilationToAllTracks)
    }

    private var compilationState: CompilationToggleState {
        viewModel.compilationToggleState(applyToAllTracks: applyCompilationToAllTracks) ?? .off
    }

    private var isCompilationEditable: Bool {
        !isSaveOperationRunning && viewModel.canEditCompilation(applyToAllTracks: applyCompilationToAllTracks)
    }

    private var selectedGenreBinding: Binding<String>? {
        selectedTagBinding(tagName: TagKey.genre)
    }

    private var hasTotalTracksMismatch: Bool {
        formatOnTrackTotalMismatch &&
            trackCountKeyStrategy != .none &&
            viewModel.hasTotalTracksMismatch
    }

    private var totalTracksHoverMessage: String {
        viewModel.totalTracksHoverMessage
    }

    private var hasTotalDiscsMismatch: Bool {
        formatOnDiscTotalMismatch &&
            discCountKeyStrategy != .none &&
            viewModel.hasTotalDiscsMismatch
    }

    private var totalDiscsHoverMessage: String {
        viewModel.totalDiscsHoverMessage
    }

    private var isAlbumMetadataEditable: Bool {
        viewModel.hasUnlockedTracks && !isSaveOperationRunning
    }

    private var isSelectedAlbumMetadataEditable: Bool {
        isSelectionEditable
    }

    private var isSelectionEditable: Bool {
        viewModel.isSelectionEditable() && !isSaveOperationRunning
    }

    private var lockMenuTitle: String {
        viewModel.lockMenuTitle(for: selectedTrackIDs) ?? "Toggle Selected Tracks Lock"
    }

    private var hasAlbumExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.album])
    }

    private var hasAlbumExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifference(forAnyOf: [TagKey.album])
    }

    private var hasAlbumArtistExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.albumArtist])
    }

    private var hasAlbumArtistExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifference(forAnyOf: [TagKey.albumArtist])
    }

    private var hasAlbumInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(forAnyOf: [TagKey.album])
    }

    private var hasAlbumArtistInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(forAnyOf: [TagKey.albumArtist])
    }

    private var hasPictureDifference: Bool {
        viewModel.hasExternalPictureDifference()
    }

    private var hasTotalTracksExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(forAnyOf: ["TOTALTRACKS", "TRACKTOTAL"])
    }

    private var hasTotalTracksExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifference(forAnyOf: ["TOTALTRACKS", "TRACKTOTAL"])
    }

    private var hasTotalTracksInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(forAnyOf: ["TOTALTRACKS", "TRACKTOTAL"])
    }

    private var hasTotalDiscsExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(
            forAnyOf: ["TOTALDISCS", "DISCTOTAL"],
            in: Set(viewModel.trackItems.map(\.id))
        )
    }

    private var hasTotalDiscsExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifferenceForAnyLoadedTrack(keys: ["TOTALDISCS", "DISCTOTAL"])
    }

    private var hasTotalDiscsInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(
            forAnyOf: ["TOTALDISCS", "DISCTOTAL"],
            in: Set(viewModel.trackItems.map(\.id))
        )
    }

    private var canToggleTrackLocks: Bool {
        !selectedTrackIDs.isEmpty && !isSaveOperationRunning
    }

    private var setTrackTotalMenuTitle: String {
        "Set Track Total (\(viewModel.nonDeletedTrackCount))"
    }

    private var canSetTrackTotal: Bool {
        !isSaveOperationRunning && viewModel.nonDeletedTrackCount > 0 && !autoUpdateTrackTotal
    }

    private var canAddFlacFiles: Bool {
        !isSaveOperationRunning
    }

    private var pictureBrowserMenuTitle: String {
        isAlbumArtSheetPresented ? "Hide Picture Browser" : "Show Picture Browser"
    }

    private var canTogglePictureBrowser: Bool {
        true
    }

    private var canSaveSwiftTagDocument: Bool {
        !isSaveOperationRunning && viewModel.canSaveSwiftTagDocument()
    }

    private var reloadSelectedTracksTitle: String {
        selectedTrackIDs.count == 1 ? "Reload Selected Track" : "Reload Selected Tracks"
    }

    private var canReloadSelectedTracks: Bool {
        guard !isSaveOperationRunning, !selectedTrackIDs.isEmpty else {
            return false
        }
        return viewModel.hasDifferences(
            in: selectedTrackIDs,
            tagWriteOptions: saveSettingsSnapshot.tagWriteOptions,
            albumArtPictures: currentAlbumArtPictures
        )
    }

    private var removeSelectedTracksTitle: String {
        selectedTrackIDs.count == 1 ? "Remove Selected Track" : "Remove Selected Tracks"
    }

    private var canRemoveSelectedTracks: Bool {
        !isSaveOperationRunning && !selectedTrackIDs.isEmpty
    }

    private var hasTrackNumberExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.trackNumber])
    }

    private var hasTrackNumberExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifference(forAnyOf: [TagKey.trackNumber])
    }

    private var hasTrackNumberInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(forAnyOf: [TagKey.trackNumber])
    }

    private var hasDiscNumberExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.discNumber])
    }

    private var hasDiscNumberExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifference(forAnyOf: [TagKey.discNumber])
    }

    private var hasDiscNumberInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(forAnyOf: [TagKey.discNumber])
    }

    private var hasCompilationExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.compilation], in: compilationTrackIDs)
    }

    private var hasCompilationExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifference(forAnyOf: [TagKey.compilation], in: compilationTrackIDs)
    }

    private var hasCompilationInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(forAnyOf: [TagKey.compilation], in: compilationTrackIDs)
    }

    private var hasGenreExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.genre])
    }

    private var hasGenreExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifference(forAnyOf: [TagKey.genre])
    }

    private var hasGenreInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(forAnyOf: [TagKey.genre])
    }

    private var hasArtistExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.artist])
    }

    private var hasArtistExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifference(forAnyOf: [TagKey.artist])
    }

    private var hasArtistInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(forAnyOf: [TagKey.artist])
    }

    private var hasComposerExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.composer])
    }

    private var hasComposerExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifference(forAnyOf: [TagKey.composer])
    }

    private var hasComposerInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(forAnyOf: [TagKey.composer])
    }

    private var hasLocationExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.location])
    }

    private var hasLocationExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifference(forAnyOf: [TagKey.location])
    }

    private var hasLocationInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(forAnyOf: [TagKey.location])
    }

    private var hasDateExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.date])
    }

    private var hasDateExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifference(forAnyOf: [TagKey.date])
    }

    private var hasDateInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(forAnyOf: [TagKey.date])
    }

    private var hasDescriptionExternalDifference: Bool {
        viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.description])
    }

    private var hasDescriptionExternallyModifiedDifference: Bool {
        viewModel.hasExternalDifference(forAnyOf: [TagKey.description])
    }

    private var hasDescriptionInternalDifference: Bool {
        viewModel.hasTrackToTrackDifference(forAnyOf: [TagKey.description])
    }

    private var trackStatusPresentationLookup: (UUID) -> TrackStatusPresentation? {
        { trackID in
            viewModel.trackStatusPresentation(
                for: trackID,
                tagWriteOptions: saveSettingsSnapshot.tagWriteOptions,
                albumArtPictures: currentAlbumArtPictures
            )
        }
    }

    private var hasExternallyModifiedTitleDifferenceLookup: (UUID) -> Bool {
        { trackID in
            viewModel.hasExternalTagDifference(for: trackID, key: TagKey.title)
        }
    }

    private var hasTrackToFileTitleDifferenceLookup: (UUID) -> Bool {
        { trackID in
            viewModel.hasTrackToFileTagDifference(for: trackID, key: TagKey.title)
        }
    }

    private var hasTrackToTrackTitleDifferenceLookup: (UUID) -> Bool {
        { _ in
            false
        }
    }

    private var hasExternalDifferenceForMiscTagRowLookup: (MiscTagRow) -> Bool {
        { row in
            viewModel.hasTrackToFileDifference(forMiscTagRow: row)
        }
    }

    private var hasExternallyModifiedDifferenceForMiscTagRowLookup: (MiscTagRow) -> Bool {
        { row in
            viewModel.hasExternalDifference(forMiscTagRow: row)
        }
    }

    private var hasInternalDifferenceForMiscTagRowLookup: (MiscTagRow) -> Bool {
        { row in
            viewModel.hasTrackToTrackDifference(forAnyOf: [row.key])
        }
    }

    private var editorView: TagEditorView {
        TagEditorView(
            albumBinding: albumBinding,
            albumArtistBinding: albumArtistBinding,
            isSaveOperationRunning: isSaveOperationRunning,
            isAlbumMetadataEditable: isAlbumMetadataEditable,
            isSelectedAlbumMetadataEditable: isSelectedAlbumMetadataEditable,
            isAlbumMixedSelection: viewModel.selectedAlbumIsMixed,
            isAlbumArtistMixedSelection: viewModel.selectedAlbumArtistIsMixed,
            hasAlbumInternalDifference: hasAlbumInternalDifference,
            hasAlbumExternalDifference: hasAlbumExternalDifference,
            hasAlbumExternallyModifiedDifference: hasAlbumExternallyModifiedDifference,
            hasAlbumArtistInternalDifference: hasAlbumArtistInternalDifference,
            hasAlbumArtistExternalDifference: hasAlbumArtistExternalDifference,
            hasAlbumArtistExternallyModifiedDifference: hasAlbumArtistExternallyModifiedDifference,
            showsPictureDifferenceOverlay: hasPictureDifference,
            frontCoverImage: albumArtViewModel.imageForAlbumArtSlot(.frontCover),
            onFrontCoverDrop: { providers in
                albumArtViewModel.handleAlbumArtDrop(
                    providers,
                    for: .frontCover,
                    albumArtTypes: albumArtTypes
                ) {
                    syncTrackPictureRecordsFromAlbumArt()
                    syncAlbumArtContext()
                }
            },
            onFrontCoverTap: {
                isAlbumArtSheetPresented = true
            },
            trackItems: trackItems,
            selectedTrackIDsBinding: selectedTrackIDsBinding,
            showsFingerprintColumnBinding: $showTrackFingerprintColumn,
            titleBindingForTrack: titleBinding(for:),
            statusPresentationForTrack: trackStatusPresentationLookup,
            isTrackLocked: viewModel.isTrackLocked(_:),
            hasDeletedFile: viewModel.hasDeletedFile(for:),
            hasTrackToTrackTitleDifference: hasTrackToTrackTitleDifferenceLookup,
            hasTrackToFileTitleDifference: hasTrackToFileTitleDifferenceLookup,
            hasExternallyModifiedTitleDifference: hasExternallyModifiedTitleDifferenceLookup,
            onToggleTrackLocks: toggleSelectedTrackLocks,
            lockMenuTitle: lockMenuTitle,
            canToggleTrackLocks: canToggleTrackLocks,
            onSetTrackTotalToCount: setTrackTotalToCurrentCount,
            setTrackTotalMenuTitle: setTrackTotalMenuTitle,
            canSetTrackTotal: canSetTrackTotal,
            onAddFlacFiles: showAddWritableImporter,
            onAddReadOnlyFlacFiles: showAddReadOnlyImporter,
            canAddFlacFiles: canAddFlacFiles,
            onReloadSelectedTracks: reloadSelectedTracks,
            reloadSelectedTracksTitle: reloadSelectedTracksTitle,
            canReloadSelectedTracks: canReloadSelectedTracks,
            onRemoveSelectedTracks: removeSelectedTracks,
            removeSelectedTracksTitle: removeSelectedTracksTitle,
            canRemoveSelectedTracks: canRemoveSelectedTracks,
            onDropFlacFiles: handleDroppedFlacFileProviders,
            totalTracksBinding: totalTracksBinding,
            isTotalTracksMixedSelection: viewModel.selectedTotalTracksIsMixed,
            hasTotalTracksMismatch: hasTotalTracksMismatch,
            hasTotalTracksInternalDifference: hasTotalTracksInternalDifference,
            totalTracksHoverMessage: totalTracksHoverMessage,
            totalDiscsBinding: totalDiscsBinding,
            hasTotalDiscsMismatch: hasTotalDiscsMismatch,
            totalDiscsHoverMessage: totalDiscsHoverMessage,
            isSelectionEditable: isSelectionEditable,
            hasTotalTracksExternalDifference: hasTotalTracksExternalDifference,
            hasTotalTracksExternallyModifiedDifference: hasTotalTracksExternallyModifiedDifference,
            hasTotalDiscsExternalDifference: hasTotalDiscsExternalDifference,
            hasTotalDiscsExternallyModifiedDifference: hasTotalDiscsExternallyModifiedDifference,
            hasTotalDiscsInternalDifference: hasTotalDiscsInternalDifference,
            selectedNumberBinding: selectedNumberBinding,
            selectedDiscBinding: selectedDiscBinding,
            compilationState: compilationState,
            isCompilationEditable: isCompilationEditable,
            onSetCompilationEnabled: setCompilationEnabled(_:),
            selectedGenreBinding: selectedGenreBinding,
            selectedArtistBinding: selectedArtistBinding,
            selectedComposerBinding: selectedComposerBinding,
            selectedLocationBinding: selectedLocationBinding,
            selectedDateBinding: selectedDateBinding,
            selectedDescriptionsBinding: selectedDescriptionsBinding,
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
            isTrackTotalAutoUpdateEnabled: autoUpdateTrackTotal,
            positiveIntegerTransform: positiveIntegerStringBinding(_:),
            miscTagRowsBinding: miscTagRowsBinding,
            selectedMiscTagRowIDsBinding: selectedMiscTagRowIDsBinding,
            focusedMiscTagKeyRowIDBinding: $focusedMiscTagKeyRowID,
            isMiscTagEditingEnabled: isSelectionEditable,
            onAddMiscTagRow: addMiscTagRow,
            onDeleteSelectedMiscTagRows: deleteSelectedMiscTagRows,
            miscTagKeyBinding: miscTagKeyBinding(for:),
            miscTagValueBinding: miscTagValueBinding(for:),
            isInvalidMiscTagKeyInput: isInvalidMiscTagKeyInput(_:for:),
            hasInternalDifferenceForMiscTagRow: hasInternalDifferenceForMiscTagRowLookup,
            hasExternalDifferenceForMiscTagRow: hasExternalDifferenceForMiscTagRowLookup,
            hasExternallyModifiedDifferenceForMiscTagRow: hasExternallyModifiedDifferenceForMiscTagRowLookup
        )
    }

    private var presentedEditorView: some View {
        editorView
            .padding()
            .frame(minWidth: 680, minHeight: 578, idealHeight: 640, alignment: .topLeading)
    }

    private var contentStack: some View {
        ZStack {
            presentedEditorView

            if let saveStatusState, isSaveStatusVisible {
                SaveStatusView(presentation: saveStatusState.presentation)
                    .transition(.opacity)
                    .zIndex(1)
            }

            if uiTestLaunchFlagEnabled("UITEST_EXPOSE_NAVIGATION_METADATA") ||
                uiTestLaunchFlagEnabled("UITEST_EXPOSE_DIFF_METADATA") {
                uiTestMetadataProbe
                    .zIndex(2)
            }
        }
    }

    private var uiTestMetadataProbe: some View {
        let metadata = navigationMetadata
        return VStack(alignment: .leading, spacing: 2) {
            if uiTestLaunchFlagEnabled("UITEST_EXPOSE_NAVIGATION_METADATA") {
                Text(metadata.title)
                    .accessibilityIdentifier("uiTest.navigation.title")
                Text(metadata.subtitle)
                    .accessibilityIdentifier("uiTest.navigation.subtitle")
                Text(metadata.documentURL?.path ?? "absent")
                    .accessibilityIdentifier("uiTest.navigation.documentURL")
                Text(isSaveNewSwiftTagDocumentPromptPresented ? "presented" : "hidden")
                    .accessibilityIdentifier("uiTest.saveNewSwiftTagDocumentPrompt")
            }

            if uiTestLaunchFlagEnabled("UITEST_EXPOSE_DIFF_METADATA") {
                Text(hasAlbumExternallyModifiedDifference ? "external" : "none")
                    .accessibilityIdentifier("uiTest.diff.album.externalState")
                Text(viewModel.selectedExternalFileValue(forAnyOf: [TagKey.album]) ?? "absent")
                    .accessibilityIdentifier("uiTest.diff.album.externalFileValue")
            }
        }
        .font(.caption2)
        .padding(2)
        .opacity(0.01)
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private var albumArtSheetView: some View {
        AlbumArtSheetView(
            isSaveOperationRunning: isSaveOperationRunning,
            isEditingEnabled: isAlbumMetadataEditable,
            showsPictureDifferenceOverlay: viewModel.hasExternalPictureDifference(),
            saveStatusPresentation: saveStatusState?.presentation,
            albumArtTypes: albumArtTypes,
            navigationPath: Binding(
                get: { albumArtViewModel.albumArtNavigationPath },
                set: { albumArtViewModel.albumArtNavigationPath = $0 }
            ),
            isFileImporterPresented: Binding(
                get: { albumArtViewModel.isAlbumArtFileImporterPresented },
                set: { albumArtViewModel.isAlbumArtFileImporterPresented = $0 }
            ),
            isFileExporterPresented: Binding(
                get: { albumArtViewModel.isAlbumArtFileExporterPresented },
                set: { albumArtViewModel.isAlbumArtFileExporterPresented = $0 }
            ),
            exportDocument: albumArtViewModel.albumArtExportDocument,
            exportContentType: albumArtViewModel.albumArtExportContentType,
            exportDefaultFileName: albumArtViewModel.albumArtExportDefaultFileName,
            imageForSlot: albumArtViewModel.imageForAlbumArtSlot(_:),
            hasImageForSlot: albumArtViewModel.hasImage(for:),
            onOpenPicker: albumArtViewModel.openAlbumArtFilePicker(for:),
            onPrepareExport: { slot in
                albumArtViewModel.prepareAlbumArtExport(for: slot, albumArtTypes: albumArtTypes)
            },
            onDropForSlot: { providers, slot in
                albumArtViewModel.handleAlbumArtDrop(
                    providers,
                    for: slot,
                    albumArtTypes: albumArtTypes
                ) {
                    syncTrackPictureRecordsFromAlbumArt()
                    syncAlbumArtContext()
                }
            },
            onFileImportResult: { result in
                albumArtViewModel.handleAlbumArtFileImportResult(result, albumArtTypes: albumArtTypes)
                syncTrackPictureRecordsFromAlbumArt()
                syncAlbumArtContext()
            },
            onFileExportResult: albumArtViewModel.handleAlbumArtFileExportResult(_:),
            itemProvidersForSlot: { slot in
                albumArtViewModel.currentPictureItemProviders(for: slot)
            },
            onCopyPictureForSlot: { slot in
                albumArtViewModel.copyCurrentPictureToPasteboard(for: slot)
            },
            pictureCountForSlot: { slot in
                albumArtViewModel.uniquePictureCount(for: slot)
            },
            infoOverlayStateForSlot: { slot in
                albumArtViewModel.infoOverlayState(for: slot, albumArtTypes: albumArtTypes)
            },
            metadataForSlot: { slot in
                albumArtViewModel.currentPictureMetadata(for: slot, albumArtTypes: albumArtTypes)
            },
            hasCrossTypeDuplicateForSlot: { slot in
                albumArtViewModel.hasCrossTypeDuplicate(for: slot)
            },
            scopeLabelText: albumArtViewModel.scopeLabelText(),
            typePictureScopeForSlot: { slot in
                albumArtViewModel.typePictureScope(for: slot)
            },
            onSetTypePictureScope: { slot, scope in
                albumArtViewModel.setTypePictureScope(scope, for: slot, albumArtTypes: albumArtTypes)
                syncTrackPictureRecordsFromAlbumArt()
                syncAlbumArtContext()
            },
            isPinTrackPictureOn: { slot in
                return albumArtViewModel.isCurrentPicturePinned(for: slot)
            },
            onSetPinTrackPicture: { slot, isOn in
                albumArtViewModel.setCurrentPicturePinned(isOn, for: slot, albumArtTypes: albumArtTypes)
                syncTrackPictureRecordsFromAlbumArt()
                syncAlbumArtContext()
            },
            isPinTrackPictureDisabled: { slot in
                albumArtViewModel.isTrackPinControlDisabled(for: slot) ||
                    !albumArtViewModel.hasImage(for: slot) ||
                    isSaveOperationRunning
            },
            isTypePictureScopeDisabled: { slot in
                albumArtViewModel.isTypePictureScopeControlDisabled(for: slot) || isSaveOperationRunning
            },
            canNavigateForSlot: { slot in
                albumArtViewModel.canNavigatePictures(for: slot)
            },
            canGoToPreviousPictureForSlot: { slot in
                albumArtViewModel.canGoToPreviousPicture(for: slot)
            },
            canGoToNextPictureForSlot: { slot in
                albumArtViewModel.canGoToNextPicture(for: slot)
            },
            onFirstPicture: { slot in
                albumArtViewModel.goToFirstPicture(for: slot, albumArtTypes: albumArtTypes)
            },
            onPreviousPicture: { slot in
                albumArtViewModel.goToPreviousPicture(for: slot, albumArtTypes: albumArtTypes)
            },
            onNextPicture: { slot in
                albumArtViewModel.goToNextPicture(for: slot, albumArtTypes: albumArtTypes)
            },
            onLastPicture: { slot in
                albumArtViewModel.goToLastPicture(for: slot, albumArtTypes: albumArtTypes)
            },
            onRemovePicture: { slot in
                albumArtViewModel.removeCurrentPicture(for: slot, albumArtTypes: albumArtTypes)
                syncTrackPictureRecordsFromAlbumArt()
                syncAlbumArtContext()
            }
        )
    }

    private var observedContent: some View {
        contentStack
            .onAppear {
                reloadMiscTagRowsFromSelection()
                syncAlbumArtContext()
                configureWindowRouting()
                refreshTrackMonitoring()
                refreshSwiftTagDocumentMonitoring()
                loadUITestStateIfNeeded()
                loadReopenRecordIfNeeded()
                registerUnsavedChangesSession()
            }
            .onChange(of: sessionValue.reopenRecordID) { _, _ in
                loadReopenRecordIfNeeded()
            }
            .onChange(of: selectedTrackIDs) { _, _ in
                reloadMiscTagRowsFromSelection()
                syncAlbumArtContext()
            }
            .onChange(of: trackMonitoringReferenceKeys) { _, _ in
                syncAlbumArtContext()
                refreshTrackMonitoring()
            }
            .onChange(of: saveFrontCoverToAllTracks) { _, _ in
                syncAlbumArtContext()
            }
            .onChange(of: saveAllPicturesToAllTracks) { _, _ in
                syncAlbumArtContext()
            }
            .onChange(of: TrackSetFingerprint.make(from: viewModel.importedTrackReferences)) { _, _ in
                registerEditorSession()
            }
            .onChange(of: viewModel.swiftTagDocumentSaveState()) { _, _ in
                registerEditorSession()
                refreshTrackMonitoring()
                refreshSwiftTagDocumentMonitoring()
            }
            .onChange(of: autoUpdateTrackTotal) { _, _ in
                applyAutoTrackTotalIfNeeded()
            }
            .onChange(of: viewModel.nonDeletedTrackCount) { _, _ in
                applyAutoTrackTotalIfNeeded()
            }
            .onChange(of: focusedMiscTagKeyRowID) { oldValue, newValue in
                if let oldValue {
                    finalizeMiscTagKeyEditing(for: oldValue)
                }

                if let newValue {
                    recordOriginalMiscTagKeyIfNeeded(for: newValue)
                }
            }
    }

    private var commandFocusedContent: some View {
        observedContent
            .focusedSceneValue(\.showTomlSheet) {
                isTomlSheetPresented = true
            }
            .focusedSceneValue(\.showFlacImporter) {
                showWritableImporter()
            }
            .focusedSceneValue(\.showReadOnlyFlacImporter) {
                showReadOnlyImporter()
            }
            .focusedSceneValue(\.showAddFlacImporter) {
                showAddWritableImporter()
            }
            .focusedSceneValue(\.showAddReadOnlyFlacImporter) {
                showAddReadOnlyImporter()
            }
            .focusedSceneValue(\.pictureBrowserMenuTitle, pictureBrowserMenuTitle)
            .focusedSceneValue(\.togglePictureBrowser) {
                togglePictureBrowser()
            }
            .focusedSceneValue(\.canTogglePictureBrowser, canTogglePictureBrowser)
            .focusedSceneValue(\.performDefaultSave) {
                save()
            }
            .focusedSceneValue(\.performSaveTagsOnly) {
                save(using: .writeTags)
            }
            .focusedSceneValue(\.performSavePicturesOnly) {
                save(using: .writePictures)
            }
            .focusedSceneValue(\.performSaveSwiftTagDocument) {
                saveSwiftTagDocument()
            }
            .focusedSceneValue(\.toggleSelectedTrackLocksTitle, lockMenuTitle)
            .focusedSceneValue(\.performToggleSelectedTrackLocks) {
                toggleSelectedTrackLocks()
            }
            .focusedSceneValue(\.canPerformToggleSelectedTrackLocks, canToggleTrackLocks)
            .focusedSceneValue(\.setTrackTotalTitle, setTrackTotalMenuTitle)
            .focusedSceneValue(\.performSetTrackTotal) {
                setTrackTotalToCurrentCount()
            }
            .focusedSceneValue(\.canPerformSetTrackTotal, canSetTrackTotal)
            .focusedSceneValue(\.reloadSelectedTracksTitle, reloadSelectedTracksTitle)
            .focusedSceneValue(\.performReloadSelectedTracks) {
                reloadSelectedTracks()
            }
            .focusedSceneValue(\.canPerformReloadSelectedTracks, canReloadSelectedTracks)
            .focusedSceneValue(\.removeSelectedTracksTitle, removeSelectedTracksTitle)
            .focusedSceneValue(\.performRemoveSelectedTracks) {
                removeSelectedTracks()
            }
            .focusedSceneValue(\.canPerformRemoveSelectedTracks, canRemoveSelectedTracks)
            .focusedSceneValue(\.canPerformDefaultSave, canSave(payload: saveSettingsSnapshot.payload))
            .focusedSceneValue(\.canPerformSaveTagsOnly, canSave(payload: .writeTags))
            .focusedSceneValue(\.canPerformSavePicturesOnly, canSave(payload: .writePictures))
            .focusedSceneValue(\.canPerformSaveSwiftTagDocument, canSaveSwiftTagDocument)
    }

    private var presentedContent: some View {
        commandFocusedContent
            .preferredColorScheme(themePreference.preferredColorScheme)
            .background(
                WindowCloseGuardRepresentable(sessionID: sessionValue.sessionID) { window in
                    UnsavedChangesCoordinator.shared.confirmCloseWindowIfNeeded(
                        for: sessionValue.sessionID,
                        window: window
                    )
                } onWindowDidBecomeKey: {
                    EditorWindowCoordinator.shared.markSessionFocused(sessionValue.sessionID)
                } onWindowWillClose: {
                    EditorWindowCoordinator.shared.markSessionClosing(sessionValue.sessionID)
                    teardownEditorSession()
                }
            )
            .fileImporter(
                isPresented: $isFlacImporterPresented,
                allowedContentTypes: [.folder, UTType(filenameExtension: "flac") ?? .data],
                allowsMultipleSelection: true,
                onCompletion: handleFlacImportResult
            )
            .sheet(isPresented: $isTomlSheetPresented) {
                TOMLUtilityView(tomlText: tomlText())
            }
            .sheet(isPresented: $isAlbumArtSheetPresented) {
                albumArtSheetView
            }
            .alert("FLAC Import Error", isPresented: $isImportErrorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
            .alert("Save Error", isPresented: $isSaveErrorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
            .alert("Save New SwiftTag Document?", isPresented: $isSaveNewSwiftTagDocumentPromptPresented) {
                Button("Cancel", role: .cancel) {}
                Button("Do Not Save") {
                    askToSaveNewSwiftTagDocumentOk = false
                }
                Button("Save") {
                    handleSaveNewSwiftTagDocumentPromptSaveAction()
                }
            } message: {
                Text("Save a new SwiftTag document for this window? Future Save commands will update it automatically.")
            }
            .alert(
                destructiveAlertContext?.title ?? "Unsaved Changes",
                isPresented: $isDestructiveAlertPresented
            ) {
                Button("Cancel", role: .cancel) {
                    destructiveAlertContext = nil
                }
                Button(destructiveAlertContext?.confirmTitle ?? "Continue", role: .destructive) {
                    performDestructiveActionFromAlert()
                }
            } message: {
                Text(destructiveAlertContext?.message ?? "")
            }
    }

    private func reloadMiscTagRowsFromSelection() {
        viewModel.reloadMiscTagRowsFromSelection()
    }

    private func addMiscTagRow() {
        let newRowID = viewModel.addMiscTagRow()
        DispatchQueue.main.async {
            focusedMiscTagKeyRowID = newRowID
        }
    }

    private func deleteSelectedMiscTagRows() {
        viewModel.deleteSelectedMiscTagRows()
    }

    private func miscTagKeyBinding(for rowID: MiscTagRow.ID) -> Binding<String>? {
        viewModel.miscTagKeyBinding(for: rowID)
    }

    private func isInvalidMiscTagKeyInput(_ rawKey: String, for rowID: MiscTagRow.ID) -> Bool {
        viewModel.isInvalidMiscTagKeyInput(rawKey, for: rowID)
    }

    private func recordOriginalMiscTagKeyIfNeeded(for rowID: MiscTagRow.ID) {
        viewModel.recordOriginalMiscTagKeyIfNeeded(for: rowID)
    }

    private func finalizeMiscTagKeyEditing(for rowID: MiscTagRow.ID) {
        viewModel.finalizeMiscTagKeyEditing(for: rowID)
    }

    private func miscTagValueBinding(for rowID: MiscTagRow.ID) -> Binding<String>? {
        viewModel.miscTagValueBinding(for: rowID)
    }

    private func positiveIntegerStringBinding(_ source: Binding<String>) -> Binding<String> {
        viewModel.positiveIntegerStringBinding(source)
    }

    private func tomlText() -> String {
        viewModel.tomlText()
    }

    private func handleFlacImportResult(_ result: Result<[URL], Error>) {
        guard case .success(let selectedURLs) = result else {
            return
        }

        let shouldLockImportedTracks = pendingImporterLockedState
        let shouldAddImportedTracks = pendingImporterAddsFiles
        pendingImporterLockedState = false
        pendingImporterAddsFiles = false

        Task {
            await importSelectedURLs(
                selectedURLs,
                locked: shouldLockImportedTracks,
                append: shouldAddImportedTracks,
                allowsDirectoryRecursion: true
            )
        }
    }

    private func collectFlacFiles(from selectedURLs: [URL]) -> [URL] {
        var flacFiles: [URL] = []
        let fileManager = FileManager.default

        for selectedURL in selectedURLs {
            if selectedURL.pathExtension.lowercased() == "flac" {
                flacFiles.append(selectedURL)
                continue
            }

            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: selectedURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                if let enumerator = fileManager.enumerator(at: selectedURL,
                                                           includingPropertiesForKeys: [.isRegularFileKey],
                                                           options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        if fileURL.pathExtension.lowercased() == "flac" {
                            flacFiles.append(fileURL)
                        }
                    }
                }
            }
        }

        let uniqueFiles = Array(Set(flacFiles.map(\.path))).map(URL.init(fileURLWithPath:))
        return uniqueFiles.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    private func collectDirectFlacFiles(from selectedURLs: [URL]) -> [URL] {
        let uniqueFiles = Set(
            selectedURLs
                .filter { $0.isFileURL }
                .filter { $0.pathExtension.localizedCaseInsensitiveCompare("flac") == .orderedSame }
                .map { $0.standardizedFileURL.path }
        )

        return uniqueFiles
            .map(URL.init(fileURLWithPath:))
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    private func importFlacFiles(_ flacFiles: [URL], locked: Bool = false, append: Bool = false) async throws {
        let existingTrackIDs = Set(viewModel.trackItems.map(\.id))
        try await viewModel.importFlacFiles(flacFiles, locked: locked, append: append)
        let importedTrackIDs = Set(viewModel.trackItems.map(\.id)).subtracting(existingTrackIDs)
        syncAlbumArtContext()
        syncTrackPictureRecordsFromAlbumArt()
        viewModel.syncCurrentStateAsSaved(
            for: append ? importedTrackIDs : nil,
            tagWriteOptions: saveSettingsSnapshot.tagWriteOptions,
            albumArtPictures: currentAlbumArtPictures
        )
        applyAutoTrackTotalIfNeeded()
        refreshTrackMonitoring()
    }

    private func importSelectedURLs(
        _ selectedURLs: [URL],
        locked: Bool,
        append: Bool,
        allowsDirectoryRecursion: Bool
    ) async {
        let startedScopedURLs = selectedURLs.filter { $0.startAccessingSecurityScopedResource() }
        defer {
            for scopedURL in startedScopedURLs {
                scopedURL.stopAccessingSecurityScopedResource()
            }
        }

        let flacFiles = allowsDirectoryRecursion
            ? collectFlacFiles(from: selectedURLs)
            : collectDirectFlacFiles(from: selectedURLs)

        do {
            if append {
                let filteredFiles = viewModel.removeDuplicateImportURLsByBookmarkIdentity(flacFiles)
                try await importFlacFiles(filteredFiles, locked: locked, append: true)
            } else {
                try await importFlacFiles(flacFiles, locked: locked, append: false)
            }
        } catch {
            importErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            isImportErrorPresented = true
        }
    }

    private var saveSettingsSnapshot: SaveSettingsSnapshot {
        SaveSettingsSnapshot(
            payload: SavePayloadOption(rawValue: defaultSavePayloadRawValue) ?? SaveSettingsDefaults.defaultSavePayload,
            scope: SaveScopeOption(rawValue: defaultSaveScopeRawValue) ?? SaveSettingsDefaults.defaultSaveScope,
            tagWriteOptions: TagWriteOptions(
                zeroPadTrackNumber: zeroPadTrackNumber,
                trackCountKeyStrategy: TrackCountKeyStrategy(rawValue: trackCountKeyStrategyRawValue) ?? SaveSettingsDefaults.trackCountKeyStrategy,
                zeroPadDiscNumber: zeroPadDiscNumber,
                discCountKeyStrategy: DiscCountKeyStrategy(rawValue: discCountKeyStrategyRawValue) ?? SaveSettingsDefaults.discCountKeyStrategy
            ),
            saveReferencedSwiftTagDocument: saveReferencedSwiftTagDocument,
            askToSaveNewSwiftTagDocument: askToSaveNewSwiftTagDocument
        )
    }

    private var currentAlbumArtPictures: [FlacWritablePictureRecord] {
        albumArtViewModel.flacPictures(albumArtTypes: albumArtTypes)
    }

    var navigationMetadata: EditorNavigationMetadata {
        viewModel.editorNavigationMetadata(
            tagWriteOptions: saveSettingsSnapshot.tagWriteOptions,
            albumArtPictures: currentAlbumArtPictures
        )
    }

    private func canSave(payload: SavePayloadOption) -> Bool {
        guard !isSaveOperationRunning else {
            return false
        }

        return viewModel.canSave(
            payload: payload,
            scope: saveSettingsSnapshot.scope,
            tagWriteOptions: saveSettingsSnapshot.tagWriteOptions,
            albumArtPictures: currentAlbumArtPictures
        )
    }

    private func save(using payload: SavePayloadOption? = nil) {
        guard !isSaveOperationRunning else {
            return
        }
        syncTrackPictureRecordsFromAlbumArt()

        let settings = saveSettingsSnapshot
        let effectivePayload = payload ?? settings.payload
        let isDefaultSaveCommand = payload == nil
        guard canSave(payload: effectivePayload) else {
            return
        }

        Task { @MainActor in
            isSaveOperationRunning = true
            defer {
                isSaveOperationRunning = false
            }

            do {
                try await performFlacSave(payload: effectivePayload, settings: settings)
                handleSwiftTagDocumentFollowOnSave(
                    SwiftTagDocumentFollowOnSaveDecision.resolve(
                        isDefaultSaveCommand: isDefaultSaveCommand,
                        saveReferencedSwiftTagDocument: settings.saveReferencedSwiftTagDocument,
                        askToSaveNewSwiftTagDocument: settings.askToSaveNewSwiftTagDocument,
                        askToSaveNewSwiftTagDocumentOk: askToSaveNewSwiftTagDocumentOk,
                        hasReferencedSwiftTagDocument: viewModel.swiftTagDocumentSaveState().hasReferencedDocument
                    )
                )
            } catch {
                presentSaveError(error)
            }
        }
    }

    private func performFlacSave(
        payload: SavePayloadOption,
        settings: SaveSettingsSnapshot
    ) async throws {
        let scope = settings.scope
        let trackCount = viewModel.saveTrackCount(for: scope)

        if trackCount > 0 {
            beginSaveStatus(totalTrackCount: trackCount, scope: scope)
        }

        do {
            let saveResult = try await viewModel.save(
                payload: payload,
                scope: scope,
                tagWriteOptions: settings.tagWriteOptions,
                albumArtPictures: currentAlbumArtPictures,
                editorSessionID: sessionValue.sessionID,
                progress: updateSaveStatus(currentTrackIndex:totalTrackCount:currentTrackName:)
            )
            refreshTrackMonitoring()
            registerEditorSession()
            let notificationPayload = SaveNotificationCoordinator.shared.prepareSuccessNotification(for: saveResult)
            Task {
                await SaveNotificationCoordinator.shared.schedulePreparedSuccessNotification(notificationPayload)
            }
            await dismissSaveStatusAfterSuccessIfNeeded()
        } catch {
            await dismissSaveStatusImmediately()
            throw error
        }
    }

    private func saveSwiftTagDocument() {
        guard !isSaveOperationRunning, canSaveSwiftTagDocument else {
            return
        }
        syncTrackPictureRecordsFromAlbumArt()

        isSaveOperationRunning = true
        Task { @MainActor in
            defer {
                isSaveOperationRunning = false
            }

            do {
                _ = try performSwiftTagDocumentSave(using: .rememberedOrPrompt)
            } catch {
                presentSaveError(error)
            }
        }
    }

    private func handleSwiftTagDocumentFollowOnSave(_ action: SwiftTagDocumentFollowOnSaveAction) {
        switch action {
        case .none:
            return
        case .saveReferencedDocument:
            do {
                _ = try performSwiftTagDocumentSave(using: .rememberedOnly)
            } catch {
                presentFollowOnSwiftTagDocumentSaveError(error)
            }
        case .promptForNewDocument:
            isSaveNewSwiftTagDocumentPromptPresented = true
        }
    }

    private func handleSaveNewSwiftTagDocumentPromptSaveAction() {
        guard !isSaveOperationRunning, canSaveSwiftTagDocument else {
            return
        }

        syncTrackPictureRecordsFromAlbumArt()
        isSaveOperationRunning = true
        Task { @MainActor in
            defer {
                isSaveOperationRunning = false
            }

            do {
                _ = try performSwiftTagDocumentSave(using: .promptForNewDocument)
            } catch {
                presentFollowOnSwiftTagDocumentSaveError(error)
            }
        }
    }

    private func performSwiftTagDocumentSave(using destinationMode: SwiftTagDocumentSaveDestinationMode) throws -> Bool {
        let currentState = viewModel.swiftTagDocumentSaveState()
        let destinationURL: URL?
        if currentState.isDeleted, destinationMode != .promptForNewDocument {
            destinationURL = resolveDeletedSwiftTagDocumentRecoveryDestination(currentState: currentState)
        } else {
            destinationURL = resolveSwiftTagDocumentDestination(
                using: destinationMode,
                currentState: currentState
            )
        }
        guard let destinationURL else {
            return false
        }

        let exportTracks = try viewModel.validatedSwiftTagDocumentExportTracks()
        let postSaveMutationSourceURL = exportTracks.first?.sourceFileURL

        if uiTestLaunchFlagEnabled("UITEST_FAIL_SWIFTTAG_SAVE") {
            throw SwiftTagDocumentSaveFlowError.uiTestForcedFailure
        }

        let result = try withAccessingResolvedSwiftTagDocumentDestination(
            currentState: currentState,
            destinationMode: destinationMode,
            destinationURL: destinationURL
        ) { resolvedDestinationURL in
            try SwiftTagDocumentPackageWriter.save(
                tracks: exportTracks,
                state: currentState,
                to: resolvedDestinationURL
            )
        }
        viewModel.rememberSwiftTagDocumentSave(result)
        registerEditorSession()
        performUITestPostSaveReferenceMutationIfNeeded(sourceURL: postSaveMutationSourceURL)
        return true
    }

    private func withAccessingResolvedSwiftTagDocumentDestination<T>(
        currentState: SwiftTagDocumentSaveState,
        destinationMode: SwiftTagDocumentSaveDestinationMode,
        destinationURL: URL,
        _ body: (URL) throws -> T
    ) throws -> T {
        let normalizedDestinationURL = destinationURL.standardizedFileURL
        guard let resolvedDestinationURL = try resolvedSecurityScopedSwiftTagDocumentDestination(
            currentState: currentState,
            destinationMode: destinationMode,
            destinationURL: normalizedDestinationURL
        ) else {
            return try body(normalizedDestinationURL)
        }

        let didAccess = resolvedDestinationURL.startAccessingSecurityScopedResource()
        guard didAccess else {
            throw SwiftTagDocumentSaveFlowError.failedToAccessSecurityScopedDocument(
                path: resolvedDestinationURL.path
            )
        }
        defer {
            resolvedDestinationURL.stopAccessingSecurityScopedResource()
        }

        return try body(resolvedDestinationURL)
    }

    private func resolvedSecurityScopedSwiftTagDocumentDestination(
        currentState: SwiftTagDocumentSaveState,
        destinationMode: SwiftTagDocumentSaveDestinationMode,
        destinationURL: URL
    ) throws -> URL? {
        guard !currentState.isDeleted,
              destinationMode != .promptForNewDocument,
              let bookmarkData = currentState.securityScopedBookmarkData,
              currentState.liveDestinationURL?.standardizedFileURL == destinationURL else {
            return nil
        }

        do {
            var isStale = false
            return try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ).standardizedFileURL
        } catch {
            throw SwiftTagDocumentSaveFlowError.failedToResolveSecurityScopedDocument(
                path: destinationURL.path
            )
        }
    }

    private func resolveSwiftTagDocumentDestination(
        using destinationMode: SwiftTagDocumentSaveDestinationMode,
        currentState: SwiftTagDocumentSaveState
    ) -> URL? {
        switch destinationMode {
        case .rememberedOrPrompt:
            if let rememberedURL = currentState.liveDestinationURL {
                return rememberedURL
            }
            return promptForSwiftTagDocumentDestination()
        case .rememberedOnly:
            return currentState.liveDestinationURL
        case .promptForNewDocument:
            return promptForSwiftTagDocumentDestination()
        }
    }

    private func resolveDeletedSwiftTagDocumentRecoveryDestination(
        currentState: SwiftTagDocumentSaveState
    ) -> URL? {
        switch promptForDeletedSwiftTagDocumentRecovery(currentState: currentState) {
        case .saveNewDocument:
            return promptForSwiftTagDocumentDestination()
        case .recreateOriginal:
            return currentState.navigationDocumentURL
        case .cancel:
            return nil
        }
    }

    private func promptForDeletedSwiftTagDocumentRecovery(
        currentState: SwiftTagDocumentSaveState
    ) -> DeletedSwiftTagDocumentRecoveryChoice {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Referenced SwiftTag Document Was Deleted"

        let documentName = currentState.documentDisplayName ?? "SwiftTag Document"
        let canRecreateOriginal = canRecreateDeletedSwiftTagDocument(at: currentState.navigationDocumentURL)
        if canRecreateOriginal {
            alert.informativeText =
                "\(documentName) is no longer available. Save to a new file or recreate it at the original location."
        } else {
            alert.informativeText =
                "\(documentName) is no longer available. Save to a new file to keep using this session."
        }

        alert.addButton(withTitle: "Save New File...")
        if canRecreateOriginal {
            alert.addButton(withTitle: "Recreate Original")
        }
        alert.addButton(withTitle: "Cancel")
        alert.buttons.last?.keyEquivalent = "\u{1b}"

        let response = alert.runModal()
        let firstButton = NSApplication.ModalResponse.alertFirstButtonReturn
        if response == firstButton {
            return .saveNewDocument
        }

        if canRecreateOriginal,
           response == NSApplication.ModalResponse(rawValue: firstButton.rawValue + 1) {
            return .recreateOriginal
        }

        return .cancel
    }

    private func canRecreateDeletedSwiftTagDocument(at documentURL: URL?) -> Bool {
        guard let documentURL else {
            return false
        }

        let parentDirectoryURL = documentURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parentDirectoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        return FileManager.default.isWritableFile(atPath: parentDirectoryURL.path)
    }

    private func presentSaveError(_ error: Error) {
        saveErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        isSaveErrorPresented = true
    }

    private func presentFollowOnSwiftTagDocumentSaveError(_ error: Error) {
        let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        saveErrorMessage = "FLAC changes were saved, but the SwiftTag document could not be saved.\n\n\(description)"
        isSaveErrorPresented = true
    }

    private func promptForSwiftTagDocumentDestination() -> URL? {
        if let uiTestSaveURL = uiTestSwiftTagDocumentSaveURLIfPresent() {
            return uiTestSaveURL
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.swiftTagDocument]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = defaultSwiftTagDocumentFileName()

        return savePanel.runModal() == .OK ? savePanel.url : nil
    }

    private func registerUnsavedChangesSession() {
        UnsavedChangesCoordinator.shared.register(sessionID: sessionValue.sessionID) {
            currentUnsavedChangesSessionContext()
        } actionHandler: { choice, trigger in
            await performUnsavedChangesAction(choice, trigger: trigger)
        }
    }

    private func currentUnsavedChangesSessionContext() -> UnsavedChangesSessionContext {
        let editCounts = currentUnsavedEditCountsForLoadedTracks()
        let saveState = viewModel.swiftTagDocumentSaveState()

        return UnsavedChangesSessionContext(
            editCounts: UnsavedChangesEditCounts(
                tagEdits: editCounts.tagEdits,
                pictureEdits: editCounts.pictureEdits
            ),
            hasReferencedSwiftTagDocument: saveState.hasReferencedDocument,
            referencedSwiftTagDocumentURL: saveState.navigationDocumentURL,
            hasReferencedSwiftTagDocumentTrackListDifference: viewModel.hasReferencedSwiftTagDocumentTrackListDifference()
        )
    }

    private func performUnsavedChangesAction(
        _ choice: UnsavedChangesSaveChoice,
        trigger _: UnsavedChangesPromptTrigger
    ) async -> UnsavedChangesActionResult {
        switch choice {
        case .saveFlacFiles:
            return await performUnsavedChangesFlacSave()
        case .saveReferencedSwiftTagDocument:
            return await performUnsavedChangesSwiftTagSave(
                using: .rememberedOnly,
                errorPresenter: presentSaveError
            )
        case .saveFlacFilesAndReferencedSwiftTagDocument:
            let flacResult = await performUnsavedChangesFlacSave()
            guard flacResult == .completed else {
                return flacResult
            }
            return await performUnsavedChangesSwiftTagSave(
                using: .rememberedOnly,
                errorPresenter: presentFollowOnSwiftTagDocumentSaveError
            )
        case .saveNewSwiftTagDocument:
            return await performUnsavedChangesSwiftTagSave(
                using: .promptForNewDocument,
                errorPresenter: presentSaveError
            )
        case .saveFlacFilesAndNewSwiftTagDocument:
            let flacResult = await performUnsavedChangesFlacSave()
            guard flacResult == .completed else {
                return flacResult
            }
            return await performUnsavedChangesSwiftTagSave(
                using: .promptForNewDocument,
                errorPresenter: presentFollowOnSwiftTagDocumentSaveError
            )
        }
    }

    private func performUnsavedChangesFlacSave() async -> UnsavedChangesActionResult {
        guard !isSaveOperationRunning else {
            return .failed
        }

        syncTrackPictureRecordsFromAlbumArt()
        let settings = saveSettingsSnapshot
        let payload = settings.payload
        guard viewModel.canSave(
            payload: payload,
            scope: settings.scope,
            tagWriteOptions: settings.tagWriteOptions,
            albumArtPictures: currentAlbumArtPictures
        ) else {
            presentSaveError(TagEditorSaveError.noTracksToSave)
            return .failed
        }

        isSaveOperationRunning = true
        defer {
            isSaveOperationRunning = false
        }

        do {
            try await performFlacSave(payload: payload, settings: settings)
            return .completed
        } catch {
            presentSaveError(error)
            return .failed
        }
    }

    private func performUnsavedChangesSwiftTagSave(
        using destinationMode: SwiftTagDocumentSaveDestinationMode,
        errorPresenter: (Error) -> Void
    ) async -> UnsavedChangesActionResult {
        guard !isSaveOperationRunning, canSaveSwiftTagDocument else {
            return .failed
        }

        syncTrackPictureRecordsFromAlbumArt()
        isSaveOperationRunning = true
        defer {
            isSaveOperationRunning = false
        }

        do {
            let didSave = try performSwiftTagDocumentSave(using: destinationMode)
            return didSave ? .completed : .cancelled
        } catch {
            errorPresenter(error)
            return .failed
        }
    }

    private func performUITestPostSaveReferenceMutationIfNeeded(sourceURL: URL?) {
        guard !didPerformUITestPostSaveReferenceMutation,
              let renameBasename = uiTestLaunchValue(for: "UITEST_POST_SAVE_RENAME_BASENAME")?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !renameBasename.isEmpty,
              let sourceURL else {
            return
        }

        didPerformUITestPostSaveReferenceMutation = true
        let renamedURL = sourceURL.deletingLastPathComponent().appendingPathComponent(renameBasename)
        let shouldDeleteAfterRename = uiTestLaunchFlagEnabled("UITEST_POST_SAVE_DELETE_AFTER_RENAME")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            do {
                try FileManager.default.moveItem(at: sourceURL, to: renamedURL)
            } catch {
                return
            }

            guard shouldDeleteAfterRename else {
                return
            }

            try? await Task.sleep(nanoseconds: 200_000_000)
            try? FileManager.default.removeItem(at: renamedURL)
        }
    }

    private func defaultSwiftTagDocumentFileName() -> String {
        let albumName = viewModel.sharedAlbumDisplayText(in: .allTracks)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = albumName.isEmpty || albumName == viewModel.mixedSelectionMarker
            ? "SwiftTag Document"
            : albumName
        return baseName
    }

    private func beginSaveStatus(totalTrackCount: Int, scope: SaveScopeOption) {
        saveStatusState = SaveStatusState(
            startedAt: .now,
            presentation: SaveStatusPresentation(
                album: viewModel.sharedAlbumDisplayText(in: scope),
                currentTrackName: "",
                showsSelectedTrackName: scope == .selectedTracks,
                currentTrackIndex: min(1, totalTrackCount),
                totalTrackCount: totalTrackCount
            )
        )
        withAnimation(SaveStatusTiming.fadeAnimation) {
            isSaveStatusVisible = true
        }
    }

    private func updateSaveStatus(currentTrackIndex: Int, totalTrackCount: Int, currentTrackName: String) {
        guard var saveStatusState else {
            return
        }

        saveStatusState.presentation.album = viewModel.sharedAlbumDisplayText(in: saveSettingsSnapshot.scope)
        saveStatusState.presentation.currentTrackName = currentTrackName
        saveStatusState.presentation.currentTrackIndex = currentTrackIndex
        saveStatusState.presentation.totalTrackCount = totalTrackCount
        self.saveStatusState = saveStatusState
    }

    private func dismissSaveStatusAfterSuccessIfNeeded() async {
        guard let saveStatusState else {
            return
        }

        let remainingDisplayDuration = SaveStatusTiming.remainingDisplayDuration(startedAt: saveStatusState.startedAt)
        if remainingDisplayDuration > 0 {
            try? await Task.sleep(nanoseconds: SaveStatusTiming.nanoseconds(for: remainingDisplayDuration))
        }

        await dismissSaveStatusImmediately()
    }

    private func dismissSaveStatusImmediately() async {
        guard saveStatusState != nil else {
            return
        }

        withAnimation(SaveStatusTiming.fadeAnimation) {
            isSaveStatusVisible = false
        }
        try? await Task.sleep(nanoseconds: SaveStatusTiming.fadeDurationNanoseconds)
        saveStatusState = nil
    }

    private func configureWindowRouting() {
        EditorWindowCoordinator.shared.setOpenEditorWindowAction(for: sessionValue.sessionID) { sessionValue in
            openWindow(id: AppSceneID.editor, value: sessionValue)
        }
        EditorWindowCoordinator.shared.registerExternalOpenHandler(sessionID: sessionValue.sessionID) { urls in
            handleExternallyOpenedFlacFiles(urls)
        }
        EditorWindowCoordinator.shared.registerSwiftTagDocumentOpenHandler(sessionID: sessionValue.sessionID) { url in
            handleOpenedSwiftTagDocument(url)
        }
        registerEditorSession()
        EditorWindowCoordinator.shared.markSessionFocused(sessionValue.sessionID)
    }

    private func handleExternallyOpenedFlacFiles(_ urls: [URL]) {
        Task {
            await importSelectedURLs(
                urls,
                locked: false,
                append: true,
                allowsDirectoryRecursion: false
            )
        }
    }

    private func handleOpenedSwiftTagDocument(_ url: URL) {
        Task { @MainActor in
            do {
                let document = try SwiftTagDocumentPackageReader.read(from: url)
                viewModel.loadSwiftTagDocument(document, tagWriteOptions: saveSettingsSnapshot.tagWriteOptions)
                syncAlbumArtContext()
                viewModel.refreshLoadedTrackFileStates(
                    tagWriteOptions: saveSettingsSnapshot.tagWriteOptions,
                    albumArtPictures: currentAlbumArtPictures
                )
                refreshTrackMonitoring()
                refreshSwiftTagDocumentMonitoring()
                registerEditorSession()
            } catch {
                importErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isImportErrorPresented = true
            }
        }
    }

    private func loadReopenRecordIfNeeded() {
        guard let reopenRecordID = sessionValue.reopenRecordID,
              loadedReopenRecordID != reopenRecordID else {
            return
        }

        guard let reopenRecord = SaveNotificationCoordinator.shared.reopenRecord(for: reopenRecordID) else {
            sessionValue.reopenRecordID = nil
            importErrorMessage = "The saved track details are no longer available."
            isImportErrorPresented = true
            return
        }

        loadedReopenRecordID = reopenRecordID

        Task {
            do {
                try await importSavedTracks(from: reopenRecord.trackReferences)
                sessionValue.reopenRecordID = nil
            } catch {
                sessionValue.reopenRecordID = nil
                importErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isImportErrorPresented = true
            }
        }
    }

    private func teardownEditorSession() {
        EditorWindowCoordinator.shared.unregister(sessionID: sessionValue.sessionID)
        UnsavedChangesCoordinator.shared.unregister(sessionID: sessionValue.sessionID)
        trackFileMonitor.stopAll()
        trackFileMonitor = .init()
        swiftTagDocumentMonitor.stopAll()
        swiftTagDocumentMonitor = .init()
        viewModel = .init()
        albumArtViewModel = .init()
        saveStatusState = nil
        isSaveStatusVisible = false
        isSaveOperationRunning = false
        isTomlSheetPresented = false
        isFlacImporterPresented = false
        pendingImporterLockedState = false
        pendingImporterAddsFiles = false
        isImportErrorPresented = false
        isSaveErrorPresented = false
        isDestructiveAlertPresented = false
        isAlbumArtSheetPresented = false
        importErrorMessage = ""
        saveErrorMessage = ""
        destructiveAlertContext = nil
        pendingDestructiveAction = nil
        didPerformUITestPostSaveReferenceMutation = false
        loadedReopenRecordID = nil
        uiTestFileActionTask?.cancel()
        uiTestFileActionTask = nil
        focusedMiscTagKeyRowID = nil
    }

    private func registerEditorSession() {
        let swiftTagDocumentState = viewModel.swiftTagDocumentSaveState()
        EditorWindowCoordinator.shared.register(
            sessionValue: sessionValue,
            trackReferences: viewModel.importedTrackReferences,
            swiftTagDocumentURL: swiftTagDocumentState.liveDestinationURL,
            swiftTagDocumentID: swiftTagDocumentState.documentID
        )
    }

    private func importSavedTracks(from references: [ImportedTrackReference]) async throws {
        guard !references.isEmpty else {
            return
        }

        let resolvedFiles = try resolveTrackURLs(for: references)
        defer {
            for resolvedURL in resolvedFiles.securityScopedURLs {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }
        try await importFlacFiles(resolvedFiles.urls)
    }

    private func refreshTrackMonitoring() {
        syncTrackPictureRecordsFromAlbumArt()
        trackFileMonitor.replaceObservations(for: viewModel.trackItems) { event in
            viewModel.refreshTrackFileState(
                for: event.trackID,
                currentPath: event.currentPath,
                tagWriteOptions: saveSettingsSnapshot.tagWriteOptions,
                albumArtPictures: currentAlbumArtPictures
            )
            DispatchQueue.main.async {
                applyAutoTrackTotalIfNeeded()
                refreshTrackMonitoring()
            }
        }
    }

    private func toggleSelectedTrackLocks() {
        viewModel.toggleLockState(for: selectedTrackIDs)
        applyAutoTrackTotalIfNeeded()
    }

    private func setTrackTotalToCurrentCount() {
        guard canSetTrackTotal else {
            return
        }
        viewModel.setTrackTotalToCurrentCount()
    }

    private func setCompilationEnabled(_ isEnabled: Bool) {
        guard isCompilationEditable else {
            return
        }

        viewModel.setCompilationEnabled(isEnabled, applyToAllTracks: applyCompilationToAllTracks)
    }

    private func reloadSelectedTracks() {
        guard canReloadSelectedTracks else {
            return
        }
        confirmBeforeDestructiveAction(.reloadSelectedTracks) {
            Task { @MainActor in
                do {
                    try viewModel.reloadTracksWithDifferences(
                        in: selectedTrackIDs,
                        tagWriteOptions: saveSettingsSnapshot.tagWriteOptions,
                        albumArtPictures: currentAlbumArtPictures
                    )
                    albumArtViewModel.discardTransientState(for: selectedTrackIDs, albumArtTypes: albumArtTypes)
                    syncAlbumArtContext()
                    applyAutoTrackTotalIfNeeded()
                    refreshTrackMonitoring()
                } catch {
                    importErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    isImportErrorPresented = true
                }
            }
        }
    }

    private func refreshSwiftTagDocumentMonitoring() {
        swiftTagDocumentMonitor.replaceObservation(with: viewModel.swiftTagDocumentSaveState()) { event in
            let didChange = viewModel.refreshSwiftTagDocumentSaveState(currentPath: event.currentPath)
            if didChange {
                registerEditorSession()
            }

            DispatchQueue.main.async {
                refreshSwiftTagDocumentMonitoring()
            }
        }
    }

    private func removeSelectedTracks() {
        guard canRemoveSelectedTracks else {
            return
        }
        confirmBeforeDestructiveAction(.removeSelectedTracks) {
            viewModel.removeTracks(withIDs: selectedTrackIDs)
            applyAutoTrackTotalIfNeeded()
            refreshTrackMonitoring()
        }
    }

    private func applyAutoTrackTotalIfNeeded() {
        guard autoUpdateTrackTotal else {
            return
        }
        viewModel.setTrackTotalToCurrentCount()
    }

    private func handleDroppedFlacFileProviders(_ providers: [NSItemProvider]) -> Bool {
        guard canAddFlacFiles else {
            return false
        }

        let lockDroppedFiles = NSEvent.modifierFlags.contains(.option)
        Task { @MainActor in
            let droppedURLs = await loadDroppedFileURLs(from: providers)
            let flacFiles = collectFlacFiles(from: droppedURLs)
            let filteredFiles = viewModel.removeDuplicateImportURLsByBookmarkIdentity(flacFiles)
            do {
                try await importFlacFiles(filteredFiles, locked: lockDroppedFiles, append: true)
            } catch {
                importErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isImportErrorPresented = true
            }
        }
        return true
    }

    private func loadDroppedFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        await withTaskGroup(of: URL?.self) { group in
            for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.addTask {
                    await withCheckedContinuation { continuation in
                        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                            if let data = item as? Data,
                               let url = URL(dataRepresentation: data, relativeTo: nil) {
                                continuation.resume(returning: url)
                                return
                            }
                            if let url = item as? URL {
                                continuation.resume(returning: url)
                                return
                            }
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }

            var urls: [URL] = []
            for await url in group {
                if let url {
                    urls.append(url)
                }
            }
            return urls
        }
    }

    private func confirmBeforeDestructiveAction(_ action: DestructiveAction, perform: @escaping () -> Void) {
        syncTrackPictureRecordsFromAlbumArt()
        let affectedTrackIDs: Set<UUID>
        switch action {
        case .loadFiles:
            affectedTrackIDs = Set(viewModel.trackItems.map(\.id))
        case .reloadSelectedTracks, .removeSelectedTracks:
            affectedTrackIDs = selectedTrackIDs
        }

        let editCounts = viewModel.editorDifferenceCounts(
            for: affectedTrackIDs,
            tagWriteOptions: saveSettingsSnapshot.tagWriteOptions,
            albumArtPictures: currentAlbumArtPictures
        )
        let hasInEditorEdits = editCounts.tagEdits > 0 || editCounts.pictureEdits > 0
        guard hasInEditorEdits else {
            perform()
            return
        }

        let title: String
        let confirmTitle: String
        switch action {
        case .loadFiles:
            title = "Load Files?"
            confirmTitle = "Load File(s)"
        case .reloadSelectedTracks:
            title = "Reload Selected Track(s)?"
            confirmTitle = "Reload File(s)"
        case .removeSelectedTracks:
            title = "Remove Selected Track(s)?"
            confirmTitle = "Remove Track(s)"
        }

        let message = "There are pending changes that have not been saved: \(editCounts.tagEdits) tag edits, \(editCounts.pictureEdits) picture edits."
        destructiveAlertContext = DestructiveAlertContext(
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            action: action
        )
        pendingDestructiveAction = perform
        isDestructiveAlertPresented = true
    }

    private func currentUnsavedEditCountsForLoadedTracks() -> (tagEdits: Int, pictureEdits: Int) {
        viewModel.editorDifferenceCounts(
            for: Set(viewModel.trackItems.map(\.id)),
            tagWriteOptions: saveSettingsSnapshot.tagWriteOptions,
            albumArtPictures: currentAlbumArtPictures
        )
    }

    private func performDestructiveActionFromAlert() {
        guard let action = pendingDestructiveAction else {
            destructiveAlertContext = nil
            return
        }
        pendingDestructiveAction = nil
        destructiveAlertContext = nil
        action()
    }

    private func showWritableImporter() {
        if importUITestMenuFlacIfNeeded(locked: false, append: false) {
            return
        }
        confirmBeforeDestructiveAction(.loadFiles) {
            pendingImporterLockedState = false
            pendingImporterAddsFiles = false
            isFlacImporterPresented = true
        }
    }

    private func showReadOnlyImporter() {
        if importUITestMenuFlacIfNeeded(locked: true, append: false) {
            return
        }
        confirmBeforeDestructiveAction(.loadFiles) {
            pendingImporterLockedState = true
            pendingImporterAddsFiles = false
            isFlacImporterPresented = true
        }
    }

    private func showAddWritableImporter() {
        if importUITestMenuFlacIfNeeded(locked: false, append: true) {
            return
        }
        pendingImporterLockedState = false
        pendingImporterAddsFiles = true
        isFlacImporterPresented = true
    }

    private func showAddReadOnlyImporter() {
        if importUITestMenuFlacIfNeeded(locked: true, append: true) {
            return
        }
        pendingImporterLockedState = true
        pendingImporterAddsFiles = true
        isFlacImporterPresented = true
    }

    private func importUITestMenuFlacIfNeeded(locked: Bool, append: Bool) -> Bool {
        guard let uiTestURL = uiTestMenuFlacURLIfPresent() else {
            return false
        }

        Task {
            await importSelectedURLs(
                [uiTestURL],
                locked: locked,
                append: append,
                allowsDirectoryRecursion: true
            )
        }
        return true
    }

    private func syncAlbumArtContext() {
        albumArtViewModel.configurePinSettings(
            saveFrontCoverToAllTracks: saveFrontCoverToAllTracks,
            saveAllPicturesToAllTracks: saveAllPicturesToAllTracks
        )
        albumArtViewModel.configureTrackContext(
            trackItems: viewModel.trackItems,
            selectedTrackIDs: selectedTrackIDs,
            albumArtTypes: albumArtTypes
        )
        syncTrackPictureRecordsFromAlbumArt()
    }

    private func syncTrackPictureRecordsFromAlbumArt() {
        guard !viewModel.trackItems.isEmpty else {
            return
        }

        var recordsByTrackID: [UUID: [FlacWritablePictureRecord]] = [:]
        for track in viewModel.trackItems {
            let records = albumArtViewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes)
            if records != track.flacPictureRecords {
                recordsByTrackID[track.id] = records
            }
        }

        guard !recordsByTrackID.isEmpty else {
            return
        }
        viewModel.setPictureRecordsByTrackID(recordsByTrackID)
    }

    private func togglePictureBrowser() {
        isAlbumArtSheetPresented.toggle()
    }

    private func resolveTrackURLs(
        for references: [ImportedTrackReference]
    ) throws -> (urls: [URL], securityScopedURLs: [URL]) {
        var resolvedURLs: [URL] = []
        var securityScopedURLs: [URL] = []

        do {
            for reference in references {
                if let bookmarkData = reference.securityScopedBookmarkData {
                    var isStale = false
                    let resolvedURL = try URL(
                        resolvingBookmarkData: bookmarkData,
                        options: [.withSecurityScope, .withoutUI],
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                    let didAccess = resolvedURL.startAccessingSecurityScopedResource()
                    guard didAccess else {
                        throw TagEditorSaveError.failedToAccessFile(path: resolvedURL.path)
                    }

                    resolvedURLs.append(resolvedURL)
                    securityScopedURLs.append(resolvedURL)
                    continue
                }

                resolvedURLs.append(URL(fileURLWithPath: reference.filePath))
            }

            return (resolvedURLs, securityScopedURLs)
        } catch {
            for resolvedURL in securityScopedURLs {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
            throw error
        }
    }

    private func loadUITestStateIfNeeded() {
        guard !hasPerformedInitialUITestSetup else {
            return
        }

        hasPerformedInitialUITestSetup = true
        activateUISimulatedSaveStatusIfNeeded()
        beginUITestFileActionPollingIfNeeded()

        if uiTestLaunchFlagEnabled("UITEST_OPEN_ALBUM_ART_SHEET") {
            isAlbumArtSheetPresented = true
        }

        if sessionValue.reopenRecordID == nil,
           let rawRecordID = uiTestLaunchValue(for: "UITEST_OPEN_SAVE_NOTIFICATION_RECORD_ID"),
           let reopenRecordID = UUID(uuidString: rawRecordID) {
            sessionValue.reopenRecordID = reopenRecordID
        }

        guard let fixturePath = uiTestLaunchValue(for: "UITEST_FLAC_PATH") else {
            return
        }

        let importsFixtureAsReadOnly = uiTestLaunchFlagEnabled("UITEST_FLAC_READ_ONLY")
        Task { @MainActor in
            do {
                let fileURL = try uiTestImportFileURL(for: fixturePath)
                try await importFlacFiles([fileURL], locked: importsFixtureAsReadOnly)
            } catch {
                importErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isImportErrorPresented = true
            }
        }
    }

    private func activateUISimulatedSaveStatusIfNeeded() {
        guard uiTestLaunchFlagEnabled("UITEST_SIMULATE_SAVE_STATUS") else {
            return
        }

        let delay = Double(uiTestLaunchValue(for: "UITEST_SIMULATED_SAVE_DELAY") ?? "") ?? 0
        guard delay > 0 else {
            applyUISimulatedSaveStatus()
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: SaveStatusTiming.nanoseconds(for: delay))
            applyUISimulatedSaveStatus()
        }
    }

    private func applyUISimulatedSaveStatus() {
        guard uiTestLaunchFlagEnabled("UITEST_SIMULATE_SAVE_STATUS") else {
            return
        }

        let simulatedScopeRawValue = uiTestLaunchValue(for: "UITEST_SIMULATED_SAVE_SCOPE")
        let simulatedScope = SaveScopeOption(rawValue: simulatedScopeRawValue ?? "") ?? .allTracks
        let totalTrackCount = Int(uiTestLaunchValue(for: "UITEST_SIMULATED_SAVE_TOTAL") ?? "") ?? 3
        let currentTrackIndex = Int(uiTestLaunchValue(for: "UITEST_SIMULATED_SAVE_CURRENT") ?? "") ?? 1
        let currentTrackName = uiTestLaunchValue(for: "UITEST_SIMULATED_SAVE_TRACK_NAME") ?? "Simulated Track"
        let albumValue = uiTestLaunchValue(for: "UITEST_SIMULATED_SAVE_ALBUM") ?? "Simulated Album"

        saveStatusState = SaveStatusState(
            startedAt: .now,
            presentation: SaveStatusPresentation(
                album: albumValue,
                currentTrackName: currentTrackName,
                showsSelectedTrackName: simulatedScope == .selectedTracks,
                currentTrackIndex: currentTrackIndex,
                totalTrackCount: totalTrackCount
            )
        )
        isSaveOperationRunning = true
        isSaveStatusVisible = true

        let duration = Double(uiTestLaunchValue(for: "UITEST_SIMULATED_SAVE_DURATION") ?? "") ?? 0
        guard duration > 0 else {
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: SaveStatusTiming.nanoseconds(for: duration))
            await dismissSaveStatusImmediately()
            isSaveOperationRunning = false
        }
    }

    private func uiTestLaunchFlagEnabled(_ key: String) -> Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment[key] == "1" {
            return true
        }

        return ProcessInfo.processInfo.arguments.contains("-\(key)")
    }

    private func uiTestLaunchValue(for key: String) -> String? {
        let environment = ProcessInfo.processInfo.environment
        if let value = environment[key], !value.isEmpty {
            return value
        }

        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: "-\(key)") else {
            return nil
        }

        let valueIndex = arguments.index(after: keyIndex)
        guard valueIndex < arguments.endIndex else {
            return nil
        }

        let value = arguments[valueIndex]
        return value.isEmpty ? nil : value
    }

    private func uiTestControlValueIfPresent(fileName: String) -> String? {
        for controlDirectoryURL in uiTestControlDirectoryURLs() {
            let controlURL = controlDirectoryURL.appendingPathComponent(fileName)
            guard let rawValue = try? String(contentsOf: controlURL, encoding: .utf8) else {
                continue
            }

            let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedValue.isEmpty {
                return trimmedValue
            }
        }
        return nil
    }

    private func uiTestControlDirectoryURL() -> URL {
        let directoryURL = (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("SwiftTagUITestControls", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func uiTestExternalControlDirectoryURL() -> URL? {
        let directoryURL = URL(fileURLWithPath: "/Users", isDirectory: true)
            .appendingPathComponent(NSUserName(), isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent("com.toowalks.swifttagUITests.xctrunner", isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent("com.toowalks.swifttag", isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent("SwiftTagUITestControls", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func uiTestControlDirectoryURLs() -> [URL] {
        var directories = [uiTestControlDirectoryURL()]
        if let externalDirectoryURL = uiTestExternalControlDirectoryURL(),
           !directories.contains(externalDirectoryURL) {
            directories.append(externalDirectoryURL)
        }
        return directories
    }

    private func beginUITestFileActionPollingIfNeeded() {
        guard uiTestLaunchFlagEnabled("UITEST_ENABLE_FILE_ACTIONS"),
              uiTestFileActionTask == nil else {
            return
        }

        for controlDirectoryURL in uiTestControlDirectoryURLs() {
            let readyURL = controlDirectoryURL.appendingPathComponent("file-action-ready.txt")
            try? "ready".write(to: readyURL, atomically: true, encoding: .utf8)
        }

        uiTestFileActionTask = Task { @MainActor in
            while !Task.isCancelled {
                processPendingUITestFileActionIfNeeded()
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func processPendingUITestFileActionIfNeeded() {
        for controlDirectoryURL in uiTestControlDirectoryURLs() {
            let actionURL = controlDirectoryURL.appendingPathComponent("file-action.txt")
            let resultURL = controlDirectoryURL.appendingPathComponent("file-action-result.txt")
            guard let rawAction = try? String(contentsOf: actionURL, encoding: .utf8) else {
                continue
            }

            try? FileManager.default.removeItem(at: actionURL)

            let lines = rawAction
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let operation = lines.first?.lowercased(), !operation.isEmpty else {
                try? "error:missing-operation".write(to: resultURL, atomically: true, encoding: .utf8)
                return
            }

            do {
                switch operation {
                case "rename":
                    guard lines.count >= 3 else {
                        throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError)
                    }
                    try FileManager.default.moveItem(
                        at: URL(fileURLWithPath: lines[1]),
                        to: URL(fileURLWithPath: lines[2])
                    )
                case "delete":
                    guard lines.count >= 2 else {
                        throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError)
                    }
                    try FileManager.default.removeItem(at: URL(fileURLWithPath: lines[1]))
                default:
                    throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError)
                }

                try? "success".write(to: resultURL, atomically: true, encoding: .utf8)
            } catch {
                let message = (error as NSError).localizedDescription
                try? "error:\(message)".write(to: resultURL, atomically: true, encoding: .utf8)
            }
            return
        }
    }

    private func uiTestSwiftTagDocumentSaveURLIfPresent() -> URL? {
        let rawPath = uiTestLaunchValue(for: "UITEST_SAVE_SWIFTTAG_PATH")
            ?? uiTestControlValueIfPresent(fileName: "save-swifttag-path.txt")
        let url: URL
        if let rawPath {
            url = URL(fileURLWithPath: rawPath)
        } else if uiTestLaunchFlagEnabled("UITEST_SAVE_SWIFTTAG_PATH") {
            url = uiTestMaterializedFileDirectoryURL()
                .appendingPathComponent("SwiftTagUITestSave")
                .appendingPathExtension("swifttag")
        } else {
            return nil
        }

        let directoryURL = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return url
    }

    private func uiTestMaterializedFileDirectoryURL() -> URL {
        let directoryURL = (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("SwiftTagUITestFixtures", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func uiTestMenuFlacURLIfPresent() -> URL? {
        uiTestMaterializedFlacURL(
            pathValue: uiTestLaunchValue(for: "UITEST_MENU_FLAC_PATH"),
            dataValue: uiTestLaunchValue(for: "UITEST_MENU_FLAC_DATA_BASE64"),
            fileStem: "SwiftTagUITestMenuFixture"
        )
    }

    private func uiTestImportFileURL(for fallbackPath: String) throws -> URL {
        guard let dataValue = uiTestLaunchValue(for: "UITEST_FLAC_DATA_BASE64"),
              let fileData = Data(base64Encoded: dataValue) else {
            if let reuseURL = try uiTestReusableImportFileURLIfPresent() {
                return reuseURL
            }
            return URL(fileURLWithPath: fallbackPath)
        }

        let tempURL: URL
        if let reuseURL = try uiTestReusableImportFileURLIfPresent() {
            if uiTestLaunchFlagEnabled("UITEST_REUSE_IMPORTED_FLAC"),
               FileManager.default.fileExists(atPath: reuseURL.path) {
                return reuseURL
            }
            tempURL = reuseURL
        } else {
            tempURL = uiTestMaterializedFlacDirectoryURL()
                .appendingPathComponent("SwiftTagUITestFixture")
                .appendingPathExtension("flac")
        }
        try fileData.write(to: tempURL, options: .atomic)
        try applyUITestFlacOverridesIfNeeded(
            to: tempURL,
            albumModeKey: "UITEST_FLAC_ALBUM_MODE",
            titleOverrideKey: "UITEST_FLAC_TITLE_OVERRIDE",
            pictureProfileKey: "UITEST_FLAC_PICTURE_PROFILE"
        )
        return tempURL
    }

    private func uiTestMaterializedFlacURL(
        pathValue: String?,
        dataValue: String?,
        fileStem: String
    ) -> URL? {
        let trimmedPath = pathValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathExtension = URL(fileURLWithPath: trimmedPath ?? "").pathExtension
        guard let dataValue,
              let fileData = Data(base64Encoded: dataValue) else {
            guard let trimmedPath, !trimmedPath.isEmpty else {
                return nil
            }
            return URL(fileURLWithPath: trimmedPath)
        }

        let fileURL = uiTestMaterializedFlacDirectoryURL()
            .appendingPathComponent(fileStem)
            .appendingPathExtension(pathExtension.isEmpty ? "flac" : pathExtension)
        try? fileData.write(to: fileURL, options: .atomic)
        try? applyUITestFlacOverridesIfNeeded(
            to: fileURL,
            albumModeKey: pathValue == uiTestLaunchValue(for: "UITEST_MENU_FLAC_PATH")
                ? "UITEST_MENU_FLAC_ALBUM_MODE"
                : "UITEST_OPEN_DOCUMENT_FLAC_ALBUM_MODE",
            titleOverrideKey: pathValue == uiTestLaunchValue(for: "UITEST_MENU_FLAC_PATH")
                ? "UITEST_MENU_FLAC_TITLE_OVERRIDE"
                : "UITEST_OPEN_DOCUMENT_FLAC_TITLE_OVERRIDE",
            pictureProfileKey: pathValue == uiTestLaunchValue(for: "UITEST_MENU_FLAC_PATH")
                ? "UITEST_MENU_FLAC_PICTURE_PROFILE"
                : "UITEST_OPEN_DOCUMENT_FLAC_PICTURE_PROFILE"
        )
        return fileURL
    }

    private func applyUITestFlacOverridesIfNeeded(
        to fileURL: URL,
        albumModeKey: String,
        titleOverrideKey: String,
        pictureProfileKey: String
    ) throws {
        let titleOverride = uiTestLaunchValue(for: titleOverrideKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        try UITestFlacOverrideWriter.applyOverrides(
            to: fileURL,
            albumMode: uiTestLaunchValue(for: albumModeKey),
            titleOverride: titleOverride,
            pictureProfile: uiTestLaunchValue(for: pictureProfileKey)
        )
    }

    private func uiTestReusableImportFileURLIfPresent() throws -> URL? {
        guard let destinationName = uiTestLaunchValue(for: "UITEST_FLAC_DESTINATION_NAME") else {
            return nil
        }

        let fileURL = uiTestMaterializedFlacDirectoryURL()
            .appendingPathComponent(destinationName)
            .appendingPathExtension("flac")
        if uiTestLaunchFlagEnabled("UITEST_REUSE_IMPORTED_FLAC"), FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        return fileURL
    }

    private func uiTestMaterializedFlacDirectoryURL() -> URL {
        let directoryURL = (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("SwiftTagUITestFixtures", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    init(sessionValue: Binding<EditorSessionValue> = .constant(EditorSessionValue())) {
        _sessionValue = sessionValue
    }

    @MainActor
    init(
        sessionValue: Binding<EditorSessionValue>,
        viewModel: TagEditorViewModel,
        albumArtViewModel: AlbumArtViewModel
    ) {
        _sessionValue = sessionValue
        _viewModel = State(initialValue: viewModel)
        _albumArtViewModel = State(initialValue: albumArtViewModel)
    }

    @ViewBuilder
    var body: some View {
        let metadata = navigationMetadata
        if let documentURL = metadata.documentURL {
            presentedContent
                .navigationTitle(metadata.title)
                .navigationSubtitle(metadata.subtitle)
                .navigationDocument(documentURL)
        } else {
            presentedContent
                .navigationTitle(metadata.title)
                .navigationSubtitle(metadata.subtitle)
        }
    }
}

extension FocusedValues {
    @Entry var showTomlSheet: (() -> Void)?
    @Entry var showFlacImporter: (() -> Void)?
    @Entry var showReadOnlyFlacImporter: (() -> Void)?
    @Entry var showAddFlacImporter: (() -> Void)?
    @Entry var showAddReadOnlyFlacImporter: (() -> Void)?
    @Entry var togglePictureBrowser: (() -> Void)?
    @Entry var pictureBrowserMenuTitle: String?
    @Entry var canTogglePictureBrowser: Bool?
    @Entry var performDefaultSave: (() -> Void)?
    @Entry var performSaveTagsOnly: (() -> Void)?
    @Entry var performSavePicturesOnly: (() -> Void)?
    @Entry var performSaveSwiftTagDocument: (() -> Void)?
    @Entry var performToggleSelectedTrackLocks: (() -> Void)?
    @Entry var toggleSelectedTrackLocksTitle: String?
    @Entry var performSetTrackTotal: (() -> Void)?
    @Entry var setTrackTotalTitle: String?
    @Entry var canPerformSetTrackTotal: Bool?
    @Entry var performReloadSelectedTracks: (() -> Void)?
    @Entry var reloadSelectedTracksTitle: String?
    @Entry var canPerformReloadSelectedTracks: Bool?
    @Entry var performRemoveSelectedTracks: (() -> Void)?
    @Entry var removeSelectedTracksTitle: String?
    @Entry var canPerformRemoveSelectedTracks: Bool?
    @Entry var canPerformDefaultSave: Bool?
    @Entry var canPerformSaveTagsOnly: Bool?
    @Entry var canPerformSavePicturesOnly: Bool?
    @Entry var canPerformSaveSwiftTagDocument: Bool?
    @Entry var canPerformToggleSelectedTrackLocks: Bool?
}

private struct WindowCloseGuardRepresentable: NSViewRepresentable {
    let sessionID: UUID
    let shouldAllowClose: (NSWindow) -> Bool
    let onWindowDidBecomeKey: () -> Void
    let onWindowWillClose: () -> Void

    init(
        sessionID: UUID,
        shouldAllowClose: @escaping (NSWindow) -> Bool,
        onWindowDidBecomeKey: @escaping () -> Void = {},
        onWindowWillClose: @escaping () -> Void = {}
    ) {
        self.sessionID = sessionID
        self.shouldAllowClose = shouldAllowClose
        self.onWindowDidBecomeKey = onWindowDidBecomeKey
        self.onWindowWillClose = onWindowWillClose
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            sessionID: sessionID,
            shouldAllowClose: shouldAllowClose,
            onWindowDidBecomeKey: onWindowDidBecomeKey,
            onWindowWillClose: onWindowWillClose
        )
    }

    func makeNSView(context: Context) -> WindowCloseGuardHostView {
        let view = WindowCloseGuardHostView()
        view.delegateCoordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: WindowCloseGuardHostView, context: Context) {
        context.coordinator.sessionID = sessionID
        context.coordinator.shouldAllowClose = shouldAllowClose
        context.coordinator.onWindowDidBecomeKey = onWindowDidBecomeKey
        context.coordinator.onWindowWillClose = onWindowWillClose
        nsView.delegateCoordinator = context.coordinator
        nsView.attachDelegateIfNeeded()
    }

    final class Coordinator: NSObject, NSWindowDelegate, EditorWindowSessionIdentifying {
        var sessionID: UUID
        var shouldAllowClose: (NSWindow) -> Bool
        var onWindowDidBecomeKey: () -> Void
        var onWindowWillClose: () -> Void

        var editorSessionID: UUID { sessionID }

        init(
            sessionID: UUID,
            shouldAllowClose: @escaping (NSWindow) -> Bool,
            onWindowDidBecomeKey: @escaping () -> Void,
            onWindowWillClose: @escaping () -> Void
        ) {
            self.sessionID = sessionID
            self.shouldAllowClose = shouldAllowClose
            self.onWindowDidBecomeKey = onWindowDidBecomeKey
            self.onWindowWillClose = onWindowWillClose
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            shouldAllowClose(sender)
        }

        func windowDidBecomeKey(_ notification: Notification) {
            onWindowDidBecomeKey()
        }

        func windowWillClose(_ notification: Notification) {
            onWindowWillClose()
        }
    }
}

private final class WindowCloseGuardHostView: NSView {
    weak var delegateCoordinator: WindowCloseGuardRepresentable.Coordinator?
    private weak var delegatedWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachDelegateIfNeeded()
    }

    func attachDelegateIfNeeded() {
        guard let window, let delegateCoordinator else {
            return
        }
        guard delegatedWindow !== window else {
            return
        }
        delegatedWindow = window
        window.delegate = delegateCoordinator
    }
}

#if DEBUG
private enum PreviewCanvasView {
    case content
    case settings
    case diffTools
    case uView
}
private let uniqueToolbarAccessoryBarID = "com.swifttag.preview.uniqueToolbarAccessory"

private extension ToolbarItemPlacement {
    static let uniqueToolbarAccessory = Self.accessoryBar(id: uniqueToolbarAccessoryBarID)
}

private extension ToolbarPlacement {
    static let uniqueToolbarAccessory = Self.accessoryBar(id: uniqueToolbarAccessoryBarID)
}

struct IconToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            // This action is essential to flip the state manually in a custom style
            configuration.isOn.toggle()
        } label: {
            Image(systemName: configuration.isOn ? "pin.fill" : "pin.slash.fill") // Change icon based on state
                //.foregroundColor(configuration.isOn ? .blue : .secondary) // Change color based on state
                //.imageScale(.large)
                //.accessibilityLabel(configuration.label) // Maintain accessibility
        }
//        .buttonStyle(.plain) // Use a plain button style to avoid default button backgrounds
    }
}

private struct UniqueToolbarView: View {
    @State private var selectedItemForAccessory = 0
    @State private var isPinned = true // The state variable
    @State private var isFavorite = false

    var body: some View {
        NavigationStack {
            List(0..<3, id: \.self) { item in
                NavigationLink(value: item) {
                    Text("Item \(item)")
                }
            }
            .navigationTitle("Dashboard")
            .navigationDestination(for: Int.self) { item in
                Text("Destination for item \(item)")
                    .font(.title3)
                    .padding()
                    .navigationTitle("Item \(item)")
                    .toolbar {
                        ToolbarItem(placement: .uniqueToolbarAccessory) {
                            Form {
                                ControlGroup {
                                    Toggle("Pin", isOn: $isPinned)
                                        .toggleStyle(IconToggleStyle())
                                        .disabled(true)
                                    Text("Selected Tracks")
                                    
                                    Spacer(minLength: 2)
                                    
                                    Button("First", systemImage: "backward.end.fill", action: { print("First tapped!") })
                                        .labelStyle(.iconOnly)
                                    Button("Backward", systemImage: "arrowtriangle.backward.fill", action: { print("Backward tapped!") })
                                        .labelStyle(.iconOnly)
                                    Button("Forward", systemImage: "arrowtriangle.forward.fill", action: { print("Forward tapped!") })
                                        .labelStyle(.iconOnly)
                                    Button("Last", systemImage: "forward.end.fill", action: { print("Last tapped!") })
                                        .labelStyle(.iconOnly)
                                    
                                    Spacer(minLength: 2)
                                    
                                    Button("Last", systemImage: "plus", action: { print("Last tapped!") })
                                        .labelStyle(.iconOnly)
                                    Button("Last", systemImage: "minus", action: { print("Last tapped!") })
                                        .labelStyle(.iconOnly)
                                    Button("Last", systemImage: "xmark.app.fill", action: { print("Last tapped!") })
                                        .labelStyle(.iconOnly)
                                    Button("Last", systemImage: "arrow.down", action: { print("Last tapped!") })
                                        .labelStyle(.iconOnly)
                                    Button("Last", systemImage: "arrow.down.app", action: { print("Last tapped!") })
                                        .labelStyle(.iconOnly)
                                    
                                    Toggle(isOn: $isPinned) {
                                        Label("Favorite", systemImage: true ? "heart.fill" : "heart")
                                    }
                                    .toggleStyle(.button)
                                    .labelStyle(.iconOnly)
                                    
                                    Toggle(isOn: $isFavorite) {
                                        // 2. Use a Label with a title (for accessibility) and an SF Symbol icon.
                                        Label("Favorite", systemImage: isFavorite ? "heart.fill" : "heart")
                                    }
                                    // 3. Apply the .button toggle style.
                                    .toggleStyle(.button)
                                    // 4. Use .tint() to customize the color when the toggle is 'on'.
                                    .tint(.red)
                                    // 5. Optionally, make it an icon-only button for a compact design.
                                    .labelStyle(.iconOnly) // Displays only the icon
                                    // 6. Add standard button modifiers for styling
                                    .padding()
                                    .background(Color.secondary.opacity(0.2))
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                                    // Optional: add animation for a smoother icon change
                                    .animation(.easeInOut, value: isFavorite)
                                    
                                }
                                .controlSize(.regular)
                                .frame(maxWidth:.infinity, alignment: .center)
                            }
                        }
                    }
                    .toolbar(.visible, for: .uniqueToolbarAccessory)
            }
            .toolbar {
                ToolbarItem(placement: .uniqueToolbarAccessory) {
                    if true {
                        Form {
                            ControlGroup {
                                Button(action: {
                                    // action 1
                                }) {
                                    // checkmark.rectangle.stack.fill
                                    // pin.fill
                                    // plus.app.fill
                                    // photo.badge.plus.fill
                                    // plus
                                    // plus.rectangle.fill, plus.square.fill, minus.square.fill
                                    // plus.capsule.fill
                                    // photo.badge.plus.fill, photo.badge.arrow.down.fill,
                                    Label("Pin", systemImage: "checkmark.rectangle.stack.fill")
                                }
                                Button(action: {
                                    // action 2
                                }) {
                                    Label("Copy", systemImage: "pin.slash.fill")
                                }
                                Text("Selected Tracks")
                            }
                            .controlSize(.regular)
                            .frame(maxWidth:.infinity, alignment: .center)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text("Accessory Bar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Picker("Item", selection: $selectedItemForAccessory) {
                                Text("0").tag(0)
                                Text("1").tag(1)
                                Text("2").tag(2)
                            }
                            .labelsHidden()
                            .frame(width: 80)
                            
                            NavigationLink(value: selectedItemForAccessory) {
                                Label("Open", systemImage: "arrow.right.circle")
                            }
                        }
                    }
                }
            }
            .toolbar(.visible, for: .uniqueToolbarAccessory)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}

private struct PreviewCanvasRouterView: View {
    let destination: PreviewCanvasView

    var body: some View {
        switch destination {
        case .content:
            NavigationStack {
                ContentView()
            }
        case .settings:
            SettingsView()
        case .diffTools:
            DiffToolsView()
        case .uView:
            UniqueToolbarView()
        }
    }
}
#Preview {
    PreviewCanvasRouterView(destination: .uView)
}
#endif
