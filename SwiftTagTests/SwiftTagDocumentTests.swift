import AppKit
import Foundation
import Testing
@testable import SwiftTag

struct SwiftTagDocumentTests {
    private static var defaultTagWriteOptions: TagWriteOptions {
        TagWriteOptions(
            zeroPadTrackNumber: SaveSettingsDefaults.zeroPadTrackNumber,
            trackCountKeyStrategy: SaveSettingsDefaults.trackCountKeyStrategy,
            zeroPadDiscNumber: SaveSettingsDefaults.zeroPadDiscNumber,
            discCountKeyStrategy: SaveSettingsDefaults.discCountKeyStrategy
        )
    }

    private static func pngData(color: NSColor) throws -> Data {
        let imageSize = NSSize(width: 2, height: 2)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapRepresentation = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRepresentation.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SwiftTagDocumentTests", code: 1)
        }

        return pngData
    }

    private static func jpegData(color: NSColor) throws -> Data {
        let imageSize = NSSize(width: 2, height: 2)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmapRepresentation = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRepresentation.representation(using: .jpeg, properties: [:]) else {
            throw NSError(domain: "SwiftTagDocumentTests", code: 2)
        }

        return jpegData
    }

    private static func tempPackageURL(name: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent(name).appendingPathExtension(SwiftTagDocumentType.fileExtension)
    }

    private static func plistDictionary(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try #require(plist as? [String: Any])
    }

    @Test
    func swiftTagDocumentWriterWritesPackageAndDeduplicatesPictures() throws {
        let sharedPNG = try Self.pngData(color: .systemRed)
        let sharedPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Cover (front)",
            data: sharedPNG
        ).withComputedPictureMetadata()
        let secondPicture = FlacWritablePictureRecord(
            type: 4,
            mimeType: "image/jpeg",
            description: "Back",
            data: try Self.jpegData(color: .systemBlue)
        ).withComputedPictureMetadata()

        let destinationURL = try Self.tempPackageURL(name: "shared-package")
        let result = try SwiftTagDocumentPackageWriter.save(
            tracks: [
                SwiftTagDocumentExportTrack(
                    sortKey: "/tmp/a.flac",
                    tags: [TagKey.title: "One"],
                    pictures: [sharedPicture, secondPicture],
                    sourceFileURL: URL(fileURLWithPath: "/tmp/a.flac"),
                    securityScopedBookmarkData: Data([0x01, 0x02]),
                    flacFingerprint: " abc123 "
                ),
                SwiftTagDocumentExportTrack(
                    sortKey: "/tmp/b.flac",
                    tags: [TagKey.title: "Two"],
                    pictures: [sharedPicture],
                    sourceFileURL: URL(fileURLWithPath: "/tmp/b.flac"),
                    securityScopedBookmarkData: Data([0x03, 0x04]),
                    flacFingerprint: "def456"
                )
            ],
            state: .init(),
            to: destinationURL
        )

        let picturesDirectoryURL = destinationURL.appendingPathComponent("Pictures", isDirectory: true)
        let pictureFileNames = try FileManager.default.contentsOfDirectory(atPath: picturesDirectoryURL.path).sorted()
        #expect(pictureFileNames.count == 2)

        let manifest = try Self.plistDictionary(at: destinationURL.appendingPathComponent("Info.plist"))
        #expect(manifest["Id"] as? String == result.documentID.uuidString)
        #expect(manifest["Version"] as? String == SwiftTagDocumentType.version)
        #expect(manifest["Fingerprint"] as? String == result.fingerprint)

        let manifestTracks = try #require(manifest["Tracks"] as? [[String: Any]])
        #expect(manifestTracks.count == 2)
        #expect(manifestTracks[0]["FLAC File URL"] as? String == "/tmp/a.flac")
        #expect(manifestTracks[0]["FLAC Fingerprint"] as? String == " abc123 ")

        let firstTrackPictures = try #require(manifestTracks[0]["Pictures"] as? [[String: Any]])
        let secondTrackPictures = try #require(manifestTracks[1]["Pictures"] as? [[String: Any]])
        let sharedFileName = try #require(firstTrackPictures.first?["File"] as? String)
        #expect(sharedFileName == secondTrackPictures.first?["File"] as? String)
        #expect(sharedFileName.hasSuffix(".png"))
        #expect(firstTrackPictures[0]["Width"] as? Int == sharedPicture.width)
        #expect(firstTrackPictures[0]["Height"] as? Int == sharedPicture.height)
    }

    @Test
    func swiftTagDocumentWriterPreservesExistingDocumentIDWhenOverwritingPackage() throws {
        let destinationURL = try Self.tempPackageURL(name: "preserve-id")
        let track = SwiftTagDocumentExportTrack(
            sortKey: "/tmp/one.flac",
            tags: [TagKey.title: "One"],
            pictures: [],
            sourceFileURL: URL(fileURLWithPath: "/tmp/one.flac"),
            securityScopedBookmarkData: nil,
            flacFingerprint: "fingerprint-1"
        )

        let firstResult = try SwiftTagDocumentPackageWriter.save(
            tracks: [track],
            state: .init(),
            to: destinationURL
        )

        let secondResult = try SwiftTagDocumentPackageWriter.save(
            tracks: [
                SwiftTagDocumentExportTrack(
                    sortKey: "/tmp/one.flac",
                    tags: [TagKey.title: "Updated"],
                    pictures: [],
                    sourceFileURL: URL(fileURLWithPath: "/tmp/one.flac"),
                    securityScopedBookmarkData: nil,
                    flacFingerprint: "fingerprint-2"
                )
            ],
            state: .init(),
            to: destinationURL
        )

        #expect(secondResult.documentID == firstResult.documentID)
    }

    @Test
    func swiftTagDocumentWriterUsesStableFingerprintForReorderedTracks() throws {
        let firstDestinationURL = try Self.tempPackageURL(name: "fingerprint-a")
        let secondDestinationURL = try Self.tempPackageURL(name: "fingerprint-b")
        let tracks = [
            SwiftTagDocumentExportTrack(
                sortKey: "/tmp/b.flac",
                tags: [TagKey.title: "Two"],
                pictures: [],
                sourceFileURL: URL(fileURLWithPath: "/tmp/b.flac"),
                securityScopedBookmarkData: nil,
                flacFingerprint: "fingerprint-b"
            ),
            SwiftTagDocumentExportTrack(
                sortKey: "/tmp/a.flac",
                tags: [TagKey.title: "One"],
                pictures: [],
                sourceFileURL: URL(fileURLWithPath: "/tmp/a.flac"),
                securityScopedBookmarkData: nil,
                flacFingerprint: "fingerprint-a"
            )
        ]

        let firstResult = try SwiftTagDocumentPackageWriter.save(
            tracks: tracks,
            state: .init(),
            to: firstDestinationURL
        )
        let secondResult = try SwiftTagDocumentPackageWriter.save(
            tracks: tracks.reversed(),
            state: .init(),
            to: secondDestinationURL
        )

        #expect(firstResult.fingerprint == secondResult.fingerprint)
    }

    @MainActor
    @Test
    func tagEditorViewModelExportsCurrentEditorTagsForSwiftTagDocument() {
        let track = Track(
            album: "Edited Album",
            albumArtist: "Edited Artist",
            totalTracks: "12",
            tags: [
                TagKey.album: "Original Album",
                TagKey.albumArtist: "Original Artist",
                "TRACKTOTAL": "99",
                "DISCTOTAL": "3",
                TagKey.filename: "ignored.flac",
                TagKey.title: "Song"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/edited.flac")
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]

        let exportTrack = try! #require(viewModel.swiftTagDocumentExportTracks().first)
        #expect(exportTrack.tags[TagKey.album] == "Edited Album")
        #expect(exportTrack.tags[TagKey.albumArtist] == "Edited Artist")
        #expect(exportTrack.tags["TOTALTRACKS"] == "12")
        #expect(exportTrack.tags["TOTALDISCS"] == "3")
        #expect(exportTrack.tags["TRACKTOTAL"] == nil)
        #expect(exportTrack.tags[TagKey.filename] == nil)
    }

    @MainActor
    @Test
    func tagEditorViewModelTreatsPictureSpecMismatchAsSaveableDifference() throws {
        let pngData = try Self.pngData(color: .systemGreen)
        let currentPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Cover (front)",
            data: pngData
        ).withComputedPictureMetadata()
        let importedPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Cover (front)",
            data: pngData,
            width: 0,
            height: 0,
            depth: 0,
            colors: 0
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                tags: [TagKey.title: "Track"],
                flacPictureRecords: [currentPicture],
                sourceFileURL: URL(fileURLWithPath: "/tmp/mismatch.flac"),
                latestFileSnapshot: TrackFileSnapshot(
                    tags: [TagKey.title: "Track"],
                    picturesByType: [3: pngData],
                    pictureRecords: [importedPicture]
                )
            )
        ]

        #expect(
            viewModel.canSave(
                payload: .writePictures,
                scope: .allTracks,
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: []
            )
        )
    }
}
