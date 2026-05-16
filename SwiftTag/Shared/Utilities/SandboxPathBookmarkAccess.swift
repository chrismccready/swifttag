import Foundation

struct ResolvedSandboxPathBookmark {
    var folderURL: URL
    var isStale: Bool
}

enum SandboxPathBookmarkAccessError: LocalizedError {
    case failedToResolveBookmark(path: String)
    case failedToAccessFolder(path: String)
    case failedToRefreshBookmark(path: String)

    var errorDescription: String? {
        switch self {
        case let .failedToResolveBookmark(path):
            return "Failed to resolve sandbox path bookmark for \(path)."
        case let .failedToAccessFolder(path):
            return "Failed to access sandbox path \(path)."
        case let .failedToRefreshBookmark(path):
            return "Failed to refresh sandbox path bookmark for \(path)."
        }
    }
}

enum SandboxPathBookmarkAccess {
    typealias BookmarkResolver = (Data) throws -> ResolvedSandboxPathBookmark
    typealias AccessStarter = (URL) -> Bool
    typealias AccessStopper = (URL) -> Void
    typealias BookmarkRefresher = (URL) throws -> Data

    static func withAccess<T>(
        to targetURL: URL,
        userDefaults: UserDefaults = .standard,
        resolveBookmark: BookmarkResolver = defaultResolveBookmark,
        startAccessing: AccessStarter = { $0.startAccessingSecurityScopedResource() },
        stopAccessing: AccessStopper = { $0.stopAccessingSecurityScopedResource() },
        refreshBookmarkData: BookmarkRefresher = defaultRefreshBookmarkData,
        _ body: (URL) throws -> T
    ) throws -> T? {
        let normalizedTargetURL = URL(
            fileURLWithPath: SandboxPathSettingsStore.normalizedPath(for: targetURL)
        )
        let storedRecords = SandboxPathSettingsStore.records(userDefaults: userDefaults)
        guard let matchingRecord = storedRecords.first(where: {
            SandboxPathSettingsStore.isTargetPath(
                normalizedTargetURL.path,
                containedInFolderPath: $0.path
            )
        }) else {
            return nil
        }

        let resolvedBookmark: ResolvedSandboxPathBookmark
        do {
            resolvedBookmark = try resolveBookmark(matchingRecord.bookmarkData)
        } catch {
            throw SandboxPathBookmarkAccessError.failedToResolveBookmark(path: matchingRecord.path)
        }

        let resolvedFolderURL = URL(
            fileURLWithPath: SandboxPathSettingsStore.normalizedPath(for: resolvedBookmark.folderURL),
            isDirectory: true
        )

        guard startAccessing(resolvedFolderURL) else {
            throw SandboxPathBookmarkAccessError.failedToAccessFolder(path: resolvedFolderURL.path)
        }
        defer {
            stopAccessing(resolvedFolderURL)
        }

        if resolvedBookmark.isStale {
            do {
                let refreshedBookmarkData = try refreshBookmarkData(resolvedFolderURL)
                var updatedRecords = storedRecords
                if let recordIndex = updatedRecords.firstIndex(where: { $0.id == matchingRecord.id }) {
                    updatedRecords[recordIndex].path = resolvedFolderURL.path
                    updatedRecords[recordIndex].bookmarkData = refreshedBookmarkData
                    SandboxPathSettingsStore.saveRecords(updatedRecords, userDefaults: userDefaults)
                }
            } catch {
                throw SandboxPathBookmarkAccessError.failedToRefreshBookmark(path: matchingRecord.path)
            }
        }

        return try body(normalizedTargetURL)
    }

    nonisolated private static func defaultResolveBookmark(_ bookmarkData: Data) throws -> ResolvedSandboxPathBookmark {
        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        return ResolvedSandboxPathBookmark(
            folderURL: resolvedURL,
            isStale: isStale
        )
    }

    nonisolated private static func defaultRefreshBookmarkData(for folderURL: URL) throws -> Data {
        try folderURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}
