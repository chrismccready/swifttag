import Foundation
import Testing
@testable import SwiftTag

struct TrackDurationTests {
    private static let fixtureSampleRate: UInt32 = 44_100
    private static let fixtureTotalSamples: UInt64 = 6_754
    private static let fixtureBitsPerSample: UInt32 = 16
    private static let fixtureChannels: UInt32 = 1

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
    func trackSampleRateFormatterFormatsKilohertzValuesWithTrimmedPrecision() {
        #expect(TrackSampleRateFormatter.string(from: nil) == nil)
        #expect(TrackSampleRateFormatter.string(from: 48_000) == "48 kHz")
        #expect(TrackSampleRateFormatter.string(from: 44_100) == "44.1 kHz")
        #expect(TrackSampleRateFormatter.string(from: 22_050) == "22.05 kHz")
        #expect(TrackSampleRateFormatter.string(from: 1_048_575) == "1048.575 kHz")
    }

    @Test
    func trackSampleRateFormatterParsesDocumentDisplayValuesBackToHertz() {
        #expect(TrackSampleRateFormatter.hertz(from: nil) == nil)
        #expect(TrackSampleRateFormatter.hertz(from: "") == nil)
        #expect(TrackSampleRateFormatter.hertz(from: "48 kHz") == 48_000)
        #expect(TrackSampleRateFormatter.hertz(from: "44.1 kHz") == 44_100)
        #expect(TrackSampleRateFormatter.hertz(from: "22.05 kHz") == 22_050)
        #expect(TrackSampleRateFormatter.hertz(from: "1048.575 kHz") == 1_048_575)
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
        let expectedDuration = Double(Self.fixtureTotalSamples) / Double(Self.fixtureSampleRate)

        #expect(metadata.sampleRate == Self.fixtureSampleRate)
        #expect(metadata.totalSamples == Self.fixtureTotalSamples)
        #expect(metadata.bitsPerSample == Self.fixtureBitsPerSample)
        #expect(metadata.channels == Self.fixtureChannels)
        #expect(abs(duration - expectedDuration) < 0.000_000_000_1)
    }

    @Test
    func flacMetadataServiceDerivesSameDurationForPaddedFixture() throws {
        let metadata = try FlacMetadataService.readTags(for: Self.paddedFixtureURL)
        let duration = try #require(metadata.duration)
        let expectedDuration = Double(Self.fixtureTotalSamples) / Double(Self.fixtureSampleRate)

        #expect(metadata.sampleRate == Self.fixtureSampleRate)
        #expect(metadata.totalSamples == Self.fixtureTotalSamples)
        #expect(metadata.bitsPerSample == Self.fixtureBitsPerSample)
        #expect(metadata.channels == Self.fixtureChannels)
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
        viewModel.trackItems[0].sampleRate = 96_000
        viewModel.trackItems[0].totalSamples = 1
        viewModel.trackItems[0].bitsPerSample = 24
        viewModel.trackItems[0].channels = 2
        viewModel.trackItems[0].duration = 125.9

        try viewModel.reloadTracksWithDifferences(
            in: [trackID],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(viewModel.trackItems.first?.sampleRate == Self.fixtureSampleRate)
        #expect(viewModel.trackItems.first?.totalSamples == Self.fixtureTotalSamples)
        #expect(viewModel.trackItems.first?.bitsPerSample == Self.fixtureBitsPerSample)
        #expect(viewModel.trackItems.first?.channels == Self.fixtureChannels)
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
        viewModel.trackItems[0].sampleRate = nil
        viewModel.trackItems[0].totalSamples = nil
        viewModel.trackItems[0].bitsPerSample = nil
        viewModel.trackItems[0].channels = nil
        viewModel.trackItems[0].duration = nil

        viewModel.refreshLoadedTrackFileStates(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(viewModel.trackItems.first?.sampleRate == Self.fixtureSampleRate)
        #expect(viewModel.trackItems.first?.totalSamples == Self.fixtureTotalSamples)
        #expect(viewModel.trackItems.first?.bitsPerSample == Self.fixtureBitsPerSample)
        #expect(viewModel.trackItems.first?.channels == Self.fixtureChannels)
        let refreshedDuration = try #require(viewModel.trackItems.first?.duration)
        #expect(abs(refreshedDuration - expectedDuration) < 0.000_000_000_1)
    }
}
