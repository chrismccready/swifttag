import SwiftUI
import Testing
import ViewInspector
import Foundation
@testable import SwiftTag

@MainActor
struct TrackStatusViewInspectorTests {
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
            hasExternalTitleDifference: { _ in false },
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
            hasExternalTitleDifference: { _ in false },
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
        #expect(try textFields[0].isDisabled())
        #expect(try textFields[1].isDisabled())
    }

    @Test
    func tagEditorAlbumViewEnablesAlbumFieldsWhenMetadataEditingIsOn() throws {
        let sut = makeAlbumView(isMetadataEditable: true)

        let textFields = try sut.inspect().findAll(ViewType.TextField.self)
        #expect(textFields.count >= 2)
        #expect(!(try textFields[0].isDisabled()))
        #expect(!(try textFields[1].isDisabled()))
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
            hasExternalTitleDifference: { _ in false },
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
            hasExternalTitleDifference: { _ in false },
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
        let source = try String(contentsOf: sourceURL)
        let statusRange = try #require(source.range(of: "TableColumn(\"\")"))
        let titleRange = try #require(source.range(of: "TableColumn(\"Title\")"))
        let filenameRange = try #require(source.range(of: "TableColumn(\"Filename\")"))

        #expect(statusRange.lowerBound < titleRange.lowerBound)
        #expect(titleRange.lowerBound < filenameRange.lowerBound)
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
            hasAlbumExternalDifference: false,
            hasAlbumArtistExternalDifference: false,
            showsPictureDifferenceOverlay: showsPictureDifferenceOverlay,
            frontCoverImage: Image(systemName: "photo"),
            onFrontCoverDrop: { _ in false },
            onFrontCoverTap: {}
        )
    }
}

extension TagEditorTrackFileView: Inspectable {}
extension TagEditorAlbumView: Inspectable {}
extension AlbumArtWellView: Inspectable {}
