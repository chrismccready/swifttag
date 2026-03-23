import SwiftUI
import Testing
import ViewInspector
import Foundation
import UniformTypeIdentifiers
@testable import SwiftTag

@MainActor
struct TrackStatusViewInspectorTests {
    private static var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTagTestFiles")
            .appendingPathComponent("test.flac")
    }

    private static func tempFixtureCopyURL(name: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let copiedFileURL = directoryURL.appendingPathComponent(name)
        try FileManager.default.copyItem(at: fixtureURL, to: copiedFileURL)
        return copiedFileURL
    }

    @Test
    func tagEditorTrackFileViewStatusPresentationProvidesIconForTrackRow() throws {
        let track = makeTrack(id: UUID(), title: "Track A", filename: "track-a.flac")

        let sut = TagEditorTrackFileView(
            trackItems: [track],
            selection: .constant(Set([track.id])),
            titleBindingForTrack: { _ in .constant("Track A") },
            statusPresentationForTrack: { _ in
                TrackStatusPresentation(systemImageName: "fish.fill", help: "Editor matches file.")
            },
            isTrackLocked: { _ in false },
            hasDeletedFile: { _ in false },
            hasTrackToTrackTitleDifference: { _ in false },
            hasTrackToFileTitleDifference: { _ in false },
            hasExternallyModifiedTitleDifference: { _ in false },
            onToggleLockSelection: {},
            lockMenuTitle: "Lock Selected Track",
            canToggleLockSelection: true,
            onSetTrackTotalToCount: {},
            setTrackTotalMenuTitle: "Set Track Total (1)",
            canSetTrackTotal: true,
            onAddFlacFiles: {},
            onAddReadOnlyFlacFiles: {},
            canAddFlacFiles: true,
            onReloadSelectedTracks: {},
            reloadSelectedTracksTitle: "Reload Selected Track",
            canReloadSelectedTracks: false,
            onRemoveSelectedTracks: {},
            removeSelectedTracksTitle: "Remove Selected Track",
            canRemoveSelectedTracks: false,
            onDropFlacFiles: { _ in false }
        )

        let inspectedView = try sut.inspect().find(TagEditorTrackFileView.self).actualView()
        #expect(inspectedView.statusPresentationForTrack(track.id)?.systemImageName == "fish.fill")
    }

    @Test
    func tagEditorTrackFileViewHidesStatusIconWhenPresentationMissing() throws {
        let track = makeTrack(id: UUID(), title: "Track A", filename: "track-a.flac")

        let sut = TagEditorTrackFileView(
            trackItems: [track],
            selection: .constant(Set([track.id])),
            titleBindingForTrack: { _ in .constant("Track A") },
            statusPresentationForTrack: { _ in nil },
            isTrackLocked: { _ in false },
            hasDeletedFile: { _ in false },
            hasTrackToTrackTitleDifference: { _ in false },
            hasTrackToFileTitleDifference: { _ in false },
            hasExternallyModifiedTitleDifference: { _ in false },
            onToggleLockSelection: {},
            lockMenuTitle: "Lock Selected Track",
            canToggleLockSelection: true,
            onSetTrackTotalToCount: {},
            setTrackTotalMenuTitle: "Set Track Total (1)",
            canSetTrackTotal: true,
            onAddFlacFiles: {},
            onAddReadOnlyFlacFiles: {},
            canAddFlacFiles: true,
            onReloadSelectedTracks: {},
            reloadSelectedTracksTitle: "Reload Selected Track",
            canReloadSelectedTracks: false,
            onRemoveSelectedTracks: {},
            removeSelectedTracksTitle: "Remove Selected Track",
            canRemoveSelectedTracks: false,
            onDropFlacFiles: { _ in false }
        )

        #expect((try? sut.inspect().find(ViewType.Image.self)) == nil)
    }

    @Test
    func tagEditorAlbumViewDisablesAlbumFieldsWhenMetadataEditingIsOff() throws {
        let sut = makeAlbumView(isMetadataEditable: false)

        let textFields = try sut.inspect().findAll(ViewType.TextField.self)
        #expect(textFields.count >= 2)
        #expect(textFields[0].isDisabled())
        #expect(textFields[1].isDisabled())
    }

    @Test
    func tagEditorAlbumViewEnablesAlbumFieldsWhenMetadataEditingIsOn() throws {
        let sut = makeAlbumView(isMetadataEditable: true)

        let textFields = try sut.inspect().findAll(ViewType.TextField.self)
        #expect(textFields.count >= 2)
        #expect(!textFields[0].isDisabled())
        #expect(!textFields[1].isDisabled())
    }

    @Test
    func fixtureImportBindsExpectedAlbumValuesViaAlbumView() async throws {
        let viewModel = TagEditorViewModel()
        let fixtureCopyURL = try Self.tempFixtureCopyURL(name: "viewinspector-import.flac")
        try await viewModel.importFlacFiles([fixtureCopyURL])
        let importedTrack = try #require(viewModel.trackItems.first)
        viewModel.selectedTrackIDs = [importedTrack.id]
        viewModel.reloadMiscTagRowsFromSelection()

        let sut = TagEditorAlbumView(
            albumBinding: viewModel.selectedAlbumBinding(),
            albumArtistBinding: viewModel.selectedAlbumArtistBinding(),
            isSaveOperationRunning: false,
            isMetadataEditable: true,
            isArtworkEditable: true,
            isAlbumMixedSelection: viewModel.selectedAlbumIsMixed,
            isAlbumArtistMixedSelection: viewModel.selectedAlbumArtistIsMixed,
            hasAlbumInternalDifference: false,
            hasAlbumExternalDifference: false,
            hasAlbumExternallyModifiedDifference: false,
            hasAlbumArtistInternalDifference: false,
            hasAlbumArtistExternalDifference: false,
            hasAlbumArtistExternallyModifiedDifference: false,
            showsPictureDifferenceOverlay: false,
            frontCoverImage: Image(systemName: "photo"),
            onFrontCoverDrop: { _ in false },
            onFrontCoverTap: {}
        )

        let actualView = try sut.inspect().find(TagEditorAlbumView.self).actualView()
        #expect(actualView.albumBinding?.wrappedValue == "Test Album")
        #expect(actualView.albumArtistBinding?.wrappedValue == "Test AlbumArtist")
        #expect(viewModel.miscTagRows.contains { viewModel.normalizedTagKey($0.key) == "ENCODED_BY" })
    }

    @Test
    func readOnlyFixtureImportDisablesEditingViaAlbumView() async throws {
        let viewModel = TagEditorViewModel()
        let fixtureCopyURL = try Self.tempFixtureCopyURL(name: "viewinspector-readonly-import.flac")
        try await viewModel.importFlacFiles([fixtureCopyURL], locked: true)
        let importedTrack = try #require(viewModel.trackItems.first)
        viewModel.selectedTrackIDs = [importedTrack.id]
        viewModel.reloadMiscTagRowsFromSelection()

        let sut = TagEditorAlbumView(
            albumBinding: viewModel.selectedAlbumBinding(),
            albumArtistBinding: viewModel.selectedAlbumArtistBinding(),
            isSaveOperationRunning: false,
            isMetadataEditable: viewModel.isSelectionEditable(),
            isArtworkEditable: viewModel.hasUnlockedTracks,
            isAlbumMixedSelection: viewModel.selectedAlbumIsMixed,
            isAlbumArtistMixedSelection: viewModel.selectedAlbumArtistIsMixed,
            hasAlbumInternalDifference: false,
            hasAlbumExternalDifference: false,
            hasAlbumExternallyModifiedDifference: false,
            hasAlbumArtistInternalDifference: false,
            hasAlbumArtistExternalDifference: false,
            hasAlbumArtistExternallyModifiedDifference: false,
            showsPictureDifferenceOverlay: false,
            frontCoverImage: Image(systemName: "photo"),
            onFrontCoverDrop: { _ in false },
            onFrontCoverTap: {}
        )

        let textFields = try sut.inspect().findAll(ViewType.TextField.self)
        #expect(textFields.count >= 2)
        #expect(textFields[0].isDisabled())
        #expect(textFields[1].isDisabled())
    }

    @Test
    func tagEditorTrackFileViewUsesLockedStateLookupForTrackRow() throws {
        let track = makeTrack(id: UUID(), title: "Locked Track", filename: "locked.flac")

        let sut = TagEditorTrackFileView(
            trackItems: [track],
            selection: .constant(Set([track.id])),
            titleBindingForTrack: { _ in .constant("Locked Track") },
            statusPresentationForTrack: { _ in nil },
            isTrackLocked: { _ in true },
            hasDeletedFile: { _ in false },
            hasTrackToTrackTitleDifference: { _ in false },
            hasTrackToFileTitleDifference: { _ in false },
            hasExternallyModifiedTitleDifference: { _ in false },
            onToggleLockSelection: {},
            lockMenuTitle: "Unlock Selected Track",
            canToggleLockSelection: true,
            onSetTrackTotalToCount: {},
            setTrackTotalMenuTitle: "Set Track Total (1)",
            canSetTrackTotal: true,
            onAddFlacFiles: {},
            onAddReadOnlyFlacFiles: {},
            canAddFlacFiles: true,
            onReloadSelectedTracks: {},
            reloadSelectedTracksTitle: "Reload Selected Track",
            canReloadSelectedTracks: false,
            onRemoveSelectedTracks: {},
            removeSelectedTracksTitle: "Remove Selected Track",
            canRemoveSelectedTracks: false,
            onDropFlacFiles: { _ in false }
        )

        let inspectedView = try sut.inspect().find(TagEditorTrackFileView.self).actualView()
        #expect(inspectedView.isTrackLocked(track.id))
    }

    @Test
    func tagEditorTrackFileViewUsesUnlockedStateLookupForTrackRow() throws {
        let track = makeTrack(id: UUID(), title: "Unlocked Track", filename: "unlocked.flac")

        let sut = TagEditorTrackFileView(
            trackItems: [track],
            selection: .constant(Set([track.id])),
            titleBindingForTrack: { _ in .constant("Unlocked Track") },
            statusPresentationForTrack: { _ in nil },
            isTrackLocked: { _ in false },
            hasDeletedFile: { _ in false },
            hasTrackToTrackTitleDifference: { _ in false },
            hasTrackToFileTitleDifference: { _ in false },
            hasExternallyModifiedTitleDifference: { _ in false },
            onToggleLockSelection: {},
            lockMenuTitle: "Lock Selected Track",
            canToggleLockSelection: true,
            onSetTrackTotalToCount: {},
            setTrackTotalMenuTitle: "Set Track Total (1)",
            canSetTrackTotal: true,
            onAddFlacFiles: {},
            onAddReadOnlyFlacFiles: {},
            canAddFlacFiles: true,
            onReloadSelectedTracks: {},
            reloadSelectedTracksTitle: "Reload Selected Track",
            canReloadSelectedTracks: false,
            onRemoveSelectedTracks: {},
            removeSelectedTracksTitle: "Remove Selected Track",
            canRemoveSelectedTracks: false,
            onDropFlacFiles: { _ in false }
        )

        let inspectedView = try sut.inspect().find(TagEditorTrackFileView.self).actualView()
        #expect(!inspectedView.isTrackLocked(track.id))
    }

    @Test
    func tagEditorAlbumViewPassesPictureDifferenceOverlayToAlbumArtWell() throws {
        let sut = makeAlbumView(
            isMetadataEditable: true,
            isSaveOperationRunning: false,
            showsPictureDifferenceOverlay: true
        )

        let albumArtWell = try sut.inspect().find(AlbumArtWellView.self).actualView()
        #expect(albumArtWell.showsExternalDifferenceOverlay)
    }

    @Test
    func tagEditorAlbumViewDisablesAlbumArtWellWhenSaveIsRunning() throws {
        let sut = makeAlbumView(
            isMetadataEditable: true,
            isSaveOperationRunning: true,
            showsPictureDifferenceOverlay: false
        )

        let albumArtWell = try sut.inspect().find(AlbumArtWellView.self).actualView()
        #expect(!albumArtWell.isEnabled)
    }

    @Test
    func tagEditorAlbumViewInvokesFrontCoverTapWhenEditable() throws {
        var tapCount = 0
        let sut = makeAlbumView(
            isMetadataEditable: true,
            onFrontCoverTap: { tapCount += 1 }
        )

        try sut.inspect().find(viewWithAccessibilityIdentifier: "albumArtImageWell").callOnTapGesture()
        #expect(tapCount == 1)
    }

    @Test
    func albumArtSheetViewDisablesWellAndShowsSaveOverlayWhenSaveIsRunning() throws {
        let sut = makeAlbumArtSheetView(
            isSaveOperationRunning: true,
            saveStatusPresentation: SaveStatusPresentation(
                album: "Test Album",
                currentTrackName: "Test Track",
                showsSelectedTrackName: false,
                currentTrackIndex: 1,
                totalTrackCount: 1
            )
        )

        let actualView = try sut.inspect().find(AlbumArtSheetView.self).actualView()
        #expect(actualView.isSaveOperationRunning)
        #expect(actualView.saveStatusPresentation != nil)

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtSheetView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        #expect(source.contains("if let saveStatusPresentation, isSaveOperationRunning"))
    }

    @Test
    func albumArtSheetViewEnablesWellAndHidesSaveOverlayWhenSaveIsNotRunning() throws {
        let sut = makeAlbumArtSheetView(
            isSaveOperationRunning: false,
            saveStatusPresentation: SaveStatusPresentation(
                album: "Test Album",
                currentTrackName: "Test Track",
                showsSelectedTrackName: false,
                currentTrackIndex: 1,
                totalTrackCount: 1
            )
        )

        let actualView = try sut.inspect().find(AlbumArtSheetView.self).actualView()
        #expect(!actualView.isSaveOperationRunning)
        #expect(actualView.saveStatusPresentation != nil)

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtSheetView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        #expect(source.contains("if let saveStatusPresentation, isSaveOperationRunning"))
    }

    @Test
    func albumArtSheetViewRendersScopedTypeCountLabel() throws {
        let sut = makeAlbumArtSheetView(
            isSaveOperationRunning: false,
            saveStatusPresentation: nil,
            pictureCount: 3
        )

        let _ = try sut.inspect().find(text: "Front Cover (3)")
    }

    @Test
    func albumArtSheetViewProvidesOverlayAndMetadataForPresentedPicture() throws {
        let sut = makeAlbumArtSheetView(
            isSaveOperationRunning: false,
            saveStatusPresentation: nil,
            infoOverlayText: "Removed from selected tracks. Re-pin to add it back.",
            metadataText: "In file: Mixed 1 of 3"
        )

        let actualView = try sut.inspect().find(AlbumArtSheetView.self).actualView()
        #expect(actualView.infoOverlayTextForSlot(.frontCover) == "Removed from selected tracks. Re-pin to add it back.")
        #expect(actualView.metadataTextForSlot(.frontCover) == "In file: Mixed 1 of 3")

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtSheetView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        #expect(source.contains("if let infoOverlayText = infoOverlayTextForSlot(albumArtSlot)"))
        #expect(source.contains("if let metadataText = metadataTextForSlot(albumArtSlot)"))
    }

    @Test
    func albumArtSheetViewExposesScopePickersWithConfiguredScopes() throws {
        let sut = makeAlbumArtSheetView(
            isSaveOperationRunning: false,
            saveStatusPresentation: nil,
            trackPictureScope: .selectedTrackPictures,
            typePictureScope: .selectedTrackPictures
        )

        let actualView = try sut.inspect().find(AlbumArtSheetView.self).actualView()
        #expect(actualView.trackPictureScope == .selectedTrackPictures)
        #expect(actualView.typePictureScopeForSlot(.frontCover) == .selectedTrackPictures)

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtSheetView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        #expect(source.contains("albumArt.sheet.trackPictureScopePicker"))
        #expect(source.contains("albumArt.sheet.typePictureScopePicker"))
    }

    @Test
    func albumArtSheetViewDisablesNavigationButtonsAtLeadingAndTrailingBounds() throws {
        let sut = makeAlbumArtSheetView(
            isSaveOperationRunning: false,
            saveStatusPresentation: nil,
            canGoToPreviousPicture: false,
            canGoToNextPicture: false
        )

        let actualView = try sut.inspect().find(AlbumArtSheetView.self).actualView()
        #expect(!actualView.canGoToPreviousPictureForSlot(.frontCover))
        #expect(!actualView.canGoToNextPictureForSlot(.frontCover))

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtSheetView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        #expect(source.contains(".disabled(!canGoToPreviousPictureForSlot(albumArtSlot))"))
        #expect(source.contains(".disabled(!canGoToNextPictureForSlot(albumArtSlot))"))
    }

    @Test
    func albumArtSheetViewEnablesNavigationButtonsWhenScopedNavigationIsAvailable() throws {
        let sut = makeAlbumArtSheetView(
            isSaveOperationRunning: false,
            saveStatusPresentation: nil,
            canGoToPreviousPicture: true,
            canGoToNextPicture: true
        )

        let actualView = try sut.inspect().find(AlbumArtSheetView.self).actualView()
        #expect(actualView.canGoToPreviousPictureForSlot(.frontCover))
        #expect(actualView.canGoToNextPictureForSlot(.frontCover))
    }

    @Test
    func tagEditorTrackFileViewDeclaresStatusColumnBeforeTrackNumberTitleAndFilenameInSource() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("TagEditor")
            .appendingPathComponent("TagEditorTrackFileView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let statusRange = try #require(source.range(of: "TableColumn(\"\")"))
        let trackNumberRange = try #require(source.range(of: "TableColumn(\"#\")"))
        let titleRange = try #require(source.range(of: "TableColumn(\"Title\")"))
        let filenameRange = try #require(source.range(of: "TableColumn(\"Filename\")"))

        #expect(statusRange.lowerBound < trackNumberRange.lowerBound)
        #expect(trackNumberRange.lowerBound < titleRange.lowerBound)
        #expect(statusRange.lowerBound < titleRange.lowerBound)
        #expect(titleRange.lowerBound < filenameRange.lowerBound)
    }

    @Test
    func tagEditorCoreTagsViewDisablesTotalTracksWhenAutoUpdateIsEnabled() throws {
        let sut = makeCoreTagsView(isTrackTotalAutoUpdateEnabled: true)

        let textFields = try sut.inspect().findAll(ViewType.TextField.self)
        #expect(textFields.count >= 2)
        #expect(textFields[1].isDisabled())
    }

    @Test
    func tagEditorCoreTagsViewEnablesTotalTracksWhenAutoUpdateIsDisabled() throws {
        let sut = makeCoreTagsView(isTrackTotalAutoUpdateEnabled: false)

        let textFields = try sut.inspect().findAll(ViewType.TextField.self)
        #expect(textFields.count >= 2)
        #expect(!textFields[1].isDisabled())
    }

    @Test
    func diffToolsViewRendersExpectedToggleRows() throws {
        let sut = DiffToolsView()

        let rows = try sut.inspect().findAll(DiffToolsToggleRow.self)
        #expect(rows.count == 5)

        let actualRows = try rows.map { try $0.actualView() }
        #expect(actualRows[0].title == "Format on Track to File Diff")
        #expect(actualRows[0].accessibilityID == "diffTools.formatOnTrackToFileDiff")
        #expect(actualRows[1].title == "Format on Track to Track Diff")
        #expect(actualRows[1].accessibilityID == "diffTools.formatOnTrackToTrackDiff")
        #expect(actualRows[2].title == "Format on Externally Modified Diff")
        #expect(actualRows[2].accessibilityID == "diffTools.formatOnExternallyModifiedDiff")
        #expect(actualRows[3].title == "Format on Track Total Mismatch")
        #expect(actualRows[3].accessibilityID == "diffTools.formatOnTrackTotalMismatch")
        #expect(actualRows[4].title == "Format on Disc Total Mismatch")
        #expect(actualRows[4].accessibilityID == "diffTools.formatOnDiscTotalMismatch")
    }

    @Test
    func feedbackSettingsViewExposesExpectedAccessibilityIdentifiers() throws {
        let sut = FeedbackSettingsView()

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("Settings")
            .appendingPathComponent("FeedbackSettingsView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("settings.feedback.saveNotifications"))
        #expect(source.contains("settings.feedback.theme"))
        #expect(source.contains("settings.feedback.trackToTrackDiffColor"))
        #expect(source.contains("settings.feedback.trackToFileDiffColor"))
        #expect(source.contains("settings.feedback.externallyModifiedDiffColor"))
        #expect(source.contains("settings.feedback.trackDiscTotalMismatchColor"))

        let _ = try sut.inspect().find(ViewType.Form.self)
    }

    @Test
    func settingsViewDeclaresFeedbackTabInSource() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("Settings")
            .appendingPathComponent("SettingsView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("Tab(\"Feedback\""))
        #expect(source.contains("settings.tab.feedback"))
    }

    private func makeTrack(id: UUID, title: String, filename: String) -> Track {
        Track(
            id: id,
            tags: [
                TagKey.title: title,
                TagKey.filename: filename
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/\(filename)")
        )
    }

    private func makeAlbumView(
        isMetadataEditable: Bool,
        isSaveOperationRunning: Bool = false,
        showsPictureDifferenceOverlay: Bool = false,
        onFrontCoverTap: @escaping () -> Void = {}
    ) -> TagEditorAlbumView {
        TagEditorAlbumView(
            albumBinding: .constant("Album"),
            albumArtistBinding: .constant("Album Artist"),
            isSaveOperationRunning: isSaveOperationRunning,
            isMetadataEditable: isMetadataEditable,
            isArtworkEditable: isMetadataEditable,
            isAlbumMixedSelection: false,
            isAlbumArtistMixedSelection: false,
            hasAlbumInternalDifference: false,
            hasAlbumExternalDifference: false,
            hasAlbumExternallyModifiedDifference: false,
            hasAlbumArtistInternalDifference: false,
            hasAlbumArtistExternalDifference: false,
            hasAlbumArtistExternallyModifiedDifference: false,
            showsPictureDifferenceOverlay: showsPictureDifferenceOverlay,
            frontCoverImage: Image(systemName: "photo"),
            onFrontCoverDrop: { _ in false },
            onFrontCoverTap: onFrontCoverTap
        )
    }

    private func makeAlbumArtSheetView(
        isSaveOperationRunning: Bool,
        saveStatusPresentation: SaveStatusPresentation?,
        pictureCount: Int = 1,
        infoOverlayText: String? = nil,
        metadataText: String? = nil,
        trackPictureScope: AlbumArtPictureScope = .allTrackPictures,
        typePictureScope: AlbumArtPictureScope = .allTrackPictures,
        canGoToPreviousPicture: Bool = false,
        canGoToNextPicture: Bool = false
    ) -> AlbumArtSheetView {
        AlbumArtSheetView(
            isSaveOperationRunning: isSaveOperationRunning,
            isEditingEnabled: true,
            showsPictureDifferenceOverlay: false,
            saveStatusPresentation: saveStatusPresentation,
            albumArtTypes: [
                AlbumArtType(
                    flacPictureType: 3,
                    flacDescription: "Cover (front)",
                    navigationLinkName: "Front Cover",
                    slot: .frontCover
                )
            ],
            navigationPath: .constant([.frontCover]),
            isFileImporterPresented: .constant(false),
            isFileExporterPresented: .constant(false),
            exportDocument: nil,
            exportContentType: .png,
            exportDefaultFileName: "cover",
            imageForSlot: { _ in Image(systemName: "photo") },
            hasImageForSlot: { _ in true },
            onOpenPicker: { _ in },
            onPrepareExport: { _ in },
            onDropForSlot: { _, _ in false },
            onFileImportResult: { _ in },
            onFileExportResult: { _ in },
            pictureCountForSlot: { _ in pictureCount },
            infoOverlayTextForSlot: { _ in infoOverlayText },
            duplicateOverlayTextForSlot: { _ in nil },
            metadataTextForSlot: { _ in metadataText },
            hasCrossTypeDuplicateForSlot: { _ in false },
            pinAlbumPictures: false,
            isPinAlbumPicturesDisabled: false,
            onSetPinAlbumPictures: { _ in },
            trackPictureScope: trackPictureScope,
            onSetTrackPictureScope: { _ in },
            scopeLabelText: "All Tracks",
            typePictureScopeForSlot: { _ in typePictureScope },
            onSetTypePictureScope: { _, _ in },
            isPinTrackPictureOn: { _ in false },
            onSetPinTrackPicture: { _, _ in },
            isPinTrackPictureDisabled: { _ in false },
            canNavigateForSlot: { _ in false },
            canGoToPreviousPictureForSlot: { _ in canGoToPreviousPicture },
            canGoToNextPictureForSlot: { _ in canGoToNextPicture },
            onFirstPicture: { _ in },
            onPreviousPicture: { _ in },
            onNextPicture: { _ in },
            onLastPicture: { _ in },
            onRemovePicture: { _ in }
        )
    }

    private func makeCoreTagsView(isTrackTotalAutoUpdateEnabled: Bool) -> TagEditorCoreTagsView {
        TagEditorCoreTagsView(
            totalTracksBinding: .constant("2"),
            isTotalTracksMixedSelection: false,
            hasTotalTracksMismatch: false,
            hasTotalTracksInternalDifference: false,
            totalTracksHoverMessage: "",
            totalDiscsBinding: .constant("1"),
            hasTotalDiscsMismatch: false,
            totalDiscsHoverMessage: "",
            isSelectionEditable: true,
            isAlbumMetadataEditable: true,
            hasTotalTracksExternalDifference: false,
            hasTotalTracksExternallyModifiedDifference: false,
            hasTotalDiscsExternalDifference: false,
            hasTotalDiscsExternallyModifiedDifference: false,
            hasTotalDiscsInternalDifference: false,
            selectedNumberBinding: .constant("1"),
            selectedDiscBinding: .constant("1"),
            selectedGenreBinding: .constant("Genre"),
            selectedArtistBinding: .constant("Artist"),
            selectedComposerBinding: .constant("Composer"),
            selectedLocationBinding: .constant("Location"),
            selectedDateBinding: .constant("2026-03-19"),
            selectedDescriptionsBinding: .constant("Description"),
            hasTrackNumberInternalDifference: false,
            hasTrackNumberExternalDifference: false,
            hasTrackNumberExternallyModifiedDifference: false,
            hasDiscNumberInternalDifference: false,
            hasDiscNumberExternalDifference: false,
            hasDiscNumberExternallyModifiedDifference: false,
            hasGenreInternalDifference: false,
            hasGenreExternalDifference: false,
            hasGenreExternallyModifiedDifference: false,
            hasArtistInternalDifference: false,
            hasArtistExternalDifference: false,
            hasArtistExternallyModifiedDifference: false,
            hasComposerInternalDifference: false,
            hasComposerExternalDifference: false,
            hasComposerExternallyModifiedDifference: false,
            hasLocationInternalDifference: false,
            hasLocationExternalDifference: false,
            hasLocationExternallyModifiedDifference: false,
            hasDateInternalDifference: false,
            hasDateExternalDifference: false,
            hasDateExternallyModifiedDifference: false,
            hasDescriptionInternalDifference: false,
            hasDescriptionExternalDifference: false,
            hasDescriptionExternallyModifiedDifference: false,
            onSetTrackTotalToCount: {},
            setTrackTotalMenuTitle: "Set Track Total (2)",
            canSetTrackTotal: true,
            isTrackTotalAutoUpdateEnabled: isTrackTotalAutoUpdateEnabled,
            positiveIntegerTransform: { $0 }
        )
    }
}
