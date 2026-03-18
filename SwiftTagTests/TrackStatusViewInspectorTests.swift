import SwiftUI
import Testing
import ViewInspector
import Foundation
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
            canToggleLockSelection: true
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
            canToggleLockSelection: true
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
            canToggleLockSelection: true
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
            canToggleLockSelection: true
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
    func tagEditorTrackFileViewDeclaresStatusColumnBeforeTitleAndFilenameInSource() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("TagEditor")
            .appendingPathComponent("TagEditorTrackFileView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let statusRange = try #require(source.range(of: "TableColumn(\"\")"))
        let titleRange = try #require(source.range(of: "TableColumn(\"Title\")"))
        let filenameRange = try #require(source.range(of: "TableColumn(\"Filename\")"))

        #expect(statusRange.lowerBound < titleRange.lowerBound)
        #expect(titleRange.lowerBound < filenameRange.lowerBound)
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
        showsPictureDifferenceOverlay: Bool = false
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
            onFrontCoverTap: {}
        )
    }
}
