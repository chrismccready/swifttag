import AppKit
import Foundation
import SwiftUI
import Testing
import XCTest
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

    private static var defaultTagWriteOptions: TagWriteOptions {
        TagWriteOptions(
            zeroPadTrackNumber: SaveSettingsDefaults.zeroPadTrackNumber,
            trackCountKeyStrategy: SaveSettingsDefaults.trackCountKeyStrategy,
            zeroPadDiscNumber: SaveSettingsDefaults.zeroPadDiscNumber,
            discCountKeyStrategy: SaveSettingsDefaults.discCountKeyStrategy
        )
    }

    private static func trackWithSnapshot(
        tags: [String: String],
        fileTags: [String: String]? = nil,
        pictureData: Data = Data([0x01]),
        isLocked: Bool = false
    ) -> Track {
        let normalizedFileTags = fileTags ?? tags
        return Track(
            tags: tags,
            flacPicturesByType: [3: pictureData],
            sourceFileURL: URL(fileURLWithPath: "/tmp/test.flac"),
            latestFileSnapshot: TrackFileSnapshot(
                tags: normalizedFileTags,
                picturesByType: [3: pictureData]
            ),
            isLocked: isLocked
        )
    }

    @MainActor
    private static func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        pollIntervalNanoseconds: UInt64 = 25_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        return condition()
    }

    @MainActor
    static func notificationUserInfo(for payload: SaveNotificationPayload) throws -> [AnyHashable: Any] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        return jsonObject as? [AnyHashable: Any] ?? [:]
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
    func feedbackSettingsDefaultsMatchPlan() {
        #expect(FeedbackSettingsDefaults.saveNotificationMode == .whenNotFrontmost)
        #expect(FeedbackSettingsDefaults.themePreference == .system)
        #expect(FeedbackSettingsDefaults.formatOnTrackToFileDiff)
        #expect(FeedbackSettingsDefaults.formatOnTrackToTrackDiff)
        #expect(FeedbackSettingsDefaults.formatOnExternallyModifiedDiff)
        #expect(FeedbackSettingsDefaults.warnOnTrackTotalMismatch)
        #expect(FeedbackSettingsDefaults.warnOnDiscTotalMismatch)
        #expect(!FeedbackSettingsDefaults.trackDiscTotalMismatchColor.isEmpty)
    }

    @Test
    func appThemePreferenceMapsToExpectedColorScheme() {
        #expect(AppThemePreference.system.preferredColorScheme == nil)
        #expect(AppThemePreference.light.preferredColorScheme == .light)
        #expect(AppThemePreference.dark.preferredColorScheme == .dark)
    }

    @Test
    @MainActor
    func tagDiffPresentationPrefersExternallyModifiedFormattingOverTrackDiffFormatting() {
        let presentation = TagDiffPresentation.resolve(
            tag: .album,
            hasTrackToTrackDifference: true,
            hasTrackToFileDifference: true,
            hasExternallyModifiedDifference: true,
            showsMismatchWarning: false,
            isInvalid: false,
            trackToTrackColor: .orange,
            trackToFileColor: .primary,
            externallyModifiedColor: .red,
            mismatchColor: .red,
            formatOnTrackToFileDiff: true,
            formatOnTrackToTrackDiff: true,
            formatOnExternallyModifiedDiff: true
        )

        #expect(presentation.foregroundColor == .red)
        #expect(presentation.backgroundColor == nil)
        #expect(presentation.isBold)
        #expect(presentation.isItalic)
    }

    @Test
    @MainActor
    func saveNotificationCoordinatorRespectsWhenNotFrontmostMode() {
        let defaults = UserDefaults.standard
        let previousValue = defaults.string(forKey: FeedbackSettingsKey.saveNotificationMode)
        defaults.set(SaveNotificationMode.whenNotFrontmost.rawValue, forKey: FeedbackSettingsKey.saveNotificationMode)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: FeedbackSettingsKey.saveNotificationMode)
            } else {
                defaults.removeObject(forKey: FeedbackSettingsKey.saveNotificationMode)
            }
        }

        let coordinator = SaveNotificationCoordinator(notificationCenter: nil)
        #expect(!coordinator.allowsNotificationDelivery(appIsFrontmost: true))
        #expect(coordinator.allowsNotificationDelivery(appIsFrontmost: false))
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
        #expect(initialValues.totalTracks == "1")
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
    @MainActor
    func tagEditorViewModelCanSaveWhenTrackTagsDifferFromSnapshot() {
        let viewModel = TagEditorViewModel()
        viewModel.album = "Album"
        viewModel.albumArtist = "Artist"
        viewModel.totalDiscs = "1"
        viewModel.trackItems = [
            Self.trackWithSnapshot(
                tags: [
                    TagKey.title: "Changed Title",
                    TagKey.trackNumber: "1",
                    TagKey.discNumber: "1",
                    TagKey.filename: "test.flac"
                ],
                fileTags: [
                    TagKey.title: "Original Title",
                    TagKey.trackNumber: "01",
                    TagKey.discNumber: "01"
                ]
            )
        ]

        #expect(
            viewModel.canSave(
                payload: .writeTags,
                scope: .allTracks,
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: []
            )
        )
    }

    @Test
    @MainActor
    func tagEditorViewModelSelectedAlbumBindingShowsMixedMarkerAndWritesSelection() throws {
        let firstTrack = Track(
            album: "Album A",
            albumArtist: "Artist A",
            totalTracks: "2",
            tags: [TagKey.title: "One", TagKey.filename: "one.flac"]
        )
        let secondTrack = Track(
            album: "Album B",
            albumArtist: "Artist B",
            totalTracks: "2",
            tags: [TagKey.title: "Two", TagKey.filename: "two.flac"]
        )
        let unselectedTrack = Track(
            album: "Keep Me",
            albumArtist: "Artist C",
            totalTracks: "2",
            tags: [TagKey.title: "Three", TagKey.filename: "three.flac"]
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstTrack, secondTrack, unselectedTrack]
        viewModel.selectedTrackIDs = Set([firstTrack.id, secondTrack.id])

        let binding = try #require(viewModel.selectedAlbumBinding())
        #expect(binding.wrappedValue == viewModel.mixedSelectionMarker)

        binding.wrappedValue = "Shared Album"

        #expect(viewModel.trackItems[0].album == "Shared Album")
        #expect(viewModel.trackItems[1].album == "Shared Album")
        #expect(viewModel.trackItems[2].album == "Keep Me")
    }

    @Test
    @MainActor
    func tagEditorViewModelMiscTagsAddAndDeleteRow() throws {
        let track = Track(
            tags: [
                TagKey.title: "One",
                TagKey.filename: "one.flac"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]
        viewModel.reloadMiscTagRowsFromSelection()
        let initialCount = viewModel.miscTagRows.count

        let rowID = viewModel.addMiscTagRow()
        #expect(viewModel.miscTagRows.count == initialCount + 1)
        #expect(viewModel.selectedMiscTagRowIDs == [rowID])

        let keyBinding = try #require(viewModel.miscTagKeyBinding(for: rowID))
        keyBinding.wrappedValue = "CUSTOM_ROW_A"
        viewModel.finalizeMiscTagKeyEditing(for: rowID)

        let valueBinding = try #require(viewModel.miscTagValueBinding(for: rowID))
        valueBinding.wrappedValue = "Custom Value A"
        #expect(viewModel.trackItems[0].tags["CUSTOM_ROW_A"] == "Custom Value A")

        viewModel.selectedMiscTagRowIDs = [rowID]
        viewModel.deleteSelectedMiscTagRows()
        #expect(viewModel.miscTagRows.count == initialCount)
        #expect(!viewModel.miscTagRows.contains(where: { viewModel.normalizedTagKey($0.key) == "CUSTOM_ROW_A" }))
        #expect(viewModel.trackItems[0].tags["CUSTOM_ROW_A"] == nil)
    }

    @Test
    @MainActor
    func tagEditorViewModelMiscTagsRejectsExplicitKeyForNewRow() throws {
        let track = Track(
            tags: [
                TagKey.title: "One",
                TagKey.filename: "one.flac"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]
        viewModel.reloadMiscTagRowsFromSelection()
        let initialCount = viewModel.miscTagRows.count

        let rowID = viewModel.addMiscTagRow()
        let keyBinding = try #require(viewModel.miscTagKeyBinding(for: rowID))
        keyBinding.wrappedValue = "TITLE"
        viewModel.finalizeMiscTagKeyEditing(for: rowID)

        #expect(viewModel.miscTagRows.count == initialCount)
        #expect(!viewModel.miscTagRows.contains(where: { viewModel.normalizedTagKey($0.key) == TagKey.title }))
    }

    @Test
    @MainActor
    func tagEditorViewModelMiscTagsRejectsDuplicateKeyForNewRow() throws {
        let track = Track(
            tags: [
                TagKey.title: "One",
                TagKey.filename: "one.flac"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]
        viewModel.reloadMiscTagRowsFromSelection()

        let firstRowID = viewModel.addMiscTagRow()
        let firstKeyBinding = try #require(viewModel.miscTagKeyBinding(for: firstRowID))
        firstKeyBinding.wrappedValue = "DUPLICATE_BASE"
        viewModel.finalizeMiscTagKeyEditing(for: firstRowID)
        let committedCount = viewModel.miscTagRows.count

        let duplicateRowID = viewModel.addMiscTagRow()
        let duplicateKeyBinding = try #require(viewModel.miscTagKeyBinding(for: duplicateRowID))
        duplicateKeyBinding.wrappedValue = "DUPLICATE_BASE"
        viewModel.finalizeMiscTagKeyEditing(for: duplicateRowID)

        #expect(viewModel.miscTagRows.count == committedCount)
        #expect(viewModel.miscTagRows.filter { viewModel.normalizedTagKey($0.key) == "DUPLICATE_BASE" }.count == 1)
    }

    @Test
    @MainActor
    func tagEditorViewModelMiscTagsRevertsDuplicateEditToOriginalKey() throws {
        let track = Track(
            tags: [
                TagKey.title: "One",
                TagKey.filename: "one.flac"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]
        viewModel.reloadMiscTagRowsFromSelection()

        let originalRowID = viewModel.addMiscTagRow()
        let originalKeyBinding = try #require(viewModel.miscTagKeyBinding(for: originalRowID))
        originalKeyBinding.wrappedValue = "ORIGINAL_KEY"
        viewModel.finalizeMiscTagKeyEditing(for: originalRowID)

        let editedRowID = viewModel.addMiscTagRow()
        let editedKeyBinding = try #require(viewModel.miscTagKeyBinding(for: editedRowID))
        editedKeyBinding.wrappedValue = "OTHER_KEY"
        viewModel.finalizeMiscTagKeyEditing(for: editedRowID)

        viewModel.recordOriginalMiscTagKeyIfNeeded(for: editedRowID)
        editedKeyBinding.wrappedValue = "ORIGINAL_KEY"
        viewModel.finalizeMiscTagKeyEditing(for: editedRowID)

        let rowAfterFinalize = viewModel.miscTagRows.first(where: { $0.id == editedRowID })
        #expect(rowAfterFinalize?.key == "OTHER_KEY")
        #expect(viewModel.miscTagRows.filter { viewModel.normalizedTagKey($0.key) == "ORIGINAL_KEY" }.count == 1)
    }

    @Test
    @MainActor
    func tagEditorViewModelInternalDifferenceIgnoresMissingSnapshotValueForAlbum() {
        let track = Track(
            album: "Album",
            albumArtist: "Artist",
            totalTracks: "1",
            tags: [TagKey.title: "Title", TagKey.filename: "test.flac"],
            latestFileSnapshot: TrackFileSnapshot(
                tags: [TagKey.title: "Title"],
                picturesByType: [:]
            )
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = Set([track.id])

        #expect(!viewModel.hasInternalDifference(forAnyOf: [TagKey.album]))
    }

    @Test
    @MainActor
    func tagEditorViewModelSelectedTotalDiscsBindingWritesSelectedTracksOnly() throws {
        let firstTrack = Track(
            tags: [
                TagKey.title: "One",
                TagKey.filename: "one.flac",
                "TOTALDISCS": "1"
            ]
        )
        let secondTrack = Track(
            tags: [
                TagKey.title: "Two",
                TagKey.filename: "two.flac",
                "TOTALDISCS": "2"
            ]
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstTrack, secondTrack]
        viewModel.selectedTrackIDs = [firstTrack.id]

        let binding = try #require(viewModel.selectedTotalDiscsBinding())
        binding.wrappedValue = "3"

        #expect(viewModel.trackItems[0].tags["TOTALDISCS"] == "3")
        #expect(viewModel.trackItems[1].tags["TOTALDISCS"] == "2")
    }

    @Test
    @MainActor
    func tagEditorViewModelSelectedTotalDiscsBindingShowsMixedMarkerForDifferentValues() throws {
        let firstTrack = Track(
            tags: [
                TagKey.title: "One",
                TagKey.filename: "one.flac",
                "TOTALDISCS": "1"
            ]
        )
        let secondTrack = Track(
            tags: [
                TagKey.title: "Two",
                TagKey.filename: "two.flac",
                "DISCTOTAL": "2"
            ]
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstTrack, secondTrack]
        viewModel.selectedTrackIDs = [firstTrack.id, secondTrack.id]

        let binding = try #require(viewModel.selectedTotalDiscsBinding())
        #expect(binding.wrappedValue == viewModel.mixedSelectionMarker)
    }

    @Test
    @MainActor
    func tagEditorViewModelMiscRowTrackToFileDifferenceIncludesMissingSnapshotValues() {
        let track = Track(
            tags: [
                TagKey.title: "One",
                TagKey.filename: "one.flac",
                "CUSTOM": "Changed"
            ],
            latestFileSnapshot: TrackFileSnapshot(
                tags: [
                    TagKey.title: "One"
                ],
                picturesByType: [:]
            )
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]

        let row = MiscTagRow(id: UUID(), key: "CUSTOM", value: "Changed")
        #expect(viewModel.hasTrackToFileDifference(forMiscTagRow: row))
    }

    @Test
    @MainActor
    func tagEditorViewModelBlocksSaveForLockedTrack() {
        let viewModel = TagEditorViewModel()
        viewModel.album = "Album"
        viewModel.albumArtist = "Artist"
        viewModel.totalDiscs = "1"
        viewModel.trackItems = [
            Self.trackWithSnapshot(
                tags: [
                    TagKey.title: "Changed Title",
                    TagKey.trackNumber: "1",
                    TagKey.discNumber: "1",
                    TagKey.filename: "test.flac"
                ],
                fileTags: [
                    TagKey.title: "Original Title",
                    TagKey.trackNumber: "01",
                    TagKey.discNumber: "01"
                ],
                isLocked: true
            )
        ]

        #expect(
            !viewModel.canSave(
                payload: .writeTags,
                scope: .allTracks,
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: []
            )
        )
    }

    @Test
    @MainActor
    func tagEditorViewModelLockMenuTitleReflectsSelectedState() {
        let firstTrack = Self.trackWithSnapshot(
            tags: [TagKey.title: "One", TagKey.trackNumber: "1", TagKey.discNumber: "1", TagKey.filename: "one.flac"]
        )
        let secondTrack = Self.trackWithSnapshot(
            tags: [TagKey.title: "Two", TagKey.trackNumber: "2", TagKey.discNumber: "1", TagKey.filename: "two.flac"],
            isLocked: true
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstTrack, secondTrack]

        #expect(viewModel.lockMenuTitle(for: Set([firstTrack.id])) == "Lock Selected Track")
        #expect(viewModel.lockMenuTitle(for: Set([secondTrack.id])) == "Unlock Selected Track")
        #expect(viewModel.lockMenuTitle(for: Set([firstTrack.id, secondTrack.id])) == "Toggle Selected Tracks Lock")
    }

    @Test
    @MainActor
    func tagEditorViewModelLockedSelectionKeepsBindingsReadable() throws {
        let track = Self.trackWithSnapshot(
            tags: [
                TagKey.title: "Locked Title",
                TagKey.trackNumber: "1",
                TagKey.discNumber: "1",
                TagKey.date: "2026-03-10",
                TagKey.filename: "locked.flac",
                "ENCODED_BY": "Tester"
            ],
            isLocked: true
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = Set([track.id])
        viewModel.reloadMiscTagRowsFromSelection()

        #expect(!viewModel.isSelectionEditable())

        let selectedTitleBinding = viewModel.selectedTagBinding(tagName: TagKey.title)
        #expect(selectedTitleBinding?.wrappedValue == "Locked Title")

        let selectedDateBinding = try #require(viewModel.selectedDateBinding())
        #expect(DateTagFormatter.format(selectedDateBinding.wrappedValue) == "2026-03-10")

        let miscRowID = try #require(viewModel.miscTagRows.first(where: { $0.key == "ENCODED_BY" })?.id)
        let miscKeyBinding = viewModel.miscTagKeyBinding(for: miscRowID)
        let miscValueBinding = viewModel.miscTagValueBinding(for: miscRowID)
        #expect(miscKeyBinding?.wrappedValue == "ENCODED_BY")
        #expect(miscValueBinding?.wrappedValue == "Tester")
    }

    @Test
    @MainActor
    func tagEditorViewModelUnlockSelectionRestoresEditability() throws {
        let track = Self.trackWithSnapshot(
            tags: [
                TagKey.title: "Initially Locked",
                TagKey.trackNumber: "1",
                TagKey.discNumber: "1",
                TagKey.filename: "unlock.flac"
            ],
            isLocked: true
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = Set([track.id])

        #expect(!viewModel.isSelectionEditable())
        viewModel.toggleLockState(for: Set([track.id]))
        #expect(viewModel.isSelectionEditable())

        let selectedTitleBinding = try #require(viewModel.selectedTagBinding(tagName: TagKey.title))
        selectedTitleBinding.wrappedValue = "Unlocked Title"
        #expect(viewModel.trackItems.first?.tags[TagKey.title] == "Unlocked Title")
    }

    @Test
    @MainActor
    func tagEditorViewModelStatusPresentationPrefersLockAndExternalDifference() {
        let viewModel = TagEditorViewModel()
        viewModel.album = "Album"
        viewModel.albumArtist = "Artist"
        viewModel.totalDiscs = "1"

        var track = Self.trackWithSnapshot(
            tags: [
                TagKey.title: "Title",
                TagKey.trackNumber: "1",
                TagKey.discNumber: "1",
                TagKey.filename: "test.flac"
            ]
        )
        track.externalDifferences = TrackExternalDifferences(
            isDeleted: false,
            fileValuesByTag: [TagKey.title: "File Title"],
            hasPictureDifference: false
        )
        viewModel.trackItems = [track]

        let externalPresentation = viewModel.trackStatusPresentation(
            for: track.id,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        #expect(externalPresentation?.systemImageName == "exclamationmark.triangle")

        viewModel.toggleLockState(for: Set([track.id]))
        let lockedPresentation = viewModel.trackStatusPresentation(
            for: track.id,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        #expect(lockedPresentation?.systemImageName == "lock.fill")
    }

    @Test
    @MainActor
    func tagEditorViewModelImportsReadOnlyTracksAsLocked() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "read-only-import.flac")
        let viewModel = TagEditorViewModel()

        try await viewModel.importFlacFiles([fileURL], locked: true)

        #expect(viewModel.trackItems.count == 1)
        #expect(viewModel.trackItems[0].isLocked)
        #expect(viewModel.trackItems[0].latestFileSnapshot != nil)
    }

    @Test
    @MainActor
    func tagEditorViewModelSyncedSnapshotProducesFishFillStatus() {
        let viewModel = TagEditorViewModel()
        viewModel.album = "Album"
        viewModel.albumArtist = "Artist"
        viewModel.totalDiscs = "1"
        viewModel.trackItems = [
            Track(
                tags: [
                    TagKey.title: "Title",
                    TagKey.trackNumber: "1",
                    TagKey.discNumber: "1",
                    TagKey.filename: "test.flac"
                ],
                sourceFileURL: URL(fileURLWithPath: "/tmp/test.flac")
            )
        ]
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let presentation = viewModel.trackStatusPresentation(
            for: viewModel.trackItems[0].id,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(presentation?.systemImageName == "fish.fill")
    }

    @Test
    @MainActor
    func tagEditorViewModelRefreshRenameUpdatesFilenameWithoutDeletedState() throws {
        let originalURL = try Self.tempFixtureCopyURL(name: "rename-source.flac")
        let bookmarkData = try originalURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let renamedURL = originalURL.deletingLastPathComponent().appendingPathComponent("rename-destination.flac")
        try FileManager.default.moveItem(at: originalURL, to: renamedURL)
        let metadata = try FlacMetadataService.readTags(for: renamedURL)
        let importedPicturesByType = FlacImportMapper.mapPicturesByType(metadata.pictures)
        let albumArtPictures = importedPicturesByType.map { pictureType, data in
            FlacWritablePictureRecord(
                type: pictureType,
                mimeType: "image/png",
                description: "",
                data: data
            )
        }

        let viewModel = TagEditorViewModel()
        viewModel.album = "Test Album"
        viewModel.albumArtist = "Test AlbumArtist"
        viewModel.totalDiscs = "1"
        viewModel.importedFlacPicturesByType = importedPicturesByType
        viewModel.trackItems = [
            Track(
                tags: FlacImportMapper.mapTrackTags(
                    sourceTags: metadata.tags,
                    fileURL: originalURL,
                    defaultDate: .now
                ),
                flacPicturesByType: importedPicturesByType,
                sourceFileURL: originalURL,
                securityScopedBookmarkData: bookmarkData,
                latestFileSnapshot: nil
            )
        ]
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )

        let trackID = try #require(viewModel.trackItems.first?.id)
        viewModel.refreshTrackFileState(
            for: trackID,
            currentPath: originalURL.path,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )

        let refreshedTrack = try #require(viewModel.trackItems.first)
        #expect(refreshedTrack.sourceFileURL?.path == renamedURL.path)
        #expect(refreshedTrack.tags[TagKey.filename] == renamedURL.lastPathComponent)
        #expect(refreshedTrack.externalDifferences == nil)
        #expect(!viewModel.hasDeletedFile(for: trackID))
        let presentation = viewModel.trackStatusPresentation(
            for: trackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )
        #expect(presentation?.systemImageName == "fish.fill")
    }

    @Test
    @MainActor
    func tagEditorViewModelRefreshRenameWithoutCurrentPathUsesBookmarkAndKeepsTrackActive() throws {
        let originalURL = try Self.tempFixtureCopyURL(name: "rename-bookmark-source.flac")
        let bookmarkData = try originalURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let renamedURL = originalURL.deletingLastPathComponent().appendingPathComponent("rename-bookmark-destination.flac")
        try FileManager.default.moveItem(at: originalURL, to: renamedURL)

        let metadata = try FlacMetadataService.readTags(for: renamedURL)
        let importedPicturesByType = FlacImportMapper.mapPicturesByType(metadata.pictures)
        let albumArtPictures = importedPicturesByType.map { pictureType, data in
            FlacWritablePictureRecord(
                type: pictureType,
                mimeType: "image/png",
                description: "",
                data: data
            )
        }

        let viewModel = TagEditorViewModel()
        viewModel.album = "Test Album"
        viewModel.albumArtist = "Test AlbumArtist"
        viewModel.totalDiscs = "1"
        viewModel.importedFlacPicturesByType = importedPicturesByType
        viewModel.trackItems = [
            Track(
                tags: FlacImportMapper.mapTrackTags(
                    sourceTags: metadata.tags,
                    fileURL: originalURL,
                    defaultDate: .now
                ),
                flacPicturesByType: importedPicturesByType,
                sourceFileURL: originalURL,
                securityScopedBookmarkData: bookmarkData,
                latestFileSnapshot: TrackFileSnapshot(
                    tags: Dictionary(
                        uniqueKeysWithValues: metadata.tags.map { key, value in
                            (TagNormalization.normalizeTagKey(key), value.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    ),
                    picturesByType: importedPicturesByType
                )
            )
        ]

        let trackID = try #require(viewModel.trackItems.first?.id)
        viewModel.refreshTrackFileState(
            for: trackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )

        let refreshedTrack = try #require(viewModel.trackItems.first)
        #expect(refreshedTrack.sourceFileURL?.path == renamedURL.path)
        #expect(refreshedTrack.tags[TagKey.filename] == renamedURL.lastPathComponent)
        #expect(refreshedTrack.externalDifferences == nil)
        #expect(!viewModel.hasDeletedFile(for: trackID))
    }

    @Test
    @MainActor
    func tagEditorViewModelRefreshMultipleRenamesKeepsUpdatingFilename() throws {
        let originalURL = try Self.tempFixtureCopyURL(name: "rename-twice-source.flac")
        let bookmarkData = try originalURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let firstRenamedURL = originalURL.deletingLastPathComponent().appendingPathComponent("rename-twice-first.flac")
        try FileManager.default.moveItem(at: originalURL, to: firstRenamedURL)

        let metadata = try FlacMetadataService.readTags(for: firstRenamedURL)
        let importedPicturesByType = FlacImportMapper.mapPicturesByType(metadata.pictures)
        let albumArtPictures = importedPicturesByType.map { pictureType, data in
            FlacWritablePictureRecord(
                type: pictureType,
                mimeType: "image/png",
                description: "",
                data: data
            )
        }

        let viewModel = TagEditorViewModel()
        viewModel.album = "Test Album"
        viewModel.albumArtist = "Test AlbumArtist"
        viewModel.totalDiscs = "1"
        viewModel.importedFlacPicturesByType = importedPicturesByType
        viewModel.trackItems = [
            Track(
                tags: FlacImportMapper.mapTrackTags(
                    sourceTags: metadata.tags,
                    fileURL: originalURL,
                    defaultDate: .now
                ),
                flacPicturesByType: importedPicturesByType,
                sourceFileURL: originalURL,
                securityScopedBookmarkData: bookmarkData,
                latestFileSnapshot: nil
            )
        ]
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )

        let trackID = try #require(viewModel.trackItems.first?.id)
        viewModel.refreshTrackFileState(
            for: trackID,
            currentPath: originalURL.path,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )

        let secondRenamedURL = firstRenamedURL.deletingLastPathComponent().appendingPathComponent("rename-twice-second.flac")
        try FileManager.default.moveItem(at: firstRenamedURL, to: secondRenamedURL)

        viewModel.refreshTrackFileState(
            for: trackID,
            currentPath: firstRenamedURL.path,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )

        let refreshedTrack = try #require(viewModel.trackItems.first)
        #expect(refreshedTrack.sourceFileURL?.path == secondRenamedURL.path)
        #expect(refreshedTrack.tags[TagKey.filename] == secondRenamedURL.lastPathComponent)
        #expect(refreshedTrack.externalDifferences == nil)
        #expect(!viewModel.hasDeletedFile(for: trackID))
    }

    @Test
    @MainActor
    func tagEditorViewModelRefreshMultipleRenamesWithoutCurrentPathKeepsUpdatingFilename() throws {
        let originalURL = try Self.tempFixtureCopyURL(name: "rename-twice-bookmark-source.flac")
        let bookmarkData = try originalURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let firstRenamedURL = originalURL.deletingLastPathComponent().appendingPathComponent("rename-twice-bookmark-first.flac")
        try FileManager.default.moveItem(at: originalURL, to: firstRenamedURL)

        let metadata = try FlacMetadataService.readTags(for: firstRenamedURL)
        let importedPicturesByType = FlacImportMapper.mapPicturesByType(metadata.pictures)
        let albumArtPictures = importedPicturesByType.map { pictureType, data in
            FlacWritablePictureRecord(
                type: pictureType,
                mimeType: "image/png",
                description: "",
                data: data
            )
        }

        let viewModel = TagEditorViewModel()
        viewModel.album = "Test Album"
        viewModel.albumArtist = "Test AlbumArtist"
        viewModel.totalDiscs = "1"
        viewModel.importedFlacPicturesByType = importedPicturesByType
        viewModel.trackItems = [
            Track(
                tags: FlacImportMapper.mapTrackTags(
                    sourceTags: metadata.tags,
                    fileURL: originalURL,
                    defaultDate: .now
                ),
                flacPicturesByType: importedPicturesByType,
                sourceFileURL: originalURL,
                securityScopedBookmarkData: bookmarkData,
                latestFileSnapshot: TrackFileSnapshot(
                    tags: Dictionary(
                        uniqueKeysWithValues: metadata.tags.map { key, value in
                            (TagNormalization.normalizeTagKey(key), value.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    ),
                    picturesByType: importedPicturesByType
                )
            )
        ]

        let trackID = try #require(viewModel.trackItems.first?.id)
        viewModel.refreshTrackFileState(
            for: trackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )

        let secondRenamedURL = firstRenamedURL.deletingLastPathComponent().appendingPathComponent("rename-twice-bookmark-second.flac")
        try FileManager.default.moveItem(at: firstRenamedURL, to: secondRenamedURL)

        viewModel.refreshTrackFileState(
            for: trackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )

        let refreshedTrack = try #require(viewModel.trackItems.first)
        #expect(refreshedTrack.sourceFileURL?.path == secondRenamedURL.path)
        #expect(refreshedTrack.tags[TagKey.filename] == secondRenamedURL.lastPathComponent)
        #expect(refreshedTrack.externalDifferences == nil)
        #expect(!viewModel.hasDeletedFile(for: trackID))
    }

    @Test
    @MainActor
    func tagEditorViewModelRefreshAfterRewriteDoesNotMarkFileDeleted() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "rewrite-refresh.flac")
        let bookmarkData = try fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let viewModel = TagEditorViewModel()
        viewModel.album = "Rewrite Album"
        viewModel.albumArtist = "Rewrite Artist"
        viewModel.totalDiscs = "1"
        viewModel.trackItems = [
            Track(
                tags: [
                    TagKey.title: "Rewrite Title",
                    TagKey.trackNumber: "1",
                    TagKey.discNumber: "1",
                    TagKey.filename: fileURL.lastPathComponent
                ],
                sourceFileURL: fileURL,
                securityScopedBookmarkData: bookmarkData
            )
        ]
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        _ = try await viewModel.save(
            payload: .writeTags,
            scope: .allTracks,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: [],
            editorSessionID: UUID()
        )

        let trackID = try #require(viewModel.trackItems.first?.id)
        viewModel.refreshTrackFileState(
            for: trackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(!viewModel.hasDeletedFile(for: trackID))
        #expect(viewModel.trackItems.first?.sourceFileURL?.path == fileURL.path)
    }

    @Test
    func trackFileMonitorUsesFilePathForObservation() {
        let fileURL = URL(fileURLWithPath: "/tmp/test-folder/test.flac")
        let monitoredURL = TrackFileMonitor.monitoredURL(for: fileURL)

        #expect(monitoredURL.path == "/tmp/test-folder/test.flac")
    }

    @Test
    @MainActor
    func trackFileMonitorRenamesNeverInterpretTrackAsDeleted() async throws {
        let originalURL = try Self.tempFixtureCopyURL(name: "rename-monitor-source.flac")
        let bookmarkData = try originalURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let metadata = try FlacMetadataService.readTags(for: originalURL)
        let importedPicturesByType = FlacImportMapper.mapPicturesByType(metadata.pictures)
        let albumArtPictures = importedPicturesByType.map { pictureType, data in
            FlacWritablePictureRecord(
                type: pictureType,
                mimeType: "image/png",
                description: "",
                data: data
            )
        }

        let viewModel = TagEditorViewModel()
        viewModel.album = "Test Album"
        viewModel.albumArtist = "Test AlbumArtist"
        viewModel.totalDiscs = "1"
        viewModel.importedFlacPicturesByType = importedPicturesByType
        viewModel.trackItems = [
            Track(
                tags: FlacImportMapper.mapTrackTags(
                    sourceTags: metadata.tags,
                    fileURL: originalURL,
                    defaultDate: .now
                ),
                flacPicturesByType: importedPicturesByType,
                sourceFileURL: originalURL,
                securityScopedBookmarkData: bookmarkData,
                latestFileSnapshot: nil
            )
        ]
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )

        let trackID = try #require(viewModel.trackItems.first?.id)
        let monitor = TrackFileMonitor()
        defer { monitor.stopAll() }

        var sawDeleted = false
        var eventCount = 0
        var onChange: ((TrackFileMonitorEvent) -> Void)!
        onChange = { event in
            eventCount += 1
            viewModel.refreshTrackFileState(
                for: event.trackID,
                currentPath: event.currentPath,
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: albumArtPictures
            )
            if viewModel.hasDeletedFile(for: trackID) {
                sawDeleted = true
            }
            monitor.replaceObservations(for: viewModel.trackItems, onChange: onChange)
        }

        monitor.replaceObservations(for: viewModel.trackItems, onChange: onChange)

        let firstRenamedURL = originalURL.deletingLastPathComponent().appendingPathComponent("rename-monitor-first.flac")
        try FileManager.default.moveItem(at: originalURL, to: firstRenamedURL)

        let firstRenameObserved = await Self.waitUntil {
            viewModel.trackItems.first?.sourceFileURL?.path == firstRenamedURL.path
        }
        #expect(firstRenameObserved)
        #expect(viewModel.trackItems.first?.tags[TagKey.filename] == firstRenamedURL.lastPathComponent)
        #expect(!viewModel.hasDeletedFile(for: trackID))
        #expect(!sawDeleted)

        let secondRenamedURL = firstRenamedURL.deletingLastPathComponent().appendingPathComponent("rename-monitor-second.flac")
        try FileManager.default.moveItem(at: firstRenamedURL, to: secondRenamedURL)

        let secondRenameObserved = await Self.waitUntil {
            viewModel.trackItems.first?.sourceFileURL?.path == secondRenamedURL.path
        }
        #expect(secondRenameObserved)
        #expect(viewModel.trackItems.first?.tags[TagKey.filename] == secondRenamedURL.lastPathComponent)
        #expect(!viewModel.hasDeletedFile(for: trackID))
        #expect(!sawDeleted)
        #expect(eventCount >= 2)
    }

    @Test
    @MainActor
    func trackFileMonitorDeleteMarksTrackDeletedAfterRetryWindow() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "delete-monitor-source.flac")
        let bookmarkData = try fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let metadata = try FlacMetadataService.readTags(for: fileURL)
        let importedPicturesByType = FlacImportMapper.mapPicturesByType(metadata.pictures)
        let albumArtPictures = importedPicturesByType.map { pictureType, data in
            FlacWritablePictureRecord(
                type: pictureType,
                mimeType: "image/png",
                description: "",
                data: data
            )
        }

        let viewModel = TagEditorViewModel()
        viewModel.album = "Test Album"
        viewModel.albumArtist = "Test AlbumArtist"
        viewModel.totalDiscs = "1"
        viewModel.importedFlacPicturesByType = importedPicturesByType
        viewModel.trackItems = [
            Track(
                tags: FlacImportMapper.mapTrackTags(
                    sourceTags: metadata.tags,
                    fileURL: fileURL,
                    defaultDate: .now
                ),
                flacPicturesByType: importedPicturesByType,
                sourceFileURL: fileURL,
                securityScopedBookmarkData: bookmarkData,
                latestFileSnapshot: nil
            )
        ]
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )

        let trackID = try #require(viewModel.trackItems.first?.id)
        let monitor = TrackFileMonitor()
        defer { monitor.stopAll() }

        var onChange: ((TrackFileMonitorEvent) -> Void)!
        onChange = { event in
            viewModel.refreshTrackFileState(
                for: event.trackID,
                currentPath: event.currentPath,
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: albumArtPictures
            )
            monitor.replaceObservations(for: viewModel.trackItems, onChange: onChange)
        }

        monitor.replaceObservations(for: viewModel.trackItems, onChange: onChange)
        try FileManager.default.removeItem(at: fileURL)

        let deleteObserved = await Self.waitUntil {
            viewModel.hasDeletedFile(for: trackID)
        }

        #expect(deleteObserved)
    }

    @Test
    @MainActor
    func tagEditorViewModelCanSaveWhenOnlyExternalTagDifferenceExists() {
        let viewModel = TagEditorViewModel()
        viewModel.album = "Album"
        viewModel.albumArtist = "Artist"
        viewModel.totalDiscs = "1"

        viewModel.trackItems = [
            Track(tags: [
                TagKey.title: "Title",
                TagKey.trackNumber: "1",
                TagKey.discNumber: "1",
                TagKey.filename: "test.flac"
            ], sourceFileURL: URL(fileURLWithPath: "/tmp/test.flac"))
        ]
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        viewModel.trackItems[0].externalDifferences = TrackExternalDifferences(
            isDeleted: false,
            fileValuesByTag: [TagKey.title: "External Title"],
            hasPictureDifference: false
        )

        #expect(
            viewModel.canSave(
                payload: .writeTags,
                scope: .allTracks,
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: []
            )
        )

        viewModel.trackItems[0].externalDifferences = nil

        #expect(
            !viewModel.canSave(
                payload: .writeTags,
                scope: .allTracks,
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: []
            )
        )
    }

    @Test
    @MainActor
    func tagEditorViewModelCanSaveWhenOnlyExternalPictureDifferenceExists() {
        let viewModel = TagEditorViewModel()
        viewModel.album = "Album"
        viewModel.albumArtist = "Artist"
        viewModel.totalDiscs = "1"

        viewModel.trackItems = [
            Track(tags: [
                TagKey.title: "Title",
                TagKey.trackNumber: "1",
                TagKey.discNumber: "1",
                TagKey.filename: "test.flac"
            ], sourceFileURL: URL(fileURLWithPath: "/tmp/test.flac"))
        ]
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        viewModel.trackItems[0].externalDifferences = TrackExternalDifferences(
            isDeleted: false,
            fileValuesByTag: [:],
            hasPictureDifference: true
        )

        #expect(
            viewModel.canSave(
                payload: .writePictures,
                scope: .allTracks,
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: []
            )
        )

        viewModel.trackItems[0].externalDifferences = nil

        #expect(
            !viewModel.canSave(
                payload: .writePictures,
                scope: .allTracks,
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: []
            )
        )
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
    func tagEditorViewModelSaveWritesTagsToSelectedImportedTrackOnly() async throws {
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

        _ = try await viewModel.save(
            payload: .writeTags,
            scope: .selectedTracks,
            tagWriteOptions: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .totalDiscs
            ),
            albumArtPictures: [],
            editorSessionID: UUID()
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
    func tagEditorViewModelSaveWritesPicturesWithoutChangingTags() async throws {
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

        _ = try await viewModel.save(
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
            ],
            editorSessionID: UUID()
        )

        let rewrittenRecord = try FlacMetadataService.readTags(for: fileURL)
        #expect(rewrittenRecord.tags == originalRecord.tags)
        #expect(rewrittenRecord.pictures.count == 1)
        #expect(rewrittenRecord.pictures.first?.type == 3)
        #expect(rewrittenRecord.pictures.first?.data == pictureData)
    }

    @Test
    @MainActor
    func tagEditorViewModelSaveTagsPersistsAlbumEditsAcrossReimport() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "save-tags-reimport.flac")
        let firstViewModel = TagEditorViewModel()
        try await firstViewModel.importFlacFiles([fileURL])
        let firstTrack = try #require(firstViewModel.trackItems.first)
        firstViewModel.selectedTrackIDs = [firstTrack.id]
        let albumBinding = try #require(firstViewModel.selectedAlbumBinding())
        albumBinding.wrappedValue = "Saved By Menu Tags"

        _ = try await firstViewModel.save(
            payload: .writeTags,
            scope: .allTracks,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: [],
            editorSessionID: UUID()
        )

        let secondViewModel = TagEditorViewModel()
        try await secondViewModel.importFlacFiles([fileURL])
        let secondTrack = try #require(secondViewModel.trackItems.first)
        secondViewModel.selectedTrackIDs = [secondTrack.id]
        let reimportedAlbumBinding = try #require(secondViewModel.selectedAlbumBinding())
        #expect(reimportedAlbumBinding.wrappedValue == "Saved By Menu Tags")
    }

    @Test
    @MainActor
    func tagEditorViewModelSaveAllTracksWritesToAllImportedTracks() async throws {
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

        _ = try await viewModel.save(
            payload: .writeTags,
            scope: .allTracks,
            tagWriteOptions: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .totalDiscs
            ),
            albumArtPictures: [],
            editorSessionID: UUID()
        )

        let firstRecord = try FlacMetadataService.readTags(for: firstFileURL)
        let secondRecord = try FlacMetadataService.readTags(for: secondFileURL)
        #expect(firstRecord.tags["ALBUM"] == "All Tracks Album")
        #expect(secondRecord.tags["ALBUM"] == "All Tracks Album")
        #expect(firstRecord.tags["ALBUMARTIST"] == "All Tracks Artist")
        #expect(secondRecord.tags["ALBUMARTIST"] == "All Tracks Artist")
    }

    @Test
    @MainActor
    func tagEditorViewModelSaveReturnsFinalBookmarkAfterRewrite() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "save-notification-rewrite.flac")
        let originalBookmarkData = try fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let track = Track(
            tags: [
                TagKey.title: "Padded Title",
                TagKey.trackNumber: "1",
                TagKey.discNumber: "1"
            ],
            sourceFileURL: fileURL,
            securityScopedBookmarkData: originalBookmarkData
        )

        let viewModel = TagEditorViewModel()
        viewModel.album = "Padded Save Album"
        viewModel.albumArtist = "Padded Save Artist"
        viewModel.totalDiscs = "1"
        viewModel.trackItems = [track]

        let result = try await viewModel.save(
            payload: .writeTags,
            scope: .allTracks,
            tagWriteOptions: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .totalDiscs
            ),
            albumArtPictures: [],
            editorSessionID: UUID()
        )

        #expect(result.trackReferences.count == 1)
        let savedReference = try #require(result.trackReferences.first)
        let refreshedBookmarkData = try #require(savedReference.securityScopedBookmarkData)
        #expect(viewModel.trackItems.first?.securityScopedBookmarkData == refreshedBookmarkData)

        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: refreshedBookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        #expect(!isStale)

        let didAccess = resolvedURL.startAccessingSecurityScopedResource()
        #expect(didAccess)
        defer {
            if didAccess {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }

        let savedRecord = try FlacMetadataService.readTags(for: resolvedURL)
        #expect(savedRecord.tags["ALBUM"] == "Padded Save Album")
        #expect(savedRecord.tags["ALBUMARTIST"] == "Padded Save Artist")
        #expect(savedReference.filePath == resolvedURL.path)

        var originalBookmarkIsStale = false
        let originalResolvedURL = try URL(
            resolvingBookmarkData: originalBookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &originalBookmarkIsStale
        )
        #expect(!originalBookmarkIsStale)
        #expect(originalResolvedURL.path == resolvedURL.path)
    }

    @Test
    @MainActor
    func saveNotificationPreparationPersistsFinalSavedBookmarkAfterRewrite() async throws {
        let suiteName = "SwiftTagTests.SaveNotificationPreparation.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }

        let fileURL = try Self.tempFixtureCopyURL(name: "save-notification-store-rewrite.flac")
        let originalBookmarkData = try fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let track = Track(
            tags: [
                TagKey.title: "Store Title",
                TagKey.trackNumber: "1",
                TagKey.discNumber: "1"
            ],
            sourceFileURL: fileURL,
            securityScopedBookmarkData: originalBookmarkData
        )

        let viewModel = TagEditorViewModel()
        viewModel.album = "Stored Notification Album"
        viewModel.albumArtist = "Stored Notification Artist"
        viewModel.totalDiscs = "1"
        viewModel.trackItems = [track]

        let saveResult = try await viewModel.save(
            payload: .writeTags,
            scope: .allTracks,
            tagWriteOptions: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .totalDiscs
            ),
            albumArtPictures: [],
            editorSessionID: UUID()
        )

        let coordinator = SaveNotificationCoordinator(userDefaults: userDefaults)
        let payload = coordinator.prepareSuccessNotification(for: saveResult)
        let record = try #require(coordinator.reopenRecord(for: payload.reopenRecordID))
        let savedReference = try #require(record.trackReferences.first)
        let savedBookmarkData = try #require(savedReference.securityScopedBookmarkData)

        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: savedBookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        #expect(!isStale)
        #expect(savedReference.filePath == resolvedURL.path)

        let didAccess = resolvedURL.startAccessingSecurityScopedResource()
        #expect(didAccess)
        defer {
            if didAccess {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }

        let savedRecord = try FlacMetadataService.readTags(for: resolvedURL)
        #expect(savedRecord.tags["ALBUM"] == "Stored Notification Album")
        #expect(savedRecord.tags["ALBUMARTIST"] == "Stored Notification Artist")
    }

    @Test
    func saveStatusTimingReturnsRemainingDurationWhenMinimumNotMet() {
        let startedAt = Date(timeIntervalSince1970: 10)
        let endedAt = Date(timeIntervalSince1970: 10.4)

        let remaining = SaveStatusTiming.remainingDisplayDuration(
            startedAt: startedAt,
            endedAt: endedAt
        )

        #expect(abs(remaining - 1.1) < 0.0001)
    }

    @Test
    func saveStatusTimingReturnsZeroWhenMinimumAlreadyMet() {
        let startedAt = Date(timeIntervalSince1970: 10)
        let endedAt = Date(timeIntervalSince1970: 12)

        let remaining = SaveStatusTiming.remainingDisplayDuration(
            startedAt: startedAt,
            endedAt: endedAt
        )

        #expect(remaining == 0)
    }

    @Test
    @MainActor
    func tagEditorViewModelSaveReportsProgressForSelectedTrackSubset() async throws {
        let firstFileURL = try Self.tempFixtureCopyURL(name: "progress-first.flac")
        let secondFileURL = try Self.tempFixtureCopyURL(name: "progress-second.flac")
        let thirdFileURL = try Self.tempFixtureCopyURL(name: "progress-third.flac")

        let firstTrack = Self.importedTrack(
            fileURL: firstFileURL,
            tags: [
                TagKey.title: "First",
                TagKey.trackNumber: "1",
                TagKey.discNumber: "1"
            ]
        )
        let secondTrack = Self.importedTrack(
            fileURL: secondFileURL,
            tags: [
                TagKey.title: "Second",
                TagKey.trackNumber: "2",
                TagKey.discNumber: "1"
            ]
        )
        let thirdTrack = Self.importedTrack(
            fileURL: thirdFileURL,
            tags: [
                TagKey.title: "Third",
                TagKey.trackNumber: "3",
                TagKey.discNumber: "1"
            ]
        )

        let viewModel = TagEditorViewModel()
        viewModel.album = "Progress Album"
        viewModel.albumArtist = "Progress Artist"
        viewModel.totalDiscs = "1"
        viewModel.trackItems = [firstTrack, secondTrack, thirdTrack]
        viewModel.selectedTrackIDs = [firstTrack.id, thirdTrack.id]

        var progressUpdates: [(Int, Int, String)] = []

        _ = try await viewModel.save(
            payload: .writeTags,
            scope: .selectedTracks,
            tagWriteOptions: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .totalDiscs
            ),
            albumArtPictures: [],
            editorSessionID: UUID(),
            progress: { currentTrackIndex, totalTrackCount, currentTrackName in
                progressUpdates.append((currentTrackIndex, totalTrackCount, currentTrackName))
            }
        )

        #expect(progressUpdates.count == 2)
        #expect(progressUpdates[0].0 == 1)
        #expect(progressUpdates[0].1 == 2)
        #expect(progressUpdates[0].2 == "First")
        #expect(progressUpdates[1].0 == 2)
        #expect(progressUpdates[1].1 == 2)
        #expect(progressUpdates[1].2 == "Third")
    }

}

final class SaveNotificationCoordinatorTests: XCTestCase {
    func testTrackSetFingerprintUsesStableSortedPaths() {
        let fingerprint = TrackSetFingerprint.make(from: [
            "/tmp/b.flac",
            "/tmp/a.flac"
        ])

        XCTAssertEqual(fingerprint, "/tmp/a.flac\n/tmp/b.flac")
    }

    @MainActor
    func testSaveNotificationStorePersistsReopenRecords() {
        let suiteName = "SwiftTagTests.SaveNotificationCoordinator.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }

        let store = SaveNotificationStore(userDefaults: userDefaults)
        store.resetForTesting()

        let record = SaveReopenRecord(
            sourceSessionID: UUID(),
            payload: .writeTagsAndPictures,
            fingerprint: "/tmp/test.flac",
            trackReferences: [
                ImportedTrackReference(
                    filePath: "/tmp/test.flac",
                    securityScopedBookmarkData: nil
                )
            ]
        )
        store.saveReopenRecord(record)

        XCTAssertEqual(store.reopenRecord(for: record.id), record)
    }

    @MainActor
    func testPrepareSuccessNotificationRecordsLastScheduledPayload() {
        let coordinator = SaveNotificationCoordinator.shared
        coordinator.resetForTesting()
        defer {
            coordinator.resetForTesting()
        }

        let sourceSessionID = UUID()
        let trackReferences = [
            ImportedTrackReference(
                filePath: "/tmp/rewritten.flac",
                securityScopedBookmarkData: Data([0x01, 0x02, 0x03])
            )
        ]
        let result = SaveOperationResult(
            sourceSessionID: sourceSessionID,
            payload: .writeTags,
            trackReferences: trackReferences,
            fingerprint: TrackSetFingerprint.make(from: trackReferences)
        )

        let payload = coordinator.prepareSuccessNotification(for: result)

        XCTAssertEqual(coordinator.lastScheduledPayload(), payload)
        let storedRecord = coordinator.reopenRecord(for: payload.reopenRecordID)
        XCTAssertEqual(storedRecord?.id, payload.reopenRecordID)
        XCTAssertEqual(storedRecord?.sourceSessionID, result.sourceSessionID)
        XCTAssertEqual(storedRecord?.payload, result.payload)
        XCTAssertEqual(storedRecord?.fingerprint, result.fingerprint)
        XCTAssertEqual(storedRecord?.trackReferences, result.trackReferences)
    }

    @MainActor
    func testEditorWindowCoordinatorFindsRegisteredSessionByFingerprint() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let sessionValue = EditorSessionValue(sessionID: UUID())
        let references = [
            ImportedTrackReference(filePath: "/tmp/example.flac", securityScopedBookmarkData: nil)
        ]
        let fingerprint = TrackSetFingerprint.make(from: references)

        coordinator.register(sessionValue: sessionValue, trackReferences: references)

        XCTAssertEqual(coordinator.existingSession(forFingerprint: fingerprint), sessionValue)
    }

    @MainActor
    func testEditorWindowCoordinatorFindsRegisteredSessionForSavedSubset() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let sessionValue = EditorSessionValue(sessionID: UUID())
        let allReferences = [
            ImportedTrackReference(filePath: "/tmp/a.flac", securityScopedBookmarkData: nil),
            ImportedTrackReference(filePath: "/tmp/b.flac", securityScopedBookmarkData: nil)
        ]
        let savedSubset = [
            ImportedTrackReference(filePath: "/tmp/a.flac", securityScopedBookmarkData: nil)
        ]
        let savedFingerprint = TrackSetFingerprint.make(from: savedSubset)

        coordinator.register(sessionValue: sessionValue, trackReferences: allReferences)

        XCTAssertEqual(coordinator.existingSession(forFingerprint: savedFingerprint), sessionValue)
    }

    @MainActor
    func testNotificationResponseUsesExistingSessionWhenFingerprintMatches() throws {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let existingSession = EditorSessionValue(sessionID: UUID())
        let references = [
            ImportedTrackReference(filePath: "/tmp/existing.flac", securityScopedBookmarkData: nil)
        ]
        let fingerprint = TrackSetFingerprint.make(from: references)
        coordinator.register(sessionValue: existingSession, trackReferences: references)

        var openedSession: EditorSessionValue?
        coordinator.setOpenEditorWindowAction { sessionValue in
            openedSession = sessionValue
        }

        let payload = SaveNotificationPayload(
            reopenRecordID: UUID(),
            sourceSessionID: UUID(),
            payload: .writeTags,
            fingerprint: fingerprint,
            trackCount: 1
        )

        SaveNotificationCoordinator.shared.handleNotificationResponse(
            userInfo: try SwiftTagTests.notificationUserInfo(for: payload)
        )

        XCTAssertEqual(openedSession, existingSession)
    }

    @MainActor
    func testNotificationResponseOpensNewSessionWhenNoFingerprintMatches() throws {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()
        SaveNotificationCoordinator.shared.resetForTesting()

        var openedSession: EditorSessionValue?
        coordinator.setOpenEditorWindowAction { sessionValue in
            openedSession = sessionValue
        }

        let reopenRecordID = UUID()
        SaveNotificationCoordinator.shared.saveReopenRecord(
            SaveReopenRecord(
                id: reopenRecordID,
                sourceSessionID: UUID(),
                payload: .writePictures,
                fingerprint: "/tmp/missing.flac",
                trackReferences: [
                    ImportedTrackReference(filePath: "/tmp/missing.flac", securityScopedBookmarkData: nil)
                ]
            )
        )
        let payload = SaveNotificationPayload(
            reopenRecordID: reopenRecordID,
            sourceSessionID: UUID(),
            payload: .writePictures,
            fingerprint: "/tmp/missing.flac",
            trackCount: 1
        )

        SaveNotificationCoordinator.shared.handleNotificationResponse(
            userInfo: try SwiftTagTests.notificationUserInfo(for: payload)
        )

        XCTAssertEqual(openedSession?.reopenRecordID, reopenRecordID)
        XCTAssertNotNil(openedSession?.sessionID)
    }

    @MainActor
    func testNotificationResponseDoesNotOpenEmptyWindowWhenReopenRecordIsMissing() throws {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()
        SaveNotificationCoordinator.shared.resetForTesting()

        var openedSession: EditorSessionValue?
        var reportedError: String?
        coordinator.setOpenEditorWindowAction { sessionValue in
            openedSession = sessionValue
        }
        SaveNotificationCoordinator.shared.setRoutingErrorHandlerForTesting { message in
            reportedError = message
        }

        let payload = SaveNotificationPayload(
            reopenRecordID: UUID(),
            sourceSessionID: UUID(),
            payload: .writePictures,
            fingerprint: "/tmp/missing.flac",
            trackCount: 1
        )

        SaveNotificationCoordinator.shared.handleNotificationResponse(
            userInfo: try SwiftTagTests.notificationUserInfo(for: payload)
        )

        XCTAssertNil(openedSession)
        XCTAssertEqual(reportedError, "The saved track details are no longer available.")
    }

    @MainActor
    func testNotificationResponseReportsDecodeFailure() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()
        SaveNotificationCoordinator.shared.resetForTesting()

        var reportedError: String?
        SaveNotificationCoordinator.shared.setRoutingErrorHandlerForTesting { message in
            reportedError = message
        }

        SaveNotificationCoordinator.shared.handleNotificationResponse(
            userInfo: ["invalid": Data([0x00])]
        )

        XCTAssertEqual(reportedError, "The save notification did not contain valid reopening data.")
    }
}
