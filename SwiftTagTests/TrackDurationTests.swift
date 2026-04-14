import Foundation
import Testing
@testable import SwiftTag

struct TrackDurationTests {
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

    private static var defaultTagWriteOptions: TagWriteOptions {
        TagWriteOptions(
            zeroPadTrackNumber: SaveSettingsDefaults.zeroPadTrackNumber,
            trackCountKeyStrategy: SaveSettingsDefaults.trackCountKeyStrategy,
            zeroPadDiscNumber: SaveSettingsDefaults.zeroPadDiscNumber,
            discCountKeyStrategy: SaveSettingsDefaults.discCountKeyStrategy
        )
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
    func trackDurationFormatterReturnsEmptyStringForNilAndInvalidValues() {
        #expect(TrackDurationFormatter.string(from: nil) == "")
        #expect(TrackDurationFormatter.string(from: Double.nan) == "")
        #expect(TrackDurationFormatter.string(from: -1) == "")
    }

    @Test
    func trackDurationFormatterTruncatesFractionalSecondsBelowOneHour() {
        #expect(TrackDurationFormatter.string(from: 125.9) == "2:05")
    }

    @Test
    func trackDurationFormatterUsesContinuousHoursWithoutDayRollover() {
        let duration = 27.0 * 3_600.0 + 5.0 * 60.0 + 9.9
        #expect(TrackDurationFormatter.string(from: duration) == "27:05:09")
    }

    @Test
    func flacMetadataServiceDerivesDurationFromFixtureStreamInfo() throws {
        let metadata = try FlacMetadataService.readTags(for: Self.fixtureURL)
        let duration = try #require(metadata.duration)
        let expectedDuration = Double(6_754) / 44_100.0

        #expect(abs(duration - expectedDuration) < 0.000_000_000_1)
    }

    @Test
    func flacMetadataServiceDerivesSameDurationForPaddedFixture() throws {
        let metadata = try FlacMetadataService.readTags(for: Self.paddedFixtureURL)
        let duration = try #require(metadata.duration)
        let expectedDuration = Double(6_754) / 44_100.0

        #expect(abs(duration - expectedDuration) < 0.000_000_000_1)
    }

    @MainActor
    @Test
    func tagEditorViewModelReloadRestoresDerivedDuration() async throws {
        let fixtureCopyURL = try Self.tempFixtureCopyURL(name: "reload-duration.flac")
        let viewModel = TagEditorViewModel()
        try await viewModel.importFlacFiles([fixtureCopyURL])

        let trackID = try #require(viewModel.trackItems.first?.id)
        let expectedDuration = try #require(viewModel.trackItems.first?.duration)

        viewModel.trackItems[0].tags[TagKey.title] = "Edited Title"
        viewModel.trackItems[0].duration = 125.9

        try viewModel.reloadTracksWithDifferences(
            in: [trackID],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let reloadedDuration = try #require(viewModel.trackItems.first?.duration)
        #expect(abs(reloadedDuration - expectedDuration) < 0.000_000_000_1)
    }

    @MainActor
    @Test
    func tagEditorViewModelLiveRefreshRestoresDerivedDuration() async throws {
        let fixtureCopyURL = try Self.tempFixtureCopyURL(name: "refresh-duration.flac")
        let viewModel = TagEditorViewModel()
        try await viewModel.importFlacFiles([fixtureCopyURL])

        let expectedDuration = try #require(viewModel.trackItems.first?.duration)
        viewModel.trackItems[0].duration = nil

        viewModel.refreshLoadedTrackFileStates(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let refreshedDuration = try #require(viewModel.trackItems.first?.duration)
        #expect(abs(refreshedDuration - expectedDuration) < 0.000_000_000_1)
    }
}
