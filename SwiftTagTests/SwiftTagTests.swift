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

    private static let fixtureFingerprint = "ad98344c162662ceeb88f25aa552af60"

    private static func isolatedUserDefaults(prefix: String) throws -> (UserDefaults, String) {
        let suiteName = "\(prefix).\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        return (userDefaults, suiteName)
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
            throw NSError(domain: "SwiftTagTests", code: 2)
        }

        return jpegData
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

    private static func tempPNGFileURL(name: String, color: NSColor) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent(name).appendingPathExtension("png")
        try pngData(color: color).write(to: fileURL)
        return fileURL
    }

    private static func tempPackageURL(name: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent(name).appendingPathExtension(SwiftTagDocumentType.fileExtension)
    }

    private static func importedTrack(fileURL: URL, tags: [String: String]) -> Track {
        Track(
            tags: tags,
            sourceFileURL: fileURL
        )
    }

    private static func bookmarkBackedTrack(
        fileURL: URL,
        tags: [String: String],
        fingerprint: String? = nil
    ) throws -> Track {
        let bookmarkData = try fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return Track(
            tags: tags,
            sourceFileURL: fileURL,
            securityScopedBookmarkData: bookmarkData,
            fingerprint: fingerprint
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

    private static func followOnSaveActionsMatch(
        _ lhs: SwiftTagDocumentFollowOnSaveAction,
        _ rhs: SwiftTagDocumentFollowOnSaveAction
    ) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none),
             (.saveReferencedDocument, .saveReferencedDocument),
             (.promptForNewDocument, .promptForNewDocument):
            return true
        default:
            return false
        }
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
    func dateTagFormatterPreservesEditableDateText() {
        let defaultDate = DateTagFormatter.parse("2020-05-06")!

        #expect(DateTagFormatter.tagText("2026-03-01", defaultDate: defaultDate) == "2026-03-01")
        #expect(DateTagFormatter.tagText("2026-03", defaultDate: defaultDate) == "2026-03")
        #expect(DateTagFormatter.tagText("2026", defaultDate: defaultDate) == "2026")
        #expect(DateTagFormatter.tagText("2026/03/01", defaultDate: defaultDate) == "2026-03-01")
        #expect(DateTagFormatter.tagText(nil, defaultDate: defaultDate) == "2020-05-06")
        #expect(DateTagFormatter.tagText("", defaultDate: defaultDate) == "2020-05-06")
        #expect(DateTagFormatter.tagText("2026-13", defaultDate: defaultDate) == "2020-05-06")
    }

    @Test
    func tagNormalizationHandlesExpectedKeys() {
        #expect(TagNormalization.normalizeTagKey("  encoded_by  ") == "ENCODED_BY")
        #expect(TagNormalization.normalizeTagKey("  album artist  ").isEmpty)
        #expect(TagNormalization.normalizeTagKey("  track total  ").isEmpty)
        #expect(TagNormalization.isExplicitTagKey("title"))
        #expect(TagNormalization.isExplicitTagKey("ALBUMARTIST"))
        #expect(TagNormalization.isExplicitTagKey("TRACKTOTAL"))
        #expect(TagNormalization.isExplicitTagKey("DISCTOTAL"))
        #expect(TagNormalization.hasInvalidWhitespace("album artist"))
        #expect(!TagNormalization.isExplicitTagKey("album artist"))
        #expect(TagNormalization.isExplicitTagKey("compilation"))
        #expect(!TagNormalization.isExplicitTagKey("ENCODED_BY"))
    }

    @Test
    func saveSettingsDefaultsMatchPlan() {
        #expect(SaveSettingsDefaults.defaultSavePayload == .writeTagsAndPictures)
        #expect(SaveSettingsDefaults.defaultSaveScope == .allTracks)
        #expect(!SaveSettingsDefaults.zeroPadTrackNumber)
        #expect(SaveSettingsDefaults.trackCountKeyStrategy == .both)
        #expect(!SaveSettingsDefaults.zeroPadDiscNumber)
        #expect(SaveSettingsDefaults.discCountKeyStrategy == .both)
        #expect(!SaveSettingsDefaults.autoUpdateTrackTotal)
        #expect(!SaveSettingsDefaults.autoUpdateTrackTotalByDisc)
        #expect(!SaveSettingsDefaults.autoUpdateDiscTotal)
        #expect(!SaveSettingsDefaults.applyCompilationToAllTracks)
        #expect(!SaveSettingsDefaults.saveFrontCoverToAllTracks)
        #expect(!SaveSettingsDefaults.saveAllPicturesToAllTracks)
    }

    @Test
    func trackFileRenameSettingsDefaultsMatchPlan() {
        #expect(TrackFileRenameSettingsDefaults.format == "|TRACKNUMBER| |TITLE|")
        #expect(TrackFileRenameSettingsDefaults.invalidReplacementText == .hyphen)
        #expect(TrackFileRenameSettingsDefaults.spaceReplacement == .none)
        #expect(!TrackFileRenameSettingsDefaults.strict)
    }

    @Test
    func trackFileRenameFormatterNormalizesAliasesAndZeroPadsNumbers() throws {
        let track = Track(
            totalTracks: "12",
            tags: [
                TagKey.trackNumber: "3",
                TagKey.discNumber: "1",
                TagKey.title: "First/Song",
                "TOTALDISCS": "2"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/original.flac")
        )
        let knownTagKeys = TrackFileRenameFormatter.knownTagKeys(from: [track])

        let normalizedFormat = TrackFileRenameFormatter.normalizedFormat(
            "|zp track number| |number| |track total| |disc count| |TITLE|",
            knownTagKeys: knownTagKeys
        )

        #expect(normalizedFormat == "|zpTRACKNUMBER| |TRACKNUMBER| |TRACKTOTAL| |TOTALDISCS| |TITLE|")

        let fileName = try TrackFileRenameFormatter.renderedFileName(
            for: track,
            totalDiscsValue: "2",
            configuration: TrackFileRenameConfiguration(
                format: "|zp track number| |TITLE|",
                invalidReplacementText: .hyphen,
                spaceReplacement: .none,
                strict: false
            ),
            knownTagKeys: knownTagKeys
        )

        #expect(fileName == "03 First-Song.flac")
    }

    @Test
    func trackFileRenameFormatterDefersTextFieldNormalizationUntilClosingDelimiter() {
        let knownTagKeys = TrackFileRenameFormatter.knownTagKeys(from: [])

        #expect(
            TrackFileRenameFormatter.normalizedFormatAfterTextFieldEdit(
                previousFormat: "",
                newFormat: "|",
                knownTagKeys: knownTagKeys
            ) == "|"
        )
        #expect(
            TrackFileRenameFormatter.normalizedFormatAfterTextFieldEdit(
                previousFormat: "|track",
                newFormat: "|trackn",
                knownTagKeys: knownTagKeys
            ) == "|trackn"
        )
        #expect(
            TrackFileRenameFormatter.normalizedFormatAfterTextFieldEdit(
                previousFormat: "|tracknumber",
                newFormat: "|tracknumber|",
                knownTagKeys: knownTagKeys
            ) == "|TRACKNUMBER|"
        )
        #expect(
            TrackFileRenameFormatter.normalizedFormatAfterTextFieldEdit(
                previousFormat: "",
                newFormat: "|title|",
                knownTagKeys: knownTagKeys
            ) == "|TITLE|"
        )
        #expect(
            TrackFileRenameFormatter.normalizedFormatAfterTextFieldEdit(
                previousFormat: "|tit|",
                newFormat: "|titl|",
                knownTagKeys: knownTagKeys
            ) == "|titl|"
        )
    }

    @Test
    func trackFileRenameFormatterReportsSelectionAfterClosedPlaceholderEdit() {
        let knownTagKeys = TrackFileRenameFormatter.knownTagKeys(from: [])

        let expandedAliasResult = TrackFileRenameFormatter.normalizedFormatTextFieldEdit(
            previousFormat: "Album |number suffix",
            newFormat: "Album |number| suffix",
            knownTagKeys: knownTagKeys
        )

        #expect(expandedAliasResult.format == "Album |TRACKNUMBER| suffix")
        #expect(expandedAliasResult.insertionPointOffset == "Album |TRACKNUMBER|".count)

        let appendedPlaceholderResult = TrackFileRenameFormatter.normalizedFormatTextFieldEdit(
            previousFormat: "Album |tracknumber",
            newFormat: "Album |tracknumber|",
            knownTagKeys: knownTagKeys
        )

        #expect(appendedPlaceholderResult.format == "Album |TRACKNUMBER|")
        #expect(appendedPlaceholderResult.insertionPointOffset == appendedPlaceholderResult.format.count)

        let partialEditResult = TrackFileRenameFormatter.normalizedFormatTextFieldEdit(
            previousFormat: "Album |tit",
            newFormat: "Album |titl",
            knownTagKeys: knownTagKeys
        )

        #expect(partialEditResult.format == "Album |titl")
        #expect(partialEditResult.insertionPointOffset == nil)
    }

    @Test
    func trackFileRenameFormatterAppliesStrictAndNonStrictFilenameSanitizing() {
        #expect(
            TrackFileRenameFormatter.sanitizedFilenameStem(
                "A/B:C?.",
                invalidReplacement: "-",
                spaceReplacement: .none,
                strict: false
            ) == "A-B-C?."
        )
        #expect(
            TrackFileRenameFormatter.sanitizedFilenameStem(
                "A/B:C?.",
                invalidReplacement: "-",
                spaceReplacement: .none,
                strict: true
            ) == "A-B-C-."
        )
        #expect(
            TrackFileRenameFormatter.sanitizedFilenameStem(
                "A/B C",
                invalidReplacement: "_",
                spaceReplacement: .period,
                strict: false
            ) == "A_B.C"
        )
        #expect(
            TrackFileRenameFormatter.sanitizedFilenameStem(
                "A/B C.",
                invalidReplacement: " ",
                spaceReplacement: .underscore,
                strict: true
            ) == "A_B_C."
        )
    }

    @Test
    @MainActor
    func tagEditorViewModelRenamesSelectedTrackFileAndUpdatesExportReference() throws {
        let originalURL = try Self.tempFixtureCopyURL(name: "rename-selected-original.flac")
        let otherURL = try Self.tempFixtureCopyURL(name: "rename-selected-other.flac")
        let selectedTrack = Track(
            tags: [
                TagKey.trackNumber: "1",
                TagKey.title: "Renamed Song",
                TagKey.filename: originalURL.lastPathComponent
            ],
            sourceFileURL: originalURL
        )
        let otherTrack = Track(
            tags: [
                TagKey.trackNumber: "2",
                TagKey.title: "Other Song",
                TagKey.filename: otherURL.lastPathComponent
            ],
            sourceFileURL: otherURL
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [selectedTrack, otherTrack]
        viewModel.selectedTrackIDs = [selectedTrack.id]

        let renamedReferences = try viewModel.renameTrackFiles(
            scope: .selectedTracks,
            configuration: TrackFileRenameConfiguration(
                format: "|zpTRACKNUMBER| |TITLE|",
                invalidReplacementText: .hyphen,
                spaceReplacement: .none,
                strict: true
            )
        )

        let renamedURL = originalURL
            .deletingLastPathComponent()
            .appendingPathComponent("01 Renamed Song.flac")
        let renamedTrack = try #require(viewModel.trackItems.first { $0.id == selectedTrack.id })
        let untouchedTrack = try #require(viewModel.trackItems.first { $0.id == otherTrack.id })
        let exportTrack = try #require(viewModel.swiftTagDocumentExportTracks().first { $0.sourceFileURL == renamedURL })

        #expect(renamedReferences.map(\.filePath) == [renamedURL.path])
        #expect(FileManager.default.fileExists(atPath: renamedURL.path))
        #expect(!FileManager.default.fileExists(atPath: originalURL.path))
        #expect(FileManager.default.fileExists(atPath: otherURL.path))
        #expect(renamedTrack.sourceFileURL?.path == renamedURL.path)
        #expect(renamedTrack.tags[TagKey.filename] == renamedURL.lastPathComponent)
        #expect(renamedTrack.securityScopedBookmarkData != nil)
        #expect(untouchedTrack.sourceFileURL?.path == otherURL.path)
        #expect(exportTrack.securityScopedBookmarkData != nil)
    }

    @Test
    @MainActor
    func tagEditorViewModelRenameConflictAbortsWholeBatch() throws {
        let sourceURL = try Self.tempFixtureCopyURL(name: "rename-conflict-source.flac")
        let existingDestinationURL = sourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("02 Taken.flac")
        try FileManager.default.copyItem(at: Self.fixtureURL, to: existingDestinationURL)

        let sourceTrack = Track(
            tags: [
                TagKey.trackNumber: "2",
                TagKey.title: "Taken",
                TagKey.filename: sourceURL.lastPathComponent
            ],
            sourceFileURL: sourceURL
        )
        let existingTrack = Track(
            tags: [
                TagKey.trackNumber: "3",
                TagKey.title: "Existing",
                TagKey.filename: existingDestinationURL.lastPathComponent
            ],
            sourceFileURL: existingDestinationURL
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [sourceTrack, existingTrack]

        #expect(throws: TrackFileRenameError.self) {
            try viewModel.renameTrackFiles(
                scope: .allTracks,
                configuration: TrackFileRenameConfiguration(
                    format: "|zpTRACKNUMBER| |TITLE|",
                    invalidReplacementText: .hyphen,
                    spaceReplacement: .none,
                    strict: true
                )
            )
        }

        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(FileManager.default.fileExists(atPath: existingDestinationURL.path))
        #expect(viewModel.trackItems[0].sourceFileURL?.path == sourceURL.path)
        #expect(viewModel.trackItems[1].sourceFileURL?.path == existingDestinationURL.path)
    }

    @Test
    func tagEditorViewModelRenameUsesCoordinatedSandboxMove() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("TagEditor")
            .appendingPathComponent("TagEditorViewModel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        let directMoveRange = try #require(source.range(of: "try coordinatedMoveTrackFile("))
        let sandboxFallbackRange = try #require(source.range(of: "moveTrackFileUsingSandboxFolderAccess("))
        let coordinatorRange = try #require(source.range(of: "NSFileCoordinator(filePresenter: nil)"))
        let coordinateRange = try #require(source.range(of: "coordinator.coordinate("))
        let willMoveRange = try #require(
            source.range(of: "coordinator.item(at: coordinatedSourceURL, willMoveTo: coordinatedDestinationURL)")
        )
        let moveItemRange = try #require(
            source.range(of: "try fileManager.moveItem(at: coordinatedSourceURL, to: coordinatedDestinationURL)")
        )
        let didMoveRange = try #require(
            source.range(of: "coordinator.item(at: coordinatedSourceURL, didMoveTo: coordinatedDestinationURL)")
        )

        #expect(directMoveRange.lowerBound < sandboxFallbackRange.lowerBound)
        #expect(coordinatorRange.lowerBound < willMoveRange.lowerBound)
        #expect(coordinateRange.lowerBound < willMoveRange.lowerBound)
        #expect(willMoveRange.lowerBound < moveItemRange.lowerBound)
        #expect(moveItemRange.lowerBound < didMoveRange.lowerBound)
        #expect(source.contains("SandboxPathBookmarkAccess.withAccess"))
    }

    @Test
    func unsavedChangesChoiceResolverBypassesPromptWithoutUnsavedEdits() {
        let configuration = UnsavedChangesChoiceResolver.resolve(
            trigger: .closeWindow,
            context: UnsavedChangesSessionContext(
                editCounts: UnsavedChangesEditCounts(tagEdits: 0, pictureEdits: 0),
                hasReferencedSwiftTagDocument: false,
                referencedSwiftTagDocumentURL: nil
            )
        )

        #expect(configuration == nil)
    }

    @Test
    func unsavedChangesChoiceResolverUsesReferencedDocumentActionsWhenAvailable() {
        let configuration = UnsavedChangesChoiceResolver.resolve(
            trigger: .closeWindow,
            context: UnsavedChangesSessionContext(
                editCounts: UnsavedChangesEditCounts(tagEdits: 2, pictureEdits: 1),
                hasReferencedSwiftTagDocument: true,
                referencedSwiftTagDocumentURL: URL(fileURLWithPath: "/tmp/Session Save.swifttag")
            )
        )

        #expect(configuration?.discardTitle == "Close Window")
        #expect(configuration?.saveChoices.map(\.title) == [
            "Save FLAC files",
            "Save Session Save.swifttag",
            "Save FLAC files & Session Save.swifttag"
        ])
    }

    @Test
    func unsavedChangesChoiceResolverUsesNewDocumentActionsWithoutReference() {
        let configuration = UnsavedChangesChoiceResolver.resolve(
            trigger: .quitApplication,
            context: UnsavedChangesSessionContext(
                editCounts: UnsavedChangesEditCounts(tagEdits: 3, pictureEdits: 0),
                hasReferencedSwiftTagDocument: false,
                referencedSwiftTagDocumentURL: nil
            )
        )

        #expect(configuration?.discardTitle == "Quit")
        #expect(configuration?.saveChoices.map(\.title) == [
            "Save FLAC files",
            "Save New SwiftTag Document...",
            "Save FLAC files & New SwiftTag Document..."
        ])
    }

    @Test
    func unsavedChangesChoiceResolverFallsBackToGenericReferencedDocumentLabel() {
        let configuration = UnsavedChangesChoiceResolver.resolve(
            trigger: .closeWindow,
            context: UnsavedChangesSessionContext(
                editCounts: UnsavedChangesEditCounts(tagEdits: 1, pictureEdits: 1),
                hasReferencedSwiftTagDocument: true,
                referencedSwiftTagDocumentURL: nil
            )
        )

        #expect(configuration?.saveChoices.map(\.title) == [
            "Save FLAC files",
            "Save SwiftTag Document",
            "Save FLAC files & SwiftTag Document"
        ])
    }

    @Test
    func unsavedChangesChoiceResolverTruncatesReferencedDocumentLabelInMiddle() {
        let configuration = UnsavedChangesChoiceResolver.resolve(
            trigger: .closeWindow,
            context: UnsavedChangesSessionContext(
                editCounts: UnsavedChangesEditCounts(tagEdits: 1, pictureEdits: 0),
                hasReferencedSwiftTagDocument: true,
                referencedSwiftTagDocumentURL: URL(
                    fileURLWithPath: "/tmp/Very Long Album Name Deluxe Edition.swifttag"
                )
            )
        )

        #expect(configuration?.saveChoices.map(\.title) == [
            "Save FLAC files",
            "Save Very Long Al…on.swifttag",
            "Save FLAC files & Very Long Al…on.swifttag"
        ])
    }

    @Test
    @MainActor
    func referencedSwiftTagDocumentTrackListIgnoresTagOnlyDifferencesForMatchingBookmarkURLs() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "track-list-tag-only.flac")
        let bookmarkData = try fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let baseline = ReferencedSwiftTagDocumentTrackList.make(from: [
            Track(
                tags: [TagKey.title: "Original Title", TagKey.filename: fileURL.lastPathComponent],
                sourceFileURL: fileURL,
                securityScopedBookmarkData: bookmarkData,
                fingerprint: Self.fixtureFingerprint
            )
        ])
        let current = ReferencedSwiftTagDocumentTrackList.make(from: [
            Track(
                tags: [TagKey.title: "Changed Title", TagKey.filename: fileURL.lastPathComponent],
                sourceFileURL: fileURL,
                securityScopedBookmarkData: bookmarkData,
                fingerprint: Self.fixtureFingerprint
            )
        ])

        #expect(!ReferencedSwiftTagDocumentTrackList.differs(current: current, baseline: baseline))
    }

    @Test
    @MainActor
    func referencedSwiftTagDocumentTrackListTreatsDifferentBookmarkURLsWithSameFingerprintAsDifferentTracks() throws {
        let firstURL = try Self.tempFixtureCopyURL(name: "track-list-same-fingerprint-a.flac")
        let secondURL = try Self.tempFixtureCopyURL(name: "track-list-same-fingerprint-b.flac")
        let baseline = ReferencedSwiftTagDocumentTrackList.make(from: [
            try Self.bookmarkBackedTrack(
                fileURL: firstURL,
                tags: [TagKey.title: "First", TagKey.filename: firstURL.lastPathComponent],
                fingerprint: Self.fixtureFingerprint
            )
        ])
        let current = ReferencedSwiftTagDocumentTrackList.make(from: [
            try Self.bookmarkBackedTrack(
                fileURL: secondURL,
                tags: [TagKey.title: "Second", TagKey.filename: secondURL.lastPathComponent],
                fingerprint: Self.fixtureFingerprint
            )
        ])

        #expect(ReferencedSwiftTagDocumentTrackList.differs(current: current, baseline: baseline))
    }

    @Test
    @MainActor
    func referencedSwiftTagDocumentTrackListTreatsOrderOnlyChangesAsDirty() throws {
        let firstURL = try Self.tempFixtureCopyURL(name: "track-list-order-first.flac")
        let secondURL = try Self.tempFixtureCopyURL(name: "track-list-order-second.flac")
        let firstTrack = try Self.bookmarkBackedTrack(
            fileURL: firstURL,
            tags: [TagKey.title: "First", TagKey.filename: firstURL.lastPathComponent],
            fingerprint: Self.fixtureFingerprint
        )
        let secondTrack = try Self.bookmarkBackedTrack(
            fileURL: secondURL,
            tags: [TagKey.title: "Second", TagKey.filename: secondURL.lastPathComponent],
            fingerprint: Self.fixtureFingerprint
        )
        let baseline = ReferencedSwiftTagDocumentTrackList.make(from: [firstTrack, secondTrack])
        let current = ReferencedSwiftTagDocumentTrackList.make(from: [secondTrack, firstTrack])

        #expect(ReferencedSwiftTagDocumentTrackList.differs(current: current, baseline: baseline))
    }

    @Test
    @MainActor
    func referencedSwiftTagDocumentTrackListTreatsSessionOnlyTrackAdditionAsDirty() {
        let sessionTrack = Track(tags: [TagKey.title: "Session Track"])
        let baseline = ReferencedSwiftTagDocumentTrackList.make(from: [sessionTrack])
        let current = ReferencedSwiftTagDocumentTrackList.make(from: [
            sessionTrack,
            Track(tags: [TagKey.title: "Added Session Track"])
        ])

        #expect(ReferencedSwiftTagDocumentTrackList.differs(current: current, baseline: baseline))
    }

    @Test
    @MainActor
    func tagEditorViewModelCanSaveSwiftTagDocumentWithoutTracks() {
        let viewModel = TagEditorViewModel()

        #expect(viewModel.canSaveSwiftTagDocument())

        viewModel.rememberSwiftTagDocumentSave(
            SwiftTagDocumentSaveResult(
                destinationURL: URL(fileURLWithPath: "/tmp/Empty Session.swifttag"),
                documentID: UUID(),
                fingerprint: "document-fingerprint"
            )
        )

        #expect(viewModel.canSaveSwiftTagDocument())
    }

    @Test
    func unsavedChangesChoiceResolverUsesReferencedDocumentActionForTrackListDifferenceOnlyWhenClosing() {
        let configuration = UnsavedChangesChoiceResolver.resolve(
            trigger: .closeWindow,
            context: UnsavedChangesSessionContext(
                editCounts: UnsavedChangesEditCounts(tagEdits: 0, pictureEdits: 0),
                hasReferencedSwiftTagDocument: true,
                referencedSwiftTagDocumentURL: URL(fileURLWithPath: "/tmp/Session Save.swifttag"),
                hasReferencedSwiftTagDocumentTrackListDifference: true
            )
        )

        #expect(configuration?.discardTitle == "Close Window")
        #expect(configuration?.saveChoices.map(\.title) == ["Save Session Save.swifttag"])
        #expect(
            configuration?.informativeText
                == "The referenced SwiftTag document track list no longer matches the current session. Choose how to continue."
        )
    }

    @Test
    func unsavedChangesChoiceResolverUsesReferencedDocumentActionForTrackListDifferenceOnlyWhenQuitting() {
        let configuration = UnsavedChangesChoiceResolver.resolve(
            trigger: .quitApplication,
            context: UnsavedChangesSessionContext(
                editCounts: UnsavedChangesEditCounts(tagEdits: 0, pictureEdits: 0),
                hasReferencedSwiftTagDocument: true,
                referencedSwiftTagDocumentURL: URL(fileURLWithPath: "/tmp/Session Save.swifttag"),
                hasReferencedSwiftTagDocumentTrackListDifference: true
            )
        )

        #expect(configuration?.discardTitle == "Quit")
        #expect(configuration?.saveChoices.map(\.title) == ["Save Session Save.swifttag"])
    }

    @Test
    func unsavedChangesChoiceResolverKeepsExistingFlacPromptWhenTrackListDifferenceAlsoExists() {
        let configuration = UnsavedChangesChoiceResolver.resolve(
            trigger: .closeWindow,
            context: UnsavedChangesSessionContext(
                editCounts: UnsavedChangesEditCounts(tagEdits: 2, pictureEdits: 1),
                hasReferencedSwiftTagDocument: true,
                referencedSwiftTagDocumentURL: URL(fileURLWithPath: "/tmp/Session Save.swifttag"),
                hasReferencedSwiftTagDocumentTrackListDifference: true
            )
        )

        #expect(configuration?.saveChoices.map(\.title) == [
            "Save FLAC files",
            "Save Session Save.swifttag",
            "Save FLAC files & Session Save.swifttag"
        ])
    }

    @Test
    @MainActor
    func trackTableSortModeOrdersTracksByNumberAndFilename() {
        let secondTrack = Track(
            tags: [
                TagKey.trackNumber: "2",
                TagKey.filename: "02-Bravo.flac"
            ]
        )
        let firstTrack = Track(
            tags: [
                TagKey.trackNumber: "1",
                TagKey.filename: "03-Charlie.flac"
            ]
        )
        let missingNumberTrack = Track(
            tags: [
                TagKey.trackNumber: "",
                TagKey.filename: "01-Alpha.flac"
            ]
        )

        let tracks = [secondTrack, firstTrack, missingNumberTrack]

        #expect(tracks.sortedForTrackTableDisplay(sortMode: .number).map(\.id) == [
            firstTrack.id,
            secondTrack.id,
            missingNumberTrack.id
        ])
        #expect(tracks.sortedForTrackTableDisplay(sortMode: .filename).map(\.id) == [
            missingNumberTrack.id,
            secondTrack.id,
            firstTrack.id
        ])
    }

    @Test
    @MainActor
    func tagEditorViewModelSetTrackNumbersUsesCurrentVisibleOrderAndLockedPositions() {
        let alpha = Track(
            tags: [
                TagKey.trackNumber: "7",
                TagKey.filename: "01-Alpha.flac"
            ],
            externalDifferences: TrackExternalDifferences(
                isDeleted: false,
                fileValuesByTag: [TagKey.trackNumber: "99"],
                hasPictureDifference: false
            )
        )
        let lockedBeta = Track(
            tags: [
                TagKey.trackNumber: "9",
                TagKey.filename: "02-Beta.flac"
            ],
            isLocked: true
        )
        let gamma = Track(
            tags: [
                TagKey.trackNumber: "3",
                TagKey.filename: "03-Gamma.flac"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [gamma, lockedBeta, alpha]
        viewModel.trackTableSortMode = .filename

        viewModel.setTrackNumbersToCurrentTableOrder()

        #expect(viewModel.trackItems.first(where: { $0.id == alpha.id })?.tags[TagKey.trackNumber] == "1")
        #expect(viewModel.trackItems.first(where: { $0.id == lockedBeta.id })?.tags[TagKey.trackNumber] == "9")
        #expect(viewModel.trackItems.first(where: { $0.id == gamma.id })?.tags[TagKey.trackNumber] == "3")
        #expect(viewModel.trackItems.first(where: { $0.id == alpha.id })?.externalDifferences == nil)
    }

    @Test
    @MainActor
    func tagEditorViewModelSetTrackNumbersByDiscCountsVisibleValidDiscRows() {
        let lockedDiscOne = Track(
            tags: [
                TagKey.trackNumber: "8",
                TagKey.discNumber: "1",
                TagKey.filename: "01-Locked.flac"
            ],
            isLocked: true
        )
        let editableDiscOneA = Track(
            tags: [
                TagKey.trackNumber: "8",
                TagKey.discNumber: "1",
                TagKey.filename: "02-Disc-One.flac"
            ]
        )
        let invalidDisc = Track(
            tags: [
                TagKey.trackNumber: "8",
                TagKey.discNumber: "Side A",
                TagKey.filename: "03-Invalid.flac"
            ]
        )
        let editableDiscTwo = Track(
            tags: [
                TagKey.trackNumber: "8",
                TagKey.discNumber: "2",
                TagKey.filename: "04-Disc-Two.flac"
            ]
        )
        let editableDiscOneB = Track(
            tags: [
                TagKey.trackNumber: "8",
                TagKey.discNumber: "1",
                TagKey.filename: "05-Disc-One.flac"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            editableDiscOneB,
            invalidDisc,
            editableDiscTwo,
            lockedDiscOne,
            editableDiscOneA
        ]
        viewModel.trackTableSortMode = .filename

        viewModel.setTrackNumbersByDiscToCurrentTableOrder()

        #expect(viewModel.trackItems.first(where: { $0.id == lockedDiscOne.id })?.tags[TagKey.trackNumber] == "8")
        #expect(viewModel.trackItems.first(where: { $0.id == editableDiscOneA.id })?.tags[TagKey.trackNumber] == "2")
        #expect(viewModel.trackItems.first(where: { $0.id == invalidDisc.id })?.tags[TagKey.trackNumber] == "8")
        #expect(viewModel.trackItems.first(where: { $0.id == editableDiscTwo.id })?.tags[TagKey.trackNumber] == "1")
        #expect(viewModel.trackItems.first(where: { $0.id == editableDiscOneB.id })?.tags[TagKey.trackNumber] == "3")
    }

    @Test
    @MainActor
    func tagEditorViewModelTrackNumberingRoundTripsThroughSortModes() {
        let firstByFilename = Track(
            tags: [
                TagKey.trackNumber: "3",
                TagKey.filename: "01-First.flac"
            ]
        )
        let secondByFilename = Track(
            tags: [
                TagKey.trackNumber: "1",
                TagKey.filename: "02-Second.flac"
            ]
        )
        let thirdByFilename = Track(
            tags: [
                TagKey.trackNumber: "2",
                TagKey.filename: "03-Third.flac"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstByFilename, secondByFilename, thirdByFilename]

        #expect(viewModel.sortedTrackItemsForTable().map(\.id) == [
            secondByFilename.id,
            thirdByFilename.id,
            firstByFilename.id
        ])

        viewModel.sortTracks(by: .filename)
        viewModel.setTrackNumbersToCurrentTableOrder()
        viewModel.sortTracks(by: .number)

        #expect(viewModel.sortedTrackItemsForTable().map(\.id) == [
            firstByFilename.id,
            secondByFilename.id,
            thirdByFilename.id
        ])
    }

    @Test
    @MainActor
    func tagEditorViewModelSetTrackTotalToCurrentCountExcludesDeletedAndLockedTracks() {
        let editableTrack = Track(
            totalTracks: "1",
            tags: [
                TagKey.title: "Editable",
                TagKey.filename: "editable.flac"
            ],
            isLocked: false
        )
        let lockedTrack = Track(
            totalTracks: "1",
            tags: [
                TagKey.title: "Locked",
                TagKey.filename: "locked.flac"
            ],
            isLocked: true
        )
        let deletedTrack = Track(
            totalTracks: "1",
            tags: [
                TagKey.title: "Deleted",
                TagKey.filename: "deleted.flac"
            ],
            externalDifferences: TrackExternalDifferences(
                isDeleted: true,
                fileValuesByTag: [:],
                hasPictureDifference: false
            ),
            isLocked: false
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [editableTrack, lockedTrack, deletedTrack]

        viewModel.setTrackTotalToCurrentCount()

        #expect(viewModel.nonDeletedTrackCount == 2)
        let firstPassEditable = viewModel.trackItems.first(where: { $0.id == editableTrack.id })
        let firstPassLocked = viewModel.trackItems.first(where: { $0.id == lockedTrack.id })
        let firstPassDeleted = viewModel.trackItems.first(where: { $0.id == deletedTrack.id })
        #expect(firstPassEditable?.totalTracks == "2")
        #expect(firstPassLocked?.totalTracks == "1")
        #expect(firstPassDeleted?.totalTracks == "1")
    }

    @Test
    @MainActor
    func tagEditorViewModelLeavesMissingTotalTracksBlankWhenTracksLoad() {
        let firstTrack = Track(
            tags: [
                TagKey.title: "First",
                TagKey.filename: "first.flac"
            ]
        )
        let secondTrack = Track(
            tags: [
                TagKey.title: "Second",
                TagKey.filename: "second.flac"
            ]
        )
        let taggedTrack = Track(
            tags: [
                TagKey.title: "Tagged",
                TagKey.filename: "tagged.flac",
                "TRACKTOTAL": "07"
            ]
        )
        let viewModel = TagEditorViewModel()

        viewModel.trackItems = [firstTrack, secondTrack, taggedTrack]

        let loadedFirstTrack = viewModel.trackItems.first { $0.id == firstTrack.id }
        let loadedSecondTrack = viewModel.trackItems.first { $0.id == secondTrack.id }
        let loadedTaggedTrack = viewModel.trackItems.first { $0.id == taggedTrack.id }
        #expect(loadedFirstTrack?.totalTracks == "")
        #expect(loadedSecondTrack?.totalTracks == "")
        #expect(loadedFirstTrack?.tags["TOTALTRACKS"] == nil)
        #expect(loadedSecondTrack?.tags["TOTALTRACKS"] == nil)
        #expect(loadedTaggedTrack?.totalTracks == "7")
    }

    @Test
    @MainActor
    func tagEditorViewModelTrackTotalDiscCountsSkipInvalidAndDeletedDiscNumbers() {
        let editableDiscOne = Track(
            totalTracks: "9",
            tags: [TagKey.title: "Disc 1 Editable", TagKey.discNumber: "1"],
            isLocked: false
        )
        let lockedDiscOne = Track(
            totalTracks: "4",
            tags: [TagKey.title: "Disc 1 Locked", TagKey.discNumber: "01"],
            isLocked: true
        )
        let editableDiscThree = Track(
            totalTracks: "9",
            tags: [TagKey.title: "Disc 3 Editable", TagKey.discNumber: "3"],
            isLocked: false
        )
        let invalidDisc = Track(
            totalTracks: "9",
            tags: [TagKey.title: "Invalid Disc", TagKey.discNumber: "Side A"],
            isLocked: false
        )
        let zeroDisc = Track(
            totalTracks: "9",
            tags: [TagKey.title: "Zero Disc", TagKey.discNumber: "0"],
            isLocked: false
        )
        let deletedDiscThree = Track(
            totalTracks: "9",
            tags: [TagKey.title: "Deleted Disc 3", TagKey.discNumber: "3"],
            externalDifferences: TrackExternalDifferences(
                isDeleted: true,
                fileValuesByTag: [:],
                hasPictureDifference: false
            ),
            isLocked: false
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            editableDiscOne,
            lockedDiscOne,
            editableDiscThree,
            invalidDisc,
            zeroDisc,
            deletedDiscThree
        ]

        #expect(viewModel.totalTrackCountsByDisc() == [1: 2, 3: 1])
        #expect(viewModel.orderedTotalTrackCountsByDisc() == [2, 0, 1])
        #expect(viewModel.totalTrackCountsByDiscMenuSuffix() == "(2,0,1)")

        viewModel.setTrackTotalToCurrentDiscCounts()

        #expect(viewModel.trackItems.first(where: { $0.id == editableDiscOne.id })?.totalTracks == "2")
        #expect(viewModel.trackItems.first(where: { $0.id == lockedDiscOne.id })?.totalTracks == "4")
        #expect(viewModel.trackItems.first(where: { $0.id == editableDiscThree.id })?.totalTracks == "1")
        #expect(viewModel.trackItems.first(where: { $0.id == invalidDisc.id })?.totalTracks == "9")
        #expect(viewModel.trackItems.first(where: { $0.id == zeroDisc.id })?.totalTracks == "9")
        #expect(viewModel.trackItems.first(where: { $0.id == deletedDiscThree.id })?.totalTracks == "9")
    }

    @Test
    @MainActor
    func tagEditorViewModelCalculatedDiscTotalUsesMaximumValidNonDeletedDiscNumber() {
        let discOne = Track(tags: [TagKey.title: "Disc 1", TagKey.discNumber: "1"])
        let paddedDiscThree = Track(tags: [TagKey.title: "Disc 3", TagKey.discNumber: "03"])
        let invalidDisc = Track(tags: [TagKey.title: "Invalid", TagKey.discNumber: "Side A"])
        let zeroDisc = Track(tags: [TagKey.title: "Zero", TagKey.discNumber: "0"])
        let deletedDiscFive = Track(
            tags: [TagKey.title: "Deleted", TagKey.discNumber: "5"],
            externalDifferences: TrackExternalDifferences(
                isDeleted: true,
                fileValuesByTag: [:],
                hasPictureDifference: false
            )
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [discOne, paddedDiscThree, invalidDisc, zeroDisc, deletedDiscFive]

        #expect(viewModel.calculatedDiscTotal() == 3)
        #expect(viewModel.discTotalMenuSuffix() == "(3)")
    }

    @Test
    @MainActor
    func tagEditorViewModelSetDiscTotalUpdatesEditableTracksAndPreservesAliasShape() {
        let totalDiscsTrack = Track(
            tags: [
                TagKey.title: "TOTALDISCS",
                TagKey.discNumber: "1",
                "TOTALDISCS": "1"
            ]
        )
        let discTotalTrack = Track(
            tags: [
                TagKey.title: "DISCTOTAL",
                TagKey.discNumber: "3",
                "DISCTOTAL": "1"
            ]
        )
        let bothAliasesTrack = Track(
            tags: [
                TagKey.title: "Both",
                TagKey.discNumber: "2",
                "TOTALDISCS": "1",
                "DISCTOTAL": "1"
            ]
        )
        let missingAliasTrack = Track(
            tags: [
                TagKey.title: "Missing Alias",
                TagKey.discNumber: "2"
            ]
        )
        let lockedTrack = Track(
            tags: [
                TagKey.title: "Locked",
                TagKey.discNumber: "4",
                "TOTALDISCS": "1"
            ],
            isLocked: true
        )
        let deletedTrack = Track(
            tags: [
                TagKey.title: "Deleted",
                TagKey.discNumber: "5",
                "TOTALDISCS": "1"
            ],
            externalDifferences: TrackExternalDifferences(
                isDeleted: true,
                fileValuesByTag: [:],
                hasPictureDifference: false
            )
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            totalDiscsTrack,
            discTotalTrack,
            bothAliasesTrack,
            missingAliasTrack,
            lockedTrack,
            deletedTrack
        ]

        viewModel.setDiscTotalToCurrentDiscCount()

        #expect(viewModel.calculatedDiscTotal() == 4)
        #expect(viewModel.trackItems[0].tags["TOTALDISCS"] == "4")
        #expect(viewModel.trackItems[0].tags["DISCTOTAL"] == nil)
        #expect(viewModel.trackItems[1].tags["TOTALDISCS"] == nil)
        #expect(viewModel.trackItems[1].tags["DISCTOTAL"] == "4")
        #expect(viewModel.trackItems[2].tags["TOTALDISCS"] == "4")
        #expect(viewModel.trackItems[2].tags["DISCTOTAL"] == "4")
        #expect(viewModel.trackItems[3].tags["TOTALDISCS"] == "4")
        #expect(viewModel.trackItems[3].tags["DISCTOTAL"] == nil)
        #expect(viewModel.trackItems[4].tags["TOTALDISCS"] == "1")
        #expect(viewModel.trackItems[5].tags["TOTALDISCS"] == "1")
    }

    @Test
    @MainActor
    func tagEditorViewModelSetDiscTotalNoOpsWithoutValidDiscNumbers() {
        let invalidTrack = Track(
            tags: [
                TagKey.title: "Invalid",
                TagKey.discNumber: "Side A",
                "TOTALDISCS": "1"
            ]
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [invalidTrack]

        viewModel.setDiscTotalToCurrentDiscCount()

        #expect(viewModel.calculatedDiscTotal() == 0)
        #expect(viewModel.discTotalMenuSuffix() == "(0)")
        #expect(viewModel.trackItems[0].tags["TOTALDISCS"] == "1")
    }

    @Test
    @MainActor
    func tagEditorViewModelDiscTotalMismatchUpdatesWhenDiscNumberDropsBelowTotal() {
        let discOne = Track(
            tags: [
                TagKey.title: "Disc One",
                TagKey.discNumber: "1"
            ]
        )
        let editedDisc = Track(
            tags: [
                TagKey.title: "Edited Disc",
                TagKey.discNumber: "3"
            ]
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [discOne, editedDisc]

        viewModel.setDiscTotalToCurrentDiscCount()
        #expect(viewModel.trackItems.allSatisfy { $0.tags["TOTALDISCS"] == "3" })
        #expect(!viewModel.hasTotalDiscsMismatch)

        viewModel.trackItems[1].tags[TagKey.discNumber] = "2"

        #expect(viewModel.calculatedDiscTotal() == 2)
        #expect(viewModel.hasTotalDiscsMismatch)
        #expect(viewModel.totalDiscsHoverMessage.contains("current maximum disc number"))
    }

    @Test
    @MainActor
    func tagEditorViewModelDiscTotalMismatchUpdatesWhenAllDiscNumbersAreRemoved() {
        let firstTrack = Track(
            tags: [
                TagKey.title: "Disc One",
                TagKey.discNumber: "1"
            ]
        )
        let secondTrack = Track(
            tags: [
                TagKey.title: "Disc Two",
                TagKey.discNumber: "2"
            ]
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstTrack, secondTrack]

        viewModel.setDiscTotalToCurrentDiscCount()
        #expect(viewModel.trackItems.allSatisfy { $0.tags["TOTALDISCS"] == "2" })
        #expect(!viewModel.hasTotalDiscsMismatch)

        viewModel.trackItems[0].tags[TagKey.discNumber] = ""
        viewModel.trackItems[1].tags[TagKey.discNumber] = ""

        #expect(viewModel.calculatedDiscTotal() == 0)
        #expect(viewModel.hasTotalDiscsMismatch)
        #expect(viewModel.totalDiscsHoverMessage.contains("current maximum disc number"))
    }

    @Test
    @MainActor
    func tagEditorViewModelSetDiscTotalClearsExternalDiscTotalDifferences() {
        var track = Track(
            tags: [
                TagKey.title: "Disc Diff",
                TagKey.discNumber: "2",
                "TOTALDISCS": "1"
            ]
        )
        track.externalDifferences = TrackExternalDifferences(
            isDeleted: false,
            fileValuesByTag: [
                "TOTALDISCS": "9",
                "DISCTOTAL": "9",
                TagKey.title: "External"
            ],
            hasPictureDifference: false
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]

        viewModel.setDiscTotalToCurrentDiscCount()

        #expect(viewModel.trackItems[0].tags["TOTALDISCS"] == "2")
        #expect(viewModel.trackItems[0].externalDifferences?.fileValuesByTag["TOTALDISCS"] == nil)
        #expect(viewModel.trackItems[0].externalDifferences?.fileValuesByTag["DISCTOTAL"] == nil)
        #expect(viewModel.trackItems[0].externalDifferences?.fileValuesByTag[TagKey.title] == "External")
    }

    @Test
    @MainActor
    func tagEditorViewModelTrackTotalMismatchUsesActiveCalculationMode() {
        let firstDiscOne = Track(
            totalTracks: "2",
            tags: [TagKey.title: "Disc 1 A", TagKey.discNumber: "1"]
        )
        let secondDiscOne = Track(
            totalTracks: "2",
            tags: [TagKey.title: "Disc 1 B", TagKey.discNumber: "1"]
        )
        let discTwo = Track(
            totalTracks: "1",
            tags: [TagKey.title: "Disc 2", TagKey.discNumber: "2"]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstDiscOne, secondDiscOne, discTwo]
        viewModel.selectedTrackIDs = Set(viewModel.trackItems.map(\.id))

        #expect(viewModel.hasTotalTracksMismatch(autoUpdateTrackTotalByDisc: false))
        #expect(!viewModel.hasTotalTracksMismatch(autoUpdateTrackTotalByDisc: true))
        #expect(viewModel.totalTracksHoverMessage(autoUpdateTrackTotalByDisc: true).contains("(2,1)"))

        viewModel.trackItems[0].totalTracks = "3"
        viewModel.trackItems[1].totalTracks = "3"
        viewModel.trackItems[2].totalTracks = "3"

        #expect(!viewModel.hasTotalTracksMismatch(autoUpdateTrackTotalByDisc: false))
        #expect(!viewModel.hasTotalTracksMismatch(autoUpdateTrackTotalByDisc: true))

        viewModel.trackItems[0].totalTracks = "9"
        #expect(viewModel.hasTotalTracksMismatch(autoUpdateTrackTotalByDisc: true))
    }

    @Test
    @MainActor
    func tagEditorViewModelTrackTotalByDiscMismatchRequiresDiscNumber() {
        let validDisc = Track(
            totalTracks: "2",
            tags: [TagKey.title: "Valid Disc", TagKey.discNumber: "1"]
        )
        let missingDisc = Track(
            totalTracks: "2",
            tags: [TagKey.title: "Missing Disc", TagKey.discNumber: ""]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [validDisc, missingDisc]
        viewModel.selectedTrackIDs = Set(viewModel.trackItems.map(\.id))

        #expect(!viewModel.hasTotalTracksMismatch(autoUpdateTrackTotalByDisc: false))
        #expect(viewModel.hasTotalTracksMismatch(autoUpdateTrackTotalByDisc: true))
    }

    @Test
    @MainActor
    func tagEditorViewModelTrackToFileDifferenceReflectsDiscCountMutation() {
        let firstTrack = Self.trackWithSnapshot(
            tags: [
                TagKey.title: "Disc Count A",
                TagKey.discNumber: "1",
                "TOTALTRACKS": "9"
            ]
        )
        let secondTrack = Self.trackWithSnapshot(
            tags: [
                TagKey.title: "Disc Count B",
                TagKey.discNumber: "1",
                "TOTALTRACKS": "9"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstTrack, secondTrack]
        viewModel.selectedTrackIDs = Set(viewModel.trackItems.map(\.id))

        #expect(!viewModel.hasTrackToFileDifference(forAnyOf: ["TOTALTRACKS", "TRACKTOTAL"]))

        viewModel.setTrackTotalToCurrentDiscCounts()

        #expect(viewModel.trackItems.allSatisfy { $0.totalTracks == "2" })
        #expect(viewModel.hasTrackToFileDifference(forAnyOf: ["TOTALTRACKS", "TRACKTOTAL"]))
    }

    @Test
    func trackSharedTagAccessorsUseTagsAsSourceOfTruth() {
        var track = Track(
            album: "  Explicit Album  ",
            tags: [
                TagKey.album: "Tag Album",
                TagKey.albumArtist: "  Tag Artist  ",
                "TRACKTOTAL": "07",
                TagKey.title: "Track"
            ]
        )

        #expect(track.album == "Explicit Album")
        #expect(track.tags[TagKey.album] == "Explicit Album")
        #expect(track.albumArtist == "Tag Artist")
        #expect(track.tags[TagKey.albumArtist] == "Tag Artist")
        #expect(track.totalTracks == "7")
        #expect(track.tags["TOTALTRACKS"] == "7")
        #expect(track.tags["TRACKTOTAL"] == nil)

        track.album = ""
        track.albumArtist = "  New Artist  "
        track.totalTracks = " 09 "

        #expect(track.tags[TagKey.album] == "")
        #expect(track.tags[TagKey.albumArtist] == "New Artist")
        #expect(track.tags["TOTALTRACKS"] == "9")
        #expect(track.tags["TRACKTOTAL"] == nil)

        track.totalTracks = ""
        #expect(track.totalTracks == "")
        #expect(track.tags["TOTALTRACKS"] == "")
    }

    @Test
    @MainActor
    func tagEditorSelectedSharedBindingsWriteTagBackedValues() throws {
        let firstTrack = Track(
            tags: [
                TagKey.title: "First",
                TagKey.filename: "first.flac"
            ]
        )
        let secondTrack = Track(
            tags: [
                TagKey.title: "Second",
                TagKey.filename: "second.flac"
            ]
        )
        let outOfScopeTrack = Track(
            tags: [
                TagKey.title: "Third",
                TagKey.filename: "third.flac"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstTrack, secondTrack, outOfScopeTrack]
        viewModel.selectedTrackIDs = [firstTrack.id, secondTrack.id]

        let albumBinding = try #require(viewModel.selectedAlbumBinding())
        let albumArtistBinding = try #require(viewModel.selectedAlbumArtistBinding())
        let totalTracksBinding = try #require(viewModel.selectedTotalTracksBinding())

        albumBinding.wrappedValue = " Shared Album "
        albumArtistBinding.wrappedValue = " Shared Artist "
        totalTracksBinding.wrappedValue = " 12 "

        let selectedTracks = viewModel.trackItems.filter { viewModel.selectedTrackIDs.contains($0.id) }
        #expect(selectedTracks.map { $0.tags[TagKey.album] } == ["Shared Album", "Shared Album"])
        #expect(selectedTracks.map { $0.tags[TagKey.albumArtist] } == ["Shared Artist", "Shared Artist"])
        #expect(selectedTracks.map { $0.tags["TOTALTRACKS"] } == ["12", "12"])
        #expect(selectedTracks.allSatisfy { $0.tags["TRACKTOTAL"] == nil })
        #expect(viewModel.trackItems.first(where: { $0.id == outOfScopeTrack.id })?.tags[TagKey.album] == nil)
    }

    @Test
    func compilationTagNormalizesPresenceToCanonicalValue() {
        #expect(CompilationTag.normalizedValue(nil) == nil)
        #expect(CompilationTag.normalizedValue("") == nil)
        #expect(CompilationTag.normalizedValue("   ") == nil)
        #expect(CompilationTag.normalizedValue("0") == nil)
        #expect(CompilationTag.normalizedValue("false") == nil)
        #expect(CompilationTag.normalizedValue("1") == CompilationTag.storedValue)
        #expect(CompilationTag.normalizedValue("T") == CompilationTag.storedValue)
        #expect(CompilationTag.normalizedValue("true") == CompilationTag.storedValue)
        #expect(CompilationTag.normalizedValue("On") == CompilationTag.storedValue)
        #expect(CompilationTag.normalizedValue("YES") == CompilationTag.storedValue)
    }

    @Test
    @MainActor
    func tagEditorViewModelAddDuplicateFilteringUsesBookmarkIdentity() throws {
        let loadedFileURL = try Self.tempFixtureCopyURL(name: "dedupe-loaded.flac")
        let newFileURL = try Self.tempFixtureCopyURL(name: "dedupe-new.flac")
        let loadedBookmarkData = try loadedFileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let alreadyLoadedTrack = Track(
            tags: [
                TagKey.title: "Loaded",
                TagKey.filename: loadedFileURL.lastPathComponent
            ],
            sourceFileURL: nil,
            securityScopedBookmarkData: loadedBookmarkData
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [alreadyLoadedTrack]

        let dedupedURLs = viewModel.removeDuplicateImportURLsByBookmarkIdentity([
            loadedFileURL,
            newFileURL,
            newFileURL
        ])

        #expect(dedupedURLs.count == 1)
        #expect(dedupedURLs.first?.path == newFileURL.path)
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
        #expect(FeedbackSettingsDefaults.showTrackFingerprintColumn)
        #expect(!FeedbackSettingsDefaults.quitAppOnLastWindowClose)
        #expect(FeedbackSettingsDefaults.formatOnTrackToFileDiff)
        #expect(FeedbackSettingsDefaults.formatOnTrackToTrackDiff)
        #expect(FeedbackSettingsDefaults.formatOnExternallyModifiedDiff)
        #expect(FeedbackSettingsDefaults.formatOnTrackTotalMismatch)
        #expect(FeedbackSettingsDefaults.formatOnDiscTotalMismatch)
        #expect(FeedbackSettingsDefaults.formatOnDuplicatePicture)
        #expect(!FeedbackSettingsDefaults.trackDiscTotalMismatchColor.isEmpty)
        #expect(!FeedbackSettingsDefaults.pictureStatusOverlayColor.isEmpty)
    }

    @Test
    func appDelegateDefaultsToKeepingAppOpenAfterLastWindowClose() throws {
        let (userDefaults, suiteName) = try Self.isolatedUserDefaults(
            prefix: "SwiftTagTests.WindowManagement"
        )
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        #expect(!AppDelegate.shouldTerminateAfterLastWindowClosed(userDefaults: userDefaults))
    }

    @Test
    func appDelegateReadsQuitAppOnLastWindowClosePreference() throws {
        let (userDefaults, suiteName) = try Self.isolatedUserDefaults(
            prefix: "SwiftTagTests.WindowManagement"
        )
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        userDefaults.set(true, forKey: FeedbackSettingsKey.quitAppOnLastWindowClose)
        #expect(AppDelegate.shouldTerminateAfterLastWindowClosed(userDefaults: userDefaults))

        userDefaults.set(false, forKey: FeedbackSettingsKey.quitAppOnLastWindowClose)
        #expect(!AppDelegate.shouldTerminateAfterLastWindowClosed(userDefaults: userDefaults))
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
    func tagDiffPresentationUsesMismatchColorWhenMismatchWarningIsShown() {
        let mismatchColor = Color.red
        let presentation = TagDiffPresentation.resolve(
            tag: .totalDiscs,
            hasTrackToTrackDifference: true,
            hasTrackToFileDifference: true,
            hasExternallyModifiedDifference: true,
            showsMismatchWarning: true,
            isInvalid: false,
            trackToTrackColor: .orange,
            trackToFileColor: .primary,
            externallyModifiedColor: .green,
            mismatchColor: mismatchColor,
            formatOnTrackToFileDiff: true,
            formatOnTrackToTrackDiff: true,
            formatOnExternallyModifiedDiff: true
        )

        #expect(presentation.foregroundColor == mismatchColor)
        #expect(presentation.backgroundColor == mismatchColor)
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
            "DISCTOTAL": "01",
            "GENRE": "Test Genre",
            "LOCATION": "Test Location",
            "DATE": "2026-03-01",
            "COMPOSER": "Test Composer",
            "DESCRIPTION": "Test Description",
            "COMMENT": "Test Comment",
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
        #expect(mapped[TagKey.comment] == "Test Comment")
        #expect(mapped[TagKey.trackNumber] == "1")
        #expect(mapped[TagKey.discNumber] == "1")
        #expect(mapped["TOTALTRACKS"] == "01")
        #expect(mapped["DISCTOTAL"] == "01")
        #expect(mapped["ENCODED_BY"] == "Test Encoded_By")
        #expect(mapped[TagKey.filename] == "test.flac")
    }

    @Test
    func flacImportMapperKeepsCommentSeparateFromDescription() {
        let mapped = FlacImportMapper.mapTrackTags(
            sourceTags: [TagKey.comment: "Legacy Misc Comment"],
            fileURL: URL(fileURLWithPath: "/tmp/comment-only.flac"),
            defaultDate: Date(timeIntervalSince1970: 0)
        )

        #expect(mapped[TagKey.comment] == "Legacy Misc Comment")
        #expect(mapped[TagKey.description] == "")
    }

    @Test
    func flacImportMapperPreservesPartialDateTagText() {
        let defaultDate = DateTagFormatter.parse("2020-05-06")!
        let yearMapped = FlacImportMapper.mapTrackTags(
            sourceTags: [TagKey.date: "2026"],
            fileURL: URL(fileURLWithPath: "/tmp/year.flac"),
            defaultDate: defaultDate
        )
        let monthMapped = FlacImportMapper.mapTrackTags(
            sourceTags: [TagKey.date: "2026-03"],
            fileURL: URL(fileURLWithPath: "/tmp/month.flac"),
            defaultDate: defaultDate
        )

        #expect(yearMapped[TagKey.date] == "2026")
        #expect(monthMapped[TagKey.date] == "2026-03")
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
        #expect(record.sampleRate == 44_100)
        #expect(record.totalSamples == 6_754)
        #expect(record.bitsPerSample == 16)
        #expect(record.channels == 1)
        #expect(record.fingerprint == Self.fixtureFingerprint)
        #expect(record.pictures.count >= 0)
    }

    @Test
    func flacMetadataServiceReadsPaddedFixtureFile() throws {
        let fileURL = Self.paddedFixtureURL
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let record = try FlacMetadataService.readTags(for: fileURL)
        #expect(record.tags["ALBUM"] == "Test Album")
        #expect(record.tags["ALBUMARTIST"] == "Test AlbumArtist")
        #expect(record.sampleRate == 44_100)
        #expect(record.totalSamples == 6_754)
        #expect(record.bitsPerSample == 16)
        #expect(record.channels == 1)
        #expect(record.fingerprint == Self.fixtureFingerprint)
    }

    @Test
    func flacMetadataServiceSurfacesBridgeFailureForMissingFile() {
        let missingURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString)-missing.flac")

        do {
            _ = try FlacMetadataService.readTags(for: missingURL)
            Issue.record("Expected missing file read to fail.")
        } catch let error as FlacMetadataServiceError {
            switch error {
            case let .bridgeFailed(message):
                #expect(!message.isEmpty)
                #expect(message.contains("FLAC__metadata_get_tags failed for file."))
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    @MainActor
    func importFlacFilesPropagatesFixtureFingerprintToTrackAndSnapshot() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "fingerprint-import.flac")
        let viewModel = TagEditorViewModel()

        try await viewModel.importFlacFiles([fileURL])

        let importedTrack = try #require(viewModel.trackItems.first)
        #expect(importedTrack.fingerprint == Self.fixtureFingerprint)
        #expect(importedTrack.latestFileSnapshot?.fingerprint == Self.fixtureFingerprint)
    }

    @Test
    @MainActor
    func reloadTracksWithDifferencesRestoresTrackFingerprintFromFile() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "fingerprint-reload.flac")
        let viewModel = TagEditorViewModel()

        try await viewModel.importFlacFiles([fileURL])
        let trackID = try #require(viewModel.trackItems.first?.id)

        viewModel.trackItems[0].tags[TagKey.title] = "Changed Title"
        viewModel.trackItems[0].fingerprint = "stale"

        try viewModel.reloadTracksWithDifferences(
            in: [trackID],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(viewModel.trackItems[0].fingerprint == Self.fixtureFingerprint)
        #expect(viewModel.trackItems[0].latestFileSnapshot?.fingerprint == Self.fixtureFingerprint)
    }

    @Test
    @MainActor
    func refreshTrackFileStateReplacesStaleFingerprintFromCurrentFile() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "fingerprint-refresh.flac")
        let viewModel = TagEditorViewModel()

        try await viewModel.importFlacFiles([fileURL])
        let trackID = try #require(viewModel.trackItems.first?.id)

        viewModel.trackItems[0].fingerprint = "stale"

        viewModel.refreshTrackFileState(
            for: trackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(viewModel.trackItems[0].fingerprint == Self.fixtureFingerprint)
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
    func flacPictureDescriptionBudgetReservesFixedFieldsAndSafetyBuffer() {
        let pictureData = Data(repeating: 0x7F, count: 1_024)
        let mimeType = "image/png"
        let validation = FlacPictureDescriptionBudget.validation(
            mimeType: mimeType,
            pictureData: pictureData,
            proposedDescription: String(repeating: "a", count: 32)
        )

        let expectedMaximumDescriptionBytes = FlacPictureDescriptionBudget.metadataPayloadMaxBytes
            - FlacPictureDescriptionBudget.fixedMetadataFieldBytes
            - FlacPictureDescriptionBudget.safetyBufferBytes
            - mimeType.lengthOfBytes(using: .utf8)
            - pictureData.count

        #expect(validation.maximumDescriptionBytes == expectedMaximumDescriptionBytes)
        #expect(validation.proposedDescriptionBytes == 32)
        #expect(validation.isValid)
    }

    @Test
    func flacPictureDescriptionBudgetAllowsEmptyDescriptionWhenPictureFits() {
        let validation = FlacPictureDescriptionBudget.validation(
            mimeType: "image/png",
            pictureData: Data(repeating: 0x01, count: 64),
            proposedDescription: ""
        )

        #expect(validation.proposedDescriptionBytes == 0)
        #expect(validation.isValid)
    }

    @Test
    func flacPictureDataBudgetReservesCurrentDescriptionAndSafetyBuffer() {
        let mimeType = "image/png"
        let currentDescription = "Edited Front Cover"
        let pictureData = Data(repeating: 0x7F, count: 4_096)
        let validation = FlacPictureDataBudget.validation(
            mimeType: mimeType,
            currentDescription: currentDescription,
            proposedPictureData: pictureData
        )

        let expectedMaximumPictureBytes = FlacPictureDescriptionBudget.metadataPayloadMaxBytes
            - FlacPictureDescriptionBudget.fixedMetadataFieldBytes
            - FlacPictureDescriptionBudget.safetyBufferBytes
            - FlacPictureDescriptionBudget.editDescriptionBufferBytes
            - mimeType.lengthOfBytes(using: .utf8)
            - currentDescription.lengthOfBytes(using: .utf8)

        #expect(validation.maximumPictureBytes == expectedMaximumPictureBytes)
        #expect(validation.proposedPictureBytes == pictureData.count)
        #expect(validation.isValid)
    }

    @Test
    @MainActor
    func albumArtViewModelRejectsOversizedPictureImportAndShowsAlert() throws {
        let frontData = try Self.pngData(color: .purple)
        let currentDescription = "Edited Front Cover"
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(
                    type: 3,
                    mimeType: "image/png",
                    description: currentDescription,
                    data: frontData
                )
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        let maximumPictureBytes = try #require(
            viewModel.currentPictureImportValidation(
                for: .frontCover,
                proposedPictureData: Data(),
                mimeType: "image/png",
                albumArtTypes: albumArtTypes
            )?.maximumPictureBytes
        )
        let oversizedPictureData = Data(repeating: 0xFF, count: maximumPictureBytes + 1)

        let didReject = viewModel.rejectOversizedPictureImportIfNeeded(
            for: .frontCover,
            pictureData: oversizedPictureData,
            mimeType: "image/png",
            albumArtTypes: albumArtTypes
        )

        #expect(didReject)
        #expect(viewModel.isPictureImportAlertPresented)
        #expect(viewModel.pictureImportAlertMessage.contains("current description"))
        #expect(viewModel.pictureImportAlertMessage.contains("256-byte buffer"))
        #expect(viewModel.pictureImportAlertMessage.contains("\(maximumPictureBytes) bytes"))
        #expect(viewModel.trackReferencesByTrackID[track.id, default: []].count == 1)
        #expect(viewModel.trackReferencesByTrackID[track.id, default: []].first?.description == currentDescription)
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
    @MainActor
    func albumArtViewModelBytesOnlyDedupePreservesPerReferenceMetadata() throws {
        let sharedData = try Self.pngData(color: .purple)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let trackA = Track(
            tags: [TagKey.title: "A"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front A", data: sharedData)
            ]
        )
        let trackB = Track(
            tags: [TagKey.title: "B"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/jpeg", description: "Front B", data: sharedData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [trackA, trackB], selectedTrackIDs: [], albumArtTypes: albumArtTypes)

        #expect(viewModel.picturePool.count == 1)

        let trackARecords = viewModel.flacPictures(for: trackA.id, albumArtTypes: albumArtTypes)
        let trackBRecords = viewModel.flacPictures(for: trackB.id, albumArtTypes: albumArtTypes)
        #expect(trackARecords.first?.mimeType == "image/png")
        #expect(trackARecords.first?.description == "Front A")
        #expect(trackBRecords.first?.mimeType == "image/jpeg")
        #expect(trackBRecords.first?.description == "Front B")
    }

    @Test
    @MainActor
    func albumArtViewModelUsesDisplayImageWithoutChangingPictureBytes() throws {
        let jpegData = try Self.jpegData(color: .systemBlue)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/jpeg", description: "Front", data: jpegData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        let displayAsset = try #require(viewModel.albumArtImages[.frontCover])
        let exportedRecord = try #require(viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes).first)

        #expect(displayAsset.data == jpegData)
        #expect(exportedRecord.data == jpegData)
        #expect(exportedRecord.mimeType == "image/jpeg")
    }

    @Test
    @MainActor
    func albumArtViewModelUsesCachedPictureSpecificationsForWritableRecords() throws {
        let jpegData = try Self.jpegData(color: .systemOrange)
        let expectedSpecifications = PictureDataUtilities.computedSpecifications(from: jpegData)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/jpeg", description: "Front", data: jpegData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        let poolItem = try #require(viewModel.picturePool.values.first)
        let exportedRecords = (0 ..< 10).compactMap { _ in
            viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes).first
        }

        #expect(poolItem.specifications == expectedSpecifications)
        #expect(exportedRecords.count == 10)
        #expect(exportedRecords.allSatisfy { record in
            record.width == expectedSpecifications.width &&
                record.height == expectedSpecifications.height &&
                record.depth == expectedSpecifications.depth &&
                record.colors == expectedSpecifications.colors
            })
    }

    @Test
    @MainActor
    func albumArtViewModelSelectionContextKeepsCachedPictureState() throws {
        let frontData = try Self.jpegData(color: .systemOrange)
        let backData = try Self.jpegData(color: .systemPurple)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let trackA = Track(
            tags: [TagKey.title: "A"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/jpeg", description: "Front A", data: frontData)
            ]
        )
        let trackB = Track(
            tags: [TagKey.title: "B"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 4, mimeType: "image/jpeg", description: "Back B", data: backData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [trackA, trackB], selectedTrackIDs: [trackA.id], albumArtTypes: albumArtTypes)
        let initialPicturePool = viewModel.picturePool
        let initialPicturePoolOrder = viewModel.picturePoolOrder
        let initialReferencesByTrackID = viewModel.trackReferencesByTrackID
        let initialTrackARecords = viewModel.flacPictures(for: trackA.id, albumArtTypes: albumArtTypes)
        let initialTrackBRecords = viewModel.flacPictures(for: trackB.id, albumArtTypes: albumArtTypes)

        viewModel.updateTrackSelectionContext(
            trackItems: [trackA, trackB],
            selectedTrackIDs: [trackB.id],
            albumArtTypes: albumArtTypes
        )

        #expect(viewModel.selectedTrackIDs == Set([trackB.id]))
        #expect(viewModel.picturePool == initialPicturePool)
        #expect(viewModel.picturePoolOrder == initialPicturePoolOrder)
        #expect(viewModel.trackReferencesByTrackID == initialReferencesByTrackID)
        #expect(viewModel.flacPictures(for: trackA.id, albumArtTypes: albumArtTypes) == initialTrackARecords)
        #expect(viewModel.flacPictures(for: trackB.id, albumArtTypes: albumArtTypes) == initialTrackBRecords)
    }

    @Test
    func albumArtDisplayImageFactoryCreatesSRGBBitmap() throws {
        let displayImage = try #require(AlbumArtDisplayImageFactory.image(from: try Self.jpegData(color: .systemGreen)))
        var proposedRect = NSRect(origin: .zero, size: displayImage.size)
        let cgImage = try #require(displayImage.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil))

        #expect(cgImage.width <= 1024)
        #expect(cgImage.height <= 1024)
        #expect(cgImage.bitsPerComponent == 8)
        #expect(cgImage.colorSpace?.name == CGColorSpace.sRGB)
    }

    @Test
    @MainActor
    func albumArtViewModelPictureIdentityCanFollowTrackRecordOrder() throws {
        let sharedData = try Self.pngData(color: .purple)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let frontRecord = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Front",
            data: sharedData
        )
        let backRecord = FlacWritablePictureRecord(
            type: 4,
            mimeType: "image/png",
            description: "Back",
            data: sharedData
        )
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [frontRecord, backRecord]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        let frontIdentity = try #require(
            viewModel.appleScriptPictureIdentity(
                for: track.id,
                record: frontRecord,
                occurrence: 0,
                albumArtTypes: albumArtTypes
            )
        )
        let backIdentity = try #require(
            viewModel.appleScriptPictureIdentity(
                for: track.id,
                record: backRecord,
                occurrence: 0,
                albumArtTypes: albumArtTypes
            )
        )

        #expect(frontIdentity.id != backIdentity.id)
        #expect(frontIdentity.poolId == backIdentity.poolId)
    }

    @Test
    @MainActor
    func albumArtViewModelRefreshUpdatesMatchingPictureDescriptionMetadata() throws {
        let frontData = try Self.pngData(color: .purple)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Original", data: frontData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        let initialMetadata = try #require(
            viewModel.currentPictureMetadata(for: .frontCover, albumArtTypes: albumArtTypes)
        )
        #expect(initialMetadata.descriptionText() == "Original")

        let updatedTrack = Track(
            id: track.id,
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Edited", data: frontData)
            ]
        )
        viewModel.configureTrackContext(
            trackItems: [updatedTrack],
            selectedTrackIDs: [updatedTrack.id],
            albumArtTypes: albumArtTypes
        )

        let updatedMetadata = try #require(
            viewModel.currentPictureMetadata(for: .frontCover, albumArtTypes: albumArtTypes)
        )
        #expect(updatedMetadata.description == "Edited")
        #expect(updatedMetadata.descriptionText() == "Edited")
        #expect(viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes).map(\.description) == ["Edited"])
        #expect(viewModel.trackReferencesByTrackID[track.id, default: []].map(\.description) == ["Edited"])
    }

    @Test
    @MainActor
    func albumArtViewModelRefreshKeepsDuplicatePictureDescriptionsAligned() throws {
        let frontData = try Self.pngData(color: .purple)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "First", data: frontData),
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Second", data: frontData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        let updatedTrack = Track(
            id: track.id,
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "First", data: frontData),
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Second Edited", data: frontData)
            ]
        )
        viewModel.configureTrackContext(
            trackItems: [updatedTrack],
            selectedTrackIDs: [updatedTrack.id],
            albumArtTypes: albumArtTypes
        )

        #expect(viewModel.trackReferencesByTrackID[track.id, default: []].map(\.description) == [
            "First",
            "Second Edited"
        ])
        #expect(viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes).map(\.description) == [
            "First",
            "Second Edited"
        ])
    }

    @Test
    @MainActor
    func albumArtViewModelDescriptionEditUpdatesAllMatchingInScopeReferences() throws {
        let sharedData = try Self.pngData(color: .purple)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let firstSelectedTrack = Track(
            tags: [TagKey.title: "First"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front A", data: sharedData)
            ]
        )
        let secondSelectedTrack = Track(
            tags: [TagKey.title: "Second"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front B", data: sharedData)
            ]
        )
        let outOfScopeTrack = Track(
            tags: [TagKey.title: "Out"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front Out", data: sharedData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [firstSelectedTrack, secondSelectedTrack, outOfScopeTrack],
            selectedTrackIDs: [firstSelectedTrack.id, secondSelectedTrack.id],
            albumArtTypes: albumArtTypes
        )

        let didUpdate = viewModel.updateCurrentPictureDescription(
            "Edited Front",
            for: .frontCover,
            albumArtTypes: albumArtTypes
        )

        #expect(didUpdate)
        #expect(viewModel.flacPictures(for: firstSelectedTrack.id, albumArtTypes: albumArtTypes).first?.description == "Edited Front")
        #expect(viewModel.flacPictures(for: secondSelectedTrack.id, albumArtTypes: albumArtTypes).first?.description == "Edited Front")
        #expect(viewModel.flacPictures(for: outOfScopeTrack.id, albumArtTypes: albumArtTypes).first?.description == "Front Out")
    }

    @Test
    @MainActor
    func albumArtViewModelDescriptionEditPreservesUnpinnedReferences() throws {
        let frontData = try Self.pngData(color: .brown)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Cover (front)", data: frontData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)
        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: false)
        viewModel.setCurrentPicturePinned(false, for: .frontCover, albumArtTypes: albumArtTypes)

        let didUpdate = viewModel.updateCurrentPictureDescription(
            "Edited Cover",
            for: .frontCover,
            albumArtTypes: albumArtTypes
        )

        #expect(didUpdate)
        #expect(!viewModel.isCurrentPicturePinned(for: .frontCover))
        #expect(viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes).isEmpty)
        #expect(viewModel.trackReferencesByTrackID[track.id, default: []].first?.description == "Edited Cover")
    }

    @Test
    @MainActor
    func albumArtViewModelSaveAllPicturesExcludesLockedTracksFromPinMutations() throws {
        let frontData = try Self.pngData(color: .red)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let unlockedTrack = Track(
            tags: [TagKey.title: "Unlocked"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Cover (front)", data: frontData)
            ],
            isLocked: false
        )
        let lockedTrack = Track(tags: [TagKey.title: "Locked"], flacPictureRecords: [], isLocked: true)

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [unlockedTrack, lockedTrack],
            selectedTrackIDs: [unlockedTrack.id],
            albumArtTypes: albumArtTypes
        )
        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: true)

        viewModel.setCurrentPicturePinned(true, for: .frontCover, albumArtTypes: albumArtTypes)

        #expect(viewModel.trackReferencesByTrackID[lockedTrack.id, default: []].isEmpty)
        #expect(!viewModel.trackReferencesByTrackID[unlockedTrack.id, default: []].isEmpty)
    }

    @Test
    @MainActor
    func albumArtViewModelSaveAllPicturesForcesAllUnlockedTracksAndScope() throws {
        let frontData = try Self.pngData(color: .cyan)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let sourceTrack = Track(
            tags: [TagKey.title: "Source"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front", data: frontData)
            ]
        )
        let targetTrack = Track(tags: [TagKey.title: "Target"], flacPictureRecords: [])
        let lockedTrack = Track(tags: [TagKey.title: "Locked"], flacPictureRecords: [], isLocked: true)

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [sourceTrack, targetTrack, lockedTrack],
            selectedTrackIDs: [targetTrack.id],
            albumArtTypes: albumArtTypes
        )

        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: true)

        #expect(viewModel.typePictureScope(for: .frontCover) == .allTrackPictures)
        #expect(viewModel.isTrackPinControlDisabled(for: .frontCover))
        #expect(viewModel.flacPictures(for: sourceTrack.id, albumArtTypes: albumArtTypes).count == 1)
        #expect(viewModel.flacPictures(for: targetTrack.id, albumArtTypes: albumArtTypes).count == 1)
        #expect(viewModel.flacPictures(for: lockedTrack.id, albumArtTypes: albumArtTypes).isEmpty)
    }

    @Test
    @MainActor
    func albumArtViewModelSaveAllPicturesOffRestoresSelectedScopeAndPreservesUnlockedPins() throws {
        let frontData = try Self.pngData(color: .magenta)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let sourceTrack = Track(
            tags: [TagKey.title: "Source"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front", data: frontData)
            ]
        )
        let targetTrack = Track(tags: [TagKey.title: "Target"], flacPictureRecords: [])

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [sourceTrack, targetTrack],
            selectedTrackIDs: [targetTrack.id],
            albumArtTypes: albumArtTypes
        )

        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: true)
        #expect(viewModel.flacPictures(for: targetTrack.id, albumArtTypes: albumArtTypes).count == 1)

        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: false)

        #expect(viewModel.typePictureScope(for: .frontCover) == .allTrackPictures)
        #expect(!viewModel.isTrackPinControlDisabled(for: .frontCover))
        #expect(viewModel.flacPictures(for: targetTrack.id, albumArtTypes: albumArtTypes).count == 1)
    }

    @Test
    @MainActor
    func albumArtViewModelFrontCoverSettingForcesOnlyFrontCoverSlot() throws {
        let frontData = try Self.pngData(color: .red)
        let backData = try Self.pngData(color: .blue)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let sourceTrack = Track(
            tags: [TagKey.title: "Source"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front", data: frontData),
                FlacWritablePictureRecord(type: 4, mimeType: "image/png", description: "Back", data: backData)
            ]
        )
        let targetTrack = Track(tags: [TagKey.title: "Target"], flacPictureRecords: [])

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [sourceTrack, targetTrack],
            selectedTrackIDs: [targetTrack.id],
            albumArtTypes: albumArtTypes
        )

        viewModel.configurePinSettings(saveFrontCoverToAllTracks: true, saveAllPicturesToAllTracks: false)

        #expect(viewModel.typePictureScope(for: .frontCover) == .allTrackPictures)
        #expect(viewModel.typePictureScope(for: .backCover) == .selectedTrackPictures)
        #expect(viewModel.isTrackPinControlDisabled(for: .frontCover))
        #expect(!viewModel.isTrackPinControlDisabled(for: .backCover))
        #expect(viewModel.flacPictures(for: targetTrack.id, albumArtTypes: albumArtTypes).map(\.type) == [3])
    }

    @Test
    @MainActor
    func albumArtViewModelDepinKeepsPictureBrowsableButExcludesItFromTrackWrite() throws {
        let frontData = try Self.pngData(color: .brown)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Cover (front)", data: frontData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)
        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: false)

        #expect(viewModel.hasImage(for: .frontCover))
        #expect(viewModel.isCurrentPicturePinned(for: .frontCover))

        viewModel.setCurrentPicturePinned(false, for: .frontCover, albumArtTypes: albumArtTypes)

        #expect(viewModel.hasImage(for: .frontCover))
        #expect(!viewModel.isCurrentPicturePinned(for: .frontCover))
        let writable = viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes)
        #expect(writable.isEmpty)
    }

    @Test
    @MainActor
    func albumArtViewModelUniquePictureCountIncludesPinCount() throws {
        let frontData = try Self.pngData(color: .brown)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let firstTrack = Track(
            tags: [TagKey.title: "A"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front", data: frontData)
            ]
        )
        let secondTrack = Track(
            tags: [TagKey.title: "B"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front", data: frontData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [firstTrack, secondTrack],
            selectedTrackIDs: [firstTrack.id, secondTrack.id],
            albumArtTypes: albumArtTypes
        )
        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: false)

        let initialCounts = viewModel.uniquePictureCount(for: .frontCover)
        #expect(initialCounts.count == 1)
        #expect(initialCounts.pinCount == 2)

        viewModel.setCurrentPicturePinned(false, for: .frontCover, albumArtTypes: albumArtTypes)

        let updatedCounts = viewModel.uniquePictureCount(for: .frontCover)
        #expect(updatedCounts.count == 1)
        #expect(updatedCounts.pinCount == 0)
    }

    @Test
    @MainActor
    func albumArtViewModelDepinKeepsPictureAvailableAfterContextRefresh() throws {
        let frontData = try Self.pngData(color: .brown)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Cover (front)", data: frontData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)
        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: false)
        viewModel.setCurrentPicturePinned(false, for: .frontCover, albumArtTypes: albumArtTypes)

        let updatedTrack = Track(
            id: track.id,
            tags: [TagKey.title: "Track"],
            flacPictureRecords: []
        )
        viewModel.configureTrackContext(trackItems: [updatedTrack], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        #expect(viewModel.uniquePictureCount(for: .frontCover).count == 1)
        #expect(viewModel.hasImage(for: .frontCover))
        #expect(!viewModel.isCurrentPicturePinned(for: .frontCover))
        #expect(viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes).isEmpty)
    }

    @Test
    @MainActor
    func albumArtViewModelDiscardTransientStateRemovesUnpinnedPictureForReloadedTrack() throws {
        let frontData = try Self.pngData(color: .brown)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Cover (front)", data: frontData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)
        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: false)
        viewModel.setCurrentPicturePinned(false, for: .frontCover, albumArtTypes: albumArtTypes)

        #expect(viewModel.hasImage(for: .frontCover))
        #expect(viewModel.flacPictures(albumArtTypes: albumArtTypes).count == 1)

        viewModel.discardTransientState(for: [track.id], albumArtTypes: albumArtTypes)
        viewModel.configureTrackContext(
            trackItems: [
                Track(id: track.id, tags: [TagKey.title: "Track"], flacPictureRecords: [])
            ],
            selectedTrackIDs: [track.id],
            albumArtTypes: albumArtTypes
        )

        #expect(!viewModel.hasImage(for: .frontCover))
        #expect(viewModel.flacPictures(albumArtTypes: albumArtTypes).isEmpty)
        #expect(viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes).isEmpty)
    }

    @Test
    @MainActor
    func albumArtViewModelRemovesAppleScriptPictureIdentityWithoutRekeyingRemainingPictures() throws {
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let backData = try Self.pngData(color: .systemPurple)
        let firstFrontData = try Self.pngData(color: .systemPink)
        let secondFrontData = try Self.pngData(color: .systemTeal)
        let track = Track(
            tags: [TagKey.title: "Stable Picture IDs"],
            flacPictureRecords: [
                FlacWritablePictureRecord(
                    type: 4,
                    mimeType: "image/png",
                    description: "Back",
                    data: backData
                ).withComputedPictureMetadata(),
                FlacWritablePictureRecord(
                    type: 3,
                    mimeType: "image/png",
                    description: "First Front",
                    data: firstFrontData
                ).withComputedPictureMetadata(),
                FlacWritablePictureRecord(
                    type: 3,
                    mimeType: "image/png",
                    description: "Second Front",
                    data: secondFrontData
                ).withComputedPictureMetadata()
            ]
        )
        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [track],
            selectedTrackIDs: [track.id],
            albumArtTypes: albumArtTypes
        )

        let backIdentity = try #require(
            viewModel.appleScriptPictureIdentity(for: track.id, pictureIndex: 0, albumArtTypes: albumArtTypes)
        )
        let firstFrontIdentity = try #require(
            viewModel.appleScriptPictureIdentity(for: track.id, pictureIndex: 1, albumArtTypes: albumArtTypes)
        )
        let secondFrontIdentity = try #require(
            viewModel.appleScriptPictureIdentity(for: track.id, pictureIndex: 2, albumArtTypes: albumArtTypes)
        )

        viewModel.removeAppleScriptPictureIdentity(
            firstFrontIdentity,
            for: track.id,
            albumArtTypes: albumArtTypes
        )
        var updatedTrack = track
        updatedTrack.flacPictureRecords.remove(at: 1)
        viewModel.configureTrackContext(
            trackItems: [updatedTrack],
            selectedTrackIDs: [track.id],
            albumArtTypes: albumArtTypes
        )

        #expect(viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes).map(\.description) == [
            "Back",
            "Second Front"
        ])
        #expect(
            viewModel.appleScriptPictureIdentity(for: track.id, pictureIndex: 0, albumArtTypes: albumArtTypes) ==
                backIdentity
        )
        #expect(
            viewModel.appleScriptPictureIdentity(for: track.id, pictureIndex: 1, albumArtTypes: albumArtTypes) ==
                secondFrontIdentity
        )
    }

    @Test
    @MainActor
    func albumArtViewModelLetsTrackBrowseAndPinPicturesContributedByOtherTracks() throws {
        let sharedData = try Self.pngData(color: .cyan)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let sourceTrack = Track(
            tags: [TagKey.title: "Source"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Source Cover", data: sharedData)
            ]
        )
        let targetTrack = Track(tags: [TagKey.title: "Target"], flacPictureRecords: [])

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [sourceTrack, targetTrack],
            selectedTrackIDs: [targetTrack.id],
            albumArtTypes: albumArtTypes
        )
        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: false)

        #expect(viewModel.uniquePictureCount(for: .frontCover).count == 0)
        #expect(!viewModel.hasImage(for: .frontCover))
        #expect(!viewModel.isCurrentPicturePinned(for: .frontCover))

        viewModel.setTypePictureScope(.allTrackPictures, for: .frontCover, albumArtTypes: albumArtTypes)

        #expect(viewModel.uniquePictureCount(for: .frontCover).count == 1)
        #expect(viewModel.hasImage(for: .frontCover))

        viewModel.setCurrentPicturePinned(true, for: .frontCover, albumArtTypes: albumArtTypes)

        let targetPictures = viewModel.flacPictures(for: targetTrack.id, albumArtTypes: albumArtTypes)
        #expect(targetPictures.count == 1)
        #expect(targetPictures.first?.data == sharedData)
        #expect(viewModel.isCurrentPicturePinned(for: .frontCover))
    }

    @Test
    @MainActor
    func albumArtViewModelRemoveCurrentPictureShowsRepinHintWhenOutOfScopeReferenceRemains() throws {
        let frontData = try Self.pngData(color: .orange)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let selectedTrack = Track(
            tags: [TagKey.title: "Selected"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Cover (front)", data: frontData)
            ]
        )
        let otherTrack = Track(
            tags: [TagKey.title: "Other"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Cover (front)", data: frontData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [selectedTrack, otherTrack],
            selectedTrackIDs: [selectedTrack.id],
            albumArtTypes: albumArtTypes
        )
        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: false)
        viewModel.setTypePictureScope(.allTrackPictures, for: .frontCover, albumArtTypes: albumArtTypes)

        viewModel.removeCurrentPicture(for: .frontCover, albumArtTypes: albumArtTypes)

        #expect(viewModel.trackReferencesByTrackID[selectedTrack.id, default: []].isEmpty)
        #expect(!viewModel.trackReferencesByTrackID[otherTrack.id, default: []].isEmpty)
        let overlayMessages = viewModel.infoOverlayMessages(for: .frontCover, albumArtTypes: albumArtTypes)
        #expect(overlayMessages.contains(where: { $0.message.localizedCaseInsensitiveContains("pin") }))
        #expect(viewModel.hasImage(for: .frontCover))
        #expect(!viewModel.canNavigatePictures(for: .frontCover))
    }

    @Test
    @MainActor
    func albumArtViewModelCrossTypeDuplicateWarningUsesTwinTypeNames() throws {
        let sharedData = try Self.pngData(color: .cyan)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front", data: sharedData),
                FlacWritablePictureRecord(type: 4, mimeType: "image/png", description: "Back", data: sharedData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        #expect(viewModel.hasCrossTypeDuplicate(for: .frontCover))
        let overlayMessages = viewModel.infoOverlayMessages(for: .frontCover, albumArtTypes: albumArtTypes)
        #expect(overlayMessages.first?.messageType == .hasDuplicateInOtherSlot)
        #expect(overlayMessages.first?.message.contains("Back Cover") == true)
    }

    @Test
    @MainActor
    func albumArtViewModelCrossTypeDuplicateOverlayTracksCurrentPicture() throws {
        let duplicateData = try Self.pngData(color: .cyan)
        let uniqueData = try Self.pngData(color: .orange)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front Duplicate", data: duplicateData),
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front Unique", data: uniqueData),
                FlacWritablePictureRecord(type: 4, mimeType: "image/png", description: "Back Duplicate", data: duplicateData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        let firstOverlayState = viewModel.infoOverlayState(for: .frontCover, albumArtTypes: albumArtTypes)
        #expect(firstOverlayState?.messages.contains(where: { $0.messageType == .hasDuplicateInOtherSlot }) == true)

        viewModel.goToNextPicture(for: .frontCover, albumArtTypes: albumArtTypes)

        let secondOverlayState = viewModel.infoOverlayState(for: .frontCover, albumArtTypes: albumArtTypes)
        #expect(secondOverlayState == nil)
    }

    @Test
    @MainActor
    func albumArtViewModelDropExistingPictureIntoOtherSlotShowsCrossTypeDuplicateOverlay() async throws {
        let sharedData = try Self.pngData(color: .blue)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front", data: sharedData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        let duplicateURL = try Self.tempPNGFileURL(name: "album-art-cross-slot-duplicate", color: .blue)
        guard let provider = NSItemProvider(contentsOf: duplicateURL) else {
            Issue.record("Failed to create item provider for cross-slot duplicate picture test")
            return
        }

        #expect(viewModel.handleAlbumArtDrop([provider], for: .backCover, albumArtTypes: albumArtTypes))
        let didSelectDroppedPicture = await Self.waitUntil {
            viewModel.albumArtImages[.backCover]?.data == sharedData
        }

        #expect(didSelectDroppedPicture)
        let overlayState = viewModel.infoOverlayState(for: .backCover, albumArtTypes: albumArtTypes)
        #expect(overlayState?.messages.contains(where: { $0.messageType == .hasDuplicateInOtherSlot }) == true)
        #expect(overlayState?.messages.first?.message.contains("Front Cover") == true)
    }

    @Test
    @MainActor
    func albumArtViewModelCrossTypeDuplicateUsesSelectedTrackScope() throws {
        let sharedData = try Self.pngData(color: .systemTeal)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let selectedTrack = Track(
            tags: [TagKey.title: "Selected"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front", data: sharedData)
            ]
        )
        let otherTrack = Track(
            tags: [TagKey.title: "Other"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 4, mimeType: "image/png", description: "Back", data: sharedData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [selectedTrack, otherTrack],
            selectedTrackIDs: [selectedTrack.id],
            albumArtTypes: albumArtTypes
        )

        #expect(!viewModel.hasCrossTypeDuplicate(for: .frontCover))
        #expect(viewModel.infoOverlayState(for: .frontCover, albumArtTypes: albumArtTypes) == nil)

        viewModel.setTypePictureScope(.allTrackPictures, for: .frontCover, albumArtTypes: albumArtTypes)

        #expect(viewModel.hasCrossTypeDuplicate(for: .frontCover))
        let overlayState = viewModel.infoOverlayState(for: .frontCover, albumArtTypes: albumArtTypes)
        #expect(overlayState?.messages.contains(where: { $0.messageType == .hasDuplicateInOtherSlot }) == true)
        #expect(overlayState?.messages.first?.message.contains("Back Cover") == true)
    }

    @Test
    @MainActor
    func albumArtViewModelCrossTypeDuplicateAcrossDifferentTracksUsesAllTrackScope() throws {
        let sharedData = try Self.pngData(color: .systemIndigo)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let firstTrack = Track(
            tags: [TagKey.title: "A"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front", data: sharedData)
            ]
        )
        let secondTrack = Track(
            tags: [TagKey.title: "B"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 4, mimeType: "image/png", description: "Back", data: sharedData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [firstTrack, secondTrack],
            selectedTrackIDs: [],
            albumArtTypes: albumArtTypes
        )

        viewModel.setTypePictureScope(.allTrackPictures, for: .frontCover, albumArtTypes: albumArtTypes)

        #expect(viewModel.hasCrossTypeDuplicate(for: .frontCover))
        let overlayState = viewModel.infoOverlayState(for: .frontCover, albumArtTypes: albumArtTypes)
        #expect(overlayState?.messages.contains(where: { $0.messageType == .hasDuplicateInOtherSlot }) == true)
        #expect(overlayState?.messages.first?.message.contains("Back Cover") == true)
    }

    @Test
    @MainActor
    func albumArtViewModelOutOfScopeOverlayClearsAfterRepin() throws {
        let sharedData = try Self.pngData(color: .purple)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let selectedTrack = Track(
            tags: [TagKey.title: "Selected"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front", data: sharedData)
            ]
        )
        let otherTrack = Track(
            tags: [TagKey.title: "Other"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front", data: sharedData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [selectedTrack, otherTrack],
            selectedTrackIDs: [selectedTrack.id],
            albumArtTypes: albumArtTypes
        )
        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: false)
        viewModel.setTypePictureScope(.allTrackPictures, for: .frontCover, albumArtTypes: albumArtTypes)

        viewModel.removeCurrentPicture(for: .frontCover, albumArtTypes: albumArtTypes)
        let messagesAfterRemove = viewModel.infoOverlayMessages(for: .frontCover, albumArtTypes: albumArtTypes)
        #expect(messagesAfterRemove.contains(where: { $0.messageType == .hasOutOfScopeReference }))

        viewModel.setCurrentPicturePinned(true, for: .frontCover, albumArtTypes: albumArtTypes)

        let messagesAfterRepin = viewModel.infoOverlayMessages(for: .frontCover, albumArtTypes: albumArtTypes)
        #expect(!messagesAfterRepin.contains(where: { $0.messageType == .hasOutOfScopeReference }))
    }

    @Test
    @MainActor
    func albumArtViewModelBrowsesUniqueImagesAndShowsReferenceCountInMetadata() throws {
        let sharedData = try Self.pngData(color: .magenta)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let firstTrack = Track(
            tags: [TagKey.title: "A"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front A", data: sharedData)
            ]
        )
        let secondTrack = Track(
            tags: [TagKey.title: "B"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Front B", data: sharedData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [firstTrack, secondTrack],
            selectedTrackIDs: [firstTrack.id, secondTrack.id],
            albumArtTypes: albumArtTypes
        )

        #expect(!viewModel.canNavigatePictures(for: .frontCover))
        let metadata = try #require(
            viewModel.currentPictureMetadata(for: .frontCover, albumArtTypes: albumArtTypes)
        )
        #expect(metadata.inSlotReferenceCount == 2)
        #expect(metadata.outOfSlotReferenceCount == 0)
        #expect(metadata.pinCount == 2)
        #expect(metadata.currentIndex == 1)
        #expect(metadata.totalCount == 1)
    }

    @Test
    @MainActor
    func albumArtViewModelNavigationAvailabilityStopsAtBounds() throws {
        let firstData = try Self.pngData(color: .red)
        let secondData = try Self.pngData(color: .blue)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "First", data: firstData),
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Second", data: secondData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        #expect(!viewModel.canGoToPreviousPicture(for: .frontCover))
        #expect(viewModel.canGoToNextPicture(for: .frontCover))

        viewModel.goToNextPicture(for: .frontCover, albumArtTypes: albumArtTypes)

        #expect(viewModel.canGoToPreviousPicture(for: .frontCover))
        #expect(!viewModel.canGoToNextPicture(for: .frontCover))
    }

    @Test
    @MainActor
    func albumArtViewModelDropNewPictureSelectsLastPosition() async throws {
        let firstData = try Self.pngData(color: .red)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 4, mimeType: "image/png", description: "Existing", data: firstData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        let addedData = try Self.pngData(color: .green)
        let addedURL = try Self.tempPNGFileURL(name: "album-art-added", color: .green)
        guard let provider = NSItemProvider(contentsOf: addedURL) else {
            Issue.record("Failed to create item provider for new picture test")
            return
        }

        #expect(viewModel.handleAlbumArtDrop([provider], for: .backCover, albumArtTypes: albumArtTypes))
        let didSelectAddedPicture = await Self.waitUntil {
            viewModel.albumArtImages[.backCover]?.data == addedData
        }

        #expect(didSelectAddedPicture)
        let metadata = try #require(
            viewModel.currentPictureMetadata(for: .backCover, albumArtTypes: albumArtTypes)
        )
        #expect(metadata.currentIndex == 2)
        #expect(metadata.totalCount == 2)
    }

    @Test
    @MainActor
    func albumArtViewModelDropExistingPictureSelectsMatchingPosition() async throws {
        let firstData = try Self.pngData(color: .red)
        let secondData = try Self.pngData(color: .blue)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let firstTrack = Track(
            tags: [TagKey.title: "A"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 4, mimeType: "image/png", description: "First", data: firstData)
            ]
        )
        let secondTrack = Track(
            tags: [TagKey.title: "B"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 4, mimeType: "image/png", description: "Second", data: secondData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [firstTrack, secondTrack], selectedTrackIDs: [], albumArtTypes: albumArtTypes)

        let duplicateURL = try Self.tempPNGFileURL(name: "album-art-duplicate", color: .blue)
        guard let provider = NSItemProvider(contentsOf: duplicateURL) else {
            Issue.record("Failed to create item provider for duplicate picture test")
            return
        }

        #expect(viewModel.handleAlbumArtDrop([provider], for: .backCover, albumArtTypes: albumArtTypes))
        let didSelectMatchingPicture = await Self.waitUntil {
            viewModel.albumArtImages[.backCover]?.data == secondData
        }

        #expect(didSelectMatchingPicture)
        let metadata = try #require(
            viewModel.currentPictureMetadata(for: .backCover, albumArtTypes: albumArtTypes)
        )
        #expect(metadata.totalCount == 2)
        #expect((1...2).contains(metadata.currentIndex))
    }

    @Test
    @MainActor
    func albumArtViewModelDropExistingPictureInSameTrackAndSlotDoesNotAddDuplicateReference() async throws {
        let existingData = try Self.pngData(color: .orange)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 4, mimeType: "image/png", description: "Existing", data: existingData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        let duplicateURL = try Self.tempPNGFileURL(name: "album-art-same-track-duplicate", color: .orange)
        guard let provider = NSItemProvider(contentsOf: duplicateURL) else {
            Issue.record("Failed to create item provider for same-track duplicate picture test")
            return
        }

        let initialTrackReferenceCount = viewModel.trackReferencesByTrackID[track.id, default: []].count
        let initialWritableCount = viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes).count

        #expect(viewModel.handleAlbumArtDrop([provider], for: .backCover, albumArtTypes: albumArtTypes))
        let didSelectExistingPicture = await Self.waitUntil {
            viewModel.albumArtImages[.backCover]?.data == existingData
        }

        #expect(didSelectExistingPicture)
        #expect(viewModel.trackReferencesByTrackID[track.id, default: []].count == initialTrackReferenceCount)
        #expect(viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes).count == initialWritableCount)
        let metadata = try #require(
            viewModel.currentPictureMetadata(for: .backCover, albumArtTypes: albumArtTypes)
        )
        #expect(metadata.currentIndex == 1)
        #expect(metadata.totalCount == 1)
    }

    @Test
    @MainActor
    func albumArtViewModelWritesFirstFrontCoverLastPerTrack() throws {
        let firstFront = try Self.pngData(color: .orange)
        let secondFront = try Self.pngData(color: .green)
        let backCover = try Self.pngData(color: .yellow)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover),
            AlbumArtType(flacPictureType: 4, flacDescription: "Cover (back)", navigationLinkName: "Back Cover", slot: .backCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "First Front", data: firstFront),
                FlacWritablePictureRecord(type: 4, mimeType: "image/png", description: "Back", data: backCover),
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Second Front", data: secondFront)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)

        let writtenPictures = viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes)
        #expect(writtenPictures.map(\.type) == [4, 3, 3])
        #expect(writtenPictures.map(\.description) == ["Back", "First Front", "Second Front"])
    }

    @Test
    @MainActor
    func albumArtViewModelTypePictureScopeChangesTypeCount() throws {
        let firstData = try Self.pngData(color: .red)
        let secondData = try Self.pngData(color: .blue)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let selectedTrack = Track(
            tags: [TagKey.title: "Selected"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Selected", data: firstData)
            ]
        )
        let otherTrack = Track(
            tags: [TagKey.title: "Other"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Other", data: secondData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [selectedTrack, otherTrack],
            selectedTrackIDs: [selectedTrack.id],
            albumArtTypes: albumArtTypes
        )

        #expect(viewModel.uniquePictureCount(for: .frontCover).count == 1)

        viewModel.setTypePictureScope(.allTrackPictures, for: .frontCover, albumArtTypes: albumArtTypes)

        #expect(viewModel.uniquePictureCount(for: .frontCover).count == 2)
    }

    @Test
    @MainActor
    func albumArtViewModelTypePictureScopeAllPinsAcrossAllTracks() throws {
        let sharedData = try Self.pngData(color: .cyan)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let sourceTrack = Track(
            tags: [TagKey.title: "Source"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Source", data: sharedData)
            ]
        )
        let targetTrack = Track(tags: [TagKey.title: "Target"], flacPictureRecords: [])
        let extraTrack = Track(tags: [TagKey.title: "Extra"], flacPictureRecords: [])

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [sourceTrack, targetTrack, extraTrack],
            selectedTrackIDs: [targetTrack.id],
            albumArtTypes: albumArtTypes
        )
        viewModel.setTypePictureScope(.allTrackPictures, for: .frontCover, albumArtTypes: albumArtTypes)

        viewModel.setCurrentPicturePinned(true, for: .frontCover, albumArtTypes: albumArtTypes)

        #expect(viewModel.flacPictures(for: targetTrack.id, albumArtTypes: albumArtTypes).count == 1)
        #expect(viewModel.flacPictures(for: extraTrack.id, albumArtTypes: albumArtTypes).count == 1)
    }

    @Test
    @MainActor
    func albumArtViewModelFrontCoverAddAppendsInsteadOfReplacing() async throws {
        let firstFront = try Self.pngData(color: .orange)
        let secondFront = try Self.pngData(color: .green)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "First Front", data: firstFront)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)
        #if DEBUG
        viewModel.debugFrontCoverDropAction = "add"
        #endif

        let addedURL = try Self.tempPNGFileURL(name: "album-art-front-cover-add", color: .green)
        guard let provider = NSItemProvider(contentsOf: addedURL) else {
            Issue.record("Failed to create item provider for front-cover add test")
            return
        }

        #expect(viewModel.handleAlbumArtDrop([provider], for: .frontCover, albumArtTypes: albumArtTypes))
        let didSelectAddedPicture = await Self.waitUntil {
            viewModel.albumArtImages[.frontCover]?.data == secondFront
        }

        #expect(didSelectAddedPicture)
        #expect(viewModel.flacPictures(for: track.id, albumArtTypes: albumArtTypes).map(\.description) == ["First Front", "Cover (front)"])
        let metadata = try #require(
            viewModel.currentPictureMetadata(for: .frontCover, albumArtTypes: albumArtTypes)
        )
        #expect(metadata.currentIndex == 2)
        #expect(metadata.totalCount == 2)
    }

    @Test
    @MainActor
    func albumArtViewModelForcedSaveAllPicturesRestoresStoredPinStateWhenDisabled() throws {
        let frontData = try Self.pngData(color: .brown)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Cover (front)", data: frontData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(trackItems: [track], selectedTrackIDs: [track.id], albumArtTypes: albumArtTypes)
        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: false)
        viewModel.setCurrentPicturePinned(false, for: .frontCover, albumArtTypes: albumArtTypes)
        #expect(!viewModel.isCurrentPicturePinned(for: .frontCover))

        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: true)
        #expect(viewModel.isCurrentPicturePinned(for: .frontCover))

        viewModel.configurePinSettings(saveFrontCoverToAllTracks: false, saveAllPicturesToAllTracks: false)
        #expect(viewModel.isCurrentPicturePinned(for: .frontCover))
        #expect(viewModel.typePictureScope(for: .frontCover) == .allTrackPictures)
        #expect(!viewModel.isTrackPinControlDisabled(for: .frontCover))
    }

    @Test
    @MainActor
    func albumArtViewModelMetadataShowsMixedInFileStatusAndPosition() throws {
        let firstData = try Self.pngData(color: .orange)
        let secondData = try Self.pngData(color: .green)
        let albumArtTypes: [AlbumArtType] = [
            AlbumArtType(flacPictureType: 3, flacDescription: "Cover (front)", navigationLinkName: "Front Cover", slot: .frontCover)
        ]
        let firstTrack = Track(
            tags: [TagKey.title: "A"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "First", data: firstData),
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Second", data: secondData)
            ]
        )
        let secondTrack = Track(
            tags: [TagKey.title: "B"],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "First", data: firstData)
            ]
        )

        let viewModel = AlbumArtViewModel()
        viewModel.configureTrackContext(
            trackItems: [firstTrack, secondTrack],
            selectedTrackIDs: [firstTrack.id, secondTrack.id],
            albumArtTypes: albumArtTypes
        )

        let metadata = try #require(
            viewModel.currentPictureMetadata(for: .frontCover, albumArtTypes: albumArtTypes)
        )
        #expect(metadata.inSlotReferenceCount == 2)
        #expect(metadata.outOfSlotReferenceCount == 0)
        #expect(metadata.currentIndex == 1)
        #expect(metadata.totalCount == 2)

        viewModel.goToNextPicture(for: .frontCover, albumArtTypes: albumArtTypes)

        let secondMetadata = try #require(
            viewModel.currentPictureMetadata(for: .frontCover, albumArtTypes: albumArtTypes)
        )
        #expect(secondMetadata.inSlotReferenceCount == 1)
        #expect(secondMetadata.outOfSlotReferenceCount == 0)
        #expect(secondMetadata.currentIndex == 2)
        #expect(secondMetadata.totalCount == 2)
    }

    @Test
    @MainActor
    func tagEditorViewModelTreatsOrderedMultiPictureChangesAsUnsavedImmediately() throws {
        let originalFront = try Self.pngData(color: .purple)
        let addedFront = try Self.pngData(color: .cyan)
        let originalRecords = [
            FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Original", data: originalFront)
        ]
        let updatedRecords = [
            FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Original", data: originalFront),
            FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Added", data: addedFront)
        ]
        let track = Track(
            tags: [TagKey.title: "Track"],
            flacPictureRecords: originalRecords,
            latestFileSnapshot: TrackFileSnapshot(
                tags: [TagKey.title: "Track"],
                picturesByType: [3: originalFront],
                pictureRecords: originalRecords
            )
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]

        viewModel.setPictureRecordsByTrackID(
            [track.id: updatedRecords],
            tagWriteOptions: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .totalDiscs
            ),
            albumArtPictures: []
        )

        let differences = viewModel.editorDifferenceCounts(
            for: [track.id],
            tagWriteOptions: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .totalDiscs
            ),
            albumArtPictures: []
        )

        #expect(differences.pictureEdits == 1)
        #expect(viewModel.hasDifferences(
            in: [track.id],
            tagWriteOptions: TagWriteOptions(
                zeroPadTrackNumber: true,
                trackCountKeyStrategy: .both,
                zeroPadDiscNumber: true,
                discCountKeyStrategy: .totalDiscs
            ),
            albumArtPictures: []
        ))
    }

    @Test
    @MainActor
    func tagEditorViewModelTreatsDescriptionOnlyPictureChangesAsPictureEdits() throws {
        let pictureData = try Self.pngData(color: .orange)
        let originalRecords = [
            FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Original", data: pictureData)
        ]
        let updatedRecords = [
            FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Edited", data: pictureData)
        ]
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                tags: [
                    TagKey.title: "Track",
                    TagKey.trackNumber: "1",
                    TagKey.discNumber: "1"
                ],
                flacPictureRecords: originalRecords,
                sourceFileURL: URL(fileURLWithPath: "/tmp/picture-description-diff.flac")
            )
        ]
        let trackID = try #require(viewModel.trackItems.first?.id)
        viewModel.selectedTrackIDs = [trackID]
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        viewModel.setPictureRecordsByTrackID(
            [trackID: updatedRecords],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let differences = viewModel.editorDifferenceCounts(
            for: [trackID],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        let navigationMetadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(differences.tagEdits == 0)
        #expect(differences.pictureEdits == 1)
        #expect(viewModel.hasDifferences(
            in: [trackID],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        ))
        #expect(navigationMetadata.subtitle.contains("Tag Δ: 0 (0)"))
        #expect(navigationMetadata.subtitle.contains("Picture Δ: 1 (1)"))
    }

    @Test
    @MainActor
    func tagEditorViewModelNavigationMetadataUsesSwiftTagWhenEditorIsEmpty() {
        let viewModel = TagEditorViewModel()

        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(metadata.title == "SwiftTag")
        #expect(metadata.subtitle == "Tracks: 0 (0) • Tag Δ: 0 (0) • Picture Δ: 0 (0)")
        #expect(metadata.documentURL == nil)
        #expect(metadata.documentDisplayName == nil)
    }

    @Test
    @MainActor
    func tagEditorViewModelNavigationMetadataUsesLoadedAlbumWhenNothingIsSelected() {
        let track = Track(
            album: "Loaded Album",
            tags: [
                TagKey.album: "Loaded Album",
                TagKey.title: "Track",
                TagKey.filename: "loaded.flac"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/loaded.flac")
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]

        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(metadata.title == "Loaded Album")
    }

    @Test
    @MainActor
    func tagEditorViewModelNavigationMetadataUsesSharedSelectedAlbumWhenSelectionMatches() {
        let firstTrack = Track(
            album: "Shared Album",
            tags: [
                TagKey.album: "Shared Album",
                TagKey.title: "Track 1",
                TagKey.filename: "track-1.flac"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/track-1.flac")
        )
        let secondTrack = Track(
            album: "Shared Album",
            tags: [
                TagKey.album: "Shared Album",
                TagKey.title: "Track 2",
                TagKey.filename: "track-2.flac"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/track-2.flac")
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstTrack, secondTrack]
        viewModel.selectedTrackIDs = [firstTrack.id, secondTrack.id]

        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(metadata.title == "Shared Album")
    }

    @Test
    @MainActor
    func tagEditorViewModelNavigationMetadataUsesMixedWhenSelectedAlbumsDiffer() {
        let firstTrack = Track(
            album: "Album A",
            tags: [
                TagKey.album: "Album A",
                TagKey.title: "Track 1",
                TagKey.filename: "track-1.flac"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/track-1.flac")
        )
        let secondTrack = Track(
            album: "Album B",
            tags: [
                TagKey.album: "Album B",
                TagKey.title: "Track 2",
                TagKey.filename: "track-2.flac"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/track-2.flac")
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstTrack, secondTrack]
        viewModel.selectedTrackIDs = [firstTrack.id, secondTrack.id]

        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(metadata.title == "Mixed")
    }

    @Test
    @MainActor
    func tagEditorViewModelNavigationMetadataUsesUntitledWhenSelectedAlbumIsEmpty() {
        let track = Track(
            album: "",
            tags: [
                TagKey.album: "",
                TagKey.title: "Track",
                TagKey.filename: "untitled.flac"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/untitled.flac")
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]

        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(metadata.title == "Untitled")
    }

    @Test
    @MainActor
    func tagEditorViewModelNavigationMetadataUsesDocumentNameAndStandardizedURLWhenPresent() {
        let track = Track(
            album: "Album",
            tags: [
                TagKey.album: "Album",
                TagKey.title: "Track",
                TagKey.filename: "track.flac"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/track.flac")
        )
        let documentURL = URL(fileURLWithPath: "/tmp/navigation-tests/../Session.swifttag")
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]
        viewModel.rememberSwiftTagDocumentSave(
            SwiftTagDocumentSaveResult(
                destinationURL: documentURL,
                documentID: UUID(),
                fingerprint: "fingerprint"
            )
        )

        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(metadata.title == "Session.swifttag")
        #expect(metadata.documentDisplayName == "Session.swifttag")
        #expect(metadata.documentURL == documentURL.standardizedFileURL)
    }

    @Test
    @MainActor
    func tagEditorViewModelNavigationMetadataShowsDeletedAssociatedDocumentState() throws {
        let track = Track(
            album: "Album",
            tags: [
                TagKey.album: "Album",
                TagKey.title: "Track",
                TagKey.filename: "track.flac"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/track.flac")
        )
        let documentURL = try Self.tempPackageURL(name: "Deleted Session")
        let saveResult = try SwiftTagDocumentPackageWriter.save(
            tracks: [
                SwiftTagDocumentExportTrack(
                    sortKey: "/tmp/track.flac",
                    tags: [TagKey.title: "Track"],
                    pictures: [],
                    sourceFileURL: URL(fileURLWithPath: "/tmp/track.flac"),
                    securityScopedBookmarkData: nil,
                    flacFingerprint: "fingerprint"
                )
            ],
            state: .init(),
            to: documentURL
        )
        try FileManager.default.removeItem(at: documentURL)

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]
        viewModel.rememberSwiftTagDocumentSave(saveResult)

        let didRefresh = viewModel.refreshSwiftTagDocumentSaveState(allowMissingRetry: false)
        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(didRefresh)
        #expect(metadata.title == "Deleted Session.swifttag (deleted)")
        #expect(metadata.documentDisplayName == "Deleted Session.swifttag")
        #expect(metadata.documentURL == documentURL.standardizedFileURL)
    }

    @Test
    @MainActor
    func tagEditorViewModelNavigationMetadataAppendsMarkerForReferencedDocumentTrackListDifference() throws {
        let firstURL = try Self.tempFixtureCopyURL(name: "navigation-dirty-first.flac")
        let secondURL = try Self.tempFixtureCopyURL(name: "navigation-dirty-second.flac")
        let firstTrack = try Self.bookmarkBackedTrack(
            fileURL: firstURL,
            tags: [TagKey.title: "First", TagKey.filename: firstURL.lastPathComponent],
            fingerprint: Self.fixtureFingerprint
        )
        let secondTrack = try Self.bookmarkBackedTrack(
            fileURL: secondURL,
            tags: [TagKey.title: "Second", TagKey.filename: secondURL.lastPathComponent],
            fingerprint: Self.fixtureFingerprint
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstTrack, secondTrack]
        viewModel.rememberSwiftTagDocumentSave(
            SwiftTagDocumentSaveResult(
                destinationURL: URL(fileURLWithPath: "/tmp/Session.swifttag"),
                documentID: UUID(),
                fingerprint: "document-fingerprint"
            )
        )

        viewModel.trackItems.removeLast()
        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(viewModel.hasReferencedSwiftTagDocumentTrackListDifference())
        #expect(metadata.title == "Session.swifttag*")
    }

    @Test
    @MainActor
    func tagEditorViewModelNavigationMetadataAppendsMarkerForTagOnlyReferencedDocumentDifferences() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "navigation-tag-only.flac")
        let track = try Self.bookmarkBackedTrack(
            fileURL: fileURL,
            tags: [TagKey.title: "Original Title", TagKey.filename: fileURL.lastPathComponent],
            fingerprint: Self.fixtureFingerprint
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.rememberSwiftTagDocumentSave(
            SwiftTagDocumentSaveResult(
                destinationURL: URL(fileURLWithPath: "/tmp/Session.swifttag"),
                documentID: UUID(),
                fingerprint: "document-fingerprint"
            )
        )

        viewModel.trackItems[0].tags[TagKey.title] = "Changed Title"
        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(!viewModel.hasReferencedSwiftTagDocumentTrackListDifference())
        #expect(viewModel.hasReferencedSwiftTagDocumentEditStateDifference())
        #expect(metadata.title == "Session.swifttag*")
    }

    @Test
    @MainActor
    func tagEditorViewModelNavigationMetadataAppendsMarkerForPictureOnlyReferencedDocumentDifferences() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "navigation-picture-only.flac")
        let originalPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Original",
            data: try Self.pngData(color: .systemPink)
        )
        let changedPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Changed",
            data: try Self.pngData(color: .systemBlue)
        )
        let bookmarkData = try fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let track = Track(
            tags: [TagKey.title: "Track", TagKey.filename: fileURL.lastPathComponent],
            flacPictureRecords: [originalPicture],
            sourceFileURL: fileURL,
            securityScopedBookmarkData: bookmarkData,
            fingerprint: Self.fixtureFingerprint
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.rememberSwiftTagDocumentSave(
            SwiftTagDocumentSaveResult(
                destinationURL: URL(fileURLWithPath: "/tmp/Session.swifttag"),
                documentID: UUID(),
                fingerprint: "document-fingerprint"
            )
        )

        viewModel.trackItems[0].flacPictureRecords = [changedPicture]
        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(!viewModel.hasReferencedSwiftTagDocumentTrackListDifference())
        #expect(viewModel.hasReferencedSwiftTagDocumentEditStateDifference())
        #expect(metadata.title == "Session.swifttag*")
    }

    @Test
    @MainActor
    func tagEditorViewModelRememberSwiftTagDocumentSaveClearsEditStateMarkerWithoutClearingFlacDirtyState() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "navigation-save-document-clears-marker.flac")
        let latestSnapshot = TrackFileSnapshot(
            tags: [TagKey.title: "Original Title"],
            picturesByType: [:],
            pictureRecords: [],
            fingerprint: Self.fixtureFingerprint
        )
        let bookmarkData = try fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let track = Track(
            tags: [TagKey.title: "Original Title", TagKey.filename: fileURL.lastPathComponent],
            sourceFileURL: fileURL,
            securityScopedBookmarkData: bookmarkData,
            latestFileSnapshot: latestSnapshot,
            fingerprint: Self.fixtureFingerprint
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.rememberSwiftTagDocumentSave(
            SwiftTagDocumentSaveResult(
                destinationURL: URL(fileURLWithPath: "/tmp/Session.swifttag"),
                documentID: UUID(),
                fingerprint: "document-fingerprint-a"
            )
        )

        viewModel.trackItems[0].tags[TagKey.title] = "Changed Title"
        #expect(viewModel.hasReferencedSwiftTagDocumentEditStateDifference())
        #expect(viewModel.editorDifferenceCounts(
            for: Set(viewModel.trackItems.map(\.id)),
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        ).tagEdits == 1)

        viewModel.rememberSwiftTagDocumentSave(
            SwiftTagDocumentSaveResult(
                destinationURL: URL(fileURLWithPath: "/tmp/Session.swifttag"),
                documentID: UUID(),
                fingerprint: "document-fingerprint-b"
            )
        )
        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(!viewModel.hasReferencedSwiftTagDocumentEditStateDifference())
        #expect(metadata.title == "Session.swifttag")
        #expect(viewModel.editorDifferenceCounts(
            for: Set(viewModel.trackItems.map(\.id)),
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        ).tagEdits == 1)
    }

    @Test
    @MainActor
    func tagEditorViewModelReferencedDocumentTrackListBaselineUsesMostRecentBookmarkResolvedURLAfterRename() throws {
        let originalURL = try Self.tempFixtureCopyURL(name: "track-list-rename-source.flac")
        let track = try Self.bookmarkBackedTrack(
            fileURL: originalURL,
            tags: [TagKey.title: "Original", TagKey.filename: originalURL.lastPathComponent],
            fingerprint: Self.fixtureFingerprint
        )
        let renamedURL = originalURL.deletingLastPathComponent().appendingPathComponent("track-list-rename-target.flac")
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.rememberSwiftTagDocumentSave(
            SwiftTagDocumentSaveResult(
                destinationURL: URL(fileURLWithPath: "/tmp/Session.swifttag"),
                documentID: UUID(),
                fingerprint: "document-fingerprint-a"
            )
        )

        try FileManager.default.moveItem(at: originalURL, to: renamedURL)

        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(!viewModel.hasReferencedSwiftTagDocumentTrackListDifference())
        #expect(metadata.title == "Session.swifttag")
    }

    @Test
    @MainActor
    func tagEditorViewModelRememberSwiftTagDocumentSaveRefreshesReferencedDocumentTrackListBaseline() throws {
        let firstURL = try Self.tempFixtureCopyURL(name: "track-list-baseline-first.flac")
        let secondURL = try Self.tempFixtureCopyURL(name: "track-list-baseline-second.flac")
        let firstTrack = try Self.bookmarkBackedTrack(
            fileURL: firstURL,
            tags: [TagKey.title: "First", TagKey.filename: firstURL.lastPathComponent],
            fingerprint: Self.fixtureFingerprint
        )
        let secondTrack = try Self.bookmarkBackedTrack(
            fileURL: secondURL,
            tags: [TagKey.title: "Second", TagKey.filename: secondURL.lastPathComponent],
            fingerprint: Self.fixtureFingerprint
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [firstTrack]
        viewModel.rememberSwiftTagDocumentSave(
            SwiftTagDocumentSaveResult(
                destinationURL: URL(fileURLWithPath: "/tmp/Session.swifttag"),
                documentID: UUID(),
                fingerprint: "document-fingerprint-a"
            )
        )

        viewModel.trackItems.append(secondTrack)
        #expect(viewModel.hasReferencedSwiftTagDocumentTrackListDifference())

        viewModel.rememberSwiftTagDocumentSave(
            SwiftTagDocumentSaveResult(
                destinationURL: URL(fileURLWithPath: "/tmp/Session.swifttag"),
                documentID: UUID(),
                fingerprint: "document-fingerprint-b"
            )
        )

        #expect(!viewModel.hasReferencedSwiftTagDocumentTrackListDifference())
    }

    @Test
    @MainActor
    func tagEditorViewModelNavigationMetadataSubtitleReportsLoadedSelectedAndUnsavedCounts() {
        let deletedTagTrack = Track(
            tags: [
                TagKey.album: "Album",
                TagKey.title: "Original Title",
                TagKey.filename: "changed.flac"
            ],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Current", data: Data([0x01]))
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/changed.flac")
        )
        let pictureChangedTrack = Track(
            tags: [
                TagKey.album: "Album",
                TagKey.title: "Picture Changed",
                TagKey.filename: "picture.flac"
            ],
            flacPictureRecords: [
                FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Snapshot", data: Data([0x03]))
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/picture.flac")
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [deletedTagTrack, pictureChangedTrack]
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        viewModel.trackItems[0].tags[TagKey.title] = "Changed Title"
        viewModel.trackItems[0].externalDifferences = TrackExternalDifferences(
            isDeleted: true,
            fileValuesByTag: [:],
            hasPictureDifference: false
        )
        viewModel.trackItems[1].flacPictureRecords = [
            FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Current", data: Data([0x02]))
        ]
        viewModel.selectedTrackIDs = [deletedTagTrack.id]

        let metadata = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(metadata.subtitle == "Tracks: 2 (1) • Tag Δ: 1 (1) • Picture Δ: 1 (0)")
    }

    @Test
    @MainActor
    func contentViewNavigationMetadataUsesViewModelDerivationSeam() {
        let track = Track(
            album: "Content Album",
            tags: [
                TagKey.album: "Content Album",
                TagKey.title: "Track",
                TagKey.filename: "content.flac"
            ],
            sourceFileURL: URL(fileURLWithPath: "/tmp/content.flac")
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]
        let expected = viewModel.editorNavigationMetadata(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let sut = ContentView(
            sessionValue: .constant(EditorSessionValue()),
            viewModel: viewModel,
            albumArtViewModel: AlbumArtViewModel()
        )

        #expect(sut.navigationMetadata.title == expected.title)
        #expect(sut.navigationMetadata.subtitle == expected.subtitle)
        #expect(sut.navigationMetadata.documentURL == expected.documentURL)
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
    func tagEditorViewModelTreatsCommentAsExplicitCoreTag() throws {
        let track = Track(
            tags: [
                TagKey.title: "One",
                TagKey.filename: "one.flac",
                TagKey.comment: "Legacy Misc Comment",
                "ENCODED_BY": "Tester"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]
        viewModel.reloadMiscTagRowsFromSelection()

        let miscKeys = Set(viewModel.miscTagRows.map { viewModel.normalizedTagKey($0.key) })
        #expect(viewModel.isExplicitTagKey(TagKey.comment))
        #expect(!miscKeys.contains(TagKey.comment))
        #expect(miscKeys.contains("ENCODED_BY"))

        let commentBinding = try #require(viewModel.selectedTagBinding(tagName: TagKey.comment))
        #expect(commentBinding.wrappedValue == "Legacy Misc Comment")

        commentBinding.wrappedValue = "Edited Comment"

        #expect(viewModel.trackItems[0].tags[TagKey.comment] == "Edited Comment")
    }

    @Test
    @MainActor
    func tagEditorViewModelMiscTagsClearValuesWhenSelectionIsEmpty() throws {
        let track = Track(
            tags: [
                TagKey.title: "One",
                TagKey.filename: "one.flac",
                "ENCODED_BY": "Tester"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]
        viewModel.reloadMiscTagRowsFromSelection()

        let selectedRow = try #require(viewModel.miscTagRows.first { $0.key == "ENCODED_BY" })
        #expect(selectedRow.value == "Tester")

        viewModel.selectedTrackIDs = []
        viewModel.reloadMiscTagRowsFromSelection()

        let deselectedRow = try #require(viewModel.miscTagRows.first { $0.key == "ENCODED_BY" })
        #expect(deselectedRow.value == "")
    }

    @Test
    @MainActor
    func reloadTracksWithDifferencesRestoresMiscTagRowsFromSelectedFile() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "misc-tag-reload.flac")
        let viewModel = TagEditorViewModel()

        try await viewModel.importFlacFiles([fileURL])
        let trackID = try #require(viewModel.trackItems.first?.id)
        viewModel.selectedTrackIDs = [trackID]
        viewModel.reloadMiscTagRowsFromSelection()

        let rowID = try #require(viewModel.miscTagRows.first(where: { $0.key == "ENCODED_BY" })?.id)
        let valueBinding = try #require(viewModel.miscTagValueBinding(for: rowID))
        #expect(valueBinding.wrappedValue == "Test Encoded_By")

        valueBinding.wrappedValue = "Edited Encoded By"
        try viewModel.reloadTracksWithDifferences(
            in: [trackID],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let reloadedValueRow = try #require(viewModel.miscTagRows.first { $0.key == "ENCODED_BY" })
        #expect(viewModel.trackItems[0].tags["ENCODED_BY"] == "Test Encoded_By")
        #expect(reloadedValueRow.value == "Test Encoded_By")

        viewModel.selectedMiscTagRowIDs = [reloadedValueRow.id]
        viewModel.deleteSelectedMiscTagRows()
        #expect(!viewModel.miscTagRows.contains { $0.key == "ENCODED_BY" })

        try viewModel.reloadTracksWithDifferences(
            in: [trackID],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let reloadedDeletedRow = try #require(viewModel.miscTagRows.first { $0.key == "ENCODED_BY" })
        #expect(viewModel.trackItems[0].tags["ENCODED_BY"] == "Test Encoded_By")
        #expect(reloadedDeletedRow.value == "Test Encoded_By")
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
    func tagEditorViewModelMiscTagsRejectsWhitespaceKeyForNewRow() throws {
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
        keyBinding.wrappedValue = "BAD KEY"

        #expect(viewModel.isInvalidMiscTagKeyInput("BAD KEY", for: rowID))

        viewModel.finalizeMiscTagKeyEditing(for: rowID)

        #expect(viewModel.miscTagRows.count == initialCount)
        #expect(viewModel.trackItems[0].tags["BAD KEY"] == nil)
    }

    @Test
    @MainActor
    func tagEditorViewModelAppleScriptRejectsWhitespaceTagKey() {
        let track = Track(
            tags: [
                TagKey.title: "One",
                TagKey.filename: "one.flac"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]

        do {
            try viewModel.appleScriptUpsertTag(key: "ALBUM ARTIST", value: "Artist", forTrackID: track.id)
            Issue.record("Expected AppleScript tag upsert to reject whitespace tag key.")
        } catch let error as SwiftTagAppleScriptCommandError {
            switch error {
            case .invalidTagKey:
                break
            default:
                Issue.record("Unexpected AppleScript error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
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
    func tagEditorViewModelDateDifferencesUseLiteralText() {
        let sameYearTrack = Self.trackWithSnapshot(
            tags: [
                TagKey.title: "Same Year",
                TagKey.date: "2026"
            ],
            fileTags: [
                TagKey.title: "Same Year",
                TagKey.date: "2026"
            ]
        )
        let expandedYearTrack = Self.trackWithSnapshot(
            tags: [
                TagKey.title: "Expanded Year",
                TagKey.date: "2026-01-01"
            ],
            fileTags: [
                TagKey.title: "Expanded Year",
                TagKey.date: "2026"
            ]
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [sameYearTrack, expandedYearTrack]
        let dateOnlyTagWriteOptions = TagWriteOptions(
            zeroPadTrackNumber: false,
            trackCountKeyStrategy: .none,
            zeroPadDiscNumber: false,
            discCountKeyStrategy: .none
        )

        #expect(!viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.date], in: [sameYearTrack.id]))
        #expect(viewModel.editorDifferenceCounts(
            for: [sameYearTrack.id],
            tagWriteOptions: dateOnlyTagWriteOptions,
            albumArtPictures: []
        ).tagEdits == 0)

        #expect(viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.date], in: [expandedYearTrack.id]))
        #expect(viewModel.editorDifferenceCounts(
            for: [expandedYearTrack.id],
            tagWriteOptions: dateOnlyTagWriteOptions,
            albumArtPictures: []
        ).tagEdits == 1)
        #expect(viewModel.hasTrackToTrackDifference(
            forAnyOf: [TagKey.date],
            in: [sameYearTrack.id, expandedYearTrack.id]
        ))
    }

    @Test
    @MainActor
    func tagEditorViewModelDoesNotDirtyTotalCountTagAliasStrategyChanges() {
        let track = Track(
            tags: [
                TagKey.title: "Title",
                TagKey.trackNumber: "1",
                TagKey.discNumber: "1",
                "TOTALTRACKS": "7",
                "TOTALDISCS": "2"
            ],
            latestFileSnapshot: TrackFileSnapshot(
                tags: [
                    TagKey.title: "Title",
                    TagKey.trackNumber: "1",
                    TagKey.discNumber: "1",
                    "TRACKTOTAL": "7",
                    "DISCTOTAL": "2"
                ],
                picturesByType: [:]
            )
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        let tagWriteOptions = TagWriteOptions(
            zeroPadTrackNumber: false,
            trackCountKeyStrategy: .both,
            zeroPadDiscNumber: false,
            discCountKeyStrategy: .both
        )

        let differences = viewModel.editorDifferenceCounts(
            for: [track.id],
            tagWriteOptions: tagWriteOptions,
            albumArtPictures: []
        )

        #expect(differences.tagEdits == 0)
        #expect(!viewModel.hasDifferences(
            in: [track.id],
            tagWriteOptions: tagWriteOptions,
            albumArtPictures: []
        ))
        #expect(!viewModel.hasTrackToFileDifference(forAnyOf: ["TOTALTRACKS", "TRACKTOTAL"], in: [track.id]))
        #expect(!viewModel.hasTrackToFileDifference(forAnyOf: ["TOTALDISCS", "DISCTOTAL"], in: [track.id]))
    }

    @Test
    @MainActor
    func tagEditorViewModelDirtiesTotalCountGroupsOnlyForValueOrPresenceChanges() {
        let changedValueTrack = Track(
            totalTracks: "8",
            tags: [
                TagKey.title: "Changed Value",
                "TOTALTRACKS": "7",
                "TOTALDISCS": "2"
            ],
            latestFileSnapshot: TrackFileSnapshot(
                tags: [
                    TagKey.title: "Changed Value",
                    "TOTALTRACKS": "7",
                    "TOTALDISCS": "2"
                ],
                picturesByType: [:]
            )
        )
        let missingInFileTrack = Track(
            totalTracks: "7",
            tags: [
                TagKey.title: "Missing In File",
                "TOTALTRACKS": "7"
            ],
            latestFileSnapshot: TrackFileSnapshot(
                tags: [
                    TagKey.title: "Missing In File"
                ],
                picturesByType: [:]
            )
        )
        let removedOnSaveTrack = Track(
            totalTracks: "7",
            tags: [
                TagKey.title: "Removed On Save",
                "TOTALTRACKS": "7",
                "TOTALDISCS": "2"
            ],
            latestFileSnapshot: TrackFileSnapshot(
                tags: [
                    TagKey.title: "Removed On Save",
                    "TRACKTOTAL": "7",
                    "DISCTOTAL": "2"
                ],
                picturesByType: [:]
            )
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [changedValueTrack, missingInFileTrack, removedOnSaveTrack]
        let writeCountsOptions = TagWriteOptions(
            zeroPadTrackNumber: false,
            trackCountKeyStrategy: .totalTracks,
            zeroPadDiscNumber: false,
            discCountKeyStrategy: .totalDiscs
        )
        let removeCountsOptions = TagWriteOptions(
            zeroPadTrackNumber: false,
            trackCountKeyStrategy: .none,
            zeroPadDiscNumber: false,
            discCountKeyStrategy: .none
        )

        #expect(viewModel.editorDifferenceCounts(
            for: [changedValueTrack.id],
            tagWriteOptions: writeCountsOptions,
            albumArtPictures: []
        ).tagEdits == 1)
        #expect(viewModel.editorDifferenceCounts(
            for: [missingInFileTrack.id],
            tagWriteOptions: writeCountsOptions,
            albumArtPictures: []
        ).tagEdits == 1)
        #expect(viewModel.editorDifferenceCounts(
            for: [removedOnSaveTrack.id],
            tagWriteOptions: removeCountsOptions,
            albumArtPictures: []
        ).tagEdits == 1)
    }

    @Test
    @MainActor
    func tagEditorViewModelExcludesTotalCountAliasesFromMiscTags() {
        let track = Track(tags: [
            TagKey.title: "Title",
            "TRACKTOTAL": "7",
            "TOTALTRACKS": "7",
            "DISCTOTAL": "2",
            "TOTALDISCS": "2",
            "CUSTOM": "Value"
        ])

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]
        viewModel.reloadMiscTagRowsFromSelection()

        let miscKeys = Set(viewModel.miscTagRows.map { viewModel.normalizedTagKey($0.key) })
        #expect(miscKeys.contains("CUSTOM"))
        #expect(!miscKeys.contains("TRACKTOTAL"))
        #expect(!miscKeys.contains("TOTALTRACKS"))
        #expect(!miscKeys.contains("DISCTOTAL"))
        #expect(!miscKeys.contains("TOTALDISCS"))
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
                TagKey.date: "2026-03",
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

        let selectedDateBinding = try #require(viewModel.selectedDateTextBinding())
        #expect(selectedDateBinding.wrappedValue == "2026-03")

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
    func tagEditorViewModelStatusPresentationUsesWarningForExternalPictureDifferences() {
        let viewModel = TagEditorViewModel()
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
            fileValuesByTag: [:],
            hasPictureDifference: true,
            externallyModifiedPictureTypes: [3]
        )
        viewModel.trackItems = [track]

        let presentation = viewModel.trackStatusPresentation(
            for: track.id,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(presentation?.systemImageName == "exclamationmark.triangle")
    }

    @Test
    @MainActor
    func tagEditorViewModelStatusPresentationUsesFishForInternalPictureDescriptionEdits() throws {
        let pictureData = try Self.pngData(color: .systemOrange)
        let originalRecords = [
            FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Original", data: pictureData)
        ]
        let updatedRecords = [
            FlacWritablePictureRecord(type: 3, mimeType: "image/png", description: "Edited", data: pictureData)
        ]

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                tags: [
                    TagKey.title: "Track",
                    TagKey.trackNumber: "1",
                    TagKey.discNumber: "1",
                    TagKey.filename: "internal-picture-description-status.flac"
                ],
                flacPictureRecords: originalRecords,
                sourceFileURL: URL(fileURLWithPath: "/tmp/internal-picture-description-status.flac")
            )
        ]

        let trackID = try #require(viewModel.trackItems.first?.id)
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        viewModel.setPictureRecordsByTrackID(
            [trackID: updatedRecords],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let differences = try #require(viewModel.trackItems.first?.externalDifferences)
        #expect(differences.hasPictureDifference)
        #expect(!differences.hasExternallyModifiedPictureDifference)

        let presentation = viewModel.trackStatusPresentation(
            for: trackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(presentation?.systemImageName == "fish")
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
        let differences = viewModel.editorDifferenceCounts(
            for: [trackID],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )
        #expect(differences.tagEdits == 0)
        #expect(differences.pictureEdits == 0)
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
    func tagEditorViewModelReloadTracksWithDifferencesRestoresSyncedStatusPresentation() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "reload-status-source.flac")

        let viewModel = TagEditorViewModel()
        try await viewModel.importFlacFiles([fileURL], locked: false)

        let trackID = try #require(viewModel.trackItems.first?.id)
        let pictureRecords = try #require(viewModel.trackItems.first?.flacPictureRecords)
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: pictureRecords
        )

        let cleanPresentation = viewModel.trackStatusPresentation(
            for: trackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: pictureRecords
        )
        #expect(cleanPresentation?.systemImageName == "fish.fill")

        viewModel.trackItems[0].tags[TagKey.title] = "Edited Title"

        let dirtyPresentation = viewModel.trackStatusPresentation(
            for: trackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: pictureRecords
        )
        #expect(dirtyPresentation?.systemImageName == "fish")

        try viewModel.reloadTracksWithDifferences(
            in: [trackID],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: pictureRecords
        )

        let presentation = viewModel.trackStatusPresentation(
            for: trackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: pictureRecords
        )
        #expect(presentation?.systemImageName == "fish.fill")
        #expect(viewModel.trackItems[0].externalDifferences == nil)
        #expect(viewModel.trackItems[0].tags[TagKey.title] != "Edited Title")
    }

    @Test
    @MainActor
    func tagEditorViewModelAddImportKeepsExistingDirtyTrackStatusWhileCleaningNewTrack() async throws {
        let firstURL = try Self.tempFixtureCopyURL(name: "append-dirty-existing.flac")
        let secondURL = try Self.tempFixtureCopyURL(name: "append-clean-new.flac")

        let viewModel = TagEditorViewModel()
        try await viewModel.importFlacFiles([firstURL], locked: false)
        viewModel.syncCurrentStateAsSaved(
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        let originalTrackID = try #require(viewModel.trackItems.first?.id)
        viewModel.trackItems[0].tags[TagKey.title] = "Edited Existing Track"

        let dirtyBeforeAdd = viewModel.trackStatusPresentation(
            for: originalTrackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        #expect(dirtyBeforeAdd?.systemImageName == "fish")

        let existingTrackIDs = Set(viewModel.trackItems.map(\.id))
        try await viewModel.importFlacFiles([secondURL], locked: false, append: true)
        let importedTrackIDs = Set(viewModel.trackItems.map(\.id)).subtracting(existingTrackIDs)
        let addedTrackID = try #require(importedTrackIDs.first)

        viewModel.syncCurrentStateAsSaved(
            for: importedTrackIDs,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        #expect(
            viewModel.hasDifferences(
                in: [originalTrackID],
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: []
            )
        )

        let dirtyAfterAdd = viewModel.trackStatusPresentation(
            for: originalTrackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        #expect(dirtyAfterAdd?.systemImageName == "fish")

        let addedTrackPresentation = viewModel.trackStatusPresentation(
            for: addedTrackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )
        #expect(addedTrackPresentation?.systemImageName == "fish.fill")
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
        viewModel.album = "Rewrite Album Updated"

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
    func trackFileMonitorSamePathRewriteContinuesObservingFutureChanges() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "rewrite-monitor-source.flac")
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
        viewModel.album = metadata.tags[TagKey.album] ?? ""
        viewModel.albumArtist = metadata.tags[TagKey.albumArtist] ?? ""
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

        @MainActor
        func onChange(_ event: TrackFileMonitorEvent) {
            viewModel.refreshTrackFileState(
                for: event.trackID,
                currentPath: event.currentPath,
                tagWriteOptions: Self.defaultTagWriteOptions,
                albumArtPictures: albumArtPictures
            )
            monitor.replaceObservations(for: viewModel.trackItems, onChange: onChange)
        }

        monitor.replaceObservations(for: viewModel.trackItems, onChange: onChange)

        let firstAlbum = "Rewrite Monitor First \(UUID().uuidString)"
        let secondAlbum = "Rewrite Monitor Second \(UUID().uuidString)"

        var firstTags = metadata.tags
        firstTags[TagKey.album] = firstAlbum
        let usedTempRewriteForFirstSave = try FlacMetadataService.writeMetadata(
            tags: firstTags,
            to: fileURL,
            writeTags: true,
            writePictures: false
        )
        #expect(usedTempRewriteForFirstSave)

        let firstObserved = await Self.waitUntil {
            viewModel.trackItems.first?.externalDifferences?.fileValuesByTag[TagKey.album] == firstAlbum
        }
        #expect(firstObserved)
        #expect(!viewModel.hasDeletedFile(for: trackID))

        var secondTags = firstTags
        secondTags[TagKey.album] = secondAlbum
        let usedTempRewriteForSecondSave = try FlacMetadataService.writeMetadata(
            tags: secondTags,
            to: fileURL,
            writeTags: true,
            writePictures: false
        )
        #expect(usedTempRewriteForSecondSave)

        let secondObserved = await Self.waitUntil {
            viewModel.trackItems.first?.externalDifferences?.fileValuesByTag[TagKey.album] == secondAlbum
        }
        #expect(secondObserved)
        #expect(!viewModel.hasDeletedFile(for: trackID))
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
        @MainActor
        func onChange(_ event: TrackFileMonitorEvent) {
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
        let firstDifferences = viewModel.editorDifferenceCounts(
            for: [trackID],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )
        #expect(firstDifferences.tagEdits == 0)
        #expect(firstDifferences.pictureEdits == 0)
        #expect(!sawDeleted)

        let secondRenamedURL = firstRenamedURL.deletingLastPathComponent().appendingPathComponent("rename-monitor-second.flac")
        try FileManager.default.moveItem(at: firstRenamedURL, to: secondRenamedURL)

        let secondRenameObserved = await Self.waitUntil {
            viewModel.trackItems.first?.sourceFileURL?.path == secondRenamedURL.path
        }
        #expect(secondRenameObserved)
        #expect(viewModel.trackItems.first?.tags[TagKey.filename] == secondRenamedURL.lastPathComponent)
        #expect(!viewModel.hasDeletedFile(for: trackID))
        let secondDifferences = viewModel.editorDifferenceCounts(
            for: [trackID],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: albumArtPictures
        )
        #expect(secondDifferences.tagEdits == 0)
        #expect(secondDifferences.pictureEdits == 0)
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

        @MainActor
        func onChange(_ event: TrackFileMonitorEvent) {
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
    @MainActor
    func tagEditorViewModelClassifiesInternalPictureDescriptionEditsWithoutExternalOverlay() {
        let originalData = Data([0x01, 0x02, 0x03])
        let originalPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Original Description",
            data: originalData
        )
        let updatedPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Edited Description",
            data: originalData
        )
        let trackID = UUID()

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                id: trackID,
                tags: [TagKey.title: "Title", TagKey.filename: "test.flac"],
                flacPictureRecords: [originalPicture],
                latestFileSnapshot: TrackFileSnapshot(
                    tags: [TagKey.title: "Title"],
                    picturesByType: [3: originalData],
                    pictureRecords: [originalPicture]
                )
            )
        ]

        viewModel.setPictureRecordsByTrackID(
            [trackID: [updatedPicture]],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: [updatedPicture]
        )

        #expect(
            viewModel.hasInternalPictureDifference(
                for: 3,
                albumArtPictures: [updatedPicture]
            )
        )
        #expect(
            !viewModel.hasExternalPictureDifference(
                for: 3,
                albumArtPictures: [updatedPicture]
            )
        )
        #expect(viewModel.trackItems[0].externalDifferences?.externallyModifiedPictureTypes.isEmpty == true)
    }

    @Test
    @MainActor
    func tagEditorViewModelClassifiesExternalPictureDescriptionEditsAsOverlayOnly() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "external-picture-description-diff.flac")
        let pictureData = try Self.pngData(color: .magenta)
        let originalPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Original Description",
            data: pictureData
        )
        let updatedPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "External Description",
            data: pictureData
        )

        _ = try FlacMetadataService.writeMetadata(
            pictures: [originalPicture],
            to: fileURL,
            writeTags: false,
            writePictures: true
        )

        let originalRecord = try FlacMetadataService.readTags(for: fileURL)
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                tags: originalRecord.tags,
                flacPictureRecords: [originalPicture],
                sourceFileURL: fileURL,
                latestFileSnapshot: TrackFileSnapshot(
                    tags: originalRecord.tags,
                    picturesByType: [3: pictureData],
                    pictureRecords: [originalPicture]
                )
            )
        ]

        _ = try FlacMetadataService.writeMetadata(
            pictures: [updatedPicture],
            to: fileURL,
            writeTags: false,
            writePictures: true
        )

        let trackID = try #require(viewModel.trackItems.first?.id)
        viewModel.refreshTrackFileState(
            for: trackID,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: [originalPicture]
        )

        #expect(
            viewModel.hasExternalPictureDifference(
                for: 3,
                albumArtPictures: [originalPicture]
            )
        )
        #expect(
            !viewModel.hasInternalPictureDifference(
                for: 3,
                albumArtPictures: [originalPicture]
            )
        )
        #expect(viewModel.trackItems[0].externalDifferences?.externallyModifiedPictureTypes == Set([3]))
    }

    @Test
    func swiftTagDocumentFollowOnSaveDecisionReturnsNoActionWhenAutoSaveIsOff() {
        let action = SwiftTagDocumentFollowOnSaveDecision.resolve(
            isDefaultSaveCommand: true,
            saveReferencedSwiftTagDocument: false,
            askToSaveNewSwiftTagDocument: true,
            askToSaveNewSwiftTagDocumentOk: true,
            hasReferencedSwiftTagDocument: true
        )

        #expect(Self.followOnSaveActionsMatch(action, .none))
    }

    @Test
    func swiftTagDocumentFollowOnSaveDecisionReturnsSaveExistingWhenReferenceExists() {
        let action = SwiftTagDocumentFollowOnSaveDecision.resolve(
            isDefaultSaveCommand: true,
            saveReferencedSwiftTagDocument: true,
            askToSaveNewSwiftTagDocument: false,
            askToSaveNewSwiftTagDocumentOk: true,
            hasReferencedSwiftTagDocument: true
        )

        #expect(Self.followOnSaveActionsMatch(action, .saveReferencedDocument))
    }

    @Test
    func swiftTagDocumentFollowOnSaveDecisionReturnsNoActionWhenAskSettingIsOff() {
        let action = SwiftTagDocumentFollowOnSaveDecision.resolve(
            isDefaultSaveCommand: true,
            saveReferencedSwiftTagDocument: true,
            askToSaveNewSwiftTagDocument: false,
            askToSaveNewSwiftTagDocumentOk: true,
            hasReferencedSwiftTagDocument: false
        )

        #expect(Self.followOnSaveActionsMatch(action, .none))
    }

    @Test
    func swiftTagDocumentFollowOnSaveDecisionReturnsPromptWhenAskSettingAndGateAreOn() {
        let action = SwiftTagDocumentFollowOnSaveDecision.resolve(
            isDefaultSaveCommand: true,
            saveReferencedSwiftTagDocument: true,
            askToSaveNewSwiftTagDocument: true,
            askToSaveNewSwiftTagDocumentOk: true,
            hasReferencedSwiftTagDocument: false
        )

        #expect(Self.followOnSaveActionsMatch(action, .promptForNewDocument))
    }

    @Test
    func swiftTagDocumentFollowOnSaveDecisionReturnsNoActionWhenPromptGateIsOff() {
        let action = SwiftTagDocumentFollowOnSaveDecision.resolve(
            isDefaultSaveCommand: true,
            saveReferencedSwiftTagDocument: true,
            askToSaveNewSwiftTagDocument: true,
            askToSaveNewSwiftTagDocumentOk: false,
            hasReferencedSwiftTagDocument: false
        )

        #expect(Self.followOnSaveActionsMatch(action, .none))
    }

    @Test
    func swiftTagDocumentFollowOnSaveDecisionReturnsNoActionForAlternateSaveCommands() {
        let action = SwiftTagDocumentFollowOnSaveDecision.resolve(
            isDefaultSaveCommand: false,
            saveReferencedSwiftTagDocument: true,
            askToSaveNewSwiftTagDocument: true,
            askToSaveNewSwiftTagDocumentOk: true,
            hasReferencedSwiftTagDocument: true
        )

        #expect(Self.followOnSaveActionsMatch(action, .none))
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
    func flacWriteMapperWritesCompilationAsOneWhenEnabledAndOmitsItWhenDisabled() {
        let enabledTrack = Track(tags: [
            TagKey.title: "Mapped Title",
            TagKey.compilation: "yes"
        ])
        let enabledTags = FlacWriteMapper.makeTags(
            for: enabledTrack,
            album: "Album",
            albumArtist: "Album Artist",
            totalTracks: 3,
            totalDiscs: "1",
            options: Self.defaultTagWriteOptions
        )
        #expect(enabledTags[TagKey.compilation] == "1")

        var disabledSourceTags = [
            TagKey.title: "Mapped Title",
            TagKey.compilation: "1"
        ]
        CompilationTag.setEnabled(false, in: &disabledSourceTags)
        let disabledTrack = Track(tags: disabledSourceTags)
        let disabledTags = FlacWriteMapper.makeTags(
            for: disabledTrack,
            album: "Album",
            albumArtist: "Album Artist",
            totalTracks: 3,
            totalDiscs: "1",
            options: Self.defaultTagWriteOptions
        )
        #expect(disabledTags[TagKey.compilation] == nil)
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
    @MainActor
    func tagEditorViewModelCompilationToggleTreatsTruthyValuesAsOnForDifferences() {
        let track = Self.trackWithSnapshot(
            tags: [
                TagKey.title: "Title",
                TagKey.compilation: "TrUe"
            ],
            fileTags: [
                TagKey.title: "Title",
                TagKey.compilation: "1"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]

        #expect(!viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.compilation]))
        #expect(viewModel.compilationToggleState(applyToAllTracks: false) == .on)
    }

    @Test
    @MainActor
    func tagEditorViewModelCompilationToggleTreatsNonTruthyValuesAsOff() {
        let track = Self.trackWithSnapshot(
            tags: [
                TagKey.title: "Title",
                TagKey.compilation: "0"
            ],
            fileTags: [
                TagKey.title: "Title",
                TagKey.compilation: "1"
            ]
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.selectedTrackIDs = [track.id]

        #expect(viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.compilation]))
        #expect(viewModel.compilationToggleState(applyToAllTracks: false) == .off)
    }

    @Test
    @MainActor
    func tagEditorViewModelCompilationToggleUpdatesOnlySelectedUnlockedTracks() {
        let selectedUnlocked = Track(
            tags: [
                TagKey.title: "Unlocked",
                TagKey.filename: "unlocked.flac"
            ]
        )
        let selectedLocked = Track(
            tags: [
                TagKey.title: "Locked",
                TagKey.filename: "locked.flac"
            ],
            isLocked: true
        )
        let unselectedUnlocked = Track(
            tags: [
                TagKey.title: "Unselected",
                TagKey.filename: "unselected.flac"
            ]
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [selectedUnlocked, selectedLocked, unselectedUnlocked]
        viewModel.selectedTrackIDs = [selectedUnlocked.id, selectedLocked.id]

        viewModel.setCompilationEnabled(true, applyToAllTracks: false)

        #expect(viewModel.trackItems[0].tags[TagKey.compilation] == "1")
        #expect(viewModel.trackItems[1].tags[TagKey.compilation] == nil)
        #expect(viewModel.trackItems[2].tags[TagKey.compilation] == nil)
    }

    @Test
    @MainActor
    func tagEditorViewModelCompilationToggleRetainsSelectedLockedTrackStateWhenReadOnly() {
        let lockedSelected = Track(
            tags: [
                TagKey.title: "Locked On",
                TagKey.filename: "locked-on.flac",
                TagKey.compilation: "YES"
            ],
            isLocked: true
        )
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [lockedSelected]
        viewModel.selectedTrackIDs = [lockedSelected.id]

        #expect(!viewModel.canEditCompilation(applyToAllTracks: false))
        #expect(viewModel.compilationToggleState(applyToAllTracks: false) == .on)
        #expect(viewModel.compilationTrackIDs(applyToAllTracks: false) == [lockedSelected.id])
    }

    @Test
    @MainActor
    func tagEditorViewModelCompilationToggleAppliesToAllUnlockedTracksWithoutSelection() {
        let unlockedOff = Track(
            tags: [
                TagKey.title: "Unlocked Off",
                TagKey.filename: "unlocked-off.flac"
            ]
        )
        let unlockedOn = Track(
            tags: [
                TagKey.title: "Unlocked On",
                TagKey.filename: "unlocked-on.flac",
                TagKey.compilation: "YES"
            ]
        )
        let lockedOff = Track(
            tags: [
                TagKey.title: "Locked Off",
                TagKey.filename: "locked-off.flac"
            ],
            isLocked: true
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [unlockedOff, unlockedOn, lockedOff]

        #expect(viewModel.canEditCompilation(applyToAllTracks: true))
        #expect(viewModel.compilationToggleState(applyToAllTracks: true) == .mixed)

        viewModel.setCompilationEnabled(true, applyToAllTracks: true)

        #expect(viewModel.trackItems[0].tags[TagKey.compilation] == "1")
        #expect(viewModel.trackItems[1].tags[TagKey.compilation] == "1")
        #expect(viewModel.trackItems[2].tags[TagKey.compilation] == nil)
        #expect(viewModel.compilationToggleState(applyToAllTracks: true) == .on)
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
    func flacMetadataServiceConvertsNonJPEGPNGPictureToPNGBeforeWrite() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "write-picture-tiff-convert.flac")
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.systemTeal.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation else {
            Issue.record("Failed to create TIFF test data")
            return
        }

        _ = try FlacMetadataService.writeMetadata(
            pictures: [
                FlacWritablePictureRecord(
                    type: 3,
                    mimeType: "image/tiff",
                    description: "Cover (front)",
                    data: tiffData
                )
            ],
            to: fileURL,
            writeTags: false,
            writePictures: true
        )

        let rewrittenRecord = try FlacMetadataService.readTags(for: fileURL)
        #expect(rewrittenRecord.pictures.count == 1)
        #expect(rewrittenRecord.pictures.first?.mimeType == "image/png")
        #expect(NSImage(data: try #require(rewrittenRecord.pictures.first?.data)) != nil)
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
    func flacMetadataServiceRejectsMultipleTypeTwoPictures() throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "write-type2-multiple.flac")
        let firstIcon = try Self.pngData(color: .black)
        let secondIcon = try Self.jpegData(color: .white)

        do {
            try FlacMetadataService.writeMetadata(
                pictures: [
                    FlacWritablePictureRecord(
                        type: 2,
                        mimeType: "image/png",
                        description: "Icon 1",
                        data: firstIcon
                    ),
                    FlacWritablePictureRecord(
                        type: 2,
                        mimeType: "image/jpeg",
                        description: "Icon 2",
                        data: secondIcon
                    )
                ],
                to: fileURL,
                writeTags: false,
                writePictures: true
            )
            Issue.record("Expected duplicate type 2 picture write to fail.")
        } catch let error as FlacMetadataServiceError {
            switch error {
            case let .bridgeFailed(message):
                #expect(message == "FLAC picture type 2 allows only a single icon per file.")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
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

        let unselectedRecord = try FlacMetadataService.readTags(for: unselectedFileURL)
        #expect(unselectedRecord.tags["ALBUM"] == "Test Album")
        #expect(unselectedRecord.tags[TagKey.title] == "Test Title")
        #expect(unselectedRecord.tags[TagKey.trackNumber] == "01")
    }

    @Test
    @MainActor
    func tagEditorViewModelSaveSynchronouslyWritesTagsToSelectedImportedTrackOnly() throws {
        let selectedFileURL = try Self.tempFixtureCopyURL(name: "selected-sync-save.flac")
        let unselectedFileURL = try Self.tempFixtureCopyURL(name: "unselected-sync-save.flac")
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
        viewModel.album = "Saved Sync Album"
        viewModel.albumArtist = "Saved Sync Album Artist"
        viewModel.trackItems = [selectedTrack, unselectedTrack]
        viewModel.selectedTrackIDs = [selectedTrack.id]

        _ = try viewModel.saveSynchronously(
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
        #expect(selectedRecord.tags["ALBUM"] == "Saved Sync Album")
        #expect(selectedRecord.tags["ALBUMARTIST"] == "Saved Sync Album Artist")
        #expect(selectedRecord.tags[TagKey.title] == "Selected Title")

        let unselectedRecord = try FlacMetadataService.readTags(for: unselectedFileURL)
        #expect(unselectedRecord.tags["ALBUM"] == "Test Album")
        #expect(unselectedRecord.tags[TagKey.title] == "Test Title")
    }

    @Test
    @MainActor
    func tagEditorViewModelSaveWritesPicturesWithoutChangingTags() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "viewmodel-write-pictures.flac")
        let originalRecord = try FlacMetadataService.readTags(for: fileURL)
        let pictureData = try Self.pngData(color: .purple)
        let updatedPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Cover (front)",
            data: pictureData
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                tags: [
                    TagKey.title: originalRecord.tags[TagKey.title] ?? "",
                    TagKey.trackNumber: originalRecord.tags[TagKey.trackNumber] ?? "",
                    TagKey.discNumber: originalRecord.tags[TagKey.discNumber] ?? ""
                ],
                flacPictureRecords: [updatedPicture],
                sourceFileURL: fileURL
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
            albumArtPictures: [updatedPicture],
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
    func tagEditorViewModelSavePicturesPersistsDescriptionOnlyPictureEdits() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "viewmodel-write-picture-description.flac")
        let pictureData = try Self.pngData(color: .green)
        let originalPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Original Description",
            data: pictureData
        )
        let updatedPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Edited Description",
            data: pictureData
        )

        _ = try FlacMetadataService.writeMetadata(
            pictures: [originalPicture],
            to: fileURL,
            writeTags: false,
            writePictures: true
        )

        let originalRecord = try FlacMetadataService.readTags(for: fileURL)
        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [
            Track(
                tags: originalRecord.tags,
                flacPictureRecords: [updatedPicture],
                sourceFileURL: fileURL,
                latestFileSnapshot: TrackFileSnapshot(
                    tags: originalRecord.tags,
                    picturesByType: [3: pictureData],
                    pictureRecords: [originalPicture]
                )
            )
        ]

        _ = try await viewModel.save(
            payload: .writePictures,
            scope: .allTracks,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: [updatedPicture],
            editorSessionID: UUID()
        )

        let rewrittenRecord = try FlacMetadataService.readTags(for: fileURL)
        #expect(rewrittenRecord.pictures.first?.description == "Edited Description")
    }

    @Test
    @MainActor
    func tagEditorViewModelSaveTagsLeavesDescriptionOnlyPictureEditsUnsaved() async throws {
        let fileURL = try Self.tempFixtureCopyURL(name: "viewmodel-tag-save-keeps-picture-description.flac")
        let pictureData = try Self.pngData(color: .cyan)
        let originalPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Original Description",
            data: pictureData
        )
        let updatedPicture = FlacWritablePictureRecord(
            type: 3,
            mimeType: "image/png",
            description: "Edited Description",
            data: pictureData
        )

        _ = try FlacMetadataService.writeMetadata(
            pictures: [originalPicture],
            to: fileURL,
            writeTags: false,
            writePictures: true
        )

        let originalRecord = try FlacMetadataService.readTags(for: fileURL)
        let track = Track(
            tags: originalRecord.tags,
            flacPictureRecords: [updatedPicture],
            sourceFileURL: fileURL,
            latestFileSnapshot: TrackFileSnapshot(
                tags: originalRecord.tags,
                picturesByType: [3: pictureData],
                pictureRecords: [originalPicture]
            )
        )

        let viewModel = TagEditorViewModel()
        viewModel.trackItems = [track]
        viewModel.trackItems[0].album = "Tag Only Description Test"

        _ = try await viewModel.save(
            payload: .writeTags,
            scope: .allTracks,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: [updatedPicture],
            editorSessionID: UUID()
        )

        let rewrittenRecord = try FlacMetadataService.readTags(for: fileURL)
        let differences = viewModel.editorDifferenceCounts(
            for: [track.id],
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: [updatedPicture]
        )

        #expect(rewrittenRecord.tags["ALBUM"] == "Tag Only Description Test")
        #expect(rewrittenRecord.pictures.first?.description == "Original Description")
        #expect(differences.tagEdits == 0)
        #expect(differences.pictureEdits == 1)
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
    func tagEditorViewModelRefreshAfterSavedAlbumEditKeepsUnsavedAlbumEditInternal() async throws {
        let firstFileURL = try Self.tempFixtureCopyURL(name: "saved-edit-refresh-first.flac")
        let secondFileURL = try Self.tempFixtureCopyURL(name: "saved-edit-refresh-second.flac")
        let viewModel = TagEditorViewModel()

        try await viewModel.importFlacFiles([firstFileURL, secondFileURL])
        let firstTrack = try #require(viewModel.trackItems.first)
        let secondTrack = try #require(viewModel.trackItems.dropFirst().first)
        viewModel.selectedTrackIDs = [firstTrack.id]

        let albumBinding = try #require(viewModel.selectedAlbumBinding())
        albumBinding.wrappedValue = "Saved Album Before Refresh"
        _ = try await viewModel.save(
            payload: .writeTags,
            scope: .selectedTracks,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: [],
            editorSessionID: UUID()
        )

        albumBinding.wrappedValue = "Unsaved Album After Save"
        #expect(viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.album], in: [firstTrack.id]))
        #expect(!viewModel.hasExternalDifference(forAnyOf: [TagKey.album], in: [firstTrack.id]))

        viewModel.selectedTrackIDs = [secondTrack.id]
        viewModel.reloadMiscTagRowsFromSelection()
        viewModel.trackItems[0].fingerprint = "stale"
        viewModel.refreshTrackFileState(
            for: firstTrack.id,
            currentPath: firstFileURL.path,
            tagWriteOptions: Self.defaultTagWriteOptions,
            albumArtPictures: []
        )

        viewModel.selectedTrackIDs = [firstTrack.id]
        #expect(viewModel.trackItems[0].fingerprint != "stale")
        #expect(viewModel.hasTrackToFileDifference(forAnyOf: [TagKey.album], in: [firstTrack.id]))
        #expect(!viewModel.hasExternalDifference(forAnyOf: [TagKey.album], in: [firstTrack.id]))
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
    func tagEditorViewModelSaveSkipsUnchangedFiles() async throws {
        let changedFileURL = try Self.tempFixtureCopyURL(name: "save-changed.flac")
        let unchangedFileURL = try Self.tempFixtureCopyURL(name: "save-unchanged.flac")

        let viewModel = TagEditorViewModel()
        try await viewModel.importFlacFiles([changedFileURL, unchangedFileURL])
        let saveOptions = TagWriteOptions(
            zeroPadTrackNumber: true,
            trackCountKeyStrategy: .none,
            zeroPadDiscNumber: true,
            discCountKeyStrategy: .none
        )
        viewModel.syncCurrentStateAsSaved(tagWriteOptions: saveOptions, albumArtPictures: [])
        let changedTrack = try #require(viewModel.trackItems.first(where: { $0.sourceFileURL?.path == changedFileURL.path }))
        let changedTitleBinding = try #require(viewModel.tagBinding(for: changedTrack.id, tagName: TagKey.title))
        changedTitleBinding.wrappedValue = "Changed Title"

        let result = try await viewModel.save(
            payload: .writeTags,
            scope: .allTracks,
            tagWriteOptions: saveOptions,
            albumArtPictures: [],
            editorSessionID: UUID()
        )

        #expect(result.trackReferences.count == 1)
        #expect(result.trackReferences.first?.filePath == changedFileURL.path)
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

    @MainActor
    func testFinderOpenRoutesToFocusedSessionWhenAppIsActive() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let sessionValue = EditorSessionValue(sessionID: UUID())
        coordinator.register(sessionValue: sessionValue, trackReferences: [])
        coordinator.markSessionFocused(sessionValue.sessionID)

        var deliveredURLs: [URL] = []
        coordinator.registerExternalOpenHandler(sessionID: sessionValue.sessionID) { urls in
            deliveredURLs = urls
        }

        let didRouteFiles = coordinator.routeFinderOpenedFiles(
            [
                URL(fileURLWithPath: "/tmp/Focused.flac"),
                URL(fileURLWithPath: "/tmp/ignored.txt")
            ],
            appIsActive: true
        )

        XCTAssertTrue(didRouteFiles)
        XCTAssertEqual(deliveredURLs.map(\.path), ["/tmp/Focused.flac"])
    }

    @MainActor
    func testFinderOpenCreatesNewWindowWhenAppIsInactive() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let existingSession = EditorSessionValue(sessionID: UUID())
        coordinator.register(sessionValue: existingSession, trackReferences: [])
        coordinator.markSessionFocused(existingSession.sessionID)

        var openedSession: EditorSessionValue?
        coordinator.setOpenEditorWindowAction { sessionValue in
            openedSession = sessionValue
        }
        var activationRequests = 0
        coordinator.setAppActivationHandlerForTesting {
            activationRequests += 1
        }

        let didRouteFiles = coordinator.routeFinderOpenedFiles(
            [URL(fileURLWithPath: "/tmp/inactive.flac")],
            appIsActive: false
        )

        XCTAssertTrue(didRouteFiles)
        XCTAssertNotNil(openedSession)
        XCTAssertNotEqual(openedSession?.sessionID, existingSession.sessionID)
        XCTAssertEqual(activationRequests, 1)
    }

    @MainActor
    func testFinderOpenCreatesNewEditorWindowWhenAppIsActiveWithoutEditorSession() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        var openedSession: EditorSessionValue?
        coordinator.setOpenEditorWindowAction { sessionValue in
            openedSession = sessionValue
        }

        let didRouteFiles = coordinator.routeFinderOpenedFiles(
            [URL(fileURLWithPath: "/tmp/settings-only.flac")],
            appIsActive: true
        )

        XCTAssertTrue(didRouteFiles)
        XCTAssertNotNil(openedSession)
    }

    @MainActor
    func testFinderOpenBringsExistingEditorWindowForwardWhenAppIsActive() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let sessionValue = EditorSessionValue(sessionID: UUID())
        coordinator.register(sessionValue: sessionValue, trackReferences: [])
        coordinator.markSessionFocused(sessionValue.sessionID)

        var openedSessions: [EditorSessionValue] = []
        coordinator.setOpenEditorWindowAction { sessionValue in
            openedSessions.append(sessionValue)
        }

        var deliveredURLs: [URL] = []
        coordinator.registerExternalOpenHandler(sessionID: sessionValue.sessionID) { urls in
            deliveredURLs = urls
        }

        let didRouteFiles = coordinator.routeFinderOpenedFiles(
            [URL(fileURLWithPath: "/tmp/bring-forward.flac")],
            appIsActive: true
        )

        XCTAssertTrue(didRouteFiles)
        XCTAssertEqual(openedSessions, [sessionValue])
        XCTAssertEqual(deliveredURLs.map(\.path), ["/tmp/bring-forward.flac"])
    }

    @MainActor
    func testFinderOpenQueuesFilesUntilNewSessionRegistersHandler() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let existingSession = EditorSessionValue(sessionID: UUID())
        coordinator.register(sessionValue: existingSession, trackReferences: [])

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let bURL = temporaryDirectory.appendingPathComponent("b.flac")
        let aURL = temporaryDirectory.appendingPathComponent("a.flac")
        FileManager.default.createFile(atPath: bURL.path, contents: Data())
        FileManager.default.createFile(atPath: aURL.path, contents: Data())

        var openedSession: EditorSessionValue?
        coordinator.setOpenEditorWindowAction { sessionValue in
            openedSession = sessionValue
        }

        let didRouteFiles = coordinator.routeFinderOpenedFiles(
            [
                bURL,
                aURL,
                aURL
            ],
            appIsActive: false
        )

        XCTAssertTrue(didRouteFiles)
        guard let openedSession else {
            XCTFail("Expected a new session to open.")
            return
        }

        coordinator.register(sessionValue: openedSession, trackReferences: [])

        var deliveredURLs: [URL] = []
        coordinator.registerExternalOpenHandler(sessionID: openedSession.sessionID) { urls in
            deliveredURLs = urls
        }

        XCTAssertNotEqual(openedSession.sessionID, existingSession.sessionID)
        XCTAssertEqual(deliveredURLs, [aURL.standardizedFileURL, bURL.standardizedFileURL])
    }

    @MainActor
    func testFinderOpenBeforeAnySessionBootstrapsFirstRegisteredHandler() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let didRouteFiles = coordinator.routeFinderOpenedFiles(
            [URL(fileURLWithPath: "/tmp/bootstrap.flac")],
            appIsActive: false
        )

        XCTAssertTrue(didRouteFiles)

        let firstSession = EditorSessionValue(sessionID: UUID())
        coordinator.register(sessionValue: firstSession, trackReferences: [])

        var deliveredURLs: [URL] = []
        coordinator.registerExternalOpenHandler(sessionID: firstSession.sessionID) { urls in
            deliveredURLs = urls
        }

        XCTAssertEqual(deliveredURLs.map(\.path), ["/tmp/bootstrap.flac"])
    }

    @MainActor
    func testSwiftTagDocumentOpenFocusesExistingAssociatedSession() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let sessionValue = EditorSessionValue(sessionID: UUID())
        let documentURL = URL(fileURLWithPath: "/tmp/existing-document.swifttag")
        coordinator.register(
            sessionValue: sessionValue,
            trackReferences: [],
            swiftTagDocumentURL: documentURL,
            swiftTagDocumentID: UUID()
        )

        var openedSessions: [EditorSessionValue] = []
        coordinator.setOpenEditorWindowAction { openedSession in
            openedSessions.append(openedSession)
        }

        var deliveredDocumentURL: URL?
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: sessionValue.sessionID) { url in
            deliveredDocumentURL = url
        }

        let didRouteDocuments = coordinator.routeOpenedSwiftTagDocuments([documentURL])

        XCTAssertTrue(didRouteDocuments)
        XCTAssertEqual(openedSessions, [sessionValue])
        XCTAssertNil(deliveredDocumentURL)
    }

    @MainActor
    func testEditorWindowCoordinatorRoutesMovedSwiftTagDocumentByDocumentID() throws {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        let originalDocumentURL = tempDirectoryURL
            .appendingPathComponent("coordinator-document")
            .appendingPathExtension(SwiftTagDocumentType.fileExtension)
        let saveResult = try SwiftTagDocumentPackageWriter.save(
            tracks: [
                SwiftTagDocumentExportTrack(
                    sortKey: "/tmp/track.flac",
                    tags: [TagKey.title: "Track"],
                    pictures: [],
                    sourceFileURL: URL(fileURLWithPath: "/tmp/track.flac"),
                    securityScopedBookmarkData: nil,
                    flacFingerprint: "fingerprint"
                )
            ],
            state: .init(),
            to: originalDocumentURL
        )

        let movedDirectoryURL = originalDocumentURL.deletingLastPathComponent()
            .appendingPathComponent("Moved", isDirectory: true)
        try FileManager.default.createDirectory(at: movedDirectoryURL, withIntermediateDirectories: true)
        let movedDocumentURL = movedDirectoryURL.appendingPathComponent(originalDocumentURL.lastPathComponent)
        try FileManager.default.moveItem(at: originalDocumentURL, to: movedDocumentURL)

        let sessionValue = EditorSessionValue(sessionID: UUID())
        coordinator.register(
            sessionValue: sessionValue,
            trackReferences: [],
            swiftTagDocumentURL: originalDocumentURL,
            swiftTagDocumentID: saveResult.documentID
        )

        var openedSessions: [EditorSessionValue] = []
        coordinator.setOpenEditorWindowAction { openedSession in
            openedSessions.append(openedSession)
        }
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: sessionValue.sessionID) { _ in }

        let didRouteDocuments = coordinator.routeOpenedSwiftTagDocuments([movedDocumentURL])

        XCTAssertTrue(didRouteDocuments)
        XCTAssertEqual(openedSessions, [sessionValue])
    }

    @MainActor
    func testSwiftTagDocumentOpenOpensNewWindowInsteadOfReusingUnusedWindow() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let unusedSession = EditorSessionValue(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        coordinator.register(sessionValue: unusedSession, trackReferences: [])

        var deliveredDocumentURL: URL?
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: unusedSession.sessionID) { url in
            deliveredDocumentURL = url
        }

        var openedSessions: [EditorSessionValue] = []
        coordinator.setOpenEditorWindowAction { sessionValue in
            openedSessions.append(sessionValue)
        }

        let documentURL = URL(fileURLWithPath: "/tmp/reused-window.swifttag")
        let didRouteDocuments = coordinator.routeOpenedSwiftTagDocuments([documentURL])

        XCTAssertTrue(didRouteDocuments)
        XCTAssertEqual(openedSessions.count, 1)
        XCTAssertNotEqual(openedSessions.first?.sessionID, unusedSession.sessionID)
        XCTAssertNil(deliveredDocumentURL)

        guard let openedSession = openedSessions.first else {
            XCTFail("Expected a new session to open.")
            return
        }

        coordinator.register(
            sessionValue: openedSession,
            trackReferences: [],
            swiftTagDocumentURL: documentURL,
            swiftTagDocumentID: UUID()
        )
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: openedSession.sessionID) { url in
            deliveredDocumentURL = url
        }

        XCTAssertEqual(deliveredDocumentURL?.path, documentURL.path)
    }

    @MainActor
    func testSwiftTagDocumentOpenOpensNewWindowsWhenUnusedWindowsAlreadyExist() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let firstUnusedSession = EditorSessionValue(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        let secondUnusedSession = EditorSessionValue(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        )
        coordinator.register(sessionValue: secondUnusedSession, trackReferences: [])
        coordinator.register(sessionValue: firstUnusedSession, trackReferences: [])

        var deliveredDocumentPathsBySessionID: [UUID: String] = [:]
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: firstUnusedSession.sessionID) { url in
            deliveredDocumentPathsBySessionID[firstUnusedSession.sessionID] = url.path
        }
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: secondUnusedSession.sessionID) { url in
            deliveredDocumentPathsBySessionID[secondUnusedSession.sessionID] = url.path
        }

        var openedSessions: [EditorSessionValue] = []
        coordinator.setOpenEditorWindowAction { sessionValue in
            openedSessions.append(sessionValue)
        }

        let didRouteDocuments = coordinator.routeOpenedSwiftTagDocuments([
            URL(fileURLWithPath: "/tmp/b.swifttag"),
            URL(fileURLWithPath: "/tmp/a.swifttag")
        ])

        XCTAssertTrue(didRouteDocuments)
        XCTAssertEqual(openedSessions.count, 2)
        XCTAssertFalse(openedSessions.contains(firstUnusedSession))
        XCTAssertFalse(openedSessions.contains(secondUnusedSession))
        XCTAssertTrue(deliveredDocumentPathsBySessionID.isEmpty)

        for (index, sessionValue) in openedSessions.enumerated() {
            let expectedURL = URL(fileURLWithPath: index == 0 ? "/tmp/a.swifttag" : "/tmp/b.swifttag")
            coordinator.register(
                sessionValue: sessionValue,
                trackReferences: [],
                swiftTagDocumentURL: expectedURL,
                swiftTagDocumentID: UUID()
            )
            coordinator.registerSwiftTagDocumentOpenHandler(sessionID: sessionValue.sessionID) { url in
                deliveredDocumentPathsBySessionID[sessionValue.sessionID] = url.path
            }
        }

        XCTAssertEqual(deliveredDocumentPathsBySessionID.count, 2)
        XCTAssertEqual(
            deliveredDocumentPathsBySessionID[openedSessions[0].sessionID],
            "/tmp/a.swifttag"
        )
        XCTAssertEqual(
            deliveredDocumentPathsBySessionID[openedSessions[1].sessionID],
            "/tmp/b.swifttag"
        )
    }

    @MainActor
    func testSwiftTagDocumentOpenQueuesDocumentUntilHandlerRegisters() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        var openedSession: EditorSessionValue?
        coordinator.setOpenEditorWindowAction { sessionValue in
            openedSession = sessionValue
        }

        let documentURL = URL(fileURLWithPath: "/tmp/queued-document.swifttag")
        let didRouteDocuments = coordinator.routeOpenedSwiftTagDocuments([documentURL])

        XCTAssertTrue(didRouteDocuments)
        guard let openedSession else {
            XCTFail("Expected a new session to open.")
            return
        }

        coordinator.register(
            sessionValue: openedSession,
            trackReferences: [],
            swiftTagDocumentURL: documentURL,
            swiftTagDocumentID: UUID()
        )

        var deliveredDocumentURL: URL?
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: openedSession.sessionID) { url in
            deliveredDocumentURL = url
        }

        XCTAssertEqual(deliveredDocumentURL?.path, documentURL.path)
    }

    @MainActor
    func testSwiftTagDocumentOpenDoesNotDeliverToUnassociatedLiveSession() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let staleUnusedSession = EditorSessionValue(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
        )
        coordinator.register(sessionValue: staleUnusedSession, trackReferences: [])

        let liveSession = EditorSessionValue(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!
        )
        coordinator.register(sessionValue: liveSession, trackReferences: [])

        var openedSessions: [EditorSessionValue] = []
        coordinator.setOpenEditorWindowAction(for: liveSession.sessionID) { sessionValue in
            openedSessions.append(sessionValue)
        }
        coordinator.registerExternalOpenHandler(sessionID: liveSession.sessionID) { _ in }
        var deliveredDocumentURL: URL?
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: liveSession.sessionID) { url in
            deliveredDocumentURL = url
        }

        let documentURL = URL(fileURLWithPath: "/tmp/new-window.swifttag")
        let didRouteDocuments = coordinator.routeOpenedSwiftTagDocuments([documentURL])

        XCTAssertTrue(didRouteDocuments)
        XCTAssertEqual(openedSessions.count, 1)
        XCTAssertNotEqual(openedSessions.first?.sessionID, liveSession.sessionID)
        XCTAssertNil(deliveredDocumentURL)

        guard let openedSession = openedSessions.first else {
            XCTFail("Expected a new session to open.")
            return
        }

        coordinator.register(
            sessionValue: openedSession,
            trackReferences: [],
            swiftTagDocumentURL: documentURL,
            swiftTagDocumentID: UUID()
        )
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: openedSession.sessionID) { url in
            deliveredDocumentURL = url
        }

        XCTAssertEqual(deliveredDocumentURL?.path, documentURL.path)
    }

    @MainActor
    func testSwiftTagDocumentOpenRoutesMultipleSelectionsDeterministically() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        var openedSessions: [EditorSessionValue] = []
        coordinator.setOpenEditorWindowAction { sessionValue in
            openedSessions.append(sessionValue)
        }

        let didRouteDocuments = coordinator.routeOpenedSwiftTagDocuments([
            URL(fileURLWithPath: "/tmp/b.swifttag"),
            URL(fileURLWithPath: "/tmp/a.swifttag"),
            URL(fileURLWithPath: "/tmp/a.swifttag")
        ])

        XCTAssertTrue(didRouteDocuments)
        XCTAssertEqual(openedSessions.count, 2)

        var deliveredDocumentPaths: [String] = []
        for (index, sessionValue) in openedSessions.enumerated() {
            coordinator.register(
                sessionValue: sessionValue,
                trackReferences: [],
                swiftTagDocumentURL: URL(fileURLWithPath: index == 0 ? "/tmp/a.swifttag" : "/tmp/b.swifttag"),
                swiftTagDocumentID: UUID()
            )
            coordinator.registerSwiftTagDocumentOpenHandler(sessionID: sessionValue.sessionID) { url in
                deliveredDocumentPaths.append(url.path)
            }
        }

        XCTAssertEqual(deliveredDocumentPaths, ["/tmp/a.swifttag", "/tmp/b.swifttag"])
    }

    @MainActor
    func testUnifiedOpenRoutingHandlesSwiftTagDocuments() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        var openedSessions: [EditorSessionValue] = []
        coordinator.setOpenEditorWindowAction { sessionValue in
            openedSessions.append(sessionValue)
        }

        let documentURL = URL(fileURLWithPath: "/tmp/routed-document.swifttag")
        let didRouteDocuments = coordinator.routeOpenedDocuments([documentURL], appIsActive: true)

        XCTAssertTrue(didRouteDocuments)
        XCTAssertEqual(openedSessions.count, 1)

        guard let openedSession = openedSessions.first else {
            XCTFail("Expected a new session to open.")
            return
        }

        coordinator.register(sessionValue: openedSession, trackReferences: [])

        var deliveredDocumentURL: URL?
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: openedSession.sessionID) { url in
            deliveredDocumentURL = url
        }

        XCTAssertEqual(deliveredDocumentURL?.path, documentURL.path)
    }

    @MainActor
    func testReopeningClosedSwiftTagDocumentUsesRemainingWindowRoutingAction() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let loadedSession = EditorSessionValue(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        )
        coordinator.register(
            sessionValue: loadedSession,
            trackReferences: [
                ImportedTrackReference(filePath: "/tmp/loaded.flac", securityScopedBookmarkData: nil)
            ]
        )
        coordinator.markSessionFocused(loadedSession.sessionID)

        var openedSessionsFromLoadedWindow: [EditorSessionValue] = []
        coordinator.setOpenEditorWindowAction(for: loadedSession.sessionID) { sessionValue in
            openedSessionsFromLoadedWindow.append(sessionValue)
        }

        let documentURL = URL(fileURLWithPath: "/tmp/reopen-sequence.swifttag")
        let firstOpenDidRoute = coordinator.routeOpenedDocuments([documentURL], appIsActive: true)

        XCTAssertTrue(firstOpenDidRoute)
        XCTAssertEqual(openedSessionsFromLoadedWindow.count, 1)

        guard let firstDocumentSession = openedSessionsFromLoadedWindow.first else {
            XCTFail("Expected the first document window to open.")
            return
        }

        coordinator.register(
            sessionValue: firstDocumentSession,
            trackReferences: [],
            swiftTagDocumentURL: documentURL,
            swiftTagDocumentID: UUID()
        )

        var firstDeliveredDocumentURL: URL?
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: firstDocumentSession.sessionID) { url in
            firstDeliveredDocumentURL = url
        }

        XCTAssertEqual(firstDeliveredDocumentURL?.path, documentURL.path)

        var openedSessionsFromClosedDocumentWindow: [EditorSessionValue] = []
        coordinator.setOpenEditorWindowAction(for: firstDocumentSession.sessionID) { sessionValue in
            openedSessionsFromClosedDocumentWindow.append(sessionValue)
        }

        coordinator.unregister(sessionID: firstDocumentSession.sessionID)

        let reopenedDidRoute = coordinator.routeOpenedDocuments([documentURL], appIsActive: true)

        XCTAssertTrue(reopenedDidRoute)
        XCTAssertEqual(openedSessionsFromClosedDocumentWindow.count, 0)
        XCTAssertEqual(openedSessionsFromLoadedWindow.count, 2)

        guard let reopenedSession = openedSessionsFromLoadedWindow.last else {
            XCTFail("Expected the reopened document window to open.")
            return
        }

        var reopenedDeliveredDocumentURL: URL?
        coordinator.register(sessionValue: reopenedSession, trackReferences: [])
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: reopenedSession.sessionID) { url in
            reopenedDeliveredDocumentURL = url
        }

        XCTAssertEqual(reopenedDeliveredDocumentURL?.path, documentURL.path)
    }

    @MainActor
    func testReopeningSwiftTagDocumentIgnoresStaleRegisteredSessionWithoutHandler() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let loadedSession = EditorSessionValue(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
        )
        coordinator.register(
            sessionValue: loadedSession,
            trackReferences: [
                ImportedTrackReference(filePath: "/tmp/loaded.flac", securityScopedBookmarkData: nil)
            ]
        )
        coordinator.markSessionFocused(loadedSession.sessionID)

        var openedSessionsFromLoadedWindow: [EditorSessionValue] = []
        coordinator.setOpenEditorWindowAction(for: loadedSession.sessionID) { sessionValue in
            openedSessionsFromLoadedWindow.append(sessionValue)
        }

        let documentURL = URL(fileURLWithPath: "/tmp/stale-reopen-sequence.swifttag")
        let firstOpenDidRoute = coordinator.routeOpenedDocuments([documentURL], appIsActive: true)

        XCTAssertTrue(firstOpenDidRoute)
        guard let staleDocumentSession = openedSessionsFromLoadedWindow.first else {
            XCTFail("Expected the first document window to open.")
            return
        }

        coordinator.register(
            sessionValue: staleDocumentSession,
            trackReferences: [],
            swiftTagDocumentURL: documentURL,
            swiftTagDocumentID: UUID()
        )

        let reopenedDidRoute = coordinator.routeOpenedDocuments([documentURL], appIsActive: true)

        XCTAssertTrue(reopenedDidRoute)
        XCTAssertEqual(openedSessionsFromLoadedWindow.count, 2)

        guard let reopenedSession = openedSessionsFromLoadedWindow.last else {
            XCTFail("Expected the reopened document window to open.")
            return
        }

        XCTAssertNotEqual(reopenedSession.sessionID, staleDocumentSession.sessionID)

        var reopenedDeliveredDocumentURL: URL?
        coordinator.register(sessionValue: reopenedSession, trackReferences: [])
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: reopenedSession.sessionID) { url in
            reopenedDeliveredDocumentURL = url
        }

        XCTAssertEqual(reopenedDeliveredDocumentURL?.path, documentURL.path)
    }

    @MainActor
    func testReopeningSwiftTagDocumentIgnoresSessionMarkedClosing() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let loadedSession = EditorSessionValue(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
        )
        coordinator.register(
            sessionValue: loadedSession,
            trackReferences: [
                ImportedTrackReference(filePath: "/tmp/loaded.flac", securityScopedBookmarkData: nil)
            ]
        )
        coordinator.markSessionFocused(loadedSession.sessionID)

        var openedSessionsFromLoadedWindow: [EditorSessionValue] = []
        coordinator.setOpenEditorWindowAction(for: loadedSession.sessionID) { sessionValue in
            openedSessionsFromLoadedWindow.append(sessionValue)
        }

        let documentURL = URL(fileURLWithPath: "/tmp/closing-reopen-sequence.swifttag")
        let firstOpenDidRoute = coordinator.routeOpenedDocuments([documentURL], appIsActive: true)

        XCTAssertTrue(firstOpenDidRoute)
        guard let closingDocumentSession = openedSessionsFromLoadedWindow.first else {
            XCTFail("Expected the first document window to open.")
            return
        }

        coordinator.register(
            sessionValue: closingDocumentSession,
            trackReferences: [],
            swiftTagDocumentURL: documentURL,
            swiftTagDocumentID: UUID()
        )
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: closingDocumentSession.sessionID) { _ in }
        coordinator.markSessionClosing(closingDocumentSession.sessionID)

        let reopenedDidRoute = coordinator.routeOpenedDocuments([documentURL], appIsActive: true)

        XCTAssertTrue(reopenedDidRoute)
        XCTAssertEqual(openedSessionsFromLoadedWindow.count, 2)

        guard let reopenedSession = openedSessionsFromLoadedWindow.last else {
            XCTFail("Expected the reopened document window to open.")
            return
        }

        XCTAssertNotEqual(reopenedSession.sessionID, closingDocumentSession.sessionID)

        var reopenedDeliveredDocumentURL: URL?
        coordinator.register(sessionValue: reopenedSession, trackReferences: [])
        coordinator.registerSwiftTagDocumentOpenHandler(sessionID: reopenedSession.sessionID) { url in
            reopenedDeliveredDocumentURL = url
        }

        XCTAssertEqual(reopenedDeliveredDocumentURL?.path, documentURL.path)
    }

    @MainActor
    func testFinderOpenRejectsUnsupportedBatches() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let didRouteFiles = coordinator.routeFinderOpenedFiles(
            [URL(fileURLWithPath: "/tmp/ignored.txt")],
            appIsActive: true
        )

        XCTAssertFalse(didRouteFiles)
    }

    @MainActor
    func testSwiftTagDocumentOpenRejectsUnsupportedBatches() {
        let coordinator = EditorWindowCoordinator.shared
        coordinator.resetForTesting()

        let didRouteDocuments = coordinator.routeOpenedSwiftTagDocuments([
            URL(fileURLWithPath: "/tmp/ignored.txt")
        ])

        XCTAssertFalse(didRouteDocuments)
    }
}
