import Foundation
import Testing
@testable import SwiftTag

@MainActor
struct SandboxPathSettingsTests {
    private static var generalSettingsSourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SwiftTag")
            .appendingPathComponent("Features")
            .appendingPathComponent("Settings")
            .appendingPathComponent("GeneralSettingsView.swift")
    }

    private static func isolatedUserDefaults() throws -> (UserDefaults, String) {
        let suiteName = "SwiftTagTests.SandboxPaths.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        return (userDefaults, suiteName)
    }

    private static func temporaryDirectoryURL() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    @Test
    func sandboxPathRecordsEncodeDecodeThroughUserDefaults() throws {
        let (userDefaults, suiteName) = try Self.isolatedUserDefaults()
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let record = SandboxPathBookmarkRecord(
            id: UUID(),
            path: "/tmp/Music",
            bookmarkData: Data([1, 2, 3]),
            dateAdded: Date(timeIntervalSince1970: 123)
        )

        SandboxPathSettingsStore.saveRecords([record], userDefaults: userDefaults)

        #expect(SandboxPathSettingsStore.records(userDefaults: userDefaults) == [record])
    }

    @Test
    func sandboxPathStoreReturnsEmptyRecordsForMissingAndCorruptData() throws {
        let (userDefaults, suiteName) = try Self.isolatedUserDefaults()
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        #expect(SandboxPathSettingsStore.records(userDefaults: userDefaults).isEmpty)

        userDefaults.set(Data([0x00, 0x01]), forKey: SaveSettingsKey.sandboxPathBookmarks)

        #expect(SandboxPathSettingsStore.records(userDefaults: userDefaults).isEmpty)
    }

    @Test
    func sandboxPathSortModePersistsRawValueWithDefaultFallback() throws {
        let (userDefaults, suiteName) = try Self.isolatedUserDefaults()
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        #expect(SandboxPathSettingsStore.sortMode(userDefaults: userDefaults) == .dateAdded)

        SandboxPathSettingsStore.saveSortMode(.name, userDefaults: userDefaults)

        #expect(SandboxPathSettingsStore.sortMode(userDefaults: userDefaults) == .name)
    }

    @Test
    func sandboxPathBatchAddSkipsExistingAndBatchDuplicates() throws {
        let directoryURL = try Self.temporaryDirectoryURL()
        let existingRecord = SandboxPathBookmarkRecord(
            path: SandboxPathSettingsStore.normalizedPath(for: directoryURL),
            bookmarkData: Data([0x01]),
            dateAdded: Date(timeIntervalSince1970: 1)
        )
        var bookmarkCreationCount = 0

        let updatedRecords = try SandboxPathSettingsStore.records(
            afterAddingFolderURLs: [
                directoryURL,
                directoryURL.appendingPathComponent(".")
            ],
            to: [existingRecord]
        ) { _ in
            bookmarkCreationCount += 1
            return Data([0x02])
        }

        #expect(updatedRecords == [existingRecord])
        #expect(bookmarkCreationCount == 0)
    }

    @Test
    func sandboxPathBatchAddKeepsUniqueFoldersInPanelOrder() throws {
        let firstDirectoryURL = try Self.temporaryDirectoryURL()
        let secondDirectoryURL = try Self.temporaryDirectoryURL()
        var date = Date(timeIntervalSince1970: 10)

        let updatedRecords = try SandboxPathSettingsStore.records(
            afterAddingFolderURLs: [firstDirectoryURL, secondDirectoryURL],
            to: [],
            dateProvider: {
                defer {
                    date = date.addingTimeInterval(1)
                }
                return date
            }
        ) { folderURL in
            Data(folderURL.lastPathComponent.utf8)
        }

        #expect(updatedRecords.map(\.path) == [
            SandboxPathSettingsStore.normalizedPath(for: firstDirectoryURL),
            SandboxPathSettingsStore.normalizedPath(for: secondDirectoryURL)
        ])
        #expect(updatedRecords.map(\.dateAdded) == [
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 11)
        ])
    }

    @Test
    func sandboxPathContainmentRejectsPrefixOnlySiblingPaths() {
        #expect(SandboxPathSettingsStore.isTargetPath("/tmp/Music/song.flac", containedInFolderPath: "/tmp/Music"))
        #expect(SandboxPathSettingsStore.isTargetPath("/tmp/Music", containedInFolderPath: "/tmp/Music"))
        #expect(!SandboxPathSettingsStore.isTargetPath("/tmp/Music Archive/song.flac", containedInFolderPath: "/tmp/Music"))
    }

    @Test
    func sandboxPathRemovalDropsOnlySelectedRecords() {
        let firstID = UUID()
        let secondID = UUID()
        let firstRecord = SandboxPathBookmarkRecord(
            id: firstID,
            path: "/tmp/A",
            bookmarkData: Data([0x01]),
            dateAdded: Date(timeIntervalSince1970: 1)
        )
        let secondRecord = SandboxPathBookmarkRecord(
            id: secondID,
            path: "/tmp/B",
            bookmarkData: Data([0x02]),
            dateAdded: Date(timeIntervalSince1970: 2)
        )

        let updatedRecords = SandboxPathSettingsStore.records(
            afterRemovingIDs: [firstID],
            from: [firstRecord, secondRecord]
        )

        #expect(updatedRecords == [secondRecord])
    }

    @Test
    func sandboxPathSortingUsesNameAndDateAddedModes() {
        let olderZed = SandboxPathBookmarkRecord(
            path: "/tmp/Zed",
            bookmarkData: Data([0x01]),
            dateAdded: Date(timeIntervalSince1970: 1)
        )
        let newerAlpha = SandboxPathBookmarkRecord(
            path: "/tmp/Alpha",
            bookmarkData: Data([0x02]),
            dateAdded: Date(timeIntervalSince1970: 2)
        )

        #expect(SandboxPathSettingsStore.sortedRecords([newerAlpha, olderZed], by: .dateAdded) == [
            olderZed,
            newerAlpha
        ])
        #expect(SandboxPathSettingsStore.sortedRecords([olderZed, newerAlpha], by: .name) == [
            newerAlpha,
            olderZed
        ])
    }

    @Test
    func sandboxPathAccessReturnsNilWhenNoStoredFolderContainsTarget() throws {
        let (userDefaults, suiteName) = try Self.isolatedUserDefaults()
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let result = try SandboxPathBookmarkAccess.withAccess(
            to: URL(fileURLWithPath: "/tmp/outside/song.flac"),
            userDefaults: userDefaults,
            resolveBookmark: { _ in
                Issue.record("Resolver should not run without matching record.")
                return ResolvedSandboxPathBookmark(folderURL: URL(fileURLWithPath: "/tmp"), isStale: false)
            },
            startAccessing: { _ in false },
            stopAccessing: { _ in },
            refreshBookmarkData: { _ in Data() }
        ) { _ in
            true
        }

        #expect(result == nil)
    }

    @Test
    func sandboxPathAccessRefreshesStaleBookmarkAndBalancesAccess() throws {
        let (userDefaults, suiteName) = try Self.isolatedUserDefaults()
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let folderURL = try Self.temporaryDirectoryURL()
        let normalizedFolderPath = SandboxPathSettingsStore.normalizedPath(for: folderURL)
        let targetURL = URL(fileURLWithPath: normalizedFolderPath)
            .appendingPathComponent("song.flac")
        let record = SandboxPathBookmarkRecord(
            path: normalizedFolderPath,
            bookmarkData: Data([0x01]),
            dateAdded: Date(timeIntervalSince1970: 1)
        )
        SandboxPathSettingsStore.saveRecords([record], userDefaults: userDefaults)

        var didStopAccess = false
        let result = try SandboxPathBookmarkAccess.withAccess(
            to: targetURL,
            userDefaults: userDefaults,
            resolveBookmark: { bookmarkData in
                #expect(bookmarkData == Data([0x01]))
                return ResolvedSandboxPathBookmark(folderURL: folderURL, isStale: true)
            },
            startAccessing: { folder in
                #expect(folder.path == normalizedFolderPath)
                return true
            },
            stopAccessing: { folder in
                #expect(folder.path == normalizedFolderPath)
                didStopAccess = true
            },
            refreshBookmarkData: { folder in
                #expect(folder.path == normalizedFolderPath)
                return Data([0x02])
            }
        ) { scopedTargetURL in
            scopedTargetURL.path
        }

        let refreshedRecord = try #require(SandboxPathSettingsStore.records(userDefaults: userDefaults).first)
        #expect(result == targetURL.path)
        #expect(refreshedRecord.bookmarkData == Data([0x02]))
        #expect(didStopAccess)
    }

    @Test
    func generalSettingsSourceContainsSandboxPathControlsAndContextMenu() throws {
        let source = try String(contentsOf: Self.generalSettingsSourceURL, encoding: .utf8)

        #expect(source.contains("GroupBox(\"SwiftTag Sandbox Paths\")"))
        #expect(source.contains("SandboxPathListView("))
        #expect(source.contains("ScrollView(.vertical, showsIndicators: true)"))
        #expect(source.contains("LazyVStack(alignment: .leading, spacing: 0)"))
        #expect(source.contains("scrollBounceBehavior(.basedOnSize, axes: .vertical)"))
        #expect(source.contains("onModifierKeysChanged(mask: [.command, .shift]"))
        #expect(source.contains("activeEventModifiers.contains(.command)"))
        #expect(source.contains("activeEventModifiers.contains(.shift)"))
        #expect(source.contains("selectionAnchorID"))
        #expect(!source.contains("NSViewRepresentable"))
        #expect(!source.contains("NSScrollView"))
        #expect(!source.contains("NSTableView"))
        #expect(!source.contains("Table(sortedSandboxPathRecords"))
        #expect(!source.contains("TableColumn(\""))
        #expect(source.contains("settings.general.sandboxPaths.table"))
        #expect(source.contains("settings.general.sandboxPaths.addButton"))
        #expect(source.contains("settings.general.sandboxPaths.deleteButton"))
        #expect(source.contains("canChooseDirectories = true"))
        #expect(source.contains("canChooseFiles = false"))
        #expect(source.contains("Image(systemName: \"plus\")"))
        #expect(source.contains("Image(systemName: \"minus\")"))
        #expect(source.contains("width: plusMinusButtonSize.width"))
        #expect(source.contains("height: plusMinusButtonSize.height"))
        #expect(source.contains(".frame(height: 154)"))

        let documentSaveIndex = try #require(source.range(of: "SwiftTag Document Save")?.lowerBound)
        let sandboxPathsIndex = try #require(source.range(of: "SwiftTag Sandbox")?.lowerBound)
        #expect(documentSaveIndex < sandboxPathsIndex)

        let sortByNameIndex = try #require(source.range(of: "Sort by Name")?.lowerBound)
        let sortByDateAddedIndex = try #require(source.range(of: "Sort by Date Added")?.lowerBound)
        let dividerIndex = try #require(source.range(of: "Divider()")?.lowerBound)
        let addPathIndex = try #require(source.range(of: "Add Path…")?.lowerBound)
        let removePathIndex = try #require(source.range(of: "Remove Path")?.lowerBound)
        #expect(sortByNameIndex < sortByDateAddedIndex)
        #expect(sortByDateAddedIndex < dividerIndex)
        #expect(dividerIndex < addPathIndex)
        #expect(addPathIndex < removePathIndex)
    }
}
