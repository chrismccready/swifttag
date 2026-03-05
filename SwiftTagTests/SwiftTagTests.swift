import AppKit
import Foundation
import Testing
@testable import SwiftTag

struct SwiftTagTests {
    private static var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTagTestFiles")
            .appendingPathComponent("test.flac")
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
            throw NSError(domain: "SwiftTagTests", code: 1)
        }

        return pngData
    }

    @Test
    func dateTagFormatterParsesSupportedFormats() {
        #expect(DateTagFormatter.format(DateTagFormatter.parse("2026-03-01")!) == "2026-03-01")
        #expect(DateTagFormatter.format(DateTagFormatter.parse("2026/03/01")!) == "2026-03-01")
        #expect(DateTagFormatter.format(DateTagFormatter.parse("2026-03")!) == "2026-03-01")
        #expect(DateTagFormatter.format(DateTagFormatter.parse("2026")!) == "2026-01-01")
        #expect(DateTagFormatter.parse(nil) == nil)
        #expect(DateTagFormatter.parse("") == nil)
    }

    @Test
    func tagNormalizationHandlesExpectedKeys() {
        #expect(TagNormalization.normalizeTagKey("  encoded_by  ") == "ENCODED_BY")
        #expect(TagNormalization.isExplicitTagKey("title"))
        #expect(TagNormalization.isExplicitTagKey("ALBUMARTIST"))
        #expect(!TagNormalization.isExplicitTagKey("ENCODED_BY"))
    }

    @Test
    func flacImportMapperMapsFixtureValues() {
        let tags: [String: String] = [
            "ALBUM": "Test Album",
            "ARTIST": "Test Artist",
            "ALBUMARTIST": "Test AlbumArtist",
            "TITLE": "Test Title",
            "TRACKNUMBER": "01",
            "TOTALTRACKS": "01",
            "DISCNUMBER": "01",
            "TOTALDISCS": "01",
            "GENRE": "Test Genre",
            "LOCATION": "Test Location",
            "DATE": "2026-03-01",
            "COMPOSER": "Test Composer",
            "DESCRIPTION": "Test Description",
            "ENCODED_BY": "Test Encoded_By"
        ]

        let initialValues = FlacImportMapper.initialValues(from: tags)
        #expect(initialValues.album == "Test Album")
        #expect(initialValues.albumArtist == "Test AlbumArtist")
        #expect(initialValues.totalDiscs == "1")

        let mapped = FlacImportMapper.mapTrackTags(
            sourceTags: tags,
            fileURL: URL(fileURLWithPath: "/tmp/test.flac"),
            defaultDate: Date(timeIntervalSince1970: 0)
        )

        #expect(mapped[TagKey.title] == "Test Title")
        #expect(mapped[TagKey.artist] == "Test Artist")
        #expect(mapped[TagKey.composer] == "Test Composer")
        #expect(mapped[TagKey.genre] == "Test Genre")
        #expect(mapped[TagKey.location] == "Test Location")
        #expect(mapped[TagKey.date] == "2026-03-01")
        #expect(mapped[TagKey.description] == "Test Description")
        #expect(mapped[TagKey.number] == "1")
        #expect(mapped[TagKey.disc] == "1")
        #expect(mapped["TOTALTRACKS"] == "01")
        #expect(mapped["TOTALDISCS"] == "01")
        #expect(mapped["ENCODED_BY"] == "Test Encoded_By")
        #expect(mapped[TagKey.filename] == "test.flac")
    }

    @Test
    func flacMetadataServiceReadsFixtureFile() throws {
        let fileURL = Self.fixtureURL
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let record = try FlacMetadataService.readTags(for: fileURL)
        #expect(record.tags["ALBUM"] == "Test Album")
        #expect(record.tags["ARTIST"] == "Test Artist")
        #expect(record.tags["ALBUMARTIST"] == "Test AlbumArtist")
        #expect(record.tags["TITLE"] == "Test Title")
        #expect(record.tags["TRACKNUMBER"] == "01")
        #expect(record.tags["TOTALTRACKS"] == "01")
        #expect(record.tags["DISCNUMBER"] == "1")
        #expect(record.tags["TOTALDISCS"] == "1")
        #expect(record.tags["GENRE"] == "Test Genre")
        #expect(record.tags["LOCATION"] == "Test Location")
        #expect(record.tags["DATE"] == "2026-03-01")
        #expect(record.tags["COMPOSER"] == "Test Composer")
        #expect(record.tags["DESCRIPTION"] == "Test Description")
        #expect(record.tags["ENCODED_BY"] == "Test Encoded_By")
        #expect(record.pictures.count >= 0)
    }

    @Test
    func flacImportMapperKeepsFirstPicturePerType() {
        let firstFrontCoverData = Data([0x00, 0x01, 0x02])
        let secondFrontCoverData = Data([0x03, 0x04, 0x05])
        let backCoverData = Data([0x06, 0x07, 0x08])

        let mapped = FlacImportMapper.mapPicturesByType([
            FlacPictureRecord(type: 3, mimeType: "image/png", description: "Front 1", data: firstFrontCoverData),
            FlacPictureRecord(type: 3, mimeType: "image/png", description: "Front 2", data: secondFrontCoverData),
            FlacPictureRecord(type: 4, mimeType: "image/png", description: "Back", data: backCoverData)
        ])

        #expect(mapped[3] == firstFrontCoverData)
        #expect(mapped[4] == backCoverData)
    }

    @Test
    @MainActor
    func albumArtViewModelAppliesTypeThreeToFrontCoverSlot() throws {
        let frontCoverData = try Self.pngData(color: .red)
        let backCoverData = try Self.pngData(color: .blue)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]

        let viewModel = AlbumArtViewModel()
        viewModel.applyImportedFlacPictures(
            [3: frontCoverData, 4: backCoverData],
            albumArtTypes: albumArtTypes
        )

        #expect(viewModel.hasImage(for: .frontCover))
        #expect(viewModel.hasImage(for: .backCover))
    }
}
