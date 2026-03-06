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

    private static var paddedFixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTagTestFiles")
            .appendingPathComponent("test-with_padding.flac")
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

    private static func tempFixtureCopyURL(name: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent(name)
        try FileManager.default.copyItem(at: fixtureURL, to: fileURL)
        return fileURL
    }

    private static func tempPaddedFixtureCopyURL(name: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent(name)
        try FileManager.default.copyItem(at: paddedFixtureURL, to: fileURL)
        return fileURL
    }

    private static func importedTrack(fileURL: URL, tags: [String: String]) -> Track {
        Track(
            tags: tags,
            sourceFileURL: fileURL
        )
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
    func saveSettingsDefaultsMatchPlan() {
        #expect(SaveSettingsDefaults.defaultSavePayload == .writeTagsAndPictures)
        #expect(SaveSettingsDefaults.defaultSaveScope == .allTracks)
        #expect(SaveSettingsDefaults.zeroPadTrackNumber)
        #expect(SaveSettingsDefaults.trackCountKeyStrategy == .both)
        #expect(SaveSettingsDefaults.zeroPadDiscNumber)
        #expect(SaveSettingsDefaults.discCountKeyStrategy == .totalDiscs)
    }

    @Test
    func saveSettingsEnumsRoundTripRawValues() {
        for payload in SavePayloadOption.allCases {
            #expect(SavePayloadOption(rawValue: payload.rawValue) == payload)
        }
        for scope in SaveScopeOption.allCases {
            #expect(SaveScopeOption(rawValue: scope.rawValue) == scope)
        }
        for strategy in TrackCountKeyStrategy.allCases {
            #expect(TrackCountKeyStrategy(rawValue: strategy.rawValue) == strategy)
        }
        for strategy in DiscCountKeyStrategy.allCases {
            #expect(DiscCountKeyStrategy(rawValue: strategy.rawValue) == strategy)
        }
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
        #expect(mapped[TagKey.trackNumber] == "1")
        #expect(mapped[TagKey.discNumber] == "1")
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
    func flacMetadataServiceReadsPaddedFixtureFile() throws {
        let fileURL = Self.paddedFixtureURL
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let record = try FlacMetadataService.readTags(for: fileURL)
        #expect(record.tags["ALBUM"] == "Test Album")
        #expect(record.tags["ALBUMARTIST"] == "Test AlbumArtist")
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

    @Test
    func flacWriteMapperProducesCanonicalKeysOnly() {
        let track = Track(tags: [
            TagKey.trackNumber: "1",
            TagKey.discNumber: "1",
            TagKey.title: "Mapped Title",
            TagKey.filename: "ignored.flac",
            "COMMENT": "Kept comment",
            "TRACK": "legacy",
            "DISC": "legacy"
        ])

        let tags = FlacWriteMapper.makeTags(
            for: track,
            album: "Album",
            albumArtist: "Album Artist",
            totalTracks: 12,
            totalDiscs: "2",
            options: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .totalDiscs
            )
        )

        #expect(tags[TagKey.trackNumber] == "01")
        #expect(tags[TagKey.discNumber] == "01")
        #expect(tags["ALBUM"] == "Album")
        #expect(tags["ALBUMARTIST"] == "Album Artist")
        #expect(tags["TOTALTRACKS"] == "12")
        #expect(tags["TRACKTOTAL"] == "12")
        #expect(tags["TOTALDISCS"] == "02")
        #expect(tags["COMMENT"] == "Kept comment")
        #expect(tags[TagKey.filename] == nil)
        #expect(tags["TRACK"] == nil)
        #expect(tags["DISC"] == nil)
    }

    @Test
    func flacWriteMapperAppliesZeroPaddingToTotalCountKeys() {
        let track = Track(tags: [
            TagKey.trackNumber: "2",
            TagKey.discNumber: "1",
            TagKey.title: "Mapped Title"
        ])

        let tags = FlacWriteMapper.makeTags(
            for: track,
            album: "Album",
            albumArtist: "Album Artist",
            totalTracks: 3,
            totalDiscs: "4",
            options: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .both
            )
        )

        #expect(tags[TagKey.trackNumber] == "02")
        #expect(tags["TOTALTRACKS"] == "03")
        #expect(tags["TRACKTOTAL"] == "03")
        #expect(tags[TagKey.discNumber] == "01")
        #expect(tags["TOTALDISCS"] == "04")
        #expect(tags["DISCTOTAL"] == "04")
    }

    @Test
    func flacWriteMapperLeavesTotalCountKeysUnpaddedWhenDisabled() {
        let track = Track(tags: [
            TagKey.trackNumber: "2",
            TagKey.discNumber: "1",
            TagKey.title: "Mapped Title"
        ])

        let tags = FlacWriteMapper.makeTags(
            for: track,
            album: "Album",
            albumArtist: "Album Artist",
            totalTracks: 3,
            totalDiscs: "4",
            options: TagWriteOptions(
                zeroPadTrackNumber: false,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: false,
                discCountKeyStrategy: .both
            )
        )

        #expect(tags[TagKey.trackNumber] == "2")
        #expect(tags["TOTALTRACKS"] == "3")
        #expect(tags["TRACKTOTAL"] == "3")
        #expect(tags[TagKey.discNumber] == "1")
        #expect(tags["TOTALDISCS"] == "4")
        #expect(tags["DISCTOTAL"] == "4")
    }

    @Test
    func flacMetadataServiceWritesTagsToFixtureCopy() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "write-tags-test.flac")

        _ = try FlacMetadataService.writeMetadata(
            tags: [
                "ALBUM": "Saved Album",
                TagKey.trackNumber: "03",
                "TRACKTOTAL": "09",
                "CUSTOM": "Value"
            ],
            to: fileURL,
            writeTags: true,
            writePictures: false
        )

        let record = try FlacMetadataService.readTags(for: fileURL)
        #expect(record.tags["ALBUM"] == "Saved Album")
        #expect(record.tags[TagKey.trackNumber] == "03")
        #expect(record.tags["TRACKTOTAL"] == "09")
        #expect(record.tags["CUSTOM"] == "Value")
        #expect(record.tags["ARTIST"] == nil)
    }

    @Test
    func flacMetadataServiceUsesTempfileRewriteWhenFixtureNeedsRewrite() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "write-tags-tempfile-needed.flac")
        let largeValue = String(repeating: "X", count: 16_384)

        let usedTempRewrite = try FlacMetadataService.writeMetadata(
            tags: [
                "ALBUM": "Temp Rewrite Album",
                "LARGE_CUSTOM": largeValue
            ],
            to: fileURL,
            writeTags: true,
            writePictures: false
        )

        #expect(usedTempRewrite)

        let record = try FlacMetadataService.readTags(for: fileURL)
        #expect(record.tags["ALBUM"] == "Temp Rewrite Album")
        #expect(record.tags["LARGE_CUSTOM"] == largeValue)
    }

    @Test
    func flacMetadataServiceWritesTagsWithoutChangingPictures() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "write-tags-keep-pictures.flac")
        let originalRecord = try FlacMetadataService.readTags(for: fileURL)

        _ = try FlacMetadataService.writeMetadata(
            tags: [
                "ALBUM": "Tags Only Album",
                TagKey.title: "Tags Only Title"
            ],
            to: fileURL,
            writeTags: true,
            writePictures: false
        )

        let rewrittenRecord = try FlacMetadataService.readTags(for: fileURL)
        #expect(rewrittenRecord.tags["ALBUM"] == "Tags Only Album")
        #expect(rewrittenRecord.tags[TagKey.title] == "Tags Only Title")
        #expect(rewrittenRecord.pictures.count == originalRecord.pictures.count)
        #expect(rewrittenRecord.pictures.map(\.type) == originalRecord.pictures.map(\.type))
        #expect(rewrittenRecord.pictures.map(\.data) == originalRecord.pictures.map(\.data))
    }

    @Test
    func flacMetadataServiceKeepsInPlaceWriteWhenPaddedFixtureAllowsIt() throws {
        let fileURL = try Self.tempPaddedFixtureCopyURL(name: "write-tags-no-tempfile.flac")

        let usedTempRewrite = try FlacMetadataService.writeMetadata(
            tags: [
                "ALBUM": "In Place Album"
            ],
            to: fileURL,
            writeTags: true,
            writePictures: false
        )

        #expect(!usedTempRewrite)

        let record = try FlacMetadataService.readTags(for: fileURL)
        #expect(record.tags["ALBUM"] == "In Place Album")
    }

    @Test
    func flacMetadataServiceOmitsEmptyStringTagValues() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "write-tags-omit-empty.flac")

        _ = try FlacMetadataService.writeMetadata(
            tags: [
                "ALBUM": "Non Empty Album",
                "COMMENT": "   ",
                "CUSTOM_EMPTY": ""
            ],
            to: fileURL,
            writeTags: true,
            writePictures: false
        )

        let record = try FlacMetadataService.readTags(for: fileURL)
        #expect(record.tags["ALBUM"] == "Non Empty Album")
        #expect(record.tags["COMMENT"] == nil)
        #expect(record.tags["CUSTOM_EMPTY"] == nil)
    }

    @Test
    func flacMetadataServiceWritesPicturesWithoutChangingTags() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "write-pictures-test.flac")
        let pictureData = try Self.pngData(color: .green)

        let originalRecord = try FlacMetadataService.readTags(for: fileURL)

        _ = try FlacMetadataService.writeMetadata(
            pictures: [
                FlacWritablePictureRecord(
                    type: 3,
                    mimeType: "image/png",
                    description: "Cover (front)",
                    data: pictureData
                )
            ],
            to: fileURL,
            writeTags: false,
            writePictures: true
        )

        let rewrittenRecord = try FlacMetadataService.readTags(for: fileURL)
        #expect(rewrittenRecord.tags == originalRecord.tags)
        #expect(rewrittenRecord.pictures.count == 1)
        #expect(rewrittenRecord.pictures.first?.type == 3)
        #expect(rewrittenRecord.pictures.first?.data == pictureData)
    }

    @Test
    func flacMetadataServiceWritesTagsAndPicturesTogether() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "write-tags-and-pictures-test.flac")
        let pictureData = try Self.pngData(color: .orange)

        _ = try FlacMetadataService.writeMetadata(
            tags: [
                "ALBUM": "Combined Save Album",
                TagKey.title: "Combined Save Title",
                TagKey.trackNumber: "07"
            ],
            pictures: [
                FlacWritablePictureRecord(
                    type: 3,
                    mimeType: "image/png",
                    description: "Cover (front)",
                    data: pictureData
                )
            ],
            to: fileURL,
            writeTags: true,
            writePictures: true
        )

        let record = try FlacMetadataService.readTags(for: fileURL)
        #expect(record.tags["ALBUM"] == "Combined Save Album")
        #expect(record.tags[TagKey.title] == "Combined Save Title")
        #expect(record.tags[TagKey.trackNumber] == "07")
        #expect(record.pictures.count == 1)
        #expect(record.pictures.first?.type == 3)
        #expect(record.pictures.first?.data == pictureData)
    }

    @Test
    func flacMetadataServiceRejectsNonPNGTypeOnePicture() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "write-type1-invalid.flac")

        #expect(throws: Error.self) {
            try FlacMetadataService.writeMetadata(
                pictures: [
                    FlacWritablePictureRecord(
                        type: 1,
                        mimeType: "image/jpeg",
                        description: "Icon",
                        data: Data([0xFF, 0xD8, 0xFF, 0xD9])
                    )
                ],
                to: fileURL,
                writeTags: false,
                writePictures: true
            )
        }
    }

    @Test
    func flacMetadataServiceRejectsMultipleTypeOnePictures() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "write-type1-multiple.flac")
        let firstIcon = try Self.pngData(color: .black)
        let secondIcon = try Self.pngData(color: .white)

        #expect(throws: Error.self) {
            try FlacMetadataService.writeMetadata(
                pictures: [
                    FlacWritablePictureRecord(
                        type: 1,
                        mimeType: "image/png",
                        description: "Icon 1",
                        data: firstIcon
                    ),
                    FlacWritablePictureRecord(
                        type: 1,
                        mimeType: "image/png",
                        description: "Icon 2",
                        data: secondIcon
                    )
                ],
                to: fileURL,
                writeTags: false,
                writePictures: true
            )
        }
    }

    @Test
    @MainActor
    func tagEditorViewModelSaveWritesTagsToSelectedImportedTrackOnly() throws {
        let selectedFileURL = try Self.tempFixtureCopyURL(name: "selected-save.flac")
        let unselectedFileURL = try Self.tempFixtureCopyURL(name: "unselected-save.flac")

        let selectedTrack = Self.importedTrack(
            fileURL: selectedFileURL,
            tags: [
                TagKey.title: "Selected Title",
                TagKey.trackNumber: "1",
                TagKey.discNumber: "1"
            ]
        )
        let unselectedTrack = Self.importedTrack(
            fileURL: unselectedFileURL,
            tags: [
                TagKey.title: "Unselected Title",
                TagKey.trackNumber: "2",
                TagKey.discNumber: "1"
            ]
        )

        let viewModel = TagEditorViewModel()
        viewModel.album = "Saved Album"
        viewModel.albumArtist = "Saved Album Artist"
        viewModel.totalDiscs = "1"
        viewModel.trackItems = [selectedTrack, unselectedTrack]
        viewModel.selectedTrackIDs = [selectedTrack.id]

        try viewModel.save(
            payload: .writeTags,
            scope: .selectedTracks,
            tagWriteOptions: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .totalDiscs
            ),
            albumArtPictures: []
        )

        let selectedRecord = try FlacMetadataService.readTags(for: selectedFileURL)
        #expect(selectedRecord.tags["ALBUM"] == "Saved Album")
        #expect(selectedRecord.tags["ALBUMARTIST"] == "Saved Album Artist")
        #expect(selectedRecord.tags[TagKey.title] == "Selected Title")
        #expect(selectedRecord.tags[TagKey.trackNumber] == "01")
        #expect(selectedRecord.tags["TOTALTRACKS"] == "02")
        #expect(selectedRecord.tags["TRACKTOTAL"] == "02")
        #expect(selectedRecord.tags["TOTALDISCS"] == "01")

        let unselectedRecord = try FlacMetadataService.readTags(for: unselectedFileURL)
        #expect(unselectedRecord.tags["ALBUM"] == "Test Album")
        #expect(unselectedRecord.tags[TagKey.title] == "Test Title")
        #expect(unselectedRecord.tags[TagKey.trackNumber] == "01")
    }

    @Test
    @MainActor
    func tagEditorViewModelSaveWritesPicturesWithoutChangingTags() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "viewmodel-write-pictures.flac")
        let originalRecord = try FlacMetadataService.readTags(for: fileURL)
        let pictureData = try Self.pngData(color: .purple)

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Self.importedTrack(
                fileURL: fileURL,
                tags: [
                    TagKey.title: originalRecord.tags[TagKey.title] ?? "",
                    TagKey.trackNumber: originalRecord.tags[TagKey.trackNumber] ?? "",
                    TagKey.discNumber: originalRecord.tags[TagKey.discNumber] ?? ""
                ]
            )
        ]

        try viewModel.save(
            payload: .writePictures,
            scope: .allTracks,
            tagWriteOptions: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .totalDiscs
            ),
            albumArtPictures: [
                FlacWritablePictureRecord(
                    type: 3,
                    mimeType: "image/png",
                    description: "Cover (front)",
                    data: pictureData
                )
            ]
        )

        let rewrittenRecord = try FlacMetadataService.readTags(for: fileURL)
        #expect(rewrittenRecord.tags == originalRecord.tags)
        #expect(rewrittenRecord.pictures.count == 1)
        #expect(rewrittenRecord.pictures.first?.type == 3)
        #expect(rewrittenRecord.pictures.first?.data == pictureData)
    }

    @Test
    @MainActor
    func tagEditorViewModelSaveAllTracksWritesToAllImportedTracks() throws {
        let firstFileURL = try Self.tempFixtureCopyURL(name: "save-all-first.flac")
        let secondFileURL = try Self.tempFixtureCopyURL(name: "save-all-second.flac")

        let firstTrack = Self.importedTrack(
            fileURL: firstFileURL,
            tags: [
                TagKey.title: "First Title",
                TagKey.trackNumber: "1",
                TagKey.discNumber: "1"
            ]
        )
        let secondTrack = Self.importedTrack(
            fileURL: secondFileURL,
            tags: [
                TagKey.title: "Second Title",
                TagKey.trackNumber: "2",
                TagKey.discNumber: "1"
            ]
        )

        let viewModel = TagEditorViewModel()
        viewModel.album = "All Tracks Album"
        viewModel.albumArtist = "All Tracks Artist"
        viewModel.totalDiscs = "1"
        viewModel.trackItems = [firstTrack, secondTrack]

        try viewModel.save(
            payload: .writeTags,
            scope: .allTracks,
            tagWriteOptions: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .totalDiscs
            ),
            albumArtPictures: []
        )

        let firstRecord = try FlacMetadataService.readTags(for: firstFileURL)
        let secondRecord = try FlacMetadataService.readTags(for: secondFileURL)
        #expect(firstRecord.tags["ALBUM"] == "All Tracks Album")
        #expect(secondRecord.tags["ALBUM"] == "All Tracks Album")
        #expect(firstRecord.tags["ALBUMARTIST"] == "All Tracks Artist")
        #expect(secondRecord.tags["ALBUMARTIST"] == "All Tracks Artist")
    }
}
