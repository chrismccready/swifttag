import Foundation

struct Track: Identifiable {
    let id: UUID
    var tags: [String: String]
    var flacPicturesByType: [Int: Data]
    var sourceFileURL: URL?
    var securityScopedBookmarkData: Data?
    var latestFileSnapshot: TrackFileSnapshot?
    var externalDifferences: TrackExternalDifferences?
    var isLocked: Bool

    var isImportedFlacTrack: Bool {
        sourceFileURL?.pathExtension.lowercased() == "flac"
    }

    var importedTrackReference: ImportedTrackReference? {
        guard let sourceFileURL else {
            return nil
        }

        return ImportedTrackReference(
            filePath: sourceFileURL.path,
            securityScopedBookmarkData: securityScopedBookmarkData
        )
    }

    init(
        id: UUID = UUID(),
        tags: [String: String],
        flacPicturesByType: [Int: Data] = [:],
        sourceFileURL: URL? = nil,
        securityScopedBookmarkData: Data? = nil,
        latestFileSnapshot: TrackFileSnapshot? = nil,
        externalDifferences: TrackExternalDifferences? = nil,
        isLocked: Bool = false
    ) {
        self.id = id
        self.tags = tags
        self.flacPicturesByType = flacPicturesByType
        self.sourceFileURL = sourceFileURL
        self.securityScopedBookmarkData = securityScopedBookmarkData
        self.latestFileSnapshot = latestFileSnapshot
        self.externalDifferences = externalDifferences
        self.isLocked = isLocked
    }
}
