import AppKit
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
            showsFingerprintColumn: .constant(true),
            showsDurationColumn: .constant(false),
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
            showsFingerprintColumn: .constant(true),
            showsDurationColumn: .constant(false),
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
            showsFingerprintColumn: .constant(true),
            showsDurationColumn: .constant(false),
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
            showsFingerprintColumn: .constant(true),
            showsDurationColumn: .constant(false),
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
    func albumArtSheetViewDoesNotOpenPickerOnSingleImageWellClick() throws {
        var openedSlots: [AlbumArtSlot] = []
        let sut = makeAlbumArtSheetView(
            isSaveOperationRunning: false,
            saveStatusPresentation: nil,
            onOpenPicker: { slot in
                openedSlots.append(slot)
            }
        )

        let actualView = try sut.inspect().find(AlbumArtSheetView.self).actualView()
        #expect(actualView.isEditingEnabled)
        #expect(openedSlots.isEmpty)

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtSheetView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let pickerRequestCount = source.components(separatedBy: "onOpenPicker(albumArtSlot)").count - 1
        #expect(pickerRequestCount == 2)
        #expect(!source.contains(".onTapGesture"))
        #expect(source.contains("Button(\"Import \\(navigationLinkName)...\")"))
        #expect(source.contains("Button(\"Import Picture\", systemImage: \"plus\")"))
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
            pictureCount: 3,
            pinCount: 2
        )

        let inspection = try sut.inspect()
        let _ = try inspection.find(text: "Front Cover")
        let _ = try inspection.find(text: "3 : 2")
    }

    @Test
    func albumArtSheetViewUsesBoldSidebarTextForInternalPictureDifferences() throws {
        let sut = makeAlbumArtSheetView(
            isSaveOperationRunning: false,
            saveStatusPresentation: nil,
            hasInternalPictureDifference: true
        )

        let actualView = try sut.inspect().find(AlbumArtSheetView.self).actualView()
        #expect(actualView.hasInternalPictureDifferenceForSlot(.frontCover))

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtSheetView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("let hasInternalPictureDifference = hasInternalPictureDifferenceForSlot(albumArtType.slot)"))
        #expect(source.contains(".fontWeight(hasInternalPictureDifference ? .bold : .regular)"))
    }

    @Test
    func albumArtSheetViewProvidesOverlayAndMetadataForPresentedPicture() throws {
        let sut = makeAlbumArtSheetView(
            isSaveOperationRunning: false,
            saveStatusPresentation: nil,
            infoOverlayState: AlbumArtInfoOverlayState(
                poolItemID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                messages: [
                    AlbumArtInfoOverlayMessage(
                        messageType: .hasOutOfScopeReference,
                        message: "Removed from selected tracks. Re-pin to add it back."
                    )
                ]
            ),
            metadata: AlbumArtPictureMetadata(
                poolItemID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                description: "Front Cover",
                poolItemIDShort: "ABC123",
                inSlotReferenceCount: 2,
                outOfSlotReferenceCount: 1,
                pinCount: 1,
                mimeType: "image/png",
                byteCount: 1_024,
                currentIndex: 1,
                totalCount: 3
            )
        )

        let actualView = try sut.inspect().find(AlbumArtSheetView.self).actualView()
        #expect(actualView.infoOverlayStateForSlot(.frontCover)?.messages.count == 1)
        #expect(actualView.infoOverlayStateForSlot(.frontCover)?.messages.first?.message == "Removed from selected tracks. Re-pin to add it back.")
        #expect(actualView.metadataForSlot(.frontCover)?.currentIndex == 1)
        #expect(actualView.metadataForSlot(.frontCover)?.totalCount == 3)

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtSheetView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        #expect(source.contains("let infoOverlayState = infoOverlayStateForSlot(albumArtSlot)"))
        #expect(source.contains("let overlayMessages = filteredInfoOverlayMessages(from: infoOverlayState)"))
        #expect(source.contains("let shouldShowInfoOverlay = metadataForSlot(albumArtSlot)?.poolItemID == infoOverlayState?.poolItemID"))
        #expect(source.contains("ForEach(Array(overlayMessages.enumerated()), id: \\.offset)"))
        #expect(source.contains("Button(\"Copy \\(navigationLinkName)\")"))
        #expect(source.contains("Button(\"Paste \\(navigationLinkName)\")"))
        #expect(source.contains("allowedContentTypes: [.image]"))
        #expect(source.contains("if let metadata = metadataForSlot(albumArtSlot)"))
    }

    @Test
    func albumArtSheetViewDeclaresPictureDescriptionEditorInSource() throws {
        let sut = makeAlbumArtSheetView(
            isSaveOperationRunning: false,
            saveStatusPresentation: nil
        )

        let actualView = try sut.inspect().find(AlbumArtSheetView.self).actualView()
        #expect(actualView.canEditDescriptionForSlot(.frontCover))
        #expect(actualView.descriptionValidationForSlot(.frontCover, "Draft")?.isValid == true)

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtSheetView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("Divider()"))
        #expect(source.contains("Button(\"Edit Description...\")"))
        #expect(source.contains("Text(\"Picture Description\")"))
        #expect(source.contains("Text(\"Current Description\")"))
        #expect(source.contains("TextEditor(text: $stagedPictureDescription)"))
        #expect(source.contains(".sheet(isPresented: $isPictureDescriptionSheetPresented"))
        #expect(source.contains(".alert(\"Description Too Large\""))
        #expect(source.contains(".alert(\"Picture Too Large\""))
        #expect(source.contains("Text(pictureImportAlertMessage)"))
        #expect(source.contains("Button(\"Ok\") {}"))
        #expect(source.contains("Button(\"Cancel\", role: .cancel)"))
        #expect(source.contains("Button(\"Done\")"))
    }

    @Test
    func albumArtWellViewDeclaresCopyAndPasteCommandsInSource() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtWellView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains(".onCopyCommand"))
        #expect(source.contains(".onPasteCommand(of: Self.supportedPasteContentTypes)"))
        #expect(source.contains("static func pasteProvidersFromPasteboard() -> [NSItemProvider]"))
        #expect(source.contains("utType.conforms(to: .image)"))
        #expect(source.contains("itemProvider(for: data, typeIdentifier: typeIdentifier)"))
        #expect(source.contains(".focusable(isEnabled, interactions: .activate)"))
    }

    @Test
    func albumArtViewModelPrefersOriginalImageTypeIdentifierForDropInSource() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtViewModel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("let preferredTypeIdentifier = preferredImageTypeIdentifier(for: imageProvider) ?? UTType.image.identifier"))
        #expect(source.contains("type: UTType(preferredTypeIdentifier) ?? self.albumArtType(for: data)"))
        #expect(source.contains("private func preferredImageTypeIdentifier(for provider: NSItemProvider) -> String?"))
    }

    @Test
    func flacMetadataServiceNormalizesUnsupportedPicturesToPNGInSource() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("FlacMetadataService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("let normalizedPictures = try normalizePicturesForFlacWrite(pictures)"))
        #expect(source.contains("private static func normalizePicturesForFlacWrite"))
        #expect(source.contains("mimeType: \"image/png\""))
    }

    @Test
    func albumArtSheetViewExposesTypeScopePickerWithoutTrackScopePicker() throws {
        let sut = makeAlbumArtSheetView(
            isSaveOperationRunning: false,
            saveStatusPresentation: nil,
            typePictureScope: .selectedTrackPictures
        )

        let actualView = try sut.inspect().find(AlbumArtSheetView.self).actualView()
        #expect(actualView.typePictureScopeForSlot(.frontCover) == .selectedTrackPictures)

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtSheetView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        #expect(source.contains("albumArt.sheet.typePictureScopePicker"))
        #expect(!source.contains("albumArt.sheet.trackPictureScopePicker"))
        #expect(!source.contains("Pin Album Pictures"))
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
    func albumArtViewModelSourceIncludesFrontCoverAddAction() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("AlbumArt")
            .appendingPathComponent("AlbumArtViewModel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("case .add"))
        #expect(source.contains("alert.addButton(withTitle: \"Add\")"))
    }

    @Test
    func tagEditorTrackFileViewDeclaresStatusDurationAndFingerprintColumnsInSourceOrder() throws {
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
        let durationRange = try #require(source.range(of: "TableColumn(\"Duration\")"))
        let filenameRange = try #require(source.range(of: "TableColumn(\"Filename\")"))
        let fingerprintRange = try #require(source.range(of: "TableColumn(\"Fingerprint (ffp)\")"))

        #expect(statusRange.lowerBound < trackNumberRange.lowerBound)
        #expect(trackNumberRange.lowerBound < titleRange.lowerBound)
        #expect(statusRange.lowerBound < titleRange.lowerBound)
        #expect(titleRange.lowerBound < durationRange.lowerBound)
        #expect(durationRange.lowerBound < filenameRange.lowerBound)
        #expect(filenameRange.lowerBound < fingerprintRange.lowerBound)
    }

    @Test
    func tagEditorTrackFileViewReceivesFingerprintColumnVisibilityBinding() throws {
        let track = makeTrack(id: UUID(), title: "Track A", filename: "track-a.flac")

        let sut = TagEditorTrackFileView(
            trackItems: [track],
            selection: .constant(Set([track.id])),
            showsFingerprintColumn: .constant(false),
            showsDurationColumn: .constant(false),
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

        let actualView = try sut.inspect().find(TagEditorTrackFileView.self).actualView()
        #expect(!actualView.showsFingerprintColumn.wrappedValue)
    }

    @Test
    func tagEditorTrackFileViewReceivesDurationColumnVisibilityBinding() throws {
        let track = makeTrack(id: UUID(), title: "Track A", filename: "track-a.flac")

        let sut = TagEditorTrackFileView(
            trackItems: [track],
            selection: .constant(Set([track.id])),
            showsFingerprintColumn: .constant(false),
            showsDurationColumn: .constant(true),
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

        let actualView = try sut.inspect().find(TagEditorTrackFileView.self).actualView()
        #expect(actualView.showsDurationColumn.wrappedValue)
    }

    @Test
    func tagEditorTrackFileViewSourceDeclaresFingerprintToggleContextMenuAction() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("TagEditor")
            .appendingPathComponent("TagEditorTrackFileView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("private var fingerprintColumnMenuTitle"))
        #expect(source.contains("\"Hide Fingerprint Column\""))
        #expect(source.contains("\"Show Fingerprint Column\""))
        #expect(source.contains("Button(fingerprintColumnMenuTitle)"))
    }

    @Test
    func tagEditorTrackFileViewSourceDeclaresDurationToggleContextMenuAction() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("TagEditor")
            .appendingPathComponent("TagEditorTrackFileView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("private var durationColumnMenuTitle"))
        #expect(source.contains("\"Hide Duration Column\""))
        #expect(source.contains("\"Show Duration Column\""))
        #expect(source.contains("Button(durationColumnMenuTitle)"))
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
    func tagEditorCoreTagsViewDimsCompilationCheckboxImageWhenDisabled() throws {
        let button = try hostedCompilationCheckbox(
            for: makeCoreTagsView(
                isTrackTotalAutoUpdateEnabled: false,
                compilationState: .mixed,
                isCompilationEditable: false
            )
        )

        let cell = try #require(button.cell as? NSButtonCell)
        #expect(button.state == .mixed)
        #expect(!button.isEnabled)
        #expect(cell.imageDimsWhenDisabled)
    }

    @Test
    func tagEditorCoreTagsViewCompilationCheckboxRespectsSwiftUIDisabledEnvironment() throws {
        let button = try hostedCompilationCheckbox(
            for: makeCoreTagsView(isTrackTotalAutoUpdateEnabled: false)
                .disabled(true)
        )

        #expect(button.state == .off)
        #expect(!button.isEnabled)
    }

    @Test
    func tagEditorCoreTagsViewSourcePlacesCompilationBetweenTotalDiscsAndGenre() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("TagEditor")
            .appendingPathComponent("TagEditorCoreTagsView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        let totalDiscsRange = try #require(source.range(of: ".help(totalDiscsHoverMessage)"))
        let compilationRange = try #require(source.range(of: "Text(\"Compilation\")"))
        let genreRange = try #require(source.range(of: "Text(\"Genre\")"))

        #expect(totalDiscsRange.upperBound < compilationRange.lowerBound)
        #expect(compilationRange.upperBound < genreRange.lowerBound)
    }

    @Test
    func tagWriteSettingsViewSourceReplacesLockedTrackTotalToggleWithCompilationScopeToggle() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("Settings")
            .appendingPathComponent("TagWriteSettingsView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("Apply Compilation to all Tracks"))
        #expect(source.contains("settings.tags.applyCompilationToAllTracks"))
        #expect(!source.contains("Update Track Total on Locked Tracks"))
        #expect(!source.contains("settings.tags.updateTrackTotalOnLockedTracks"))
    }

    @Test
    func diffToolsViewRendersExpectedToggleRows() throws {
        let sut = DiffToolsView()

        let rows = try sut.inspect().findAll(DiffToolsToggleRow.self)
        #expect(rows.count == 6)

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
        #expect(actualRows[5].title == "Format on Duplicate Picture")
        #expect(actualRows[5].accessibilityID == "diffTools.formatOnDuplicatePicture")
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
        #expect(source.contains("settings.feedback.pictureStatusOverlayColor"))
        #expect(source.contains("settings.feedback.quitAppOnLastWindowClose"))
        #expect(source.contains("@AppStorage(FeedbackSettingsKey.quitAppOnLastWindowClose)"))
        #expect(source.contains("FeedbackSettingsDefaults.quitAppOnLastWindowClose"))

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
        pinCount: Int = 0,
        infoOverlayState: AlbumArtInfoOverlayState? = nil,
        metadata: AlbumArtPictureMetadata? = nil,
        typePictureScope: AlbumArtPictureScope = .allTrackPictures,
        isTypePictureScopeDisabled: Bool = false,
        canGoToPreviousPicture: Bool = false,
        canGoToNextPicture: Bool = false,
        canEditDescription: Bool = true,
        hasInternalPictureDifference: Bool = false,
        isPictureImportAlertPresented: Bool = false,
        pictureImportAlertMessage: String = "",
        onOpenPicker: @escaping (AlbumArtSlot) -> Void = { _ in }
    ) -> AlbumArtSheetView {
        AlbumArtSheetView(
            isSaveOperationRunning: isSaveOperationRunning,
            isEditingEnabled: true,
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
            isPictureImportAlertPresented: .constant(isPictureImportAlertPresented),
            pictureImportAlertMessage: pictureImportAlertMessage,
            exportDocument: nil,
            exportContentType: .png,
            exportDefaultFileName: "cover",
            imageForSlot: { _ in Image(systemName: "photo") },
            hasImageForSlot: { _ in true },
            onOpenPicker: onOpenPicker,
            onPrepareExport: { _ in },
            onDropForSlot: { _, _ in false },
            onFileImportResult: { _ in },
            onFileExportResult: { _ in },
            itemProvidersForSlot: { _ in [] },
            onCopyPictureForSlot: { _ in },
            pictureCountForSlot: { _ in (pictureCount, pinCount) },
            infoOverlayStateForSlot: { _ in infoOverlayState },
            metadataForSlot: { _ in metadata },
            canEditDescriptionForSlot: { _ in canEditDescription },
            descriptionValidationForSlot: { _, description in
                FlacPictureDescriptionValidation(
                    maximumDescriptionBytes: 1_024,
                    proposedDescriptionBytes: description.lengthOfBytes(using: .utf8)
                )
            },
            onSaveDescriptionForSlot: { _, _ in },
            hasCrossTypeDuplicateForSlot: { _ in false },
            scopeLabelText: "All Tracks",
            typePictureScopeForSlot: { _ in typePictureScope },
            onSetTypePictureScope: { _, _ in },
            isPinTrackPictureOn: { _ in false },
            onSetPinTrackPicture: { _, _ in },
            isPinTrackPictureDisabled: { _ in false },
            isTypePictureScopeDisabled: { _ in isTypePictureScopeDisabled },
            canNavigateForSlot: { _ in false },
            canGoToPreviousPictureForSlot: { _ in canGoToPreviousPicture },
            canGoToNextPictureForSlot: { _ in canGoToNextPicture },
            onFirstPicture: { _ in },
            onPreviousPicture: { _ in },
            onNextPicture: { _ in },
            onLastPicture: { _ in },
            onRemovePicture: { _ in },
            hasExternalPictureDifferenceForSlot: { _ in false },
            hasInternalPictureDifferenceForSlot: { _ in hasInternalPictureDifference }
        )
    }

    private func hostedCompilationCheckbox<Content: View>(for rootView: Content) throws -> NSButton {
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)
        hostingView.layoutSubtreeIfNeeded()
        return try #require(findFirstButton(in: hostingView))
    }

    private func findFirstButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton {
            return button
        }

        for subview in view.subviews {
            if let button = findFirstButton(in: subview) {
                return button
            }
        }

        return nil
    }

    private func makeCoreTagsView(
        isTrackTotalAutoUpdateEnabled: Bool,
        compilationState: CompilationToggleState = .off,
        isCompilationEditable: Bool = true
    ) -> TagEditorCoreTagsView {
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
            compilationState: compilationState,
            isCompilationEditable: isCompilationEditable,
            onSetCompilationEnabled: { _ in },
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
            hasCompilationInternalDifference: false,
            hasCompilationExternalDifference: false,
            hasCompilationExternallyModifiedDifference: false,
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
