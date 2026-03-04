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
    }
}
