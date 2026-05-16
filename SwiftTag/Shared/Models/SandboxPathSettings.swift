import Foundation

struct SandboxPathBookmarkRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var path: String
    var bookmarkData: Data
    var dateAdded: Date

    init(
        id: UUID = UUID(),
        path: String,
        bookmarkData: Data,
        dateAdded: Date
    ) {
        self.id = id
        self.path = path
        self.bookmarkData = bookmarkData
        self.dateAdded = dateAdded
    }
}

enum SandboxPathSortMode: String, CaseIterable, Identifiable, Codable {
    case dateAdded
    case name

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dateAdded:
            return "Date Added"
        case .name:
            return "Name"
        }
    }
}

enum SandboxPathSettingsError: LocalizedError {
    case selectedPathIsNotFolder(path: String)
    case failedToAccessFolder(path: String)

    var errorDescription: String? {
        switch self {
        case let .selectedPathIsNotFolder(path):
            return "\(path) is not a folder."
        case let .failedToAccessFolder(path):
            return "Failed to access sandbox folder \(path)."
        }
    }
}

enum SandboxPathSettingsStore {
    static func records(userDefaults: UserDefaults = .standard) -> [SandboxPathBookmarkRecord] {
        guard let data = userDefaults.data(forKey: SaveSettingsKey.sandboxPathBookmarks),
              let decodedRecords = try? PropertyListDecoder().decode([SandboxPathBookmarkRecord].self, from: data) else {
            return SaveSettingsDefaults.sandboxPathBookmarks
        }

        return decodedRecords
    }

    static func saveRecords(
        _ records: [SandboxPathBookmarkRecord],
        userDefaults: UserDefaults = .standard
    ) {
        guard let data = try? PropertyListEncoder().encode(records) else {
            return
        }

        userDefaults.set(data, forKey: SaveSettingsKey.sandboxPathBookmarks)
    }

    static func sortMode(userDefaults: UserDefaults = .standard) -> SandboxPathSortMode {
        guard let rawValue = userDefaults.string(forKey: SaveSettingsKey.sandboxPathSortMode),
              let mode = SandboxPathSortMode(rawValue: rawValue) else {
            return SaveSettingsDefaults.sandboxPathSortMode
        }

        return mode
    }

    static func saveSortMode(
        _ mode: SandboxPathSortMode,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(mode.rawValue, forKey: SaveSettingsKey.sandboxPathSortMode)
    }

    static func normalizedPath(for fileURL: URL) -> String {
        fileURL
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    static func normalizedPath(for filePath: String) -> String? {
        let trimmedFilePath = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFilePath.isEmpty else {
            return nil
        }

        return normalizedPath(for: URL(fileURLWithPath: trimmedFilePath))
    }

    static func validateFolderURL(_ folderURL: URL) throws {
        let folderPath = normalizedPath(for: folderURL)
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw SandboxPathSettingsError.selectedPathIsNotFolder(path: folderPath)
        }
    }

    static func isTargetPath(
        _ targetPath: String,
        containedInFolderPath folderPath: String
    ) -> Bool {
        guard let normalizedTargetPath = normalizedPath(for: targetPath),
              let normalizedFolderPath = normalizedPath(for: folderPath) else {
            return false
        }

        return normalizedTargetPath == normalizedFolderPath ||
            normalizedTargetPath.hasPrefix("\(normalizedFolderPath)/")
    }

    static func sortedRecords(
        _ records: [SandboxPathBookmarkRecord],
        by sortMode: SandboxPathSortMode
    ) -> [SandboxPathBookmarkRecord] {
        records.sorted { lhs, rhs in
            switch sortMode {
            case .dateAdded:
                if lhs.dateAdded != rhs.dateAdded {
                    return lhs.dateAdded < rhs.dateAdded
                }
                return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            case .name:
                let lhsName = URL(fileURLWithPath: lhs.path).lastPathComponent
                let rhsName = URL(fileURLWithPath: rhs.path).lastPathComponent
                let nameOrder = lhsName.localizedStandardCompare(rhsName)
                if nameOrder != .orderedSame {
                    return nameOrder == .orderedAscending
                }
                return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }
        }
    }

    static func records(
        afterAddingFolderURLs folderURLs: [URL],
        to records: [SandboxPathBookmarkRecord],
        dateProvider: () -> Date = Date.init,
        bookmarkDataProvider: (URL) throws -> Data
    ) throws -> [SandboxPathBookmarkRecord] {
        var updatedRecords = records
        var knownPaths = Set(records.compactMap { normalizedPath(for: $0.path) })

        for folderURL in folderURLs {
            let normalizedURL = URL(fileURLWithPath: normalizedPath(for: folderURL), isDirectory: true)
            let normalizedFolderPath = normalizedURL.path
            guard !knownPaths.contains(normalizedFolderPath) else {
                continue
            }

            let bookmarkData = try bookmarkDataProvider(normalizedURL)
            updatedRecords.append(
                SandboxPathBookmarkRecord(
                    path: normalizedFolderPath,
                    bookmarkData: bookmarkData,
                    dateAdded: dateProvider()
                )
            )
            knownPaths.insert(normalizedFolderPath)
        }

        return updatedRecords
    }

    static func records(
        afterRemovingIDs selectedIDs: Set<SandboxPathBookmarkRecord.ID>,
        from records: [SandboxPathBookmarkRecord]
    ) -> [SandboxPathBookmarkRecord] {
        guard !selectedIDs.isEmpty else {
            return records
        }

        return records.filter { !selectedIDs.contains($0.id) }
    }
}
